import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_ai_demo_data.dart';
import 'package:schoolos_app/features/teacher/data/teacher_ai_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_ai_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_ai_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

void main() {
  test('Teacher AI preserves exact website prompt suggestions and contexts', () {
    expect(teacherAiPromptSuggestions, hasLength(4));
    expect(
      teacherAiPromptSuggestions.first,
      'Create a 40-minute revision activity for JSS 2B linear equations',
    );
    expect(
      teacherAiPromptSuggestions.last,
      'Draft parent-friendly feedback for a learner who is improving but still below target',
    );
    expect(TeacherAiContext.values, hasLength(4));
    expect(TeacherAiContext.jss2aMathematics.label, 'JSS 2A · Mathematics');
    expect(TeacherAiContext.jss2bMathematics.label, 'JSS 2B · Mathematics');
    expect(TeacherAiContext.jss3aMathematics.label, 'JSS 3A · Mathematics');
    expect(
      TeacherAiContext.ss1aFurtherMathematics.label,
      'SS 1A · Further Mathematics',
    );
  });

  test('Teacher AI preserves four website tools and three suggested actions', () {
    expect(teacherAiTools, hasLength(4));
    expect(teacherAiTools.map((item) => item.title), [
      'Lesson planner',
      'Quiz generator',
      'Assessment analyst',
      'Student support',
    ]);
    expect(teacherAiTools.map((item) => item.destination), [
      'lesson-plans',
      'assignments',
      'assessments',
      'students',
    ]);
    expect(teacherAiSuggestedActions, hasLength(3));
    expect(teacherAiSuggestedActions[0].destination, 'syllabus');
    expect(teacherAiSuggestedActions[1].destination, 'assessments');
    expect(teacherAiSuggestedActions[2].destination, 'assignments');
  });

  test('Teacher AI preserves initial website history and response contract', () {
    expect(teacherAiInitialHistory, hasLength(2));
    expect(
      teacherAiInitialHistory.first.prompt,
      'Why is JSS 2B behind the syllabus pace?',
    );
    expect(
      teacherAiInitialHistory.last.prompt,
      'Create a short revision activity for Week 6',
    );
    final response = teacherAiResponseFor(
      context: TeacherAiContext.jss2bMathematics,
      prompt: 'Plan Week 6 revision',
    );
    expect(response, contains('For JSS 2B'));
    expect(response, contains('teacher-authorized class context only'));
    expect(response, contains('reviewed by you before it is saved, sent or submitted'));
  });

  test('Teacher AI history serializes tenant-local prompt evidence', () {
    final restored = TeacherAiPromptHistoryItem.fromJson(
      teacherAiInitialHistory.first.toJson(),
    );
    expect(restored.id, teacherAiInitialHistory.first.id);
    expect(restored.prompt, teacherAiInitialHistory.first.prompt);
    expect(restored.context, TeacherAiContext.jss2bMathematics);
    expect(restored.createdAt, teacherAiInitialHistory.first.createdAt);
  });

  test('Teacher AI permissions allow drafting but deny consequential authority', () {
    final fake = _FakeTeacherAiRepository();
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
    expect(permissions.canUseAssignedClassContext, isTrue);
    expect(permissions.canDraftTeachingContent, isTrue);
    expect(permissions.canSuggestSupport, isTrue);
    expect(permissions.canRetrieveUnrelatedClasses, isFalse);
    expect(permissions.canAccessFinance, isFalse);
    expect(permissions.canAccessStaffConfidentialData, isFalse);
    expect(permissions.canAccessOtherSchools, isFalse);
    expect(permissions.canAlterMarks, isFalse);
    expect(permissions.canAlterAttendance, isFalse);
    expect(permissions.canSendMessages, isFalse);
    expect(permissions.canTakeConsequentialAction, isFalse);
    expect(fake.permissionsFor(parent).canUseAssignedClassContext, isFalse);
  });

  test('Teacher AI governance explicitly requires human authority', () {
    expect(teacherAiGovernanceBoundary, contains('alter marks or attendance'));
    expect(teacherAiGovernanceBoundary, contains('send communications'));
    expect(teacherAiGovernanceBoundary, contains('safeguarding decisions'));
    expect(teacherAiGovernanceBoundary, contains('punish'));
    expect(teacherAiGovernanceBoundary, contains('promote'));
    expect(teacherAiGovernanceBoundary, contains('fail'));
    expect(teacherAiGovernanceBoundary, contains('exclude'));
    expect(teacherAiGovernanceBoundary, contains('draft as approved school action'));
  });

  testWidgets('Teacher AI renders exact website workspace and history',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherAiPage(
            repository: _FakeTeacherAiRepository(),
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your teaching copilot'), findsOneWidget);
    expect(find.text('Ask Teacher AI'), findsWidgets);
    expect(find.text('School context on'), findsOneWidget);
    expect(find.text('Recent AI activity'), findsOneWidget);
    expect(find.text('Lesson planner'), findsOneWidget);
    expect(find.text('Quiz generator'), findsOneWidget);
    expect(find.text('Assessment analyst'), findsOneWidget);
    expect(find.text('Student support'), findsOneWidget);
    expect(find.text('Today’s suggested actions'), findsOneWidget);
    expect(find.text('Teacher AI governance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Teacher AI prompt generates review-only response and history',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _FakeTeacherAiRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherAiPage(
            repository: repository,
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'Create a recovery activity for fractions',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Ask Teacher AI'));
    await tester.pumpAndSettle();

    expect(repository.lastPrompt, 'Create a recovery activity for fractions');
    expect(find.textContaining('Nothing was saved, sent or submitted automatically'), findsOneWidget);
    expect(find.textContaining('Create a recovery activity for fractions'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Teacher AI handoffs route to governed Teacher modules',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? destination;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherAiPage(
            repository: _FakeTeacherAiRepository(),
            onNavigate: (value) => destination = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Turn into lesson plan'));
    await tester.pump();
    expect(destination, 'lesson-plans');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Create assignment'));
    await tester.pump();
    expect(destination, 'assignments');
    await tester.tap(find.widgetWithText(TextButton, 'Open tool →').first);
    await tester.pump();
    expect(destination, 'lesson-plans');
  });

  testWidgets('Teacher AI renders on phone without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherAiPage(
            repository: _FakeTeacherAiRepository(),
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your teaching copilot'), findsOneWidget);
    expect(find.text('Recent AI activity'), findsOneWidget);
    expect(find.text('Teacher AI governance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeTeacherAiRepository implements TeacherAiRepository {
  String? lastPrompt;

  @override
  TeacherAiPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherAiPermissions(
      canUseAssignedClassContext: teacher,
      canDraftTeachingContent: teacher,
      canSuggestSupport: teacher,
      canRetrieveUnrelatedClasses: false,
      canAccessFinance: false,
      canAccessStaffConfidentialData: false,
      canAccessOtherSchools: false,
      canAlterMarks: false,
      canAlterAttendance: false,
      canSendMessages: false,
      canTakeConsequentialAction: false,
    );
  }

  @override
  Future<TeacherAiSnapshot> load() async => TeacherAiSnapshot(
        history: teacherAiInitialHistory,
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
  Future<TeacherAiAskResult> ask({
    required TeacherAiContext context,
    required String prompt,
  }) async {
    lastPrompt = prompt.trim();
    final item = TeacherAiPromptHistoryItem(
      id: 'fake-new',
      prompt: lastPrompt!,
      context: context,
      createdAt: '2026-09-20T05:00:00Z',
    );
    return TeacherAiAskResult(
      success: true,
      response: teacherAiResponseFor(context: context, prompt: lastPrompt!),
      historyItem: item,
    );
  }
}
