import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_learning_progress_demo_data.dart';
import 'package:schoolos_app/features/teacher/data/teacher_learning_progress_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_learning_progress_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_learning_progress_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

const _teacher = SchoolMembership(
  id: 'teacher-1',
  schoolId: 'school-1',
  schoolName: 'BrightGate Academy',
  role: SchoolRole.teacher,
);

void main() {
  test('evidence flow and interpretation principles are present and unchanged', () {
    expect(teacherLearningEvidenceFlow, hasLength(5));
    expect(teacherLearningEvidenceFlow.first, ('Classwork', 'Daily understanding'));
    expect(teacherLearningEvidenceFlow.last,
        ('Learning Intelligence', 'Topic trend + next action'));
    expect(teacherLearningInterpretationPrinciples, hasLength(4));
  });

  test('topic combined evidence and weakest/strongest calculations', () {
    const student = TeacherLearningStudentEvidence(
      id: 'stu-1',
      name: 'Learner One',
      className: 'JSS 2A',
      subject: 'Mathematics',
      average: 0,
      attendance: 0,
      topics: [
        TeacherLearningTopicEvidence(name: 'Fractions', classwork: 58, assignment: 61, assessment: 60, cbt: 62, trend: 3),
        TeacherLearningTopicEvidence(name: 'Algebra', classwork: 88, assignment: 91, assessment: 89, cbt: 92, trend: 6),
      ],
    );
    expect(student.topics[0].combined, 60);
    expect(student.weakestTopic.name, 'Fractions');
    expect(student.strongestTopic.name, 'Algebra');
    expect(student.strongestTopic.combined, 90);
    expect(student.topics[0].isDeclining, isFalse);

    const declining = TeacherLearningTopicEvidence(
      name: 'Geometry', classwork: 40, assignment: 38, assessment: 35, cbt: 37, trend: -4,
    );
    expect(declining.isDeclining, isTrue);
  });

  test('learning evidence serializes without losing topic-level detail', () {
    const student = TeacherLearningStudentEvidence(
      id: 'stu-1',
      name: 'Learner One',
      className: 'JSS 2A',
      subject: 'Mathematics',
      average: 0,
      attendance: 0,
      topics: [
        TeacherLearningTopicEvidence(name: 'Fractions', classwork: 58, assignment: 61, assessment: 60, cbt: 62, trend: 3),
      ],
    );
    final restored = TeacherLearningStudentEvidence.fromJson(student.toJson());
    expect(restored.id, 'stu-1');
    expect(restored.topics, hasLength(1));
    expect(restored.topics.first.name, 'Fractions');
    expect(restored.topics.first.cbt, 62);
  });

  test('Learning Intelligence governance forbids deterministic child judgments', () {
    expect(teacherLearningGovernanceBoundary, contains('permanent intelligence level'));
    expect(teacherLearningGovernanceBoundary, contains('publicly rank children'));
    expect(teacherLearningGovernanceBoundary, contains('diagnose a condition'));
    expect(teacherLearningGovernanceBoundary, contains('promotion'));
    expect(teacherLearningGovernanceBoundary, contains('punishment'));
    expect(teacherLearningEvidenceBoundary, contains('not a deterministic label'));
    expect(teacherLearningOfflineBoundary, contains('does not rewrite'));
    expect(teacherLearningOfflineBoundary, contains('Source modules remain authoritative'));
  });

  test('teacher permissions allow review but never ranking diagnosis or decisions', () {
    final fake = _FakeLearningProgressRepository();
    const parent = SchoolMembership(
      id: 'parent-1',
      schoolId: 'school-1',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.parent,
    );
    final permissions = fake.permissionsFor(_teacher);
    expect(permissions.canViewAssignedLearners, isTrue);
    expect(permissions.canViewMultiEvidence, isTrue);
    expect(permissions.canSuggestSupport, isTrue);
    expect(permissions.canPubliclyRankChildren, isFalse);
    expect(permissions.canDiagnoseCondition, isFalse);
    expect(permissions.canMakePromotionDecision, isFalse);
    expect(permissions.canMakePunishmentDecision, isFalse);
    expect(fake.permissionsFor(parent).canViewAssignedLearners, isFalse);
  });

  testWidgets('Learning Progress renders real students with an honest no-evidence note, not invented scores', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherLearningProgressPage(
            repository: _FakeLearningProgressRepository(),
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Learning Progress & Performance'), findsOneWidget);
    expect(find.text('2'), findsWidgets); // Students tracked + Assigned classes KPIs
    expect(find.text('Learner One'), findsWidgets);
    expect(find.textContaining('No classwork, assignment, assessment or CBT evidence'), findsWidgets);
    expect(find.textContaining('No support actions are suggested yet'), findsOneWidget);
    expect(find.text('Topic evidence matrix'), findsOneWidget);
    expect(find.text('Learning Intelligence rule'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Learning Progress connected actions route to dedicated Teacher modules', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? destination;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherLearningProgressPage(
            repository: _FakeLearningProgressRepository(),
            onNavigate: (value) => destination = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Assignments'));
    await tester.pump();
    expect(destination, 'assignments');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Assessments'));
    await tester.pump();
    expect(destination, 'assessments');
    await tester.tap(find.widgetWithText(OutlinedButton, 'CBT Practice'));
    await tester.pump();
    expect(destination, 'cbt');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Students'));
    await tester.pump();
    expect(destination, 'students');
  });

  testWidgets('a teacher with no assigned classes sees an honest empty state, not a crash', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherLearningProgressPage(
            repository: _EmptyFakeLearningProgressRepository(),
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No classes are assigned to you yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Learning Progress renders on phone without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherLearningProgressPage(
            repository: _FakeLearningProgressRepository(),
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Students'), findsWidgets);
    // The rest of the page is below the fold on a phone viewport, so scroll to it rather than
    // asserting on unmounted off-screen widgets.
    await tester.scrollUntilVisible(find.text('Evidence interpretation'), 400);
    await tester.pumpAndSettle();
    expect(find.text('Evidence interpretation'), findsOneWidget);
    expect(find.text('Teacher action queue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeLearningProgressRepository implements TeacherLearningProgressRepository {
  final students = const [
    TeacherLearningStudentEvidence(
      id: 'stu-1',
      name: 'Learner One',
      className: 'JSS 2A',
      subject: 'Mathematics',
      average: 0,
      attendance: 0,
      topics: [],
    ),
    TeacherLearningStudentEvidence(
      id: 'stu-2',
      name: 'Learner Two',
      className: 'JSS 2B',
      subject: 'Mathematics',
      average: 0,
      attendance: 0,
      topics: [],
    ),
  ];
  final classOptions = const ['JSS 2A', 'JSS 2B'];

  @override
  TeacherLearningProgressPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherLearningProgressPermissions(
      canViewAssignedLearners: teacher,
      canViewMultiEvidence: teacher,
      canSuggestSupport: teacher,
      canPubliclyRankChildren: false,
      canDiagnoseCondition: false,
      canMakePromotionDecision: false,
      canMakePunishmentDecision: false,
    );
  }

  @override
  Future<TeacherLearningProgressSnapshot> load() async => TeacherLearningProgressSnapshot(
        students: students,
        classOptions: classOptions,
        permissions: permissionsFor(_teacher),
      );
}

class _EmptyFakeLearningProgressRepository implements TeacherLearningProgressRepository {
  @override
  TeacherLearningProgressPermissions permissionsFor(SchoolMembership membership) => const TeacherLearningProgressPermissions(
        canViewAssignedLearners: true,
        canViewMultiEvidence: true,
        canSuggestSupport: true,
        canPubliclyRankChildren: false,
        canDiagnoseCondition: false,
        canMakePromotionDecision: false,
        canMakePunishmentDecision: false,
      );

  @override
  Future<TeacherLearningProgressSnapshot> load() async => TeacherLearningProgressSnapshot(
        students: const [],
        classOptions: const [],
        permissions: permissionsFor(_teacher),
      );
}
