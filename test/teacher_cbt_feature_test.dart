import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_cbt_demo_data.dart';
import 'package:schoolos_app/features/teacher/data/teacher_cbt_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_cbt_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_cbt_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

const _teacher = SchoolMembership(
  id: 'teacher-1',
  schoolId: 'school-1',
  schoolName: 'BrightGate Academy',
  role: SchoolRole.teacher,
);

const _option = TeacherCbtOption(
  classSubjectId: 'cs-1',
  termId: 'term-1',
  term: 'First Term',
  className: 'JSS 2A',
  subject: 'Mathematics',
);

const _publishedTest = TeacherCbtTest(
  id: 'CBT-MTH-026',
  title: 'Linear Equations',
  className: 'JSS 2A',
  subject: 'Mathematics',
  classSubjectId: 'cs-1',
  termId: 'term-1',
  term: 'First Term',
  questions: [
    TeacherCbtQuestion(
      id: 'Q1',
      prompt: 'Solve: 3x + 4 = 19. What is x?',
      options: ['3', '4', '5', '6'],
      correctIndex: 2,
    ),
  ],
  durationMinutes: 20,
  state: TeacherCbtTestState.published,
  resultMode: TeacherCbtResultMode.scoreOnly,
  instructions: teacherCbtInstructions,
  totalRecipients: 4,
);

const _draftTest = TeacherCbtTest(
  id: 'CBT-MTH-027',
  title: 'Fractions Review',
  className: 'JSS 2A',
  subject: 'Mathematics',
  classSubjectId: 'cs-1',
  termId: 'term-1',
  term: 'First Term',
  questions: [
    TeacherCbtQuestion(id: 'Q1', prompt: 'What is 1/2 as a decimal?', options: ['0.2', '0.5', '0.25'], correctIndex: 1),
  ],
  durationMinutes: 15,
  state: TeacherCbtTestState.draft,
  resultMode: TeacherCbtResultMode.scoreOnly,
  instructions: teacherCbtInstructions,
);

void main() {
  test('question design boundary is still shown to teachers authoring real questions', () {
    expect(teacherCbtDesignBoundary, contains('question itself was fair'));
  });

  test('CBT boundaries keep practice separate from high-stakes decisions and name the redaction guarantee', () {
    expect(teacherCbtPracticeBoundary, contains('learning and exam familiarity'));
    expect(teacherCbtPracticeBoundary, contains('permanent student ranking'));
    expect(teacherCbtPracticeBoundary, contains('high-stakes examination result'));
    expect(teacherCbtAiBoundary, contains('cannot change scores'));
    expect(teacherCbtAiBoundary, contains('replace teacher judgment'));
    expect(teacherCbtPublicationBoundary, contains('server acknowledgement'));
    expect(teacherCbtPublicationBoundary, contains('stays on the server until a student'));
  });

  test('teacher CBT permissions are teacher-only', () {
    final fake = _FakeCbtRepository();
    const parent = SchoolMembership(
      id: 'parent-1',
      schoolId: 'school-1',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.parent,
    );
    final permissions = fake.permissionsFor(_teacher);
    expect(permissions.canCreateDraft, isTrue);
    expect(permissions.canPublish, isTrue);
    expect(permissions.canClose, isTrue);
    expect(permissions.canUsePracticeEvidence, isTrue);
    expect(fake.permissionsFor(parent).canCreateDraft, isFalse);
  });

  testWidgets('CBT renders a real published test with its real questions, not invented student evidence', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherCbtPage(repository: _FakeCbtRepository(), onNavigate: (_) {}, onMutationQueued: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Computer-Based Tests'), findsOneWidget);
    expect(find.text('Linear Equations · JSS 2A'), findsOneWidget);
    await tester.tap(find.text('Linear Equations · JSS 2A'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Solve: 3x + 4 = 19'), findsOneWidget);
    expect(
      find.textContaining('No attempts have been recorded yet'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('publishing a draft queues it and never self-confirms Published', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = _FakeCbtRepository();
    var mutationCallbacks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherCbtPage(repository: fake, onNavigate: (_) {}, onMutationQueued: () => mutationCallbacks++),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fractions Review · JSS 2A'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Publish'));
    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await tester.pumpAndSettle();

    final published = fake.tests.firstWhere((item) => item.id == 'CBT-MTH-027');
    expect(published.state, TeacherCbtTestState.published);
    expect(find.textContaining('Publication queued'), findsOneWidget);
    expect(mutationCallbacks, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creating a new test requires a title and saves a real draft for the chosen class subject', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = _FakeCbtRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherCbtPage(repository: fake, onNavigate: (_) {}, onMutationQueued: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'New test'));
    await tester.tap(find.widgetWithText(FilledButton, 'New test'));
    await tester.pumpAndSettle();

    // A blank title is refused without ever reaching the repository.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a title for the CBT test.'), findsOneWidget);

    await tester.enterText(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
      'Week 7 Practice',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(fake.tests.any((t) => t.title == 'Week 7 Practice' && t.state == TeacherCbtTestState.draft), isTrue);
  });

  testWidgets('CBT top actions route to Dashboard and Assessments', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? destination;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherCbtPage(
            repository: _FakeCbtRepository(),
            onNavigate: (value) => destination = value,
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Dashboard'));
    expect(destination, 'dashboard');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Assessments'));
    expect(destination, 'assessments');
  });

  testWidgets('a teacher with no assigned classes sees an honest empty state, not a crash', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherCbtPage(repository: _EmptyFakeCbtRepository(), onNavigate: (_) {}, onMutationQueued: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No classes are assigned to you yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CBT renders on a phone viewport without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherCbtPage(repository: _FakeCbtRepository(), onNavigate: (_) {}, onMutationQueued: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My CBT tests'), findsOneWidget);
    expect(find.text('Test configuration'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeCbtRepository implements TeacherCbtRepository {
  List<TeacherCbtTest> tests = [_publishedTest, _draftTest];
  final options = const [_option];

  @override
  TeacherCbtPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherCbtPermissions(
      canViewAssignedClassTests: teacher,
      canCreateDraft: teacher,
      canPublish: teacher,
      canClose: teacher,
      canUsePracticeEvidence: teacher,
    );
  }

  @override
  Future<TeacherCbtSnapshot> load() async {
    final draft = tests.where((t) => t.state == TeacherCbtTestState.draft).isEmpty
        ? const TeacherCbtTest(
            id: 'cbt-new',
            title: '',
            className: 'JSS 2A',
            subject: 'Mathematics',
            classSubjectId: 'cs-1',
            termId: 'term-1',
            term: 'First Term',
            questions: [],
            durationMinutes: 15,
            state: TeacherCbtTestState.draft,
            resultMode: TeacherCbtResultMode.scoreOnly,
            instructions: teacherCbtInstructions,
          )
        : tests.firstWhere((t) => t.state == TeacherCbtTestState.draft);
    return TeacherCbtSnapshot(
      tests: tests.where((t) => t.id != draft.id).toList(growable: false),
      draft: draft,
      permissions: permissionsFor(_teacher),
      options: options,
    );
  }

  @override
  Future<TeacherCbtActionResult> saveDraft(TeacherCbtTest draft) async {
    if (draft.title.trim().isEmpty) {
      return const TeacherCbtActionResult(success: false, message: 'Enter a title for the CBT test.');
    }
    final updated = draft.copyWith(version: draft.version + 1);
    final exists = tests.any((t) => t.id == updated.id);
    tests = exists
        ? tests.map((item) => item.id == updated.id ? updated : item).toList(growable: false)
        : [...tests, updated];
    return TeacherCbtActionResult(success: true, message: 'CBT draft saved locally and queued.', test: updated);
  }

  @override
  Future<TeacherCbtActionResult> publish(TeacherCbtTest draft) async {
    final updated = draft.copyWith(state: TeacherCbtTestState.published, version: draft.version + 1);
    tests = tests.map((item) => item.id == updated.id ? updated : item).toList(growable: false);
    return TeacherCbtActionResult(
      success: true,
      message: 'Publication queued. Students cannot start it until the server accepts it.',
      test: updated,
    );
  }

  @override
  Future<TeacherCbtActionResult> close(TeacherCbtTest test) async {
    final updated = test.copyWith(state: TeacherCbtTestState.closed, version: test.version + 1);
    tests = tests.map((item) => item.id == updated.id ? updated : item).toList(growable: false);
    return TeacherCbtActionResult(success: true, message: 'Closure queued.', test: updated);
  }
}

class _EmptyFakeCbtRepository implements TeacherCbtRepository {
  @override
  TeacherCbtPermissions permissionsFor(SchoolMembership membership) => const TeacherCbtPermissions(
        canViewAssignedClassTests: true,
        canCreateDraft: true,
        canPublish: true,
        canClose: true,
        canUsePracticeEvidence: true,
      );

  @override
  Future<TeacherCbtSnapshot> load() async => TeacherCbtSnapshot(
        tests: const [],
        draft: const TeacherCbtTest(
          id: 'cbt-empty',
          title: '',
          className: '',
          subject: '',
          questions: [],
          durationMinutes: 15,
          state: TeacherCbtTestState.draft,
          resultMode: TeacherCbtResultMode.scoreOnly,
          instructions: '',
        ),
        permissions: permissionsFor(_teacher),
        options: const [],
      );

  @override
  Future<TeacherCbtActionResult> saveDraft(TeacherCbtTest draft) async =>
      const TeacherCbtActionResult(success: false, message: 'Not used in this test.');

  @override
  Future<TeacherCbtActionResult> publish(TeacherCbtTest draft) async =>
      const TeacherCbtActionResult(success: false, message: 'Not used in this test.');

  @override
  Future<TeacherCbtActionResult> close(TeacherCbtTest test) async =>
      const TeacherCbtActionResult(success: false, message: 'Not used in this test.');
}
