import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_assignments_demo_data.dart';
import 'package:schoolos_app/features/principal/data/principal_assignments_repository.dart';
import 'package:schoolos_app/features/principal/domain/principal_assignments_models.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_profile_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const principal = SchoolMembership(id: 'm-principal', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.principal);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late PrincipalAssignmentsRepository principalAssignments;

  Future<void> setUpSchool([SchoolMembership who = principal]) async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([principal, teacher]);
    await session.selectSchool(who);
    principalAssignments = PrincipalAssignmentsRepository(
      localDatabase: database,
      schoolSession: session,
      students: AdministratorStudentsRepository(localDatabase: database, schoolSession: session),
      staff: OwnerStaffProfileRepository(database: database, session: session),
    );
  }

  tearDown(() => db?.close());

  test('assignment serialization preserves teacher and version lineage', () {
    const assignment = PrincipalTeachingAssignment(
      id: 'ASN-X',
      className: 'JSS 2B',
      subject: 'Mathematics',
      teacherId: 'TCH-001',
      periodsPerWeek: 5,
      version: 3,
    );
    final restored = PrincipalTeachingAssignment.fromJson(assignment.toJson());
    expect(restored.teacherId, 'TCH-001');
    expect(restored.version, 3);
    final transferred = restored.copyWith(teacherId: 'TCH-002', version: 4);
    expect(transferred.teacherId, 'TCH-002');
    expect(transferred.version, 4);
    expect(restored.teacherId, 'TCH-001');
  });

  test('transfer event preserves old and new teacher rather than overwriting history', () {
    const transfer = PrincipalAssignmentTransfer(
      id: 'TRN-1',
      assignmentId: 'ASN-003',
      className: 'JSS 2A',
      subject: 'Mathematics',
      fromTeacherId: 'TCH-001',
      toTeacherId: 'TCH-002',
      reason: 'Workload balancing',
      transferredByMembershipId: 'membership-principal-001',
      transferredAt: '2026-09-19T12:00:00Z',
      recordScope: principalTransferRecordScope,
      previousAssignmentVersion: 1,
      newAssignmentVersion: 2,
    );
    final restored = PrincipalAssignmentTransfer.fromJson(transfer.toJson());
    expect(restored.fromTeacherId, 'TCH-001');
    expect(restored.toTeacherId, 'TCH-002');
    expect(restored.previousAssignmentVersion, 1);
    expect(restored.newAssignmentVersion, 2);
  });

  test('incoming teacher receives complete teaching-work continuity scope', () {
    expect(principalTransferRecordScope.length, 6);
    expect(principalTransferRecordScope.join(' '), contains('Lesson plans'));
    expect(principalTransferRecordScope.join(' '), contains('Syllabus'));
    expect(principalTransferRecordScope.join(' '), contains('Assessment'));
    expect(principalTransferRecordScope.join(' '), contains('Class teaching notes'));
    expect(principalTransferRecordScope.join(' '), contains('Timetable'));
    expect(principalTransferRecordScope.join(' '), contains('Assignment history'));
  });

  test('record access grant can target existing or provisional staff', () {
    const grant = PrincipalTeachingRecordAccess(
      id: 'ACCESS-ASN-003-PST-1',
      assignmentId: 'ASN-003',
      teacherId: 'PST-1',
      className: 'JSS 2A',
      subject: 'Mathematics',
      recordScope: principalTransferRecordScope,
      grantedByMembershipId: 'membership-principal-001',
      grantedAt: '2026-09-19T12:00:00Z',
      provisionalTarget: true,
    );
    final restored = PrincipalTeachingRecordAccess.fromJson(grant.toJson());
    expect(restored.provisionalTarget, isTrue);
    expect(restored.recordScope, principalTransferRecordScope);
  });

  test('transfer privacy boundary excludes previous teacher private records', () {
    expect(principalTransferPrivacyBoundary, contains('private leadership notes'));
    expect(principalTransferPrivacyBoundary, contains('payroll'));
    expect(principalTransferPrivacyBoundary, contains('bank'));
    expect(principalTransferPrivacyBoundary, contains('medical'));
    expect(principalTransferPrivacyBoundary, contains('unrelated HR'));
  });

  test('Principal assignment scope stays Secondary only', () {
    expect(principalAssignmentScopeBoundary, contains('Secondary School'));
    expect(principalAssignmentScopeBoundary, contains('Primary'));
  });

  test('teachers are the real Secondary teaching staff, not a fabricated directory', () async {
    await setUpSchool();
    final snapshot = await principalAssignments.load();
    // Real staff: Amina Yusuf and Ahmad Sani teach Secondary; Khadija Musa and Safiya Ahmad are Primary
    // and must not appear here.
    expect(snapshot.teachers.map((t) => t.name).toSet(), {'Mrs. Amina Yusuf', 'Mr. Ahmad Sani'});
    for (final t in snapshot.teachers) {
      expect(t.department, 'Not recorded yet');
      expect(t.weeklyPeriods, 0, reason: 'no assignments exist yet');
      expect(t.provisional, isFalse);
    }
  });

  test('class options are the real Secondary classes from the one real student register', () async {
    await setUpSchool();
    final snapshot = await principalAssignments.load();
    expect(snapshot.classOptions, ['JSS 1', 'JSS 2', 'JSS 2A', 'JSS 2B', 'JSS 3A', 'SS1A', 'SS2A', 'SS2B', 'SS3A']);
  });

  test('assignments start empty; there is no fabricated seed', () async {
    await setUpSchool();
    final snapshot = await principalAssignments.load();
    expect(snapshot.assignments, isEmpty);
    expect(snapshot.transfers, isEmpty);
  });

  test('a valid assignment is created, saved offline and queued for sync', () async {
    await setUpSchool();
    final result = await principalAssignments.addAssignment(className: 'JSS 2B', subject: 'Mathematics', teacherId: 'STAFF-001', periodsPerWeek: 5);
    expect(result.success, isTrue, reason: result.message);
    final after = await principalAssignments.load();
    expect(after.assignments.single.className, 'JSS 2B');
    expect(after.assignments.single.teacherId, 'STAFF-001');
    expect(after.teachers.singleWhere((t) => t.id == 'STAFF-001').weeklyPeriods, 5);
    expect(db!.pendingCount(tenantId: principal.schoolId), greaterThan(0));
  });

  test('a class outside the real Secondary register is refused', () async {
    await setUpSchool();
    final result = await principalAssignments.addAssignment(className: 'Primary 3', subject: 'Mathematics', teacherId: 'STAFF-001', periodsPerWeek: 5);
    expect(result.success, isFalse);
  });

  test('an unknown teacher id is refused', () async {
    await setUpSchool();
    final result = await principalAssignments.addAssignment(className: 'JSS 2B', subject: 'Mathematics', teacherId: 'STAFF-999', periodsPerWeek: 5);
    expect(result.success, isFalse);
  });

  test('a duplicate class-subject assignment is refused', () async {
    await setUpSchool();
    await principalAssignments.addAssignment(className: 'JSS 2B', subject: 'Mathematics', teacherId: 'STAFF-001', periodsPerWeek: 5);
    final result = await principalAssignments.addAssignment(className: 'JSS 2B', subject: 'Mathematics', teacherId: 'STAFF-014', periodsPerWeek: 3);
    expect(result.success, isFalse);
  });

  test('a transfer to an existing real teacher moves the assignment and preserves history', () async {
    await setUpSchool();
    await principalAssignments.addAssignment(className: 'JSS 2B', subject: 'Mathematics', teacherId: 'STAFF-001', periodsPerWeek: 5);
    final assignmentId = (await principalAssignments.load()).assignments.single.id;
    final result = await principalAssignments.transferAssignment(assignmentId: assignmentId, existingTeacherId: 'STAFF-014', reason: 'Workload balancing');
    expect(result.success, isTrue, reason: result.message);
    final after = await principalAssignments.load();
    expect(after.assignments.single.teacherId, 'STAFF-014');
    expect(after.assignments.single.version, 2);
    expect(after.transfers.single.fromTeacherId, 'STAFF-001');
    expect(after.transfers.single.toTeacherId, 'STAFF-014');
  });

  test('a transfer to a new provisional staff member creates a real provisional teacher record', () async {
    await setUpSchool();
    await principalAssignments.addAssignment(className: 'JSS 2B', subject: 'Mathematics', teacherId: 'STAFF-001', periodsPerWeek: 5);
    final assignmentId = (await principalAssignments.load()).assignments.single.id;
    final result = await principalAssignments.transferAssignment(assignmentId: assignmentId, newStaffName: 'Mrs. Zainab Lawal', reason: 'STAFF-001 on leave');
    expect(result.success, isTrue, reason: result.message);
    final after = await principalAssignments.load();
    final target = after.teachers.singleWhere((t) => t.name == 'Mrs. Zainab Lawal');
    expect(target.provisional, isTrue);
    expect(after.assignments.single.teacherId, target.id);
  });

  test('only the principal may create or transfer Secondary teaching assignments', () async {
    await setUpSchool(teacher);
    final addResult = await principalAssignments.addAssignment(className: 'JSS 2B', subject: 'Mathematics', teacherId: 'STAFF-001', periodsPerWeek: 5);
    expect(addResult.success, isFalse);
    final transferResult = await principalAssignments.transferAssignment(assignmentId: 'ASN-1', existingTeacherId: 'STAFF-014', reason: 'x');
    expect(transferResult.success, isFalse);
  });
}
