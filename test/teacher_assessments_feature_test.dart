import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_assessment_demo_data.dart';
import 'package:schoolos_app/features/teacher/data/teacher_assessment_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_assessment_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_assessments_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

const _teacher = SchoolMembership(
  id: 'teacher-1',
  schoolId: 'school-1',
  schoolName: 'BrightGate Academy',
  role: SchoolRole.teacher,
);

const _option = TeacherAssessmentOption(
  classSubjectId: 'cs-1',
  termId: 'term-1',
  term: 'First Term',
  className: 'JSS 2A',
  subject: 'Mathematics',
);

void main() {
  test('an entry with no score is honestly distinct from an entered zero', () {
    const entry = TeacherAssessmentEntry(studentId: 'stu-1', studentName: 'Amaka Obi');
    expect(entry.score, isNull);
    final entered = entry.copyWith(score: 0);
    expect(entered.score, 0);
    expect(entered.copyWith(clearScore: true).score, isNull);
  });

  test('an assessment serializes without losing marks, type or workflow state', () {
    const assessment = TeacherAssessment(
      id: 'assessment-1',
      title: 'CA 1',
      className: 'JSS 2A',
      subject: 'Mathematics',
      type: TeacherAssessmentType.ca,
      maximumScore: 20,
      weight: 1.5,
      state: TeacherAssessmentState.published,
      entries: [
        TeacherAssessmentEntry(studentId: 'stu-1', studentName: 'Amaka Obi', score: 16),
        TeacherAssessmentEntry(studentId: 'stu-2', studentName: 'Bello Musa', score: 12),
      ],
    );
    final restored = TeacherAssessment.fromJson(assessment.toJson());
    expect(restored.entries, hasLength(2));
    expect(restored.entries[0].studentId, 'stu-1');
    expect(restored.average, 14.0);
    expect(restored.type, TeacherAssessmentType.ca);
    expect(restored.weight, 1.5);
    expect(restored.state, TeacherAssessmentState.published);
  });

  test('locking and release are never a Teacher-side capability, submitted is distinct from either', () {
    const submitted = TeacherAssessment(
      id: 'assessment-1',
      title: 'CA 1',
      className: 'JSS 2A',
      subject: 'Mathematics',
      type: TeacherAssessmentType.ca,
      maximumScore: 20,
      state: TeacherAssessmentState.submitted,
      entries: [TeacherAssessmentEntry(studentId: 'stu-1', studentName: 'Amaka Obi', score: 16)],
    );
    expect(submitted.scoresEditable, isFalse);
    expect(submitted.canLock, isFalse); // no such Teacher-side notion exists
    expect(submitted.canRelease, isFalse);
    expect(submitted.canCorrect, isTrue); // audited correction remains available
    expect(teacherAssessmentStateLabel(submitted.state), 'Submitted for review');
  });

  test('assessment boundaries keep locking, release and AI evidence advisory', () {
    expect(teacherAssessmentSaveBoundary, contains('does not lock marks'));
    expect(teacherAssessmentSubmissionBoundary, contains('cannot lock or release'));
    expect(teacherAssessmentCorrectionBoundary, contains('never a silent rewrite'));
    expect(teacherAssessmentAiBoundary, contains('cannot create, alter'));
    expect(teacherAssessmentAiBoundary, contains('teacher remains responsible'));
  });

  test('teacher permissions allow entry/submission/correction but never locking, release or AI marks', () {
    final fake = _FakeAssessmentRepository();
    const student = SchoolMembership(
      id: 'student-1',
      schoolId: 'school-1',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.student,
    );

    final permissions = fake.permissionsFor(_teacher);
    expect(permissions.canViewAssignedClassAssessments, isTrue);
    expect(permissions.canCreateDraft, isTrue);
    expect(permissions.canPublish, isTrue);
    expect(permissions.canEnterScores, isTrue);
    expect(permissions.canSubmitScores, isTrue);
    expect(permissions.canCorrectScores, isTrue);
    expect(permissions.canLockScores, isFalse);
    expect(permissions.canReleaseResults, isFalse);
    expect(permissions.canAiAlterMarks, isFalse);
    expect(fake.permissionsFor(student).canEnterScores, isFalse);
  });

  testWidgets('Assessments renders real KPIs, register and score entry computed from the assessment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherAssessmentsPage(
            repository: _FakeAssessmentRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The draft is selected by default (it is always first); select the real
    // published assessment to see its score entry.
    await tester.ensureVisible(find.text('CA 1 · JSS 2A'));
    await tester.tap(find.text('CA 1 · JSS 2A'));
    await tester.pumpAndSettle();

    expect(find.text('Assessments'), findsWidgets); // header title + KPI label
    expect(find.text('Score entry'), findsOneWidget);
    expect(find.text('1'), findsWidgets); // Assessments KPI
    expect(find.text('1/3'), findsWidgets); // Scores entered KPI (register shows it inside a longer sentence)
    expect(find.text('75%'), findsWidgets); // Average score KPI + performance overview
    expect(find.text('5.0 / 20'), findsOneWidget); // class average row: (15+0+0)/3
    expect(find.text('Assessment register'), findsOneWidget);
    expect(find.text('Open for scoring'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('entering a score updates the live class average without a repository round trip', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherAssessmentsPage(
            repository: _FakeAssessmentRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('CA 1 · JSS 2A'));
    await tester.tap(find.text('CA 1 · JSS 2A'));
    await tester.pumpAndSettle();

    // stu-2's field, initially unentered.
    final secondScore = find.byType(TextFormField).at(1);
    await tester.enterText(secondScore, '15');
    await tester.pump();
    // (15 + 15 + 0) / 3 = 10.0, computed purely in local widget state.
    expect(find.text('10.0 / 20'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save progress then submit versions the assessment without releasing results', (
    tester,
  ) async {
    final fake = _FakeAssessmentRepository();
    var queuedCallbacks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherAssessmentsPage(
            repository: fake,
            onNavigate: (_) {},
            onMutationQueued: () => queuedCallbacks++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('CA 1 · JSS 2A'));
    await tester.tap(find.text('CA 1 · JSS 2A'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save progress'));
    await tester.tap(find.text('Save progress'));
    await tester.pumpAndSettle();
    expect(fake.assessments['assessment-1']!.version, 2);
    expect(fake.assessments['assessment-1']!.state, TeacherAssessmentState.published);
    expect(find.textContaining('saved locally'), findsOneWidget);

    await tester.ensureVisible(find.text('Submit for review'));
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();
    expect(fake.assessments['assessment-1']!.version, 3);
    expect(fake.assessments['assessment-1']!.state, TeacherAssessmentState.submitted);
    expect(find.text('Submitted for review'), findsWidgets);
    expect(find.textContaining('not locked or released yet'), findsOneWidget);
    expect(queuedCallbacks, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing a class subject in "+ New assessment" saves a real draft for it', (
    tester,
  ) async {
    final fake = _FakeAssessmentRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherAssessmentsPage(
            repository: fake,
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('+ New assessment'));
    await tester.tap(find.text('+ New assessment'));
    await tester.pumpAndSettle();

    expect(find.text('New assessment'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(fake.savedDraftCount, 1);
    expect(find.textContaining('draft saved locally'), findsOneWidget);
  });

  testWidgets('a teacher with no assigned classes sees an honest empty state, not a crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherAssessmentsPage(
            repository: _EmptyFakeAssessmentRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No classes are assigned to you yet'), findsOneWidget);
    expect(find.text('Score entry'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Assessment header routes to existing Teacher modules', (
    tester,
  ) async {
    String? destination;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherAssessmentsPage(
            repository: _FakeAssessmentRepository(),
            onNavigate: (value) => destination = value,
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'My Classes'));
    await tester.pump();
    expect(destination, 'classes');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Dashboard'));
    await tester.pump();
    expect(destination, 'dashboard');
  });

  testWidgets('Assessments renders on phone without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherAssessmentsPage(
            repository: _FakeAssessmentRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Score entry'), findsOneWidget);
    expect(find.text('Performance overview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeAssessmentRepository implements TeacherAssessmentRepository {
  final Map<String, TeacherAssessment> assessments = {
    'assessment-1': const TeacherAssessment(
      id: 'assessment-1',
      title: 'CA 1',
      className: 'JSS 2A',
      subject: 'Mathematics',
      type: TeacherAssessmentType.ca,
      maximumScore: 20,
      state: TeacherAssessmentState.published,
      entries: [
        TeacherAssessmentEntry(studentId: 'stu-1', studentName: 'Amaka Obi', score: 15),
        TeacherAssessmentEntry(studentId: 'stu-2', studentName: 'Bello Musa'),
        TeacherAssessmentEntry(studentId: 'stu-3', studentName: 'Chika Eze'),
      ],
      totalStudents: 3,
      entered: 1,
      averagePercent: 75,
    ),
  };
  int savedDraftCount = 0;

  @override
  TeacherAssessmentPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherAssessmentPermissions(
      canViewAssignedClassAssessments: teacher,
      canCreateDraft: teacher,
      canPublish: teacher,
      canEnterScores: teacher,
      canSubmitScores: teacher,
      canCorrectScores: teacher,
      canLockScores: false,
      canReleaseResults: false,
      canAiAlterMarks: false,
    );
  }

  @override
  Future<TeacherAssessmentSnapshot> load() async => TeacherAssessmentSnapshot(
        assessments: assessments.values.toList(),
        draft: TeacherAssessment(
          id: 'assessment-draft',
          title: '',
          className: '',
          subject: '',
          type: TeacherAssessmentType.ca,
          maximumScore: 20,
          state: TeacherAssessmentState.draft,
          entries: const [],
        ),
        permissions: permissionsFor(_teacher),
        options: const [_option],
      );

  @override
  Future<TeacherAssessmentActionResult> saveDraft(TeacherAssessment draft) async {
    savedDraftCount++;
    final saved = draft.copyWith(version: draft.version + 1);
    assessments[saved.id] = saved;
    return TeacherAssessmentActionResult(
      success: true,
      message: 'Assessment draft saved locally and queued.',
      assessment: saved,
    );
  }

  @override
  Future<TeacherAssessmentActionResult> publish(TeacherAssessment draft) async {
    final published = draft.copyWith(state: TeacherAssessmentState.published, version: draft.version + 1);
    assessments[published.id] = published;
    return TeacherAssessmentActionResult(success: true, message: 'Publication queued.', assessment: published);
  }

  @override
  Future<TeacherAssessmentActionResult> saveScores(TeacherAssessment assessment) async {
    final updated = assessment.copyWith(version: assessment.version + 1);
    assessments[updated.id] = updated;
    return TeacherAssessmentActionResult(
      success: true,
      message: 'Score-entry progress saved locally and queued for synchronization.',
      assessment: updated,
    );
  }

  @override
  Future<TeacherAssessmentActionResult> submit(TeacherAssessment assessment) async {
    final updated = assessment.copyWith(state: TeacherAssessmentState.submitted, version: assessment.version + 1);
    assessments[updated.id] = updated;
    return TeacherAssessmentActionResult(
      success: true,
      message: 'Scores submitted for review and queued for synchronization. They are not locked or released yet.',
      assessment: updated,
    );
  }

  @override
  Future<TeacherAssessmentActionResult> correctScore(
    TeacherAssessment assessment, {
    required String studentId,
    required double? score,
    required String comment,
  }) async =>
      const TeacherAssessmentActionResult(success: false, message: 'Not used in this test.');
}

class _EmptyFakeAssessmentRepository implements TeacherAssessmentRepository {
  @override
  TeacherAssessmentPermissions permissionsFor(SchoolMembership membership) => const TeacherAssessmentPermissions(
        canViewAssignedClassAssessments: true,
        canCreateDraft: true,
        canPublish: true,
        canEnterScores: true,
        canSubmitScores: true,
        canCorrectScores: true,
        canLockScores: false,
        canReleaseResults: false,
        canAiAlterMarks: false,
      );

  @override
  Future<TeacherAssessmentSnapshot> load() async => TeacherAssessmentSnapshot(
        assessments: const [],
        draft: const TeacherAssessment(
          id: 'assessment-empty',
          title: '',
          className: '',
          subject: '',
          type: TeacherAssessmentType.ca,
          maximumScore: 20,
          state: TeacherAssessmentState.draft,
          entries: [],
        ),
        permissions: permissionsFor(_teacher),
        options: const [],
      );

  @override
  Future<TeacherAssessmentActionResult> saveDraft(TeacherAssessment draft) async =>
      const TeacherAssessmentActionResult(success: false, message: 'Not used in this test.');

  @override
  Future<TeacherAssessmentActionResult> publish(TeacherAssessment draft) async =>
      const TeacherAssessmentActionResult(success: false, message: 'Not used in this test.');

  @override
  Future<TeacherAssessmentActionResult> saveScores(TeacherAssessment assessment) async =>
      const TeacherAssessmentActionResult(success: false, message: 'Not used in this test.');

  @override
  Future<TeacherAssessmentActionResult> submit(TeacherAssessment assessment) async =>
      const TeacherAssessmentActionResult(success: false, message: 'Not used in this test.');

  @override
  Future<TeacherAssessmentActionResult> correctScore(
    TeacherAssessment assessment, {
    required String studentId,
    required double? score,
    required String comment,
  }) async =>
      const TeacherAssessmentActionResult(success: false, message: 'Not used in this test.');
}
