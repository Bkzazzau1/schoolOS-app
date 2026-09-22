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

void main() {
  test('score normalization remains integer and inside the selected maximum', () {
    const entry = TeacherAssessmentScoreEntry(studentId: 'stu-1', score: 5);
    expect(entry.copyWith(score: 99.clamp(0, 20)).score, 20);
    expect(entry.copyWith(score: (-4).clamp(0, 20)).score, 0);
  });

  test('score sheet evidence serializes without losing marks or workflow state', () {
    const sheet = TeacherAssessmentScoreSheet(
      id: 'assessment-1',
      className: 'JSS 2A',
      assessmentLabel: 'CA 1',
      maximumScore: 20,
      entries: [
        TeacherAssessmentScoreEntry(studentId: 'stu-1', score: 16),
        TeacherAssessmentScoreEntry(studentId: 'stu-2', score: 12),
      ],
      state: TeacherAssessmentSheetState.draft,
    );
    final restored = TeacherAssessmentScoreSheet.fromJson(sheet.toJson());
    expect(restored.entries, hasLength(2));
    expect(restored.entries[0].studentId, 'stu-1');
    expect(restored.average, 14.0);
    expect(restored.state, TeacherAssessmentSheetState.draft);
  });

  test('submitted assessment is distinct from locked and released results', () {
    const sheet = TeacherAssessmentScoreSheet(
      id: 'assessment-1',
      className: 'JSS 2A',
      assessmentLabel: 'CA 1',
      maximumScore: 20,
      entries: [TeacherAssessmentScoreEntry(studentId: 'stu-1', score: 16)],
      state: TeacherAssessmentSheetState.draft,
    );
    final submitted = sheet.copyWith(
      state: TeacherAssessmentSheetState.submittedForReview,
      submittedAt: '2026-09-20T05:00:00Z',
      version: 2,
    );
    expect(submitted.teacherEditable, isFalse);
    expect(submitted.lockedAt, isNull);
    expect(submitted.releasedAt, isNull);
    expect(teacherAssessmentSheetStateLabel(submitted.state), 'Submitted for review');
  });

  test('assessment boundaries keep AI evidence advisory', () {
    expect(teacherAssessmentSaveBoundary, contains('does not lock marks'));
    expect(teacherAssessmentSubmissionBoundary, contains('cannot self-lock'));
    expect(teacherAssessmentSubmissionBoundary, contains('parent-visible'));
    expect(teacherAssessmentAiBoundary, contains('cannot create, alter'));
    expect(teacherAssessmentAiBoundary, contains('teacher remains responsible'));
  });

  test('teacher permissions allow entry/submission but not lock release or AI marks', () {
    final fake = _FakeAssessmentRepository();
    const student = SchoolMembership(
      id: 'student-1',
      schoolId: 'school-1',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.student,
    );

    final permissions = fake.permissionsFor(_teacher);
    expect(permissions.canViewAssignedClassAssessments, isTrue);
    expect(permissions.canEnterScores, isTrue);
    expect(permissions.canSubmitScores, isTrue);
    expect(permissions.canLockScores, isFalse);
    expect(permissions.canReleaseResults, isFalse);
    expect(permissions.canAiAlterMarks, isFalse);
    expect(fake.permissionsFor(student).canEnterScores, isFalse);
  });

  testWidgets('Assessments renders real KPIs, register and score entry computed from the sheet', (
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

    expect(find.text('Assessments'), findsWidgets); // header title + KPI label
    expect(find.text('Score entry'), findsOneWidget);
    expect(find.text('1'), findsWidgets); // Assessments KPI
    expect(find.text('2/3'), findsWidgets); // Scores entered KPI + register subtitle prefix
    expect(find.text('25%'), findsWidgets); // Average score KPI + performance overview: 5.0/20 = 25%
    expect(find.text('5.0 / 20'), findsOneWidget); // class average row
    expect(find.text('Assessment register'), findsOneWidget);
    expect(find.textContaining('2/3 scores entered'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('score input clamps above maximum and updates the live average', (
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

    final firstScore = find.byType(TextFormField).first;
    await tester.enterText(firstScore, '99');
    await tester.pump();
    // stu-1 was 5, clamps to 20: (20 + 10 + 0) / 3 = 10.0.
    expect(find.text('10.0 / 20'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save then submit versions the score sheet without releasing results', (
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

    await tester.ensureVisible(find.text('Save progress'));
    await tester.tap(find.text('Save progress'));
    await tester.pumpAndSettle();
    expect(fake.sheets['assessment-1']!.version, 2);
    expect(fake.sheets['assessment-1']!.state, TeacherAssessmentSheetState.draft);
    expect(find.textContaining('saved locally'), findsOneWidget);

    await tester.ensureVisible(find.text('Submit scores'));
    await tester.tap(find.text('Submit scores'));
    await tester.pumpAndSettle();
    expect(fake.sheets['assessment-1']!.version, 3);
    expect(fake.sheets['assessment-1']!.state, TeacherAssessmentSheetState.submittedForReview);
    expect(fake.sheets['assessment-1']!.lockedAt, isNull);
    expect(fake.sheets['assessment-1']!.releasedAt, isNull);
    expect(find.text('Submitted for review'), findsOneWidget);
    expect(find.textContaining('not locked or released yet'), findsOneWidget);
    expect(queuedCallbacks, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creating a new assessment adds it to the register for a real assigned class', (
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

    await tester.enterText(find.widgetWithText(TextField, 'e.g. CA 1'), 'CA 2');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(fake.register, hasLength(2));
    expect(fake.register.last.title, 'CA 2');
    expect(find.textContaining('Assessment created'), findsOneWidget);
  });

  testWidgets('a teacher with no assessments yet sees an honest empty state, not a crash', (
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

    expect(find.textContaining('No assessments yet'), findsOneWidget);
    expect(find.text('Score entry'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Assessment actions route to existing Teacher modules', (
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

    await tester.ensureVisible(find.text('Create revision lesson'));
    await tester.tap(find.text('Create revision lesson'));
    await tester.pump();
    expect(destination, 'lesson-plans');
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
  final List<TeacherAssessmentRegisterItem> register = [
    const TeacherAssessmentRegisterItem(
      id: 'assessment-1',
      title: 'CA 1',
      className: 'JSS 2A',
      maximumScore: 20,
      entered: 2,
      total: 3,
      average: 5.0,
      state: TeacherAssessmentRegisterState.inProgress,
    ),
  ];
  final Map<String, TeacherAssessmentScoreSheet> sheets = {
    'assessment-1': const TeacherAssessmentScoreSheet(
      id: 'assessment-1',
      className: 'JSS 2A',
      assessmentLabel: 'CA 1',
      maximumScore: 20,
      entries: [
        TeacherAssessmentScoreEntry(studentId: 'stu-1', score: 5),
        TeacherAssessmentScoreEntry(studentId: 'stu-2', score: 10),
        TeacherAssessmentScoreEntry(studentId: 'stu-3', score: 0),
      ],
      state: TeacherAssessmentSheetState.draft,
    ),
  };
  final classOptions = const ['JSS 2A', 'JSS 2B'];
  final studentNames = const {'stu-1': 'Amaka Obi', 'stu-2': 'Bello Musa', 'stu-3': 'Chika Eze'};
  final events = <TeacherAssessmentEvent>[];

  @override
  TeacherAssessmentPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherAssessmentPermissions(
      canViewAssignedClassAssessments: teacher,
      canEnterScores: teacher,
      canSubmitScores: teacher,
      canLockScores: false,
      canReleaseResults: false,
      canAiAlterMarks: false,
    );
  }

  @override
  Future<TeacherAssessmentSnapshot> load() async => TeacherAssessmentSnapshot(
        register: List.of(register),
        sheets: Map.of(sheets),
        classOptions: classOptions,
        studentNames: studentNames,
        events: List.of(events),
        permissions: permissionsFor(_teacher),
      );

  void _syncRegisterItem(TeacherAssessmentScoreSheet sheet) {
    final entered = sheet.entries.where((e) => e.score > 0).length;
    final index = register.indexWhere((item) => item.id == sheet.id);
    final item = TeacherAssessmentRegisterItem(
      id: sheet.id,
      title: sheet.assessmentLabel,
      className: sheet.className,
      maximumScore: sheet.maximumScore,
      entered: entered,
      total: sheet.entries.length,
      average: sheet.average,
      state: entered >= sheet.entries.length && sheet.entries.isNotEmpty
          ? TeacherAssessmentRegisterState.complete
          : TeacherAssessmentRegisterState.inProgress,
    );
    if (index == -1) {
      register.add(item);
    } else {
      register[index] = item;
    }
  }

  @override
  Future<TeacherAssessmentActionResult> createAssessment({
    required String className,
    required String title,
    required int maximumScore,
  }) async {
    if (!classOptions.contains(className)) {
      return const TeacherAssessmentActionResult(success: false, message: 'You are not assigned to this class.');
    }
    final id = 'assessment-${register.length + 1}';
    final sheet = TeacherAssessmentScoreSheet(
      id: id,
      className: className,
      assessmentLabel: title,
      maximumScore: maximumScore,
      entries: const [TeacherAssessmentScoreEntry(studentId: 'stu-1', score: 0)],
      state: TeacherAssessmentSheetState.draft,
    );
    sheets[id] = sheet;
    _syncRegisterItem(sheet);
    return TeacherAssessmentActionResult(
      success: true,
      message: 'Assessment created. Enter scores below and save progress or submit when ready.',
      sheet: sheet,
    );
  }

  @override
  Future<TeacherAssessmentActionResult> saveProgress(TeacherAssessmentScoreSheet draft) async {
    final updated = draft.copyWith(
      state: TeacherAssessmentSheetState.draft,
      version: draft.version + 1,
      updatedAt: '2026-09-20T05:00:00Z',
    );
    sheets[updated.id] = updated;
    _syncRegisterItem(updated);
    events.add(
      TeacherAssessmentEvent(
        id: 'evt-save-${updated.version}',
        sheetId: updated.id,
        action: TeacherAssessmentEventAction.savedProgress,
        actorMembershipId: 'teacher-1',
        version: updated.version,
        occurredAt: '2026-09-20T05:00:00Z',
      ),
    );
    return TeacherAssessmentActionResult(
      success: true,
      message: 'Score-entry progress saved locally and queued for synchronization.',
      sheet: updated,
    );
  }

  @override
  Future<TeacherAssessmentActionResult> submitScores(TeacherAssessmentScoreSheet draft) async {
    final updated = draft.copyWith(
      state: TeacherAssessmentSheetState.submittedForReview,
      version: draft.version + 1,
      updatedAt: '2026-09-20T05:01:00Z',
      submittedAt: '2026-09-20T05:01:00Z',
    );
    sheets[updated.id] = updated;
    _syncRegisterItem(updated);
    events.add(
      TeacherAssessmentEvent(
        id: 'evt-submit-${updated.version}',
        sheetId: updated.id,
        action: TeacherAssessmentEventAction.submittedForReview,
        actorMembershipId: 'teacher-1',
        version: updated.version,
        occurredAt: '2026-09-20T05:01:00Z',
      ),
    );
    return TeacherAssessmentActionResult(
      success: true,
      message: 'Scores submitted locally for review or locking and queued for synchronization. They are not locked or released yet.',
      sheet: updated,
    );
  }
}

class _EmptyFakeAssessmentRepository implements TeacherAssessmentRepository {
  @override
  TeacherAssessmentPermissions permissionsFor(SchoolMembership membership) => const TeacherAssessmentPermissions(
        canViewAssignedClassAssessments: true,
        canEnterScores: true,
        canSubmitScores: true,
        canLockScores: false,
        canReleaseResults: false,
        canAiAlterMarks: false,
      );

  @override
  Future<TeacherAssessmentSnapshot> load() async => TeacherAssessmentSnapshot(
        register: const [],
        sheets: const {},
        classOptions: const ['JSS 2A'],
        studentNames: const {},
        events: const [],
        permissions: permissionsFor(_teacher),
      );

  @override
  Future<TeacherAssessmentActionResult> createAssessment({
    required String className,
    required String title,
    required int maximumScore,
  }) async =>
      const TeacherAssessmentActionResult(success: false, message: 'Not used in this test.');

  @override
  Future<TeacherAssessmentActionResult> saveProgress(TeacherAssessmentScoreSheet draft) async =>
      const TeacherAssessmentActionResult(success: false, message: 'Not used in this test.');

  @override
  Future<TeacherAssessmentActionResult> submitScores(TeacherAssessmentScoreSheet draft) async =>
      const TeacherAssessmentActionResult(success: false, message: 'Not used in this test.');
}
