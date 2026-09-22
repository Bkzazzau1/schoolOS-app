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

void main() {
  test('sample practice sets start with no invented attempt evidence', () {
    expect(teacherCbtSets, hasLength(3));
    expect(teacherCbtSets[0].id, 'CBT-MTH-026');
    expect(teacherCbtSets[0].title, 'JSS 2 Mathematics · Linear Equations');
    expect(teacherCbtSets[0].state, TeacherCbtSetState.published);
    // No real student CBT-taking pipeline exists yet, so sample sets never claim attempts or accuracy.
    for (final set in teacherCbtSets) {
      expect(set.attempts, 0, reason: '${set.id} must not invent attempt evidence');
      expect(set.averageAccuracy, 0, reason: '${set.id} must not invent accuracy evidence');
    }
    expect(teacherCbtSets[1].id, 'CBT-MTH-027');
    expect(teacherCbtSets[1].state, TeacherCbtSetState.draft);
    expect(teacherCbtSets[2].id, 'CBT-MTH-021');
    expect(teacherCbtSets[2].state, TeacherCbtSetState.closed);
  });

  test('question preview keeps exact item and topic tag principle', () {
    expect(teacherCbtQuestionTopic, 'Linear Equations');
    expect(teacherCbtQuestionText, 'If 3x + 4 = 19, what is the value of x?');
    expect(teacherCbtQuestionOptions, ['A. 3', 'B. 4', 'C. 5', 'D. 6']);
    expect(teacherCbtDesignBoundary, contains('topic tag'));
  });

  test('CBT set serialization preserves state without losing the zeroed evidence', () {
    final restored = TeacherCbtPracticeSet.fromJson(teacherCbtSets.first.toJson());
    expect(restored.id, 'CBT-MTH-026');
    expect(restored.state, TeacherCbtSetState.published);
    expect(restored.attempts, 0);
    expect(restored.averageAccuracy, 0);
    expect(restored.publishedAt, 'server-confirmed');
  });

  test('CBT boundaries keep practice separate from high-stakes decisions', () {
    expect(teacherCbtPracticeBoundary, contains('learning and exam familiarity'));
    expect(teacherCbtPracticeBoundary, contains('permanent student ranking'));
    expect(teacherCbtPracticeBoundary, contains('high-stakes examination result'));
    expect(teacherCbtPracticeBoundary, contains('promotion decision'));
    expect(teacherCbtAiBoundary, contains('cannot change scores'));
    expect(teacherCbtAiBoundary, contains('replace teacher judgment'));
    expect(teacherCbtPublicationBoundary, contains('server acknowledgement'));
  });

  test('teacher CBT permissions never grant publication confirmation or high-stakes authority', () {
    final fake = _FakeCbtRepository();
    const parent = SchoolMembership(
      id: 'parent-1',
      schoolId: 'school-1',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.parent,
    );
    final permissions = fake.permissionsFor(_teacher);
    expect(permissions.canViewAssignedPractice, isTrue);
    expect(permissions.canEditDrafts, isTrue);
    expect(permissions.canQueuePublication, isTrue);
    expect(permissions.canUsePracticeEvidence, isTrue);
    expect(permissions.canConfirmPublication, isFalse);
    expect(permissions.canMakeHighStakesDecision, isFalse);
    expect(fake.permissionsFor(parent).canEditDrafts, isFalse);
  });

  testWidgets('CBT Practice renders real sets and an honest empty results panel, not invented student evidence', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherCbtPage(
            repository: _FakeCbtRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CBT Practice Center'), findsOneWidget);
    expect(find.text('JSS 2 Mathematics · Linear Equations'), findsWidgets);
    expect(find.text('Question 7 of 20'), findsOneWidget);
    expect(find.text(teacherCbtQuestionText), findsOneWidget);
    expect(find.text('Learning Intelligence handoff'), findsOneWidget);
    expect(find.textContaining('No practice attempts have been recorded yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('draft publication becomes queued and never self-confirms Published', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = _FakeCbtRepository();
    var mutationCallbacks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherCbtPage(
            repository: fake,
            onNavigate: (_) {},
            onMutationQueued: () => mutationCallbacks++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('JSS 2 Mathematics · Fractions Review').first);
    await tester.pump();
    await tester.ensureVisible(find.text('Publish practice'));
    await tester.tap(find.text('Publish practice'));
    await tester.pumpAndSettle();

    final draft = fake.sets.firstWhere((item) => item.id == 'CBT-MTH-027');
    expect(draft.state, TeacherCbtSetState.queuedForPublication);
    expect(draft.publishedAt, isNull);
    expect(find.textContaining('Student availability is not confirmed'), findsOneWidget);
    expect(mutationCallbacks, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creating a new set adds a draft for a real assigned class', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = _FakeCbtRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherCbtPage(
            repository: fake,
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'New set').first);
    await tester.tap(find.widgetWithText(FilledButton, 'New set').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'e.g. Week 6 Practice'), 'Week 7 Practice');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(fake.sets.any((s) => s.title == 'Week 7 Practice' && s.state == TeacherCbtSetState.draft), isTrue);
    expect(find.textContaining('created as a draft'), findsOneWidget);
  });

  testWidgets('CBT top actions route to Teacher Dashboard and Assessments', (tester) async {
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
          body: TeacherCbtPage(
            repository: _EmptyFakeCbtRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No classes are assigned to you yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CBT Practice renders on a phone viewport without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherCbtPage(
            repository: _FakeCbtRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My CBT practice sets'), findsOneWidget);
    expect(find.text('Practice configuration'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeCbtRepository implements TeacherCbtRepository {
  List<TeacherCbtPracticeSet> sets = List<TeacherCbtPracticeSet>.from(teacherCbtSets);
  final classOptions = const ['JSS 2A', 'JSS 2B'];

  @override
  TeacherCbtPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherCbtPermissions(
      canViewAssignedPractice: teacher,
      canEditDrafts: teacher,
      canQueuePublication: teacher,
      canConfirmPublication: false,
      canUsePracticeEvidence: teacher,
      canMakeHighStakesDecision: false,
    );
  }

  @override
  Future<TeacherCbtSnapshot> load() async => TeacherCbtSnapshot(
        sets: sets,
        classOptions: classOptions,
        permissions: permissionsFor(_teacher),
      );

  @override
  Future<TeacherCbtActionResult> createDraft({required String className, required String title}) async {
    if (!classOptions.contains(className)) {
      return const TeacherCbtActionResult(success: false, message: 'You are not assigned to this class.');
    }
    final set = TeacherCbtPracticeSet(
      id: 'CBT-NEW-${sets.length + 1}',
      title: title,
      className: className,
      questions: 10,
      durationMinutes: 15,
      state: TeacherCbtSetState.draft,
      attempts: 0,
      averageAccuracy: 0,
      resultMode: 'Show score + topic feedback',
      instructions: teacherCbtInstructions,
    );
    sets = [...sets, set];
    return TeacherCbtActionResult(
      success: true,
      message: 'Practice set created as a draft. Configure it and save or publish when ready.',
      set: set,
    );
  }

  @override
  Future<TeacherCbtActionResult> saveDraft(TeacherCbtPracticeSet value) async {
    final updated = value.copyWith(version: value.version + 1);
    sets = sets.map((item) => item.id == updated.id ? updated : item).toList(growable: false);
    return TeacherCbtActionResult(
      success: true,
      message: 'CBT practice draft saved locally and queued for synchronization.',
      set: updated,
    );
  }

  @override
  Future<TeacherCbtActionResult> queuePublication(TeacherCbtPracticeSet value) async {
    final updated = value.copyWith(
      state: TeacherCbtSetState.queuedForPublication,
      version: value.version + 1,
      queuedAt: '2026-09-20T04:40:00Z',
    );
    sets = sets.map((item) => item.id == updated.id ? updated : item).toList(growable: false);
    return TeacherCbtActionResult(
      success: true,
      message: 'CBT practice queued for publication. Student availability is not confirmed until the server acknowledges it.',
      set: updated,
    );
  }
}

class _EmptyFakeCbtRepository implements TeacherCbtRepository {
  @override
  TeacherCbtPermissions permissionsFor(SchoolMembership membership) => const TeacherCbtPermissions(
        canViewAssignedPractice: true,
        canEditDrafts: true,
        canQueuePublication: true,
        canConfirmPublication: false,
        canUsePracticeEvidence: true,
        canMakeHighStakesDecision: false,
      );

  @override
  Future<TeacherCbtSnapshot> load() async => TeacherCbtSnapshot(
        sets: const [],
        classOptions: const [],
        permissions: permissionsFor(_teacher),
      );

  @override
  Future<TeacherCbtActionResult> createDraft({required String className, required String title}) async =>
      const TeacherCbtActionResult(success: false, message: 'Not used in this test.');

  @override
  Future<TeacherCbtActionResult> saveDraft(TeacherCbtPracticeSet value) async =>
      const TeacherCbtActionResult(success: false, message: 'Not used in this test.');

  @override
  Future<TeacherCbtActionResult> queuePublication(TeacherCbtPracticeSet value) async =>
      const TeacherCbtActionResult(success: false, message: 'Not used in this test.');
}
