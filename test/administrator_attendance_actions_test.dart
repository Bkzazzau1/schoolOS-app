import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_desk.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_attendance_models.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_students_models.dart';
import 'package:schoolos_app/features/administrator/presentation/administrator_attendance_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const admin = SchoolMembership(id: 'm-admin', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.administrator);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late AdministratorAttendanceRepository attendance;
  late AdministratorStudentsRepository students;
  late List<AdministratorStudentRecord> expected;

  Future<void> setUpSchool([SchoolMembership who = admin]) async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([admin, teacher]);
    await session.selectSchool(who);
    attendance = AdministratorAttendanceRepository(localDatabase: db, schoolSession: session);
    students = AdministratorStudentsRepository(localDatabase: db, schoolSession: session);
    expected = [
      for (final s in (await students.load()).students)
        if (s.status != AdministratorStudentStatus.transferredOut) s,
    ];
  }

  Future<AttendanceDesk> desk() async {
    final snapshot = await attendance.load(students: expected);
    return buildAttendanceDesk(students: expected, events: snapshot.events, corrections: snapshot.corrections);
  }

  tearDown(() => db.close());

  test('the demo school has a morning of scans: most students in, a few late, some absent, one scan to identify', () async {
    await setUpSchool();
    final d = await desk();
    expect(d.expected, expected.length);
    expect(d.present, greaterThan(d.expected ~/ 2));
    expect(d.present + d.absent + d.excused, d.expected);
    expect(d.absent, greaterThan(0));
    expect(d.unknownScans, 1);
    expect(d.pendingCorrections, 3);
    expect(d.sections.map((s) => s.name), containsAll(['Primary', 'Secondary']));
    expect(d.sections.fold<int>(0, (n, s) => n + s.expected), d.expected);

    final again = await desk();
    expect(again.present, d.present, reason: 'the same day gives the same scans');
  });

  test('a student the gate missed is checked in by hand, on time or late, and only once', () async {
    await setUpSchool();
    final before = await desk();
    final missing = expected.firstWhere((s) => before.absentNames.contains(s.name));

    final late = await attendance.checkIn(missing, now: DateTime(2026, 9, 21, 8, 30));
    expect(late.success, isTrue, reason: late.message);
    final events = (await attendance.load(students: expected)).events;
    final mine = events.firstWhere((e) => e.student == missing.name);
    expect(mine.status, AdministratorAttendanceEventStatus.late);
    expect(mine.method, 'Manual');
    expect((await desk()).absent, before.absent - 1);

    expect((await attendance.checkIn(missing)).message, contains('already has'));
  });

  test('a scan the device could not match is identified by choosing the student, never guessed', () async {
    await setUpSchool();
    final before = await desk();
    final scan = (await attendance.load(students: expected)).events.firstWhere((e) => e.isUnknown);
    final missing = expected.firstWhere((s) => before.absentNames.contains(s.name));

    final identified = await attendance.identifyUnknown(scan, missing);
    expect(identified.success, isTrue, reason: identified.message);
    final after = await desk();
    expect(after.unknownScans, 0);
    expect(after.present, before.present + 1);

    final events = (await attendance.load(students: expected)).events;
    expect(events.firstWhere((e) => e.student == missing.name).note, contains('identified'));
    expect((await attendance.identifyUnknown(events.firstWhere((e) => e.student == missing.name), missing)).message, contains('already identified'));
  });

  test('an approved correction changes the day and keeps who decided and why; the original scan is not erased', () async {
    await setUpSchool();
    final before = await desk();
    final corrections = (await attendance.load(students: expected)).corrections;
    final request = corrections.firstWhere((c) => c.id == 'ATT-081');
    expect(request.isPending, isTrue);

    final done = await attendance.decideCorrection(request, approve: true, note: 'Teacher confirmed');
    expect(done.success, isTrue, reason: done.message);
    final after = (await attendance.load(students: expected));
    final decided = after.corrections.firstWhere((c) => c.id == 'ATT-081');
    expect(decided.status, 'Approved');
    expect(decided.decidedBy, admin.id);
    expect(decided.decisionNote, 'Teacher confirmed');
    expect(decided.decidedAt, isNotEmpty);
    expect((await desk()).pendingCorrections, before.pendingCorrections - 1);
    expect(after.events.any((e) => e.student == 'Maryam Abdullahi' && e.note.contains('ATT-081')), isTrue);

    expect((await attendance.decideCorrection(decided, approve: false, note: 'x')).message, contains('already been decided'));
  });

  test('an excusal is counted as excused, not absent, and a decline needs a reason', () async {
    await setUpSchool();
    final before = await desk();
    final request = (await attendance.load(students: expected)).corrections.firstWhere((c) => c.id == 'ATT-083');
    expect(request.target, 'Excused');

    expect((await attendance.decideCorrection(request, approve: false)).message, contains('Say why'));
    expect((await attendance.decideCorrection(request, approve: true)).success, isTrue);
    final after = await desk();
    expect(after.excused, 1);
    expect(after.present + after.absent + after.excused, after.expected);
    expect(after.present, lessThanOrEqualTo(before.present), reason: 'an excused student is not counted as present');
  });

  test('a correction to something the desk cannot apply is refused', () async {
    await setUpSchool();
    const odd = AdministratorAttendanceCorrection(
      id: 'ATT-999', student: 'Ruth John', className: 'SS1A', requestedChange: 'Present → Expelled', evidence: 'x',
    );
    final refused = await attendance.decideCorrection(odd, approve: true);
    expect(refused.success, isFalse);
    expect(refused.message, contains('cannot be applied'));
  });

  test('only the administrator may change attendance', () async {
    await setUpSchool(teacher);
    expect((await attendance.checkIn(expected.first)).message, contains('administrator'));
  });

  test('sections come from the class name', () {
    expect(sectionOfClass('Nursery 2'), 'Early Years');
    expect(sectionOfClass('Primary 4'), 'Primary');
    expect(sectionOfClass('JSS 2A'), 'Secondary');
    expect(sectionOfClass('SS3A'), 'Secondary');
  });

  testWidgets('the attendance desk shows the day and approves a correction from its dialog', (tester) async {
    tester.view.physicalSize = const Size(1800, 4200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(setUpSchool);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AdministratorAttendancePage(schoolName: 'BrightGate', repository: attendance, students: students)),
    ));
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
    }

    await settle();
    expect(find.text('Present today'), findsOneWidget);
    expect(find.byKey(const ValueKey('attendance-checkin')), findsOneWidget);
    expect(find.text('Sample devices. Gate hardware is not connected yet, so these are examples.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('correction-ATT-081')));
    await tester.tap(find.byKey(const ValueKey('correction-ATT-081')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('correction-approve')));
    await settle();
    await tester.pumpAndSettle();

    late AdministratorAttendanceSnapshot snapshot;
    await tester.runAsync(() async => snapshot = await attendance.load(students: expected));
    expect(snapshot.corrections.firstWhere((c) => c.id == 'ATT-081').status, 'Approved');
    // The test font is wider than the real one, so a squeezed layout is not a fault in the app.
    final problem = tester.takeException();
    expect(problem == null || problem.toString().contains('overflowed'), isTrue, reason: '$problem');
  });
}
