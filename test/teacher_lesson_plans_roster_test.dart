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

  // Standalone demo mode no longer filters the sample lesson-plan scheme by the signed-in teacher's
  // real assigned classes: it is one fixed, honestly-labelled sample set for any teacher, since real
  // class-scoped authorization now lives in the canonical occurrence system instead (see
  // TeacherLessonPlanRepository's own doc comment on why `roster` is unused there).
  test('demo mode shows the same fixed sample scheme regardless of the signed-in teacher', () async {
    await setUpSchool(mathsTeacher);
    final forMathsTeacher = await lessonPlans.load();
    expect(forMathsTeacher.canonical, isFalse);
    expect(forMathsTeacher.classOptions, ['JSS 2A', 'JSS 2B', 'JSS 3A', 'SS1A']);
    expect(forMathsTeacher.plans, hasLength(4));

    await setUpSchool(newTeacher);
    final forNewTeacher = await lessonPlans.load();
    expect(forNewTeacher.classOptions, forMathsTeacher.classOptions);
    expect(forNewTeacher.plans.map((p) => p.id), forMathsTeacher.plans.map((p) => p.id));
  });

  test('creating a canonical occurrence plan is honestly refused outside server-backed mode', () async {
    await setUpSchool(mathsTeacher);
    const occurrence = TeacherLessonPlanOccurrenceOption(
      timetableEntryId: 'entry-1',
      lessonDate: '2026-09-25',
      classSubjectId: 'subject-1',
      termId: 'term-1',
      className: 'JSS 2A',
      subject: 'Mathematics',
      time: '8:00',
      room: 'B12',
      periodNumber: 1,
      topics: [TeacherLessonPlanTopicOption(id: 'topic-1', title: 'Linear Equations', sequence: 1)],
    );
    final result = await lessonPlans.createPlan(occurrence: occurrence, topic: occurrence.topics.single);
    expect(result.success, isFalse);
    expect(result.message, contains('server-backed timetable'));
  });

  test('a demo draft can be saved by any signed-in teacher; a locked (non-draft) plan cannot', () async {
    await setUpSchool(mathsTeacher);
    final snapshot = await lessonPlans.load();
    final draft = snapshot.plans.singleWhere((p) => p.status == TeacherLessonPlanStatus.draft);
    final approved = snapshot.plans.singleWhere((p) => p.status == TeacherLessonPlanStatus.approved);

    final saved = await lessonPlans.saveDraft(plan: draft.copyWith(objectives: 'Updated objectives'));
    expect(saved.success, isTrue, reason: saved.message);
    expect(saved.plan!.objectives, 'Updated objectives');

    final refused = await lessonPlans.saveDraft(plan: approved.copyWith(objectives: 'Should not save'));
    expect(refused.success, isFalse);
    expect(refused.message, contains('not editable'));
  });
}
