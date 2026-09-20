import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_cbt_demo_data.dart';
import 'package:schoolos_app/features/teacher/data/teacher_cbt_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_cbt_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_cbt_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

void main() {
  test('CBT Practice preserves exact website set snapshot', () {
    expect(teacherCbtSets, hasLength(3));
    expect(teacherCbtSets[0].id, 'CBT-MTH-026');
    expect(teacherCbtSets[0].title, 'JSS 2 Mathematics · Linear Equations');
    expect(teacherCbtSets[0].questions, 20);
    expect(teacherCbtSets[0].durationMinutes, 20);
    expect(teacherCbtSets[0].state, TeacherCbtSetState.published);
    expect(teacherCbtSets[0].attempts, 38);
    expect(teacherCbtSets[0].averageAccuracy, 78);
    expect(teacherCbtSets[1].id, 'CBT-MTH-027');
    expect(teacherCbtSets[1].state, TeacherCbtSetState.draft);
    expect(teacherCbtSets[1].questions, 15);
    expect(teacherCbtSets[2].id, 'CBT-MTH-021');
    expect(teacherCbtSets[2].state, TeacherCbtSetState.closed);
    expect(teacherCbtSets[2].attempts, 36);
    expect(teacherCbtSets[2].averageAccuracy, 64);
  });

  test('CBT Practice preserves exact website KPI snapshot', () {
    expect(teacherCbtKpis, hasLength(4));
    expect(teacherCbtKpis[0], ('Question sets', '12', '8 published · 4 draft'));
    expect(teacherCbtKpis[1], ('Practice attempts', '286', 'this term'));
    expect(teacherCbtKpis[2], ('Average accuracy', '74%', 'across assigned practice'));
    expect(teacherCbtKpis[3].$2, '3');
    expect(teacherCbtKpis[3].$3, 'Fractions · Geometry · Word problems');
  });

  test('CBT learner evidence matches website results exactly', () {
    expect(teacherCbtResults, hasLength(3));
    expect(teacherCbtResults[0].student, 'Maryam Abdullahi');
    expect(teacherCbtResults[0].score, '16/20');
    expect(teacherCbtResults[0].accuracy, '80%');
    expect(teacherCbtResults[0].time, '14m 12s');
    expect(teacherCbtResults[0].focus, 'Fractions · Geometry');
    expect(teacherCbtResults[1].student, 'Ibrahim Sani');
    expect(teacherCbtResults[1].accuracy, '60%');
    expect(teacherCbtResults[2].student, 'Yusuf Bello');
    expect(teacherCbtResults[2].accuracy, '45%');
    expect(teacherCbtResults[2].focus, 'Fractions · Word problems');
  });

  test('question preview keeps exact item and topic tag principle', () {
    expect(teacherCbtQuestionTopic, 'Linear Equations');
    expect(teacherCbtQuestionText, 'If 3x + 4 = 19, what is the value of x?');
    expect(teacherCbtQuestionOptions, ['A. 3', 'B. 4', 'C. 5', 'D. 6']);
    expect(teacherCbtDesignBoundary, contains('topic tag'));
  });

  test('CBT set serialization preserves publication evidence', () {
    final restored = TeacherCbtPracticeSet.fromJson(teacherCbtSets.first.toJson());
    expect(restored.id, 'CBT-MTH-026');
    expect(restored.state, TeacherCbtSetState.published);
    expect(restored.attempts, 38);
    expect(restored.averageAccuracy, 78);
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
    expect(permissions.canViewAssignedPractice, isTrue);
    expect(permissions.canEditDrafts, isTrue);
    expect(permissions.canQueuePublication, isTrue);
    expect(permissions.canUsePracticeEvidence, isTrue);
    expect(permissions.canConfirmPublication, isFalse);
    expect(permissions.canMakeHighStakesDecision, isFalse);
    expect(fake.permissionsFor(parent).canEditDrafts, isFalse);
  });

  testWidgets('CBT Practice renders exact website evidence', (tester) async {
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
    expect(find.text('Maryam Abdullahi'), findsOneWidget);
    expect(find.text('Ibrahim Sani'), findsOneWidget);
    expect(find.text('Yusuf Bello'), findsOneWidget);
    expect(find.text('Question 7 of 20'), findsOneWidget);
    expect(find.text(teacherCbtQuestionText), findsOneWidget);
    expect(find.text('Learning Intelligence handoff'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('draft publication becomes queued and never self-confirms Published', (tester) async {
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

  testWidgets('CBT top actions route to Teacher Dashboard and Assessments', (tester) async {
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
