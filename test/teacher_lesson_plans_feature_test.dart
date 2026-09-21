import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_lesson_plan_demo_data.dart';
import 'package:schoolos_app/features/teacher/data/teacher_lesson_plan_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_lesson_plan_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_lesson_plans_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

void main() {
  test('lesson plan history preserves exact four website rows', () {
    expect(teacherLessonPlans, hasLength(4));
    expect(teacherLessonPlans[0].id, 'LP-206');
    expect(teacherLessonPlans[0].className, 'JSS 2A');
    expect(teacherLessonPlans[0].week, 'Week 6');
    expect(teacherLessonPlans[0].topic, 'Linear Equations');
    expect(teacherLessonPlans[0].status, TeacherLessonPlanStatus.draft);
    expect(teacherLessonPlans[0].updatedLabel, 'Today, 9:10 AM');

    expect(teacherLessonPlans[1].id, 'LP-205');
    expect(teacherLessonPlans[1].status, TeacherLessonPlanStatus.submitted);
    expect(teacherLessonPlans[1].updatedLabel, 'Yesterday');

    expect(teacherLessonPlans[2].id, 'LP-201');
    expect(teacherLessonPlans[2].topic, 'Simultaneous Equations');
    expect(teacherLessonPlans[2].status, TeacherLessonPlanStatus.approved);

    expect(teacherLessonPlans[3].id, 'LP-198');
    expect(teacherLessonPlans[3].className, 'SS 1A');
    expect(teacherLessonPlans[3].topic, 'Functions');
    expect(teacherLessonPlans[3].status, TeacherLessonPlanStatus.needsChanges);
  });

  test('lesson plan term KPIs preserve exact website snapshot', () {
    expect(teacherLessonPlanTermKpis, [
      ('This term', '12', 'lesson plans'),
      ('Approved', '9', '75% approved'),
      ('Pending', '2', 'awaiting review'),
      ('Needs changes', '1', 'action required'),
    ]);
  });

  test('AI draft preserves exact website teaching content', () {
    expect(teacherLessonPlanAiObjectives, contains('define a linear equation'));
    expect(teacherLessonPlanAiObjectives, contains('variables and constants'));
    expect(teacherLessonPlanAiStarter, contains('balance-scale'));
    expect(teacherLessonPlanAiActivities, contains('five-question independent task'));
    expect(teacherLessonPlanAiAssessment, contains('3x + 4 = 19'));
    expect(teacherLessonPlanAiResources, contains('printed practice sheet'));
  });

  test('lesson plan model serializes version and approval state', () {
    final original = teacherLessonPlans.last.copyWith(
      objectives: 'Solve examples',
      version: 4,
    );
    final restored = TeacherLessonPlan.fromJson(original.toJson());
    expect(restored.id, 'LP-198');
    expect(restored.status, TeacherLessonPlanStatus.needsChanges);
    expect(restored.objectives, 'Solve examples');
    expect(restored.version, 4);
    expect(restored.teacherEditable, isTrue);
    expect(teacherLessonPlans[2].teacherEditable, isFalse);
  });

  test('lesson plan event is append-only version evidence', () {
    const event = TeacherLessonPlanEvent(
      id: 'evt-1',
      planId: 'LP-206',
      action: TeacherLessonPlanEventAction.submitted,
      actorMembershipId: 'teacher-membership',
      version: 3,
      occurredAt: '2026-09-14T09:20:00Z',
    );
    final restored = TeacherLessonPlanEvent.fromJson(event.toJson());
    expect(restored.planId, 'LP-206');
    expect(restored.action, TeacherLessonPlanEventAction.submitted);
    expect(restored.version, 3);
  });

  test('teacher permissions keep approval with reviewer authority', () {
    final fake = _FakeLessonPlanRepository();
    const teacher = SchoolMembership(
      id: 'teacher-membership',
      schoolId: 'school-1',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.teacher,
    );
    const principal = SchoolMembership(
      id: 'principal-membership',
      schoolId: 'school-1',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.principal,
    );

    final teacherPermissions = fake.permissionsFor(teacher);
    expect(teacherPermissions.canViewAssignedPlans, isTrue);
    expect(teacherPermissions.canEditDrafts, isTrue);
    expect(teacherPermissions.canSubmitForApproval, isTrue);
    expect(teacherPermissions.canApprovePlans, isFalse);
    expect(teacherPermissions.canOverrideReviewerStatus, isFalse);

    expect(fake.permissionsFor(principal).canEditDrafts, isFalse);
  });

  test('lesson plan boundaries keep AI and offline submission non-authoritative', () {
    expect(teacherLessonPlanAuthorityBoundary, contains('cannot approve their own plans'));
    expect(teacherLessonPlanAuthorityBoundary, contains('AI draft'));
    expect(teacherLessonPlanOfflineBoundary, contains('pending synchronization'));
    expect(teacherLessonPlanOfflineBoundary, contains('reviewer-confirmed'));
  });

  test('lesson plan search covers id class week topic and status', () {
    expect(teacherLessonPlans.where((plan) => plan.matches('LP-201')).single.className, 'JSS 3A');
    expect(teacherLessonPlans.where((plan) => plan.matches('needs changes')).single.id, 'LP-198');
    expect(teacherLessonPlans.where((plan) => plan.matches('Week 6')).length, 2);
  });

  testWidgets('AI draft fills editor but does not auto-submit', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = _FakeLessonPlanRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherLessonPlansPage(
            repository: fake,
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Generate AI draft'));
    await tester.tap(find.text('Generate AI draft'));
    await tester.pump();

    expect(find.text('AI draft ready'), findsOneWidget);
    expect(find.textContaining('AI generated a draft only'), findsOneWidget);
    expect(fake.plans.first.status, TeacherLessonPlanStatus.draft);
    expect(tester.takeException(), isNull);
  });

  testWidgets('submit moves draft to pending approval rather than approved', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = _FakeLessonPlanRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherLessonPlansPage(
            repository: fake,
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate AI draft'));
    await tester.pump();
    await tester.ensureVisible(find.text('Submit for approval'));
    await tester.tap(find.text('Submit for approval'));
    await tester.pumpAndSettle();

    expect(fake.plans.first.status, TeacherLessonPlanStatus.submitted);
    expect(find.text('Submitted for approval · sync pending'), findsOneWidget);
    expect(find.textContaining('This is not an approval'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lesson plan history search filters website rows', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherLessonPlansPage(
            repository: _FakeLessonPlanRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final search = find.widgetWithText(TextField, 'Search plans...');
    await tester.ensureVisible(search);
    await tester.enterText(search, 'LP-198');
    await tester.pump();

    expect(find.text('LP-198'), findsOneWidget);
    expect(find.text('LP-201'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Lesson Plans renders on a phone-sized viewport without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherLessonPlansPage(
            repository: _FakeLessonPlanRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create lesson plan'), findsOneWidget);
    expect(find.text('Planning guide'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeLessonPlanRepository implements TeacherLessonPlanRepository {
  List<TeacherLessonPlan> plans = List<TeacherLessonPlan>.from(teacherLessonPlans);
  final List<TeacherLessonPlanEvent> events = [];

  @override
  TeacherLessonPlanPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherLessonPlanPermissions(
      canViewAssignedPlans: teacher,
      canEditDrafts: teacher,
      canSubmitForApproval: teacher,
      canApprovePlans: false,
      canOverrideReviewerStatus: false,
    );
  }

  @override
  Future<TeacherLessonPlanSnapshot> load() async => TeacherLessonPlanSnapshot(
        plans: plans,
        events: events,
        permissions: permissionsFor(
          const SchoolMembership(
            id: 'teacher-membership',
            schoolId: 'school-1',
            schoolName: 'BrightGate Academy',
            role: SchoolRole.teacher,
          ),
        ),
      );

  @override
  Future<TeacherLessonPlanActionResult> saveDraft({required TeacherLessonPlan plan}) async {
    final current = plans.firstWhere((item) => item.id == plan.id);
    if (!current.teacherEditable) {
      return const TeacherLessonPlanActionResult(success: false, message: 'Plan locked.');
    }
    final next = plan.copyWith(
      status: current.status == TeacherLessonPlanStatus.needsChanges
          ? TeacherLessonPlanStatus.needsChanges
          : TeacherLessonPlanStatus.draft,
      updatedLabel: 'Draft saved · sync pending',
      version: current.version + 1,
    );
    _replace(next);
    events.add(
      TeacherLessonPlanEvent(
        id: 'save-${events.length}',
        planId: next.id,
        action: TeacherLessonPlanEventAction.savedDraft,
        actorMembershipId: 'teacher-membership',
        version: next.version,
        occurredAt: '2026-09-14T09:15:00Z',
      ),
    );
    return TeacherLessonPlanActionResult(
      success: true,
      message: 'Draft saved locally and queued for synchronization.',
      plan: next,
    );
  }

  @override
  Future<TeacherLessonPlanActionResult> submit({required TeacherLessonPlan plan}) async {
    final current = plans.firstWhere((item) => item.id == plan.id);
    if (!current.teacherEditable) {
      return const TeacherLessonPlanActionResult(success: false, message: 'Plan locked.');
    }
    if (plan.objectives.trim().isEmpty || plan.activities.trim().isEmpty || plan.assessment.trim().isEmpty) {
      return const TeacherLessonPlanActionResult(
        success: false,
        message: 'Add learning objectives, teaching activities and assessment evidence before submission.',
      );
    }
    final next = plan.copyWith(
      status: TeacherLessonPlanStatus.submitted,
      updatedLabel: 'Submitted · sync pending',
      version: current.version + 1,
    );
    _replace(next);
    events.add(
      TeacherLessonPlanEvent(
        id: 'submit-${events.length}',
        planId: next.id,
        action: TeacherLessonPlanEventAction.submitted,
        actorMembershipId: 'teacher-membership',
        version: next.version,
        occurredAt: '2026-09-14T09:20:00Z',
      ),
    );
    return TeacherLessonPlanActionResult(
      success: true,
      message: 'Plan submitted locally and queued for approval review. This is not an approval.',
      plan: next,
    );
  }

  void _replace(TeacherLessonPlan updated) {
    plans = [for (final plan in plans) if (plan.id == updated.id) updated else plan];
  }
}
