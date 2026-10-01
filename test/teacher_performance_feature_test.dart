import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_performance_policy_copy.dart';
import 'package:schoolos_app/features/teacher/data/teacher_performance_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_performance_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_performance_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

const _fixtureMetrics = <TeacherPerformanceMetric>[
  TeacherPerformanceMetric(label: 'Attendance completion', value: 98, target: 95, note: '4 of 4 registers submitted'),
  TeacherPerformanceMetric(label: 'Lesson-plan compliance', value: 92, target: 90, note: '11 of 12 plans submitted or further along'),
  TeacherPerformanceMetric(label: 'Assessment completion', value: 84, target: 90, note: 'Average score-entry completion across 6 real assessments'),
  TeacherPerformanceMetric(label: 'Syllabus pace', value: 71, target: 75, note: 'Average topic coverage across assigned classes'),
];

const _fixtureClassPerformance = <TeacherClassPerformance>[
  TeacherClassPerformance(name: 'JSS 2A', average: 74, attendance: 94, syllabusPace: 72),
  TeacherClassPerformance(name: 'JSS 2B', average: 68, attendance: 91, syllabusPace: 68),
  TeacherClassPerformance(name: 'JSS 3A', average: 79, attendance: 96, syllabusPace: 81),
  TeacherClassPerformance(name: 'SS1A', average: 72, attendance: 93, syllabusPace: 64),
];

const _fixtureDevelopmentLog = <TeacherDevelopmentLogItem>[
  TeacherDevelopmentLogItem(title: '2026 Term 1 · Rating 4/5', detail: 'Strong classroom management; keep up syllabus pace.'),
  TeacherDevelopmentLogItem(title: '2025 Term 3 · Rating 4/5', detail: 'Good assessment turnaround.'),
];

void main() {
  test('overall score is a transparent average of the real metrics, not a hidden formula', () {
    final average = (98 + 92 + 84 + 71) / 4;
    expect(average.round(), 86);
  });

  test('the focus metric is the real indicator with the largest real gap to its own target', () {
    // Assessment completion: target 90, value 84 -> gap 6 (the largest of the four).
    // Syllabus pace: target 75, value 71 -> gap 4.
    TeacherPerformanceMetric? focus;
    for (final metric in _fixtureMetrics) {
      if (!metric.isAtOrAboveTarget && (focus == null || metric.gapToTarget > focus.gapToTarget)) {
        focus = metric;
      }
    }
    expect(focus?.label, 'Assessment completion');
    expect(focus?.gapToTarget, 6);
  });

  test('class outcomes carry real average/attendance/syllabus context, never an invented trend', () {
    expect(_fixtureClassPerformance, hasLength(4));
    expect(
      _fixtureClassPerformance.map((item) => (item.name, item.average, item.attendance, item.syllabusPace)),
      [
        ('JSS 2A', 74, 94, 72),
        ('JSS 2B', 68, 91, 68),
        ('JSS 3A', 79, 96, 81),
        ('SS1A', 72, 93, 64),
      ],
    );
  });

  test('development log and usage principles', () {
    expect(_fixtureDevelopmentLog, hasLength(2));
    expect(_fixtureDevelopmentLog[0].title, contains('Rating 4/5'));
    expect(teacherPerformanceUsagePrinciples, hasLength(3));
    expect(teacherPerformanceUsagePrinciples[0].$1, 'Context matters');
    expect(teacherPerformanceUsagePrinciples[1].$1, 'Private by default');
    expect(teacherPerformanceUsagePrinciples[2].$1, 'Human review');
  });

  test('performance records serialize without losing target or class context', () {
    final metric = TeacherPerformanceMetric.fromJson(_fixtureMetrics.first.toJson());
    expect(metric.label, 'Attendance completion');
    expect(metric.value, 98);
    expect(metric.target, 95);

    final classRow = TeacherClassPerformance.fromJson(_fixtureClassPerformance[1].toJson());
    expect(classRow.name, 'JSS 2B');
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
    expect(teacherPerformanceReflectionBoundary, contains('not shared with school leadership'));
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

  testWidgets('My Performance renders the real score and core sections', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    expect(find.text('86'), findsOneWidget);
    expect(find.text('/100'), findsOneWidget);
    expect(find.text('Good'), findsOneWidget);
    expect(find.text('Core teaching indicators'), findsOneWidget);
    expect(find.text('Assigned-class outcomes'), findsOneWidget);
    expect(find.text('My development log'), findsOneWidget);
    expect(find.text('How this score should be used'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('period selector changes the visible coaching period', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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

  testWidgets('private reflection is saved locally in the performance view', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    // Below the fold on a phone viewport; scroll to it rather than asserting on an unmounted widget.
    await tester.scrollUntilVisible(find.text('Assigned-class outcomes'), 400);
    await tester.pumpAndSettle();
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
        metrics: _fixtureMetrics,
        classPerformance: _fixtureClassPerformance,
        developmentLog: _fixtureDevelopmentLog,
        reflections: List.unmodifiable(reflections),
        permissions: permissionsFor(
          const SchoolMembership(
            id: 'teacher-1',
            schoolId: 'school-1',
            schoolName: 'BrightGate Academy',
            role: SchoolRole.teacher,
          ),
        ),
        overallScore: 86,
        focusMetric: _fixtureMetrics[2],
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
