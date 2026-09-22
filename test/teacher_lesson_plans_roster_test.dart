import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_lesson_plan_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_roster.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_lesson_plan_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

// Has JSS 2A, JSS 2B and SS1A assigned in TeacherRoster's demo data.
const mathsTeacher = SchoolMembership(id: 'membership-teacher-003', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

// Has no demo class assignment at all.
const newTeacher = SchoolMembership(id: 'm-new-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late TeacherRoster roster;
  late TeacherLessonPlanRepository lessonPlans;

  Future<void> setUpSchool(SchoolMembership who) async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([mathsTeacher, newTeacher]);
    await session.selectSchool(who);
    roster = TeacherRoster(
      database: db,
      session: session,
      students: AdministratorStudentsRepository(localDatabase: db, schoolSession: session),
    );
    lessonPlans = TeacherLessonPlanRepository(localDatabase: db, schoolSession: session, roster: roster);
  }

  tearDown(() => db.close());

  test('sample plans and the class options are filtered to the teacher\'s real assigned classes', () async {
    await setUpSchool(mathsTeacher);
    final snapshot = await lessonPlans.load();
    // The sample scheme includes a JSS 3A plan (LP-201), which is not assigned to this teacher.
    expect(snapshot.plans.any((p) => p.className == 'JSS 3A'), isFalse);
    expect(snapshot.plans.every((p) => snapshot.classOptions.contains(p.className)), isTrue);
    expect(snapshot.classOptions, ['JSS 2A', 'JSS 2B', 'SS1A']);
  });

  test('a teacher with no assigned classes sees an honest empty list, not a crash', () async {
    await setUpSchool(newTeacher);
    final snapshot = await lessonPlans.load();
    expect(snapshot.plans, isEmpty);
    expect(snapshot.classOptions, isEmpty);
  });

  test('a new plan can only be created for a real assigned class', () async {
    await setUpSchool(mathsTeacher);
    final refused = await lessonPlans.createPlan(className: 'JSS 3A', week: 'Week 6', topic: 'Linear Equations');
    expect(refused.success, isFalse);
    expect(refused.message, contains('not assigned to this class'));

    final result = await lessonPlans.createPlan(className: 'SS1A', week: 'Week 7', topic: 'Word Problems');
    expect(result.success, isTrue, reason: result.message);
    expect(result.plan!.className, 'SS1A');
    expect(result.plan!.status, TeacherLessonPlanStatus.draft);

    final snapshot = await lessonPlans.load();
    expect(snapshot.plans.any((p) => p.id == result.plan!.id), isTrue);
  });

  test('saving a draft for a class the teacher is no longer assigned to is refused', () async {
    await setUpSchool(mathsTeacher);
    final created = await lessonPlans.createPlan(className: 'JSS 2A', week: 'Week 6', topic: 'Linear Equations');
    final foreign = created.plan!.copyWith(className: 'JSS 3A');
    final result = await lessonPlans.saveDraft(plan: foreign);
    expect(result.success, isFalse);
    expect(result.message, contains('not one of your assigned classes'));
  });
}
