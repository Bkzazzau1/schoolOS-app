import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_students_demo_data.dart';
import 'package:schoolos_app/features/principal/data/principal_students_repository.dart';
import 'package:schoolos_app/features/principal/domain/principal_students_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const principal = SchoolMembership(id: 'm-principal', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.principal);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late PrincipalStudentsRepository principalStudents;

  Future<void> setUpSchool([SchoolMembership who = principal]) async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([principal, teacher]);
    await session.selectSchool(who);
    principalStudents = PrincipalStudentsRepository(
      localDatabase: database,
      schoolSession: session,
      students: AdministratorStudentsRepository(localDatabase: database, schoolSession: session),
    );
  }

  tearDown(() => db?.close());

  test('full student profile exposes all eleven website tabs', () {
    expect(principalStudentProfileTabs.length, 11);
    expect(principalStudentProfileTabs.first, 'Overview');
    expect(principalStudentProfileTabs, contains('Status & Promotion'));
    expect(principalStudentProfileTabs.last, 'Notes');
  });

  test('Principal student authority remains Secondary and finance restricted', () {
    expect(principalStudentsScopeBoundary, contains('Secondary School'));
    expect(principalStudentsScopeBoundary, contains('Primary'));
  });

  test('notes, lifecycle, health and AI boundaries prevent silent high-impact actions', () {
    expect(principalStudentNoteBoundary, contains('internal'));
    expect(principalStudentNoteBoundary, contains('guardian'));
    expect(principalStudentLifecycleBoundary, contains('append-only'));
    expect(principalStudentLifecycleBoundary, contains('not silently overwritten'));
    expect(principalStudentHealthBoundary, contains('never be used to infer a diagnosis'));
    expect(principalStudentAiBoundary, contains('must not automatically'));
    expect(principalStudentAiBoundary, contains('punish'));
  });

  test('the directory is the real register, limited to Secondary, with no invented risk or incident evidence', () async {
    await setUpSchool();
    final snapshot = await principalStudents.load();
    // Hafsa Abdullahi (Primary 3) and every Nursery/Primary student must not appear: Principal oversight is
    // Secondary-only. Maryam, Ibrahim and Yusuf (JSS 2A/2B) must appear alongside the rest of the real
    // Secondary register (JSS 1, JSS 3A, SS1A, SS2A, SS2B, SS3A students).
    expect(snapshot.students.map((s) => s.name), isNot(contains('Hafsa Abdullahi')));
    expect(snapshot.students.map((s) => s.name), containsAll(['Maryam Abdullahi', 'Ibrahim Sani', 'Yusuf Bello']));
    expect(snapshot.students.every((s) => !s.className.toLowerCase().startsWith('primary')), isTrue);
    expect(snapshot.students.every((s) => !s.className.toLowerCase().startsWith('nursery')), isTrue);
    for (final student in snapshot.students) {
      expect(student.average, 0);
      expect(student.attendance, 0);
      expect(student.trend, 0);
      expect(student.incidents, 0);
      expect(student.interventions, 0);
      expect(student.risk, PrincipalStudentRisk.stable, reason: 'nobody is given an alarming label from nothing');
      expect(student.behaviour, PrincipalStudentBehaviour.good);
      expect(student.concern, contains('No assessment, attendance or incident history'));
    }
    expect(snapshot.classOptions, ['JSS 1', 'JSS 2', 'JSS 2A', 'JSS 2B', 'JSS 3A', 'SS1A', 'SS2A', 'SS2B', 'SS3A']);
  });

  test('a student profile has real identity but honest, empty fields where no real source exists', () async {
    await setUpSchool();
    final profile = await principalStudents.loadProfile('STU-001');
    expect(profile, isNotNull);
    expect(profile!.summary.name, 'Maryam Abdullahi');
    expect(profile.summary.className, 'JSS 2A');
    expect(profile.admissionNo, 'Not recorded yet');
    expect(profile.subjects, isEmpty);
    expect(profile.attendanceSummary, isEmpty);
    expect(profile.timeline, isEmpty);
    expect(profile.documents, isEmpty);
  });

  test('a Primary student is outside Principal scope and has no profile', () async {
    await setUpSchool();
    expect(await principalStudents.loadProfile('PRI-003'), isNull);
  });

  test('a leadership note round-trips and queues for sync', () async {
    await setUpSchool();
    final saved = await principalStudents.saveLeadershipNote(studentId: 'STU-001', note: 'Discussed with class teacher.');
    expect(saved.success, isTrue, reason: saved.message);
    expect(await principalStudents.loadLeadershipNote('STU-001'), 'Discussed with class teacher.');
    expect(db!.pendingCount(tenantId: principal.schoolId), greaterThan(0));
  });

  test('a lifecycle proposal is queued and requires a reason', () async {
    await setUpSchool();
    final refused = await principalStudents.createLifecycleProposal(
      studentId: 'STU-001', actionType: 'Promote', nextClassOrDestination: 'JSS 3A', effectiveSession: '2026/2027', reason: '',
    );
    expect(refused.success, isFalse);

    final saved = await principalStudents.createLifecycleProposal(
      studentId: 'STU-001', actionType: 'Promote', nextClassOrDestination: 'JSS 3A', effectiveSession: '2026/2027', reason: 'End of year promotion',
    );
    expect(saved.success, isTrue, reason: saved.message);
    expect(db!.pendingCount(tenantId: principal.schoolId), greaterThan(0));
  });

  test('only the principal has Secondary student oversight authority', () async {
    await setUpSchool(teacher);
    expect(await principalStudents.loadProfile('STU-001'), isNull);
    final result = await principalStudents.saveLeadershipNote(studentId: 'STU-001', note: 'x');
    expect(result.success, isFalse);
  });
}
