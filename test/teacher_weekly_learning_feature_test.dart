import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_weekly_learning_demo_data.dart';
import 'package:schoolos_app/features/teacher/data/teacher_weekly_learning_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_weekly_learning_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_weekly_learning_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

void main() {
  test('Weekly Learning preserves exact website subject seed', () {
    expect(teacherWeeklySubjects, hasLength(3));
    expect(teacherWeeklySubjects[0].subject, 'Mathematics');
    expect(teacherWeeklySubjects[0].planned, 'Linear equations and guided practice');
    expect(
      teacherWeeklySubjects[0].covered,
      'Linear equations completed with worked examples and short class assessment',
    );
    expect(teacherWeeklySubjects[0].evidence, 'Classwork 82% · Assignment 79%');
    expect(teacherWeeklySubjects[0].support, contains('Fractions'));
    expect(teacherWeeklySubjects[0].linkedPlanId, 'LP-206');
    expect(teacherWeeklySubjects[1].subject, 'English');
    expect(teacherWeeklySubjects[1].next, 'Formal letter writing');
    expect(teacherWeeklySubjects[2].subject, 'Basic Science');
    expect(teacherWeeklySubjects[2].next, 'Nutrition and balanced diet');
  });

  test('initial Weekly Learning snapshot matches website class week and readiness', () {
    expect(teacherWeeklyInitialUpdate.className, 'JSS 2A');
    expect(teacherWeeklyInitialUpdate.week, 'Week 6');
    expect(teacherWeeklyInitialUpdate.state, TeacherWeeklyPublicationState.draft);
    expect(teacherWeeklyInitialUpdate.completionPercent, 100);
    expect(teacherWeeklyInitialNote, contains('major planned topics'));
    expect(teacherWeeklyInitialNote, contains('Mathematics practice'));
    expect(teacherWeeklyTermLabel, '2026/2027 Term 1');
  });

  test('weekly workflow preserves exact four-step website intent', () {
    expect(teacherWeeklyFlow, hasLength(4));
    expect(teacherWeeklyFlow[0], ('Approved lesson plan', 'What was intended'));
    expect(teacherWeeklyFlow[1], ('Actual classroom delivery', 'What was covered'));
    expect(teacherWeeklyFlow[2], ('Evidence', 'Classwork / assignment'));
    expect(teacherWeeklyFlow[3], ('Parent update', 'What happened + what is next'));
  });

  test('weekly update serializes without losing parent-ready evidence', () {
    final restored = TeacherWeeklyLearningUpdate.fromJson(
      teacherWeeklyInitialUpdate.toJson(),
    );
    expect(restored.id, teacherWeeklyInitialUpdate.id);
    expect(restored.subjects, hasLength(3));
    expect(restored.subjects.first.linkedPlanId, 'LP-206');
    expect(restored.subjects.last.evidence, 'Class diagram + 10-question check');
    expect(restored.note, teacherWeeklyInitialNote);
    expect(restored.version, 1);
  });

  test('publication boundaries exclude private and cross-child records', () {
    expect(teacherWeeklyPublicationBoundary, contains('linked child'));
    expect(teacherWeeklyPublicationBoundary, contains('other children'));
    expect(teacherWeeklyPublicationBoundary, contains('safeguarding'));
    expect(teacherWeeklyPublicationBoundary, contains('staff-only'));
    expect(teacherWeeklyDeliveryBoundary, contains('does not prove'));
    expect(teacherWeeklyDeliveryBoundary, contains('server acknowledgement'));
    expect(teacherWeeklyEvidenceBoundary, contains('must not invent individual learner results'));
    expect(teacherWeeklyEvidenceBoundary, contains('promotion'));
  });

  test('publication state distinguishes queued from actually published', () {
    final queued = teacherWeeklyInitialUpdate.copyWith(
      state: TeacherWeeklyPublicationState.queuedForPublication,
      queuedAt: '2026-09-18T15:00:00Z',
      version: 2,
    );
    expect(queued.teacherEditable, isFalse);
    expect(queued.publishedAt, isNull);
    expect(teacherWeeklyPublicationLabel(queued.state), 'Queued for publication');
  });

  test('teacher weekly permissions never grant delivery or private-record authority', () {
    final fake = _FakeWeeklyLearningRepository();
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

    final teacherPermissions = fake.permissionsFor(teacher);
    expect(teacherPermissions.canEditDraft, isTrue);
    expect(teacherPermissions.canQueuePublication, isTrue);
    expect(teacherPermissions.canConfirmParentDelivery, isFalse);
    expect(teacherPermissions.canIncludePrivateRecords, isFalse);
    expect(fake.permissionsFor(parent).canEditDraft, isFalse);
  });

  testWidgets('Weekly Learning renders exact website content and linked plan', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherWeeklyLearningPage(
            repository: _FakeWeeklyLearningRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekly Learning Progress'), findsOneWidget);
    expect(find.text('Subjects this week'), findsOneWidget);
    expect(find.text('Mathematics'), findsWidgets);
    expect(find.text('English'), findsWidgets);
    expect(find.text('Basic Science'), findsWidgets);
    expect(find.text('From LP-206'), findsOneWidget);
    expect(find.text('Parent preview'), findsOneWidget);
    expect(find.textContaining('100% with coverage notes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save then publish keeps publication distinct from delivery', (
    tester,
  ) async {
    final fake = _FakeWeeklyLearningRepository();
    var queuedCallbacks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherWeeklyLearningPage(
            repository: fake,
            onNavigate: (_) {},
            onMutationQueued: () => queuedCallbacks++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save draft'));
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(fake.update.version, 2);
    expect(find.text('Draft saved · sync pending'), findsWidgets);

    await tester.ensureVisible(find.text('Publish weekly update'));
    await tester.tap(find.text('Publish weekly update'));
    await tester.pumpAndSettle();
    expect(fake.update.state, TeacherWeeklyPublicationState.queuedForPublication);
    expect(fake.update.publishedAt, isNull);
    expect(find.text('Queued for parent publication · sync pending'), findsWidgets);
    expect(queuedCallbacks, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Weekly Learning top actions route to dedicated Teacher modules', (
    tester,
  ) async {
    String? destination;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherWeeklyLearningPage(
            repository: _FakeWeeklyLearningRepository(),
            onNavigate: (value) => destination = value,
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Lesson Plans'));
    await tester.pump();
    expect(destination, 'lesson-plans');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Assignments'));
    await tester.pump();
    expect(destination, 'assignments');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Messages'));
    await tester.pump();
    expect(destination, 'messages');
  });

  testWidgets('Weekly Learning renders on phone without exceptions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherWeeklyLearningPage(
            repository: _FakeWeeklyLearningRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekly Learning Progress'), findsOneWidget);
    expect(find.text('Teacher does the work once'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeWeeklyLearningRepository implements TeacherWeeklyLearningRepository {
  TeacherWeeklyLearningUpdate update = teacherWeeklyInitialUpdate;
  final List<TeacherWeeklyLearningEvent> events = [];

  @override
  TeacherWeeklyLearningPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherWeeklyLearningPermissions(
      canViewAssignedClassUpdates: teacher,
      canEditDraft: teacher,
      canQueuePublication: teacher,
      canConfirmParentDelivery: false,
      canIncludePrivateRecords: false,
    );
  }

  @override
  Future<TeacherWeeklyLearningSnapshot> load() async =>
      TeacherWeeklyLearningSnapshot(
        update: update,
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
  Future<TeacherWeeklyLearningActionResult> saveDraft(
    TeacherWeeklyLearningUpdate draft,
  ) async {
    update = draft.copyWith(
      state: TeacherWeeklyPublicationState.draft,
      version: draft.version + 1,
      updatedAt: '2026-09-18T14:00:00Z',
    );
    events.add(
      TeacherWeeklyLearningEvent(
        id: 'evt-save-${update.version}',
        updateId: update.id,
        action: TeacherWeeklyEventAction.savedDraft,
        actorMembershipId: 'teacher-1',
        version: update.version,
        occurredAt: '2026-09-18T14:00:00Z',
      ),
    );
    return TeacherWeeklyLearningActionResult(
      success: true,
      message: 'Weekly learning draft saved locally and queued for synchronization.',
      update: update,
    );
  }

  @override
  Future<TeacherWeeklyLearningActionResult> queuePublication(
    TeacherWeeklyLearningUpdate draft,
  ) async {
    update = draft.copyWith(
      state: TeacherWeeklyPublicationState.queuedForPublication,
      version: draft.version + 1,
      updatedAt: '2026-09-18T15:00:00Z',
      queuedAt: '2026-09-18T15:00:00Z',
    );
    events.add(
      TeacherWeeklyLearningEvent(
        id: 'evt-publish-${update.version}',
        updateId: update.id,
        action: TeacherWeeklyEventAction.queuedForPublication,
        actorMembershipId: 'teacher-1',
        version: update.version,
        occurredAt: '2026-09-18T15:00:00Z',
      ),
    );
    return TeacherWeeklyLearningActionResult(
      success: true,
      message: 'Weekly update queued for parent publication. Delivery is not confirmed until the server or messaging provider acknowledges it.',
      update: update,
    );
  }
}
