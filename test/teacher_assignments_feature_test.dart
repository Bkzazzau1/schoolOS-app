import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_assignment_policy_copy.dart';
import 'package:schoolos_app/features/teacher/data/teacher_assignment_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_assignment_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_assignments_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

const _fixtureDraft = TeacherAssignment(
  id: 'asg-draft-104',
  title: 'Algebra Revision Assignment',
  className: 'JSS 2A',
  type: TeacherAssignmentType.homework,
  instructions: 'Answer all questions. Show your working clearly and submit before the deadline.',
  dueDate: '2026-09-15',
  maximumScore: 20,
  submissions: 0,
  totalStudents: 42,
  marked: 0,
  lateSubmissions: 0,
  state: TeacherAssignmentState.draft,
);

const _fixtureAssignments = <TeacherAssignment>[
  TeacherAssignment(
    id: 'asg-101',
    title: 'Linear Equations Practice',
    className: 'JSS 2A',
    type: TeacherAssignmentType.homework,
    instructions: '',
    dueDate: '14 Sep',
    maximumScore: 20,
    submissions: 38,
    totalStudents: 42,
    marked: 24,
    lateSubmissions: 0,
    state: TeacherAssignmentState.open,
    publishedAt: 'server-confirmed',
  ),
  TeacherAssignment(
    id: 'asg-102',
    title: 'Word Problems',
    className: 'JSS 2B',
    type: TeacherAssignmentType.homework,
    instructions: '',
    dueDate: '15 Sep',
    maximumScore: 20,
    submissions: 31,
    totalStudents: 39,
    marked: 18,
    lateSubmissions: 0,
    state: TeacherAssignmentState.open,
    publishedAt: 'server-confirmed',
  ),
  TeacherAssignment(
    id: 'asg-103',
    title: 'Simultaneous Equations',
    className: 'JSS 3A',
    type: TeacherAssignmentType.homework,
    instructions: '',
    dueDate: '12 Sep',
    maximumScore: 20,
    submissions: 40,
    totalStudents: 41,
    marked: 40,
    lateSubmissions: 0,
    state: TeacherAssignmentState.closed,
    publishedAt: 'server-confirmed',
  ),
];

void main() {
  test('assignment rows carry real submission/marking evidence', () {
    expect(_fixtureAssignments, hasLength(3));
    expect(_fixtureAssignments[0].title, 'Linear Equations Practice');
    expect(_fixtureAssignments[0].className, 'JSS 2A');
    expect(_fixtureAssignments[0].submissions, 38);
    expect(_fixtureAssignments[0].totalStudents, 42);
    expect(_fixtureAssignments[0].marked, 24);
    expect(_fixtureAssignments[1].title, 'Word Problems');
    expect(_fixtureAssignments[1].submissions, 31);
    expect(_fixtureAssignments[1].marked, 18);
    expect(_fixtureAssignments[2].title, 'Simultaneous Equations');
    expect(_fixtureAssignments[2].state, TeacherAssignmentState.closed);
    expect(_fixtureAssignments[2].marked, 40);
    expect(_fixtureAssignments[0].unmarked + _fixtureAssignments[1].unmarked, 27);
  });

  test('draft and AI wording preserve website defaults', () {
    expect(_fixtureDraft.title, 'Algebra Revision Assignment');
    expect(_fixtureDraft.className, 'JSS 2A');
    expect(_fixtureDraft.dueDate, '2026-09-15');
    expect(_fixtureDraft.maximumScore, 20);
    expect(_fixtureDraft.instructions, contains('Show your working clearly'));
    expect(teacherAssignmentAiInstruction, contains('10 progressively difficult algebra questions'));
    expect(teacherAssignmentAiInstruction, contains('short reflection'));
  });

  test('assignment serialization preserves publication and marking evidence', () {
    final restored = TeacherAssignment.fromJson(_fixtureAssignments.first.toJson());
    expect(restored.id, 'asg-101');
    expect(restored.submissions, 38);
    expect(restored.marked, 24);
    expect(restored.state, TeacherAssignmentState.open);
    expect(restored.publishedAt, 'server-confirmed');
  });

  test('queued publication and AI marking boundaries remain human-controlled', () {
    final queued = _fixtureDraft.copyWith(
      state: TeacherAssignmentState.queuedForPublication,
      queuedAt: '2026-09-20T04:30:00Z',
      version: 2,
    );
    expect(queued.teacherEditable, isFalse);
    expect(queued.publishedAt, isNull);
    expect(teacherAssignmentPublishBoundary, contains('does not prove'));
    expect(teacherAssignmentMarkingBoundary, contains('cannot assign or change a student score'));
    expect(teacherAssignmentEvidenceBoundary, contains('automatic discipline'));
  });

  test('teacher permissions never grant publication acknowledgement or auto-grade', () {
    final fake = _FakeAssignmentRepository();
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
    expect(permissions.canCreateDraft, isTrue);
    expect(permissions.canQueuePublication, isTrue);
    expect(permissions.canConfirmScores, isTrue);
    expect(permissions.canConfirmPublication, isFalse);
    expect(permissions.canAutoGrade, isFalse);
    expect(fake.permissionsFor(student).canCreateDraft, isFalse);
  });

  testWidgets('Assignments renders website content and accepts library search', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherAssignmentsPage(
            repository: _FakeAssignmentRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Assignments'), findsOneWidget);
    expect(find.text('27 pending'), findsOneWidget);
    expect(find.text('Linear Equations Practice'), findsWidgets);
    expect(find.text('Word Problems'), findsWidgets);
    expect(find.text('Simultaneous Equations'), findsWidgets);

    final search = find.widgetWithText(TextField, 'Search assignments...');
    await tester.ensureVisible(search);
    await tester.enterText(search, 'Word Problems');
    await tester.pump();
    expect(find.text('Word Problems'), findsWidgets);
    expect(find.text('No assignments match this filter.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Teacher AI draft remains a draft until teacher queues publication', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = _FakeAssignmentRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherAssignmentsPage(
            repository: fake,
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Generate with Teacher AI'));
    await tester.tap(find.text('Generate with Teacher AI'));
    await tester.pump();
    expect(find.textContaining('Teacher AI draft inserted'), findsOneWidget);
    expect(fake.draft.state, TeacherAssignmentState.draft);

    await tester.ensureVisible(find.text('Publish assignment'));
    await tester.tap(find.text('Publish assignment'));
    await tester.pumpAndSettle();
    expect(fake.draft.state, TeacherAssignmentState.queuedForPublication);
    expect(fake.draft.publishedAt, isNull);
    expect(find.textContaining('Student delivery is not confirmed'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Assignments routes to connected Teacher modules and renders on phone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? destination;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherAssignmentsPage(
            repository: _FakeAssignmentRepository(),
            onNavigate: (value) => destination = value,
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create assignment'), findsOneWidget);
    expect(find.text('Marking queue'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'My Classes'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'My Classes'));
    await tester.pump();
    expect(destination, 'classes');
    expect(tester.takeException(), isNull);
  });
}

class _FakeAssignmentRepository implements TeacherAssignmentRepository {
  TeacherAssignment draft = _fixtureDraft;
  final List<TeacherAssignment> library = List<TeacherAssignment>.from(_fixtureAssignments);

  @override
  TeacherAssignmentPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherAssignmentPermissions(
      canViewAssignedClassAssignments: teacher,
      canCreateDraft: teacher,
      canQueuePublication: teacher,
      canConfirmPublication: false,
      canConfirmScores: teacher,
      canAutoGrade: false,
    );
  }

  @override
  Future<TeacherAssignmentSnapshot> load() async => TeacherAssignmentSnapshot(
        assignments: library,
        draft: draft,
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
  Future<TeacherAssignmentActionResult> saveDraft(TeacherAssignment value) async {
    draft = value.copyWith(
      state: TeacherAssignmentState.draft,
      version: value.version + 1,
      updatedAt: '2026-09-20T04:30:00Z',
    );
    return TeacherAssignmentActionResult(
      success: true,
      message: 'Assignment draft saved locally and queued for synchronization.',
      assignment: draft,
    );
  }

  @override
  Future<TeacherAssignmentActionResult> queuePublication(TeacherAssignment value) async {
    draft = value.copyWith(
      state: TeacherAssignmentState.queuedForPublication,
      version: value.version + 1,
      updatedAt: '2026-09-20T04:31:00Z',
      queuedAt: '2026-09-20T04:31:00Z',
    );
    return TeacherAssignmentActionResult(
      success: true,
      message: 'Assignment queued for publication. Student delivery is not confirmed until the server acknowledges it.',
      assignment: draft,
    );
  }

  @override
  Future<TeacherAssignmentActionResult> revise(TeacherAssignment assignment) async =>
      const TeacherAssignmentActionResult(success: false, message: 'Not used in this test.');

  @override
  Future<TeacherAssignmentActionResult> close(TeacherAssignment assignment) async =>
      const TeacherAssignmentActionResult(success: false, message: 'Not used in this test.');

  @override
  Future<TeacherAssignmentActionResult> gradeSubmission(
    TeacherAssignmentSubmission submission, {
    required double score,
    required String feedback,
  }) async =>
      const TeacherAssignmentActionResult(success: false, message: 'Not used in this test.');

  @override
  Future<TeacherAssignmentActionResult> returnSubmission(
    TeacherAssignmentSubmission submission, {
    required String feedback,
  }) async =>
      const TeacherAssignmentActionResult(success: false, message: 'Not used in this test.');
}
