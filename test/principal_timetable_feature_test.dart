import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_assignments_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_timetable_repository.dart';
import 'package:schoolos_app/features/principal/domain/principal_timetable_models.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_profile_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const principal = SchoolMembership(id: 'm-principal', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.principal);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late PrincipalTimetableRepository timetable;
  late PrincipalAssignmentsRepository assignments;

  Future<void> setUpSchool([SchoolMembership who = principal]) async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([principal, teacher]);
    await session.selectSchool(who);
    assignments = PrincipalAssignmentsRepository(
      localDatabase: database,
      schoolSession: session,
      students: AdministratorStudentsRepository(localDatabase: database, schoolSession: session),
      staff: OwnerStaffProfileRepository(database: database, session: session),
    );
    timetable = PrincipalTimetableRepository(localDatabase: database, schoolSession: session, assignments: assignments);
  }

  tearDown(() => db?.close());

  test('a fresh demo school has no real per-period schedule, room use or exceptions', () async {
    await setUpSchool();
    final snapshot = await timetable.load();
    expect(snapshot.lessons, isEmpty);
    expect(snapshot.roomUse, isEmpty);
    expect(snapshot.exceptionStates, isEmpty);
    expect(snapshot.exceptionEvents, isEmpty);
    expect(snapshot.substitutionCount, 0);
    expect(snapshot.uncoveredCount, 0);
    expect(snapshot.clashCount, 0);
  });

  test('teacher workload lists every real Secondary teacher at zero periods with no invented schedule', () async {
    await setUpSchool();
    final snapshot = await timetable.load();
    // Real staff: Amina Yusuf and Ahmad Sani teach Secondary (see Teachers/Assignments fixes).
    expect(snapshot.teacherLoads.map((row) => row.name).toSet(), {'Mrs. Amina Yusuf', 'Mr. Ahmad Sani'});
    for (final row in snapshot.teacherLoads) {
      expect(row.lessons, 0);
      expect(row.status, 'Light');
    }
  });

  test('real teaching assignments raise that teacher\'s real weekly period count', () async {
    await setUpSchool();
    for (final className in ['JSS 2B', 'JSS 2A', 'JSS 1']) {
      final result = await assignments.addAssignment(className: className, subject: 'Mathematics', teacherId: 'STAFF-001', periodsPerWeek: 10);
      expect(result.success, isTrue, reason: result.message);
    }
    final snapshot = await timetable.load();
    final amina = snapshot.teacherLoads.singleWhere((row) => row.name == 'Mrs. Amina Yusuf');
    expect(amina.lessons, 30);
    expect(amina.status, 'Heavy', reason: '30 periods is above the fixed weekly target');
  });

  test('handling a timetable exception is honestly refused: nothing real exists to handle', () async {
    await setUpSchool();
    final result = await timetable.setExceptionHandled(lessonId: 'TT-1', handled: true);
    expect(result.success, isFalse);
  });

  test('only the principal has Secondary timetable authority', () async {
    await setUpSchool(teacher);
    final snapshot = await timetable.load();
    expect(snapshot.teacherLoads, isEmpty);
    final result = await timetable.setExceptionHandled(lessonId: 'TT-1', handled: true);
    expect(result.success, isFalse);
  });

  test('lesson and exception model serialization round-trips', () {
    const lesson = PrincipalTimetableLesson(
      id: 'TT-101',
      day: 'Monday',
      time: '8:00 - 8:40',
      className: 'JSS 2A',
      subject: 'Mathematics',
      teacher: 'Mrs. Amina Yusuf',
      room: 'B12',
      status: PrincipalTimetableStatus.scheduled,
    );
    final restored = PrincipalTimetableLesson.fromJson(lesson.toJson());
    expect(restored.id, 'TT-101');
    expect(restored.status, PrincipalTimetableStatus.scheduled);

    const state = PrincipalTimetableExceptionState(
      lessonId: 'TT-104',
      handled: true,
      updatedByMembershipId: 'MEM-PRINCIPAL-01',
      updatedAt: '2026-09-19T17:20:00Z',
    );
    final restoredState = PrincipalTimetableExceptionState.fromJson(state.toJson());
    expect(restoredState.handled, isTrue);
    expect(restoredState.updatedByMembershipId, 'MEM-PRINCIPAL-01');

    const event = PrincipalTimetableExceptionEvent(
      id: 'TT-104-1',
      lessonId: 'TT-104',
      action: PrincipalTimetableExceptionAction.handled,
      actorMembershipId: 'MEM-PRINCIPAL-01',
      occurredAt: '2026-09-19T17:20:00Z',
    );
    final restoredEvent = PrincipalTimetableExceptionEvent.fromJson(event.toJson());
    expect(restoredEvent.action, PrincipalTimetableExceptionAction.handled);
    expect(restoredEvent.actorMembershipId, 'MEM-PRINCIPAL-01');
  });

  test('principal timetable boundary text stays Secondary-scoped', () {
    expect(principalTimetableAuthorityBoundary, contains('Secondary School'));
    expect(principalTimetableExceptionBoundary, contains('do not silently reassign'));
    expect(principalTimetableAuditBoundary, contains('timestamp'));
    expect(principalTimetableAiBoundary, contains('must not silently alter'));
  });
}
