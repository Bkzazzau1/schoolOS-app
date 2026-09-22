import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/principal/data/principal_teachers_demo_data.dart';
import 'package:schoolos_app/features/principal/data/principal_teachers_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_profile_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const principal = SchoolMembership(id: 'm-principal', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.principal);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late PrincipalTeachersRepository principalTeachers;

  Future<void> setUpSchool([SchoolMembership who = principal]) async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([principal, teacher]);
    await session.selectSchool(who);
    principalTeachers = PrincipalTeachersRepository(
      localDatabase: database,
      schoolSession: session,
      staff: OwnerStaffProfileRepository(database: database, session: session),
    );
  }

  tearDown(() => db?.close());

  test('ten website staff profile tabs are preserved', () {
    expect(principalStaffProfileTabs.length, 10);
    expect(principalStaffProfileTabs, ['Overview', 'Employment', 'Qualifications', 'Teaching Load', 'Attendance', 'Leave', 'Documents', 'Timeline', 'Leadership Notes', 'Payroll Access']);
  });

  test('principal teacher scope stays Secondary only and payroll restricted', () {
    expect(principalTeacherGuidance['SECTION SCOPE'], contains('Secondary teachers only'));
    expect(principalTeacherPayrollBoundary, contains('Salary amount'));
    expect(principalTeacherPayrollBoundary, contains('bank account'));
    expect(principalTeacherPayrollBoundary, contains('staff-loan'));
  });

  test('support guidance blocks single-score and automatic high-stakes decisions', () {
    expect(principalTeacherGuidance['SUPPORT FIRST'], contains('coaching'));
    expect(principalTeacherGuidance['SUPPORT FIRST'], contains('rather than reducing quality to one score'));
    expect(principalTeacherDecisionBoundary, contains('Do not use AI or a single metric'));
    expect(principalTeacherDecisionBoundary, contains('firing'));
    expect(principalTeacherDecisionBoundary, contains('disciplinary'));
  });

  test('the directory is the real staff register, limited to Secondary teaching staff, with no invented evidence', () async {
    await setUpSchool();
    final snapshot = await principalTeachers.load();
    // Real staff: Amina Yusuf and Ahmad Sani teach Secondary; Khadija Musa and Safiya Ahmad are Primary and
    // must not appear here.
    expect(snapshot.teachers.map((t) => t.name).toSet(), {'Mrs. Amina Yusuf', 'Mr. Ahmad Sani'});
    for (final t in snapshot.teachers) {
      expect(t.classes, 0);
      expect(t.students, 0);
      expect(t.lessonPlans, 0);
      expect(t.syllabus, 0);
      expect(t.assessments, 0);
      expect(t.status, 'Not evaluated', reason: 'nobody is given an evaluative label from nothing');
      expect(t.department, 'Not recorded yet');
    }
    expect(snapshot.profiles.map((p) => p.directoryId).toSet(), snapshot.teachers.map((t) => t.id).toSet());
  });

  test('a teacher profile has real identity and role but honest, empty fields where no real source exists', () async {
    await setUpSchool();
    final snapshot = await principalTeachers.load();
    final amina = snapshot.profiles.singleWhere((p) => p.name == 'Mrs. Amina Yusuf');
    expect(amina.jobTitle, 'Teacher');
    expect(amina.section, 'Secondary');
    expect(amina.subjects, isEmpty);
    expect(amina.assignments, isEmpty);
    expect(amina.leave, isEmpty);
    expect(amina.timeline, isEmpty);
    expect(amina.payrollId, 'Not recorded yet');
  });

  test('a private note round-trips and queues for sync', () async {
    await setUpSchool();
    final snapshot = await principalTeachers.load();
    final id = snapshot.teachers.first.id;
    final saved = await principalTeachers.savePrivateNote(teacherId: id, text: 'Discussed workload.');
    expect(saved.success, isTrue, reason: saved.message);
    final after = await principalTeachers.load();
    expect(after.notes[id]?.text, 'Discussed workload.');
    expect(db!.pendingCount(tenantId: principal.schoolId), greaterThan(0));
  });

  test('only the principal may save private teacher notes', () async {
    await setUpSchool(teacher);
    final result = await principalTeachers.savePrivateNote(teacherId: 'STAFF-001', text: 'x');
    expect(result.success, isFalse);
  });
}
