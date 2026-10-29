import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_ai_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_assessment_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_assignment_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_roster.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_assessment_models.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_assignment_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const _teacher = SchoolMembership(id: 'm-teacher-1', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late TeacherAiRepository ai;

  setUp(() async {
    LocalDatabase.blockDemoSeeds = true;
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([_teacher]);
    await session.selectSchool(_teacher);
    final roster = TeacherRoster(
      database: db,
      session: session,
      students: AdministratorStudentsRepository(localDatabase: db, schoolSession: session),
    );
    ai = TeacherAiRepository(
      localDatabase: db,
      schoolSession: session,
      roster: roster,
      assignments: TeacherAssignmentRepository(localDatabase: db, schoolSession: session),
      assessments: TeacherAssessmentRepository(localDatabase: db, schoolSession: session, roster: roster),
    );
  });

  tearDown(() {
    LocalDatabase.blockDemoSeeds = false;
    db.close();
  });

  Future<void> seedAssignment(TeacherAssignment assignment) => db.upsertLocalRecord(
        tenantId: _teacher.schoolId,
        entityType: teacherAssignmentEntityType,
        entityId: assignment.id,
        payload: assignment.toJson(),
        serverVersion: 1,
      );

  Future<void> seedAssessment(TeacherAssessment assessment) => db.upsertLocalRecord(
        tenantId: _teacher.schoolId,
        entityType: teacherAssessmentEntityType,
        entityId: assessment.id,
        payload: assessment.toJson(),
        serverVersion: 1,
      );

  test('with no real assignments or assessments, there is honestly nothing to suggest', () async {
    final snapshot = await ai.load();
    expect(snapshot.suggestedActions, isEmpty);
  });

  test('a real published assignment with unmarked submissions becomes a real suggested action', () async {
    await seedAssignment(const TeacherAssignment(
      id: 'A-1',
      title: 'Fractions quiz',
      className: 'JSS 2B',
      type: TeacherAssignmentType.classwork,
      instructions: 'x',
      dueDate: '2026-10-20',
      maximumScore: 20,
      submissions: 5,
      totalStudents: 30,
      marked: 2,
      lateSubmissions: 0,
      state: TeacherAssignmentState.published,
      authorMembershipId: 'm-teacher-1',
    ));
    final actions = (await ai.load()).suggestedActions;
    expect(actions, hasLength(1));
    expect(actions.single.title, 'Fractions quiz · JSS 2B');
    expect(actions.single.description, '3 submissions still need marking.');
    expect(actions.single.destination, 'assignments');
  });

  test('a fully-marked assignment, or one still in draft, suggests nothing', () async {
    await seedAssignment(const TeacherAssignment(
      id: 'A-2',
      title: 'Fully marked',
      className: 'JSS 2B',
      type: TeacherAssignmentType.classwork,
      instructions: 'x',
      dueDate: '2026-10-20',
      maximumScore: 20,
      submissions: 5,
      totalStudents: 30,
      marked: 5,
      lateSubmissions: 0,
      state: TeacherAssignmentState.published,
      authorMembershipId: 'm-teacher-1',
    ));
    await seedAssignment(const TeacherAssignment(
      id: 'A-3',
      title: 'Still drafting',
      className: 'JSS 2B',
      type: TeacherAssignmentType.classwork,
      instructions: 'x',
      dueDate: '2026-10-20',
      maximumScore: 20,
      submissions: 5,
      totalStudents: 30,
      marked: 0,
      lateSubmissions: 0,
      state: TeacherAssignmentState.draft,
      authorMembershipId: 'm-teacher-1',
    ));
    expect((await ai.load()).suggestedActions, isEmpty);
  });

  test('a real published assessment with incomplete score entry becomes a real suggested action', () async {
    await seedAssessment(const TeacherAssessment(
      id: 'AS-1',
      title: 'Mid-term test',
      className: 'JSS 2B',
      subject: 'Mathematics',
      type: TeacherAssessmentType.test,
      maximumScore: 100,
      state: TeacherAssessmentState.published,
      entries: [],
      totalStudents: 28,
      entered: 20,
      authorMembershipId: 'm-teacher-1',
    ));
    final actions = (await ai.load()).suggestedActions;
    expect(actions, hasLength(1));
    expect(actions.single.title, 'Mid-term test · JSS 2B');
    expect(actions.single.description, '8 scores still need entering.');
    expect(actions.single.destination, 'assessments');
  });

  test('a fully-entered, or a released, assessment suggests nothing', () async {
    await seedAssessment(const TeacherAssessment(
      id: 'AS-2',
      title: 'Fully entered',
      className: 'JSS 2B',
      subject: 'Mathematics',
      type: TeacherAssessmentType.test,
      maximumScore: 100,
      state: TeacherAssessmentState.published,
      entries: [],
      totalStudents: 28,
      entered: 28,
      authorMembershipId: 'm-teacher-1',
    ));
    await seedAssessment(const TeacherAssessment(
      id: 'AS-3',
      title: 'Released with a late addition',
      className: 'JSS 2B',
      subject: 'Mathematics',
      type: TeacherAssessmentType.test,
      maximumScore: 100,
      state: TeacherAssessmentState.released,
      entries: [],
      totalStudents: 28,
      entered: 20,
      authorMembershipId: 'm-teacher-1',
    ));
    expect((await ai.load()).suggestedActions, isEmpty);
  });

  test('only this teacher\'s own real assignments and assessments are ever suggested', () async {
    await seedAssignment(const TeacherAssignment(
      id: 'A-4',
      title: 'Someone else\'s assignment',
      className: 'SS1A',
      type: TeacherAssignmentType.classwork,
      instructions: 'x',
      dueDate: '2026-10-20',
      maximumScore: 20,
      submissions: 5,
      totalStudents: 30,
      marked: 0,
      lateSubmissions: 0,
      state: TeacherAssignmentState.published,
      authorMembershipId: 'someone-else',
    ));
    expect((await ai.load()).suggestedActions, isEmpty);
  });
}
