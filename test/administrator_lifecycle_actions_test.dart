import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_lifecycle_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_lifecycle_models.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_students_models.dart';
import 'package:schoolos_app/features/administrator/presentation/administrator_lifecycle_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const admin = SchoolMembership(id: 'm-admin', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.administrator);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late AdministratorLifecycleRepository lifecycle;
  late AdministratorStudentsRepository students;

  Future<void> setUpSchool([SchoolMembership who = admin]) async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([admin, teacher]);
    await session.selectSchool(who);
    lifecycle = AdministratorLifecycleRepository(localDatabase: db, schoolSession: session);
    students = AdministratorStudentsRepository(localDatabase: db, schoolSession: session);
  }

  Future<AdministratorStudentRecord> student(String id) async =>
      (await students.load()).students.firstWhere((s) => s.id == id);

  Future<AdministratorLifecycleRecord> record(String id) async =>
      (await lifecycle.load()).records.firstWhere((r) => r.id == id);

  tearDown(() => db.close());

  test('the demo school has a real register, and every lifecycle record refers to a student who exists', () async {
    await setUpSchool();
    final register = (await students.load()).students;
    expect(register.length, greaterThan(15));
    for (final r in (await lifecycle.load()).records.where((r) => !r.isAlumni)) {
      expect(register.any((s) => s.id == r.student), isTrue, reason: '${r.studentName} (${r.student})');
    }
  });

  test('a class change is started, completed, and puts the student in the new class', () async {
    await setUpSchool();
    final ruth = await student('STU-006');
    final started = await lifecycle.request(student: ruth, workflow: 'Class change', toClass: 'SS1C');
    expect(started.success, isTrue, reason: started.message);
    expect((await student('STU-006')).className, ruth.className, reason: 'nothing moves until it is completed');

    final done = await lifecycle.complete(started.record!);
    expect(done.success, isTrue, reason: done.message);
    expect((await student('STU-006')).className, 'SS1C');
    expect(db.pendingCount(tenantId: admin.schoolId), greaterThan(0));
  });

  test('a change is refused when it makes no sense: no class, same class, twice, unknown kind, or a student who left', () async {
    await setUpSchool();
    final ruth = await student('STU-006');
    expect((await lifecycle.request(student: ruth, workflow: 'Class change')).message, contains('which class'));
    expect((await lifecycle.request(student: ruth, workflow: 'Promotion', toClass: ruth.className)).message, contains('already in'));
    expect((await lifecycle.request(student: ruth, workflow: 'Expulsion')).success, isFalse);

    expect((await lifecycle.request(student: ruth, workflow: 'Class change', toClass: 'SS1C')).success, isTrue);
    expect((await lifecycle.request(student: ruth, workflow: 'Class change', toClass: 'SS1D')).message, contains('already has a pending'));

    final left = ruth.copyWith(status: AdministratorStudentStatus.transferredOut);
    expect((await lifecycle.request(student: left, workflow: 'Class change', toClass: 'SS2A')).message, contains('already left'));
  });

  test('a promotion is an academic decision: it cannot be processed without who approved it', () async {
    await setUpSchool();
    final promotion = await record('PRI-006');
    expect(promotion.isPromotion, isTrue);
    final refused = await lifecycle.complete(promotion);
    expect(refused.success, isFalse);
    expect(refused.message, contains('academic decision'));
    expect((await student('PRI-006')).className, 'Primary 6');

    final done = await lifecycle.complete(promotion, approvedBy: 'Mr. Ibrahim Danladi (Principal)');
    expect(done.success, isTrue, reason: done.message);
    expect((await student('PRI-006')).className, 'JSS 1');
    expect((await record('PRI-006')).approvedBy, contains('Danladi'));
  });

  test('a transfer out needs the records pack, shows as pending meanwhile, then takes the student off the active register', () async {
    await setUpSchool();
    final transfer = await record('STU-003');
    expect((await student('STU-003')).status, AdministratorStudentStatus.transferPending);

    final early = await lifecycle.complete(transfer);
    expect(early.success, isFalse);
    expect(early.message, contains('records pack'));

    final ready = await lifecycle.markRecordsPackReady(transfer);
    expect(ready.success, isTrue);
    final done = await lifecycle.complete(ready.record!);
    expect(done.success, isTrue, reason: done.message);
    expect((await student('STU-003')).status, AdministratorStudentStatus.transferredOut);
    expect((await student('STU-003')).className, 'JSS 2B', reason: 'the class they left from is kept');
  });

  test('cancelling a transfer puts the student back to active and keeps the record with its reason', () async {
    await setUpSchool();
    final transfer = await record('STU-003');
    final cancelled = await lifecycle.cancel(transfer, 'Family is staying');
    expect(cancelled.success, isTrue);
    expect((await student('STU-003')).status, AdministratorStudentStatus.active);
    final kept = await record('STU-003');
    expect(kept.status, AdministratorLifecycleStatus.cancelled);
    expect(kept.note, 'Family is staying');
    expect((await lifecycle.cancel(kept, '')).message, contains('not pending'));
  });

  test('history is appended: two moves leave both on record and the latest class wins', () async {
    await setUpSchool();
    final ruth = await student('STU-006');
    final first = (await lifecycle.request(student: ruth, workflow: 'Class change', toClass: 'SS1C')).record!;
    await lifecycle.complete(first);
    final second = (await lifecycle.request(student: await student('STU-006'), workflow: 'Promotion', toClass: 'SS2A')).record!;
    await lifecycle.complete(second, approvedBy: 'Principal');
    expect((await student('STU-006')).className, 'SS2A');
    final done = (await lifecycle.load()).records.where((r) => r.student == 'STU-006' && r.status == AdministratorLifecycleStatus.completed);
    expect(done.length, greaterThanOrEqualTo(3), reason: 'the demo history plus these two');
  });

  test('only an administrator may change a student\'s class or status', () async {
    await setUpSchool(teacher);
    final ruth = await student('STU-006');
    final refused = await lifecycle.request(student: ruth, workflow: 'Class change', toClass: 'SS1C');
    expect(refused.success, isFalse);
    expect(refused.message, contains('administrator'));
  });

  testWidgets('the lifecycle desk completes a pending class change from its Open dialog', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(setUpSchool);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdministratorLifecyclePage(schoolName: 'BrightGate', repository: lifecycle, students: students),
      ),
    ));
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
    }

    await settle();
    expect(find.byKey(const ValueKey('lifecycle-new')), findsOneWidget);
    expect(find.text('Abdullahi Umar'), findsOneWidget);

    // Abdullahi Umar's class change is the third row; its Open button opens the dialog.
    final row = find.ancestor(of: find.text('Abdullahi Umar'), matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: row, matching: find.text('Open')));
    await tester.pumpAndSettle();
    expect(find.text('Complete'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lifecycle-complete')));
    await settle();
    await tester.pumpAndSettle();

    late AdministratorStudentRecord umar;
    await tester.runAsync(() async => umar = await student('STU-005'));
    expect(umar.className, 'SS1B');
  });
}
