import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_performance_demo_data.dart';
import 'package:schoolos_app/features/teacher/data/teacher_performance_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_performance_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_performance_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

void main() {
  test('My Performance preserves exact website score and teaching indicators', () {
    expect(teacherPerformanceScore, 88);
    expect(teacherPerformanceScoreLabel, 'Very good');
    expect(teacherPerformanceMetrics, hasLength(4));
    expect(
      teacherPerformanceMetrics.map((item) => (item.label, item.value, item.target)),
      [
        ('Attendance completion', 98, 95),
        ('Lesson-plan compliance', 92, 90),
        ('Assessment completion', 84, 90),
        ('Syllabus pace', 71, 75),
      ],
    );
    expect(teacherPerformanceMetrics[0].isAtOrAboveTarget, isTrue);
    expect(teacherPerformanceMetrics[2].isAtOrAboveTarget, isFalse);
  });

  test('assigned-class outcomes preserve exact website context', () {
    expect(teacherClassPerformance, hasLength(4));
    expect(
      teacherClassPerformance.map(
        (item) => (
          item.name,
          item.average,
          item.change,
          item.attendance,
          item.syllabusPace,
        ),
      ),
      [
        ('JSS 2A', 74, '+3.2%', 94, 72),
        ('JSS 2B', 68, '-1.4%', 91, 68),
        ('JSS 3A', 79, '+6.4%', 96, 81),
        ('SS 1A', 72, '+1.8%', 93, 64),
      ],
    );
    expect(teacherClassPerformance[1].isImproving, isFalse);
    expect(teacherClassPerformance[2].isImproving, isTrue);
  });

  test('development log and usage principles preserve website copy structure', () {
    expect(teacherDevelopmentLog, hasLength(3));
    expect(teacherDevelopmentLog[0].title, 'Revision strategy · JSS 2B');
    expect(teacherDevelopmentLog[1].detail, '32 of 41 CA scores entered');
    expect(
      teacherDevelopmentLog[2].detail,
      'Latest plan approved without changes',
    );
    expect(teacherPerformanceUsagePrinciples, hasLength(3));
    expect(teacherPerformanceUsagePrinciples[0].$1, 'Context matters');
    expect(teacherPerformanceUsagePrinciples[1].$1, 'Private by default');
    expect(teacherPerformanceUsagePrinciples[2].$1, 'Human review');
  });

  test('performance records serialize without losing target or class context', () {
    final metric = TeacherPerformanceMetric.fromJson(
      teacherPerformanceMetrics.first.toJson(),
    );
    expect(metric.label, 'Attendance completion');
    expect(metric.value, 98);
    expect(metric.target, 95);

    final classRow = TeacherClassPerformance.fromJson(
      teacherClassPerformance[1].toJson(),
    );
    expect(classRow.name, 'JSS 2B');
    expect(classRow.change, '-1.4%');
    expect(classRow.syllabusPace, 68);

    const reflection = TeacherPrivateReflection(
      id: 'reflection-1',
      body: 'Review JSS 2B pacing after Week 7.',
      createdAt: '2026-09-20T04:00:00Z',
    );
    final restored = TeacherPrivateReflection.fromJson(reflection.toJson());
    expect(restored.body, reflection.body);
    expect(restored.createdAt, reflection.createdAt);
  });

  test('performance governance prevents automatic HR judgments', () {
    expect(teacherPerformanceBoundary, contains('not an automatic disciplinary ranking'));
    expect(teacherPerformanceBoundary, contains('reward mechanism'));
    expect(teacherPerformanceBoundary, contains('caused a class outcome'));
    expect(teacherPerformancePrivacyBoundary, contains('private to the teacher'));
    expect(teacherPerformanceReflectionBoundary, contains('does not create an HR record'));
  });

  test('teacher permissions expose own coaching view only', () {
    final fake = _FakePerformanceRepository();
    const teacher = SchoolMembership(
      id: 'teacher-1',
      schoolId: 'school-1',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.teacher,
    );
    const principal = SchoolMembership(
      id: 'principal-1',
      schoolId: 'school-1',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.principal,
    );

    final permissions = fake.permissionsFor(teacher);
    expect(permissions.canViewOwnPerformance, isTrue);
    expect(permissions.canAddPrivateReflection, isTrue);
    expect(permissions.canViewOtherTeachersPerformance, isFalse);
    expect(permissions.canAutomaticallyDiscipline, isFalse);
    expect(permissions.canAutomaticallyReward, isFalse);
    expect(permissions.canTreatClassOutcomesAsSoleCausation, isFalse);
    expect(fake.permissionsFor(principal).canViewOwnPerformance, isFalse);
  });

  testWidgets('My Performance renders exact score and core website sections',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherPerformancePage(
            repository: _FakePerformanceRepository(),
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Performance'), findsOneWidget);
    expect(find.text('88'), findsOneWidget);
    expect(find.text('/100'), findsOneWidget);
    expect(find.text('Very good'), findsOneWidget);
    expect(find.text('Core teaching indicators'), findsOneWidget);
    expect(find.text('Assigned-class outcomes'), findsOneWidget);
    expect(find.text('My development log'), findsOneWidget);
    expect(find.text('How this score should be used'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('period selector changes the visible coaching period', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherPerformancePage(
            repository: _FakePerformanceRepository(),
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('This term').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Previous term').last);
    await tester.pumpAndSettle();

    expect(find.text('Previous term'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('professional focus routes to Syllabus', (tester) async {
    String? destination;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherPerformancePage(
            repository: _FakePerformanceRepository(),
            onNavigate: (value) => destination = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Open syllabus'));
    await tester.pump();
    expect(destination, 'syllabus');
  });

  testWidgets('private reflection is saved locally in the performance view',
      (tester) async {
    final repository = _FakePerformanceRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherPerformancePage(
            repository: repository,
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Add private reflection'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Review assessment completion before Week 7.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save privately'));
    await tester.pumpAndSettle();

    expect(repository.reflections, hasLength(1));
    expect(
      find.text('Review assessment completion before Week 7.'),
      findsOneWidget,
    );
    expect(find.text('Private on this device'), findsOneWidget);
  });

  testWidgets('My Performance renders on phone without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherPerformancePage(
            repository: _FakePerformanceRepository(),
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Performance'), findsOneWidget);
    expect(find.text('Professional focus'), findsOneWidget);
    expect(find.text('Assigned-class outcomes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakePerformanceRepository implements TeacherPerformanceDataSource {
  final List<TeacherPrivateReflection> reflections = [];

  @override
  TeacherPerformancePermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherPerformancePermissions(
      canViewOwnPerformance: teacher,
      canAddPrivateReflection: teacher,
      canViewOtherTeachersPerformance: false,
      canAutomaticallyDiscipline: false,
      canAutomaticallyReward: false,
      canTreatClassOutcomesAsSoleCausation: false,
    );
  }

  @override
  Future<TeacherPerformanceSnapshot> load() async => TeacherPerformanceSnapshot(
        metrics: teacherPerformanceMetrics,
        classPerformance: teacherClassPerformance,
        developmentLog: teacherDevelopmentLog,
        reflections: List.unmodifiable(reflections),
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
  Future<TeacherPerformanceActionResult> addPrivateReflection(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return const TeacherPerformanceActionResult(
        success: false,
        message: 'Write a reflection before saving.',
      );
    }
    final reflection = TeacherPrivateReflection(
      id: 'reflection-${reflections.length + 1}',
      body: trimmed,
      createdAt: '2026-09-20T05:00:00Z',
    );
    reflections.insert(0, reflection);
    return TeacherPerformanceActionResult(
      success: true,
      message: 'Private reflection saved on this device.',
      reflection: reflection,
    );
  }
}
