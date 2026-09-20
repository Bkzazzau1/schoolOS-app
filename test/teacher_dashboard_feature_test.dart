import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_dashboard_demo_data.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_dashboard_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_dashboard_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

void main() {
  test('teacher workspace preserves exact sixteen website destinations', () {
    expect(teacherNavigation.length, 16);
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
      'CBT Practice',
      'Learning Progress',
      'Students',
      'Messages',
      'Teacher AI',
      'My Performance',
      'Profile',
    ]);
  });

  test('teacher dashboard preserves exact website KPI snapshot', () {
    expect(teacherKpis.length, 4);
    expect(teacherKpis[0].value, '4');
    expect(teacherKpis[0].hint, '1 completed · 3 upcoming');
    expect(teacherKpis[1].value, '150');
    expect(teacherKpis[1].hint, 'Across 4 assigned classes');
    expect(teacherKpis[2].value, '7');
    expect(teacherKpis[3].value, '71%');
    expect(teacherKpis[3].hint, '+4% from last week');
  });

  test('four assigned classes reconcile exactly to 150 students', () {
    expect(teacherClasses.length, 4);
    expect(teacherClasses.fold<int>(0, (sum, item) => sum + item.students), 150);
    expect(teacherClasses.first.name, 'JSS 2A');
    expect(teacherClasses.first.progress, 72);
    expect(teacherClasses[1].room, 'B14');
    expect(teacherClasses[2].progress, 81);
    expect(teacherClasses.last.subject, 'Further Mathematics');
    expect(teacherClasses.last.students, 28);
  });

  test('today timetable preserves exact four website lessons and states', () {
    expect(teacherTodaySchedule.length, 4);
    expect(teacherTodaySchedule.first.time, '8:00 AM');
    expect(teacherTodaySchedule.first.status, 'Completed');
    expect(teacherTodaySchedule[1].className, 'JSS 2B');
    expect(teacherTodaySchedule[1].status, 'Next');
    expect(teacherTodaySchedule.where((item) => item.status == 'Upcoming').length, 2);
    expect(teacherTodaySchedule.last.topic, 'Revision / classwork');
  });

  test('student review evidence preserves exact website examples', () {
    expect(teacherStudentReview.length, 4);
    expect(teacherStudentReview.first.name, 'Maryam Abdullahi');
    expect(teacherStudentReview.first.average, 86);
    expect(teacherStudentReview[1].signal, 'Watch');
    expect(teacherStudentReview[2].name, 'Yusuf Bello');
    expect(teacherStudentReview[2].average, 48);
    expect(teacherStudentReview[2].attendance, 79);
    expect(teacherStudentReview[2].signal, 'At risk');
    expect(teacherStudentReview.last.average, 91);
  });

  test('teacher dashboard preserves exact action list destinations', () {
    expect(teacherTasks.length, 4);
    expect(teacherTasks.first.title, 'Review JSS 2A learning evidence');
    expect(teacherTasks.first.destination, 'learning-progress');
    expect(teacherTasks[1].destination, 'weekly-progress');
    expect(teacherTasks[2].destination, 'assessments');
    expect(teacherTasks.last.destination, 'cbt');
  });

  test('teacher planning and private performance preserve website evidence', () {
    expect(teacherConnectedWorkflow, contains('Plan the lesson'));
    expect(teacherConnectedWorkflow, contains('assessment/CBT results'));
    expect(teacherPerformanceScore, 88);
    expect(teacherPerformanceMetrics.map((item) => item.value).toList(), [98, 92, 84, 71]);
    expect(teacherWeeklyCompliance, 92);
    expect(teacherAiBrief, contains('JSS 2B'));
    expect(teacherAiBrief, contains('fractions'));
  });

  test('review signals and Teacher AI cannot become automatic decisions', () {
    expect(teacherReviewSignalBoundary, contains('not automatic marks'));
    expect(teacherReviewSignalBoundary, contains('punishments'));
    expect(teacherReviewSignalBoundary, contains('promotion decisions'));
    expect(teacherReviewSignalBoundary, contains('parent-facing labels'));
    expect(teacherAiBoundary, contains('cannot change marks'));
    expect(teacherAiBoundary, contains('hidden student judgments'));
    expect(teacherOfflineBoundary, contains('tenant-scoped'));
    expect(teacherOfflineBoundary, contains('durable sync'));
  });

  test('teacher review search follows website name class and signal behavior', () {
    expect(teacherStudentReview.where((item) => item.matches('JSS 2A')).length, 2);
    expect(teacherStudentReview.where((item) => item.matches('at risk')).single.name, 'Yusuf Bello');
    expect(teacherStudentReview.where((item) => item.matches('maryam')).single.signal, 'Strong');
  });

  test('teacher class and review evidence serialize without identity loss', () {
    final classRestored = TeacherClassSummary.fromJson(teacherClasses.first.toJson());
    expect(classRestored.name, teacherClasses.first.name);
    expect(classRestored.students, 42);
    expect(classRestored.progress, 72);

    final studentRestored = TeacherStudentReview.fromJson(teacherStudentReview[2].toJson());
    expect(studentRestored.name, 'Yusuf Bello');
    expect(studentRestored.className, 'JSS 2B');
    expect(studentRestored.signal, 'At risk');
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
            onNavigate: (value) => destination = value,
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Open learning progress'));
    await tester.pump();
    expect(destination, 'learning-progress');

    await tester.tap(find.text('Open CBT practice'));
    await tester.pump();
    expect(destination, 'cbt');
    expect(tester.takeException(), isNull);
  });

  testWidgets('teacher dashboard search filters the attention evidence', (tester) async {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherDashboardPage(
            schoolName: 'BrightGate Academy',
            onNavigate: (_) {},
          ),
        ),
      ),
    );

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

  testWidgets('teacher dashboard renders on phone without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherDashboardPage(
            schoolName: 'BrightGate Academy',
            onNavigate: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('TEACHER WORKSPACE'), findsOneWidget);
    expect(find.text('Good morning, Mrs. Amina.'), findsOneWidget);
    expect(find.text('Teacher AI Daily Brief'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
