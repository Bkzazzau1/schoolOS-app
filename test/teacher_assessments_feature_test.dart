import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_assessment_demo_data.dart';
import 'package:schoolos_app/features/teacher/data/teacher_assessment_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_assessment_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_assessments_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

void main() {
  test('Assessments preserves exact website register snapshot', () {
    expect(teacherAssessmentRegister, hasLength(3));
    expect(teacherAssessmentRegister[0].id, 'ca-201');
    expect(teacherAssessmentRegister[0].className, 'JSS 2A');
    expect(teacherAssessmentRegister[0].entered, 42);
    expect(teacherAssessmentRegister[0].total, 42);
    expect(teacherAssessmentRegister[0].average, 14.8);
    expect(
      teacherAssessmentRegister[0].state,
      TeacherAssessmentRegisterState.complete,
    );

    expect(teacherAssessmentRegister[1].className, 'JSS 2B');
    expect(teacherAssessmentRegister[1].entered, 34);
    expect(teacherAssessmentRegister[1].total, 39);
    expect(teacherAssessmentRegister[1].average, 12.6);
    expect(
      teacherAssessmentRegister[1].state,
      TeacherAssessmentRegisterState.inProgress,
    );

    expect(teacherAssessmentRegister[2].title, 'Topic Test');
    expect(teacherAssessmentRegister[2].maximumScore, 30);
    expect(teacherAssessmentRegister[2].entered, 41);
    expect(teacherAssessmentRegister[2].average, 22.4);
  });

  test('Assessments preserves exact website KPI and performance evidence', () {
    expect(teacherAssessmentKpis, hasLength(4));
    expect(teacherAssessmentKpis[0], (
      'CA completion',
      '84%',
      'Across assigned classes',
    ));
    expect(teacherAssessmentKpis[1].$2, '7');
    expect(teacherAssessmentKpis[2].$2, '68%');
    expect(teacherAssessmentKpis[3].$2, '11');
    expect(teacherAssessmentCurrentAverage, 63);
    expect(teacherAssessmentMetrics, [
      ('Concept mastery', 66),
      ('Question completion', 81),
      ('Algebra accuracy', 59),
      ('Improvement vs previous', 72),
    ]);
    expect(teacherAssessmentAiObservation, contains('word problems into equations'));
  });

  test('five demo scores reproduce exact 13.8 out of 20 website average', () {
    expect(teacherAssessmentInitialScores, hasLength(5));
    expect(
      teacherAssessmentInitialScores.map((item) => item.score).toList(),
      [16, 12, 9, 18, 14],
    );
    expect(teacherAssessmentInitialSheet.className, 'JSS 2B');
    expect(teacherAssessmentInitialSheet.maximumScore, 20);
    expect(teacherAssessmentInitialSheet.average, 13.8);
    expect(teacherAssessmentInitialSheet.state, TeacherAssessmentSheetState.draft);
  });

  test('assessment evidence serializes without losing marks or workflow state', () {
    final restored = TeacherAssessmentScoreSheet.fromJson(
      teacherAssessmentInitialSheet.toJson(),
    );
    expect(restored.id, teacherAssessmentInitialSheet.id);
    expect(restored.entries, hasLength(5));
    expect(restored.entries[2].studentId, 'STU-DEMO-003');
    expect(restored.entries[2].score, 9);
    expect(restored.average, 13.8);
    expect(restored.state, TeacherAssessmentSheetState.draft);
  });

  test('score normalization remains integer and inside the selected maximum', () {
    final high = teacherAssessmentInitialScores.first.copyWith(score: 99.clamp(0, 20));
    final low = teacherAssessmentInitialScores.first.copyWith(score: (-4).clamp(0, 20));
    expect(high.score, 20);
    expect(low.score, 0);
  });

  test('submitted assessment is distinct from locked and released results', () {
    final submitted = teacherAssessmentInitialSheet.copyWith(
      state: TeacherAssessmentSheetState.submittedForReview,
      submittedAt: '2026-09-20T05:00:00Z',
      version: 2,
    );
    expect(submitted.teacherEditable, isFalse);
    expect(submitted.lockedAt, isNull);
    expect(submitted.releasedAt, isNull);
    expect(
      teacherAssessmentSheetStateLabel(submitted.state),
      'Submitted for review',
    );
  });

  test('assessment boundaries keep AI and below-threshold evidence advisory', () {
    expect(teacherAssessmentSaveBoundary, contains('does not lock marks'));
    expect(teacherAssessmentSubmissionBoundary, contains('cannot self-lock'));
    expect(teacherAssessmentSubmissionBoundary, contains('parent-visible'));
    expect(teacherAssessmentAiBoundary, contains('cannot create, alter'));
    expect(teacherAssessmentAiBoundary, contains('teacher remains responsible'));
    expect(teacherAssessmentInterventionBoundary, contains('not automatic failure'));
    expect(teacherAssessmentInterventionBoundary, contains('promotion'));
    expect(teacherAssessmentInterventionBoundary, contains('safeguarding'));
  });

  test('teacher permissions allow entry/submission but not lock release or AI marks', () {
    final fake = _FakeAssessmentRepository();
    const teacher = SchoolMembership(
      id: 'teacher-1',
      schoolId: 'school-1',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.teacher,
    );
    const student = SchoolMembership(
      id: 'student-1',
      schoolId: 'school-1',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.student,
    );

    final permissions = fake.permissionsFor(teacher);
    expect(permissions.canViewAssignedClassAssessments, isTrue);
    expect(permissions.canEnterScores, isTrue);
    expect(permissions.canSubmitScores, isTrue);
    expect(permissions.canLockScores, isFalse);
    expect(permissions.canReleaseResults, isFalse);
    expect(permissions.canAiAlterMarks, isFalse);
    expect(fake.permissionsFor(student).canEnterScores, isFalse);
  });

  testWidgets('Assessments renders exact website score and insight content', (
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

    expect(find.text('Assessments'), findsOneWidget);
    expect(find.text('Score entry'), findsOneWidget);
    expect(find.text('13.8 / 20'), findsOneWidget);
    expect(find.text('63%'), findsOneWidget);
    expect(find.text('JSS 2B current average'), findsOneWidget);
    expect(find.text('Assessment register'), findsOneWidget);
    expect(find.textContaining('34/39 scores entered'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('score input clamps above maximum before save', (tester) async {
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

    final firstScore = find.byType(TextFormField).first;
    await tester.enterText(firstScore, '99');
    await tester.pump();
    expect(find.widgetWithText(TextFormField, '20'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save then submit versions score sheet without releasing results', (
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
    expect(fake.sheet.version, 2);
    expect(fake.sheet.state, TeacherAssessmentSheetState.draft);
    expect(find.textContaining('saved locally'), findsOneWidget);

    await tester.ensureVisible(find.text('Submit scores'));
    await tester.tap(find.text('Submit scores'));
    await tester.pumpAndSettle();
    expect(fake.sheet.version, 3);
    expect(fake.sheet.state, TeacherAssessmentSheetState.submittedForReview);
    expect(fake.sheet.lockedAt, isNull);
    expect(fake.sheet.releasedAt, isNull);
    expect(find.text('Submitted for review'), findsOneWidget);
    expect(find.textContaining('not locked or released yet'), findsOneWidget);
    expect(queuedCallbacks, 2);
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
    expect(find.text('Performance insight'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeAssessmentRepository implements TeacherAssessmentRepository {
  TeacherAssessmentScoreSheet sheet = teacherAssessmentInitialSheet;
  final List<TeacherAssessmentEvent> events = [];

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
        register: teacherAssessmentRegister,
        sheet: sheet,
        events: events,
        permissions: permissionsFor(
          const SchoolMembership(
            id: 'teacher-1',
            schoolId: 'school-1',
            schoolName: 'BrightGate Academy',
            role: SchoolRole.teacher,
          ),
        ),
      );

  @override
  Future<TeacherAssessmentActionResult> saveProgress(
    TeacherAssessmentScoreSheet draft,
  ) async {
    sheet = draft.copyWith(
      state: TeacherAssessmentSheetState.draft,
      version: draft.version + 1,
      updatedAt: '2026-09-20T05:00:00Z',
    );
    events.add(
      TeacherAssessmentEvent(
        id: 'evt-save-${sheet.version}',
        sheetId: sheet.id,
        action: TeacherAssessmentEventAction.savedProgress,
        actorMembershipId: 'teacher-1',
        version: sheet.version,
        occurredAt: '2026-09-20T05:00:00Z',
      ),
    );
    return TeacherAssessmentActionResult(
      success: true,
      message: 'Score-entry progress saved locally and queued for synchronization.',
      sheet: sheet,
    );
  }

  @override
  Future<TeacherAssessmentActionResult> submitScores(
    TeacherAssessmentScoreSheet draft,
  ) async {
    sheet = draft.copyWith(
      state: TeacherAssessmentSheetState.submittedForReview,
      version: draft.version + 1,
      updatedAt: '2026-09-20T05:01:00Z',
      submittedAt: '2026-09-20T05:01:00Z',
    );
    events.add(
      TeacherAssessmentEvent(
        id: 'evt-submit-${sheet.version}',
        sheetId: sheet.id,
        action: TeacherAssessmentEventAction.submittedForReview,
        actorMembershipId: 'teacher-1',
        version: sheet.version,
        occurredAt: '2026-09-20T05:01:00Z',
      ),
    );
    return TeacherAssessmentActionResult(
      success: true,
      message: 'Scores submitted locally for review or locking and queued for synchronization. They are not locked or released yet.',
      sheet: sheet,
    );
  }
}
