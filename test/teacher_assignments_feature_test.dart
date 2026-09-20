import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_assignment_demo_data.dart';
import 'package:schoolos_app/features/teacher/data/teacher_assignment_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_assignment_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_assignments_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

void main() {
  test('Assignments preserves exact website library snapshot', () {
    expect(teacherAssignments, hasLength(3));
    expect(teacherAssignments[0].id, 'asg-101');
    expect(teacherAssignments[0].title, 'Linear Equations Practice');
    expect(teacherAssignments[0].className, 'JSS 2A');
    expect(teacherAssignments[0].submissions, 38);
    expect(teacherAssignments[0].totalStudents, 42);
    expect(teacherAssignments[0].marked, 24);
    expect(teacherAssignments[0].state, TeacherAssignmentState.open);
    expect(teacherAssignments[1].title, 'Word Problems');
    expect(teacherAssignments[1].submissions, 31);
    expect(teacherAssignments[1].marked, 18);
    expect(teacherAssignments[2].title, 'Simultaneous Equations');
    expect(teacherAssignments[2].submissions, 40);
    expect(teacherAssignments[2].totalStudents, 41);
    expect(teacherAssignments[2].marked, 40);
    expect(teacherAssignments[2].state, TeacherAssignmentState.closed);
  });

  test('Assignments preserves exact website KPI snapshot', () {
    expect(teacherAssignmentKpis, hasLength(4));
    expect(teacherAssignmentKpis[0], ('Active assignments', '2', 'Across assigned classes'));
    expect(teacherAssignmentKpis[1], ('Pending marking', '27', 'Student submissions'));
    expect(teacherAssignmentKpis[2], ('Submission rate', '91%', 'Current term average'));
    expect(teacherAssignmentKpis[3], ('Late submissions', '6', 'Needs follow-up'));
    expect(teacherAssignments[0].unmarked + teacherAssignments[1].unmarked, 27);
    expect(teacherAssignments[2].unmarked, 0);
  });

  test('assignment draft preserves website defaults and Teacher AI wording', () {
    expect(teacherAssignmentDraft.title, 'Algebra Revision Assignment');
    expect(teacherAssignmentDraft.className, 'JSS 2A');
    expect(teacherAssignmentDraft.dueDate, '2026-09-15');
    expect(teacherAssignmentDraft.maximumScore, 20);
    expect(teacherAssignmentDraft.instructions, contains('Show your working clearly'));
    expect(teacherAssignmentAiInstruction, contains('10 progressively difficult algebra questions'));
    expect(teacherAssignmentAiInstruction, contains('short reflection'));
  });

  test('assignment serializes without losing publication or marking evidence', () {
    final restored = TeacherAssignment.fromJson(teacherAssignments.first.toJson());
    expect(restored.id, 'asg-101');
    expect(restored.submissions, 38);
    expect(restored.marked, 24);
    expect(restored.state, TeacherAssignmentState.open);
    expect(restored.publishedAt, 'server-confirmed');
  });

  test('queued assignment is distinct from server-confirmed Open', () {
    final queued = teacherAssignmentDraft.copyWith(
      state: TeacherAssignmentState.queuedForPublication,
      queuedAt: '2026-09-20T04:30:00Z',
      version: 2,
    );
    expect(queued.teacherEditable, isFalse);
    expect(queued.publishedAt, isNull);
    expect(teacherAssignmentStateLabel(queued.state), 'Queued');
    expect(teacherAssignmentPublishBoundary, contains('does not prove'));
    expect(teacherAssignmentPublishBoundary, contains('server-confirmed Open'));
  });

  test('AI marking and late evidence cannot make automatic decisions', () {
    expect(teacherAssignmentMarkingBoundary, contains('cannot assign or change a student score'));
    expect(teacherAssignmentMarkingBoundary, contains('teacher must confirm'));
    expect(teacherAssignmentEvidenceBoundary, contains('automatic discipline'));
    expect(teacherAssignmentEvidenceBoundary, contains('promotion'));
    expect(teacherAssignmentEvidenceBoundary, contains('safeguarding'));
  });

  test('teacher permissions keep publication acknowledgement and auto-grade unavailable', () {
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
    expect(permissions.canViewAssignedClassAssignments, isTrue);
    expect(permissions.canCreateDraft, isTrue);
    expect(permissions.canQueuePublication, isTrue);
    expect(permissions.canConfirmScores, isTrue);
    expect(permissions.canConfirmPublication, isFalse);
    expect(permissions.canAutoGrade, isFalse);
    expect(fake.permissionsFor(student).canCreateDraft, isFalse);
  });

  testWidgets('Assignments renders website content and filters the library', (tester) async {
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
    expect(find.descendant(of: find.byType(Card), matching: find.text('Linear Equations Practice')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Teacher AI draft remains editable until teacher publishes', (tester) async {
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

  testWidgets('Assignments top actions route to existing Teacher modules', (tester) async {
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

    await tester.tap(find.widgetWithText(OutlinedButton, 'My Classes'));
    await tester.pump();
    expect(destination, 'classes');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Share work'));
    await tester.pump();
    expect(destination, 'messages');
  });

  testWidgets('Assignments renders on phone without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    expect(find.text('Create assignment'), findsOneWidget);
    expect(find.text('Marking queue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeAssignmentRepository implements TeacherAssignmentRepository {
  TeacherAssignment draft = teacherAssignmentDraft;
  List<TeacherAssignment> library = List<TeacherAssignment>.from(teacherAssignments);

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
}
