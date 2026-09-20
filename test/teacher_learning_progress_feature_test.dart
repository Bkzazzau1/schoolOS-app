import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_learning_progress_demo_data.dart';
import 'package:schoolos_app/features/teacher/data/teacher_learning_progress_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_learning_progress_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_learning_progress_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

void main() {
  test('Learning Progress preserves exact website KPI and evidence flow', () {
    expect(teacherLearningProgressKpis, hasLength(4));
    expect(teacherLearningProgressKpis[0],
        ('Students tracked', '150', 'Across assigned classes'));
    expect(teacherLearningProgressKpis[1].$2, '4');
    expect(teacherLearningProgressKpis[2].$2, '7');
    expect(teacherLearningProgressKpis[3].$2, '12');
    expect(teacherLearningEvidenceFlow, hasLength(5));
    expect(teacherLearningEvidenceFlow.first, ('Classwork', 'Daily understanding'));
    expect(teacherLearningEvidenceFlow.last,
        ('Learning Intelligence', 'Topic trend + next action'));
  });

  test('Learning Progress preserves four website learners and sixteen topic rows', () {
    expect(teacherLearningStudents, hasLength(4));
    expect(
      teacherLearningStudents.fold<int>(0, (sum, student) => sum + student.topics.length),
      16,
    );
    expect(teacherLearningStudents[0].name, 'Maryam Abdullahi');
    expect(teacherLearningStudents[0].average, 86);
    expect(teacherLearningStudents[0].attendance, 96);
    expect(teacherLearningStudents[1].name, 'Ibrahim Sani');
    expect(teacherLearningStudents[1].average, 61);
    expect(teacherLearningStudents[2].name, 'Yusuf Bello');
    expect(teacherLearningStudents[2].attendance, 79);
    expect(teacherLearningStudents[3].name, 'Fatima Musa');
    expect(teacherLearningStudents[3].average, 91);
  });

  test('topic combined evidence and weakest strongest calculations match website logic', () {
    final maryam = teacherLearningStudents[0];
    expect(maryam.topics[0].combined, 60);
    expect(maryam.weakestTopic.name, 'Fractions');
    expect(maryam.strongestTopic.name, 'Algebra');
    expect(maryam.strongestTopic.combined, 90);
    expect(maryam.weakestTopic.trend, 3);

    final ibrahim = teacherLearningStudents[1];
    expect(ibrahim.weakestTopic.name, 'Fractions');
    expect(ibrahim.topics.first.isDeclining, isTrue);
    expect(ibrahim.topics.first.trend, -4);

    final yusuf = teacherLearningStudents[2];
    expect(yusuf.weakestTopic.name, 'Fractions');
    expect(yusuf.weakestTopic.combined, 40);
    expect(yusuf.topics.first.trend, -7);
  });

  test('learning evidence serializes without losing topic-level detail', () {
    final restored = TeacherLearningStudentEvidence.fromJson(
      teacherLearningStudents.first.toJson(),
    );
    expect(restored.id, 'STU-001');
    expect(restored.topics, hasLength(4));
    expect(restored.topics.first.name, 'Fractions');
    expect(restored.topics.first.cbt, 62);
    expect(restored.topics[2].assignment, 91);
  });

  test('support queue preserves exact three supportive next actions', () {
    expect(teacherLearningSupportActions, hasLength(3));
    expect(teacherLearningSupportActions[0].student, 'Maryam Abdullahi');
    expect(teacherLearningSupportActions[0].topic, 'Fractions');
    expect(teacherLearningSupportActions[0].destination, 'assignments');
    expect(teacherLearningSupportActions[1].destination, 'lesson-plans');
    expect(teacherLearningSupportActions[2].destination, 'students');
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
    const teacher = SchoolMembership(
      id: 'teacher-1',
      schoolId: 'school-1',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.teacher,
    );
    const parent = SchoolMembership(
      id: 'parent-1',
      schoolId: 'school-1',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.parent,
    );
    final permissions = fake.permissionsFor(teacher);
    expect(permissions.canViewAssignedLearners, isTrue);
    expect(permissions.canViewMultiEvidence, isTrue);
    expect(permissions.canSuggestSupport, isTrue);
    expect(permissions.canPubliclyRankChildren, isFalse);
    expect(permissions.canDiagnoseCondition, isFalse);
    expect(permissions.canMakePromotionDecision, isFalse);
    expect(permissions.canMakePunishmentDecision, isFalse);
    expect(fake.permissionsFor(parent).canViewAssignedLearners, isFalse);
  });

  testWidgets('Learning Progress renders website evidence and Maryam summary',
      (tester) async {
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
    expect(find.text('150'), findsOneWidget);
    expect(find.text('Maryam Abdullahi'), findsWidgets);
    expect(find.text('Main practice area'), findsOneWidget);
    expect(find.text('Fractions'), findsWidgets);
    expect(find.text('90%'), findsWidgets);
    expect(find.text('Topic evidence matrix'), findsOneWidget);
    expect(find.text('Learning Intelligence rule'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Learning Progress connected actions route to dedicated Teacher modules',
      (tester) async {
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
    expect(find.text('Evidence interpretation'), findsOneWidget);
    expect(find.text('Teacher action queue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeLearningProgressRepository implements TeacherLearningProgressRepository {
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
  Future<TeacherLearningProgressSnapshot> load() async =>
      TeacherLearningProgressSnapshot(
        students: teacherLearningStudents,
        permissions: permissionsFor(
          const SchoolMembership(
            id: 'teacher-1',
            schoolId: 'school-1',
            schoolName: 'BrightGate Academy',
            role: SchoolRole.teacher,
          ),
        ),
      );
}
