import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_dashboard_policy_copy.dart';
import 'package:schoolos_app/features/teacher/data/teacher_dashboard_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_dashboard_models.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_performance_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_dashboard_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

const _fixtureKpis = <TeacherKpi>[
  TeacherKpi(label: "Today's lessons", value: '4', hint: 'Scheduled for Monday'),
  TeacherKpi(label: 'My students', value: '150', hint: 'Across 4 assigned classes'),
  TeacherKpi(label: 'Classes assigned', value: '4', hint: 'JSS 2A, JSS 2B, JSS 3A, SS1A'),
  TeacherKpi(label: 'Syllabus progress', value: '71%', hint: 'Average topic coverage across assigned classes'),
];

const _fixtureClasses = <TeacherClassSummary>[
  TeacherClassSummary(name: 'JSS 2A', subject: 'Mathematics', students: 42, nextLesson: '9:20 AM', room: 'B12', progress: 72),
  TeacherClassSummary(name: 'JSS 2B', subject: 'Mathematics', students: 39, nextLesson: '11:00 AM', room: 'B14', progress: 68),
  TeacherClassSummary(name: 'JSS 3A', subject: 'Mathematics', students: 41, nextLesson: '1:10 PM', room: 'C04', progress: 81),
  TeacherClassSummary(name: 'SS 1A', subject: 'Further Mathematics', students: 28, nextLesson: 'Not scheduled', room: 'D06', progress: 64),
];

const _fixtureSchedule = <TeacherScheduleItem>[
  TeacherScheduleItem(time: '8:00', className: 'JSS 2A', topic: 'Linear equations', status: 'Scheduled'),
  TeacherScheduleItem(time: '9:20', className: 'JSS 2B', topic: 'Linear equations', status: 'Scheduled'),
  TeacherScheduleItem(time: '11:00', className: 'JSS 3A', topic: 'Simultaneous equations', status: 'Substitution'),
];

const _fixtureStudents = <TeacherStudentReview>[
  TeacherStudentReview(name: 'Maryam Abdullahi', className: 'JSS 2A'),
  TeacherStudentReview(name: 'Ibrahim Sani', className: 'JSS 2A'),
  TeacherStudentReview(name: 'Yusuf Bello', className: 'JSS 2B'),
];

const _fixtureTasks = <TeacherTask>[
  TeacherTask(title: 'Submit attendance', meta: '1 of 3 real registers submitted', tone: 'warn', destination: 'attendance'),
  TeacherTask(title: 'Finish lesson plan drafts', meta: '2 of 4 real plans submitted or further along', tone: 'normal', destination: 'lesson-plans'),
];

const _fixtureMetrics = <TeacherPerformanceMetric>[
  TeacherPerformanceMetric(label: 'Attendance completion', value: 98, target: 95, note: 'note'),
  TeacherPerformanceMetric(label: 'Lesson-plan compliance', value: 92, target: 90, note: 'note'),
];

const _fixtureSnapshot = TeacherDashboardSnapshot(
  displayName: 'Amina Yusuf',
  kpis: _fixtureKpis,
  classes: _fixtureClasses,
  todaySchedule: _fixtureSchedule,
  students: _fixtureStudents,
  tasks: _fixtureTasks,
  lessonPlansSubmitted: 2,
  lessonPlansTotal: 4,
  weeklyUpdateReady: false,
  cbtPublished: 3,
  performanceScore: 86,
  performanceLabel: 'Good',
  performanceMetrics: _fixtureMetrics,
);

void main() {
  test('teacher workspace preserves exact website destinations, plus real Family Messages', () {
    expect(teacherNavigation.length, 22);
    expect(teacherNavigation.map((item) => item.label).toList(), [
      'Dashboard',
      'My Timetable',
      'My Classes',
      'Attendance',
      'Lesson Plans',
      'Weekly Learning',
      'Syllabus',
      'Assignments',
      'Assessments',
      'Class Teacher',
      'CBT Practice',
      'Learning Progress',
      'Students',
      'Excursions',
      'Media Gallery',
      'Messages',
      'Family Messages',
      'Teacher AI',
      'My Performance',
      'Profile',
      'Community',
      'My Duties',
    ]);
  });

  test('class summaries reconcile to the real student total', () {
    expect(_fixtureClasses.length, 4);
    expect(_fixtureClasses.fold<int>(0, (sum, item) => sum + item.students), 150);
    expect(_fixtureClasses.first.name, 'JSS 2A');
    expect(_fixtureClasses.first.progress, 72);
    expect(_fixtureClasses[1].room, 'B14');
  });

  test('teacher planning workflow and governance copy', () {
    expect(teacherConnectedWorkflow, contains('Plan the lesson'));
    expect(teacherConnectedWorkflow, contains('assessment/CBT results'));
    expect(teacherReviewSignalBoundary, contains('not automatic marks'));
    expect(teacherReviewSignalBoundary, contains('punishments'));
    expect(teacherAiBoundary, contains('cannot change marks'));
    expect(teacherOfflineBoundary, contains('pending until sync confirms'));
  });

  test('teacher review search follows name and class, never a fabricated signal', () {
    expect(_fixtureStudents.where((item) => item.matches('JSS 2A')).length, 2);
    expect(_fixtureStudents.where((item) => item.matches('yusuf')).single.name, 'Yusuf Bello');
  });

  test('teacher class and review evidence serialize without identity loss', () {
    final classRestored = TeacherClassSummary.fromJson(_fixtureClasses.first.toJson());
    expect(classRestored.name, _fixtureClasses.first.name);
    expect(classRestored.students, 42);
    expect(classRestored.progress, 72);

    final studentRestored = TeacherStudentReview.fromJson(_fixtureStudents[2].toJson());
    expect(studentRestored.name, 'Yusuf Bello');
    expect(studentRestored.className, 'JSS 2B');
  });

  test('teacher remains a serializable tenant membership role', () {
    const membership = SchoolMembership(
      id: 'membership-teacher-001',
      schoolId: 'school-brightgate',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.teacher,
    );
    final restored = SchoolMembership.fromJson(membership.toJson());
    expect(restored.role, SchoolRole.teacher);
    expect(restored.roleLabel, 'Teacher');
  });

  testWidgets('dashboard actions route to the intended Teacher feature key', (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? destination;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherDashboardPage(
            schoolName: 'BrightGate Academy',
            repository: _FakeDashboardRepository(),
            onNavigate: (value) => destination = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Open learning progress'));
    await tester.pump();
    expect(destination, 'learning-progress');

    await tester.tap(find.text('Ask Teacher AI'));
    await tester.pump();
    expect(destination, 'ai');
    expect(tester.takeException(), isNull);
  });

  testWidgets('teacher dashboard search filters the real assigned-student list', (tester) async {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherDashboardPage(
            schoolName: 'BrightGate Academy',
            repository: _FakeDashboardRepository(),
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maryam Abdullahi'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Yusuf Bello');
    await tester.pump();
    expect(
      find.descendant(of: find.byType(ListTile), matching: find.text('Yusuf Bello')),
      findsOneWidget,
    );
    expect(find.text('Maryam Abdullahi'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('teacher dashboard renders the real display name and score', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherDashboardPage(
            schoolName: 'BrightGate Academy',
            repository: _FakeDashboardRepository(),
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TEACHER WORKSPACE'), findsOneWidget);
    expect(find.text('Welcome back, Amina Yusuf.'), findsOneWidget);
    expect(find.text('86'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a fresh teacher with no real data sees honest empty states, not a crash', (tester) async {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherDashboardPage(
            schoolName: 'BrightGate Academy',
            repository: _EmptyFakeDashboardRepository(),
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No real lesson is scheduled for today yet.'), findsOneWidget);
    expect(find.text('Nothing real is outstanding right now.'), findsOneWidget);
    expect(find.text('No class is assigned to this membership yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeDashboardRepository implements TeacherDashboardDataSource {
  @override
  Future<TeacherDashboardSnapshot> load() async => _fixtureSnapshot;
}

class _EmptyFakeDashboardRepository implements TeacherDashboardDataSource {
  @override
  Future<TeacherDashboardSnapshot> load() async => const TeacherDashboardSnapshot(
        displayName: 'Teacher',
        kpis: [],
        classes: [],
        todaySchedule: [],
        students: [],
        tasks: [],
        lessonPlansSubmitted: 0,
        lessonPlansTotal: 0,
        weeklyUpdateReady: false,
        cbtPublished: 0,
        performanceScore: 0,
        performanceLabel: 'Needs support',
        performanceMetrics: [],
      );
}
