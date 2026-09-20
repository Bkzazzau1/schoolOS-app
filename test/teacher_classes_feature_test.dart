import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_classes_demo_data.dart';
import 'package:schoolos_app/features/teacher/data/teacher_classes_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_classes_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_classes_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

class _FakeTeacherClassesRepository implements TeacherClassesRepository {
  @override
  Future<TeacherClassesSnapshot> load() async => const TeacherClassesSnapshot(
        assignments: teacherClassAssignments,
        permissions: TeacherClassPermissions(
          canViewAssignedClasses: true,
          canOpenAuthorizedRoster: true,
          canChangeClassMembership: false,
          canChangeAcademicMarksFromClassesPage: false,
          canAccessFinance: false,
          canAccessSafeguardingDetails: false,
        ),
      );

  @override
  TeacherClassPermissions permissionsFor(SchoolMembership membership) =>
      TeacherClassPermissions(
        canViewAssignedClasses: membership.role == SchoolRole.teacher,
        canOpenAuthorizedRoster: membership.role == SchoolRole.teacher,
        canChangeClassMembership: false,
        canChangeAcademicMarksFromClassesPage: false,
        canAccessFinance: false,
        canAccessSafeguardingDetails: false,
      );
}

void main() {
  test('My Classes preserves exact four website assignments', () {
    expect(teacherClassAssignments.length, 4);
    expect(
      teacherClassAssignments.map((item) => item.name),
      ['JSS 2A', 'JSS 2B', 'JSS 3A', 'SS 1A'],
    );
    expect(
      teacherClassAssignments.map((item) => item.subject),
      ['Mathematics', 'Mathematics', 'Mathematics', 'Further Mathematics'],
    );
    expect(
      teacherClassAssignments.map((item) => item.students),
      [42, 39, 41, 28],
    );
    expect(
      teacherClassAssignments.map((item) => item.room),
      ['B12', 'B14', 'C04', 'D06'],
    );
  });

  test('assigned classes reconcile exactly to 150 students', () {
    final total = teacherClassAssignments.fold<int>(
      0,
      (sum, item) => sum + item.students,
    );
    expect(total, 150);
  });

  test('class evidence preserves exact website metrics', () {
    final jss2a = teacherClassAssignments[0];
    expect(jss2a.progress, 72);
    expect(jss2a.attendance, 94);
    expect(jss2a.classAverage, 74);
    expect(jss2a.pendingMarking, 8);
    expect(jss2a.nextLesson, 'Mon · 8:00 AM');
    expect(jss2a.topic, 'Linear equations');

    final jss2b = teacherClassAssignments[1];
    expect(jss2b.progress, 68);
    expect(jss2b.attendance, 91);
    expect(jss2b.classAverage, 69);
    expect(jss2b.pendingMarking, 12);

    final jss3a = teacherClassAssignments[2];
    expect(jss3a.progress, 81);
    expect(jss3a.attendance, 96);
    expect(jss3a.classAverage, 78);
    expect(jss3a.pendingMarking, 5);

    final ss1a = teacherClassAssignments[3];
    expect(ss1a.progress, 64);
    expect(ss1a.attendance, 93);
    expect(ss1a.classAverage, 71);
    expect(ss1a.pendingMarking, 4);
    expect(ss1a.nextLesson, 'Tue · 8:40 AM');
    expect(ss1a.topic, 'Functions');
  });

  test('class search follows website class subject and topic behavior', () {
    expect(
      teacherClassAssignments.where((item) => item.matches('JSS 2B')).map((e) => e.id),
      ['jss2b'],
    );
    expect(
      teacherClassAssignments.where((item) => item.matches('Further Mathematics')).map((e) => e.id),
      ['ss1a'],
    );
    expect(
      teacherClassAssignments.where((item) => item.matches('linear equations')).map((e) => e.id),
      ['jss2a', 'jss2b'],
    );
    expect(
      teacherClassAssignments.where((item) => item.matches('Functions')).map((e) => e.id),
      ['ss1a'],
    );
  });

  test('class assignment serialization preserves teaching evidence', () {
    final original = teacherClassAssignments[2];
    final restored = TeacherClassAssignment.fromJson(original.toJson());
    expect(restored.id, original.id);
    expect(restored.name, original.name);
    expect(restored.subject, original.subject);
    expect(restored.students, original.students);
    expect(restored.room, original.room);
    expect(restored.progress, original.progress);
    expect(restored.attendance, original.attendance);
    expect(restored.classAverage, original.classAverage);
    expect(restored.nextLesson, original.nextLesson);
    expect(restored.topic, original.topic);
    expect(restored.pendingMarking, original.pendingMarking);
  });

  test('My Classes boundaries keep high-impact authority elsewhere', () {
    const permissions = TeacherClassPermissions(
      canViewAssignedClasses: true,
      canOpenAuthorizedRoster: true,
      canChangeClassMembership: false,
      canChangeAcademicMarksFromClassesPage: false,
      canAccessFinance: false,
      canAccessSafeguardingDetails: false,
    );
    expect(permissions.canViewAssignedClasses, isTrue);
    expect(permissions.canOpenAuthorizedRoster, isTrue);
    expect(permissions.canChangeClassMembership, isFalse);
    expect(permissions.canChangeAcademicMarksFromClassesPage, isFalse);
    expect(permissions.canAccessFinance, isFalse);
    expect(permissions.canAccessSafeguardingDetails, isFalse);
    expect(teacherClassesBoundary, contains('cannot change class membership'));
    expect(teacherClassesBoundary, contains('marks'));
    expect(teacherClassAiBoundary, contains('cannot change marks'));
    expect(teacherClassAiBoundary, contains('assigned scope'));
  });

  test('website class activity list remains exact', () {
    expect(teacherClassActivity, [
      'Attendance completed for 3 lessons',
      '2 lesson plans submitted',
      '1 assignment awaiting marking',
      'Syllabus updated after last lesson',
    ]);
  });

  testWidgets('My Classes routes connected teaching actions', (tester) async {
    String? destination;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherClassesPage(
            schoolName: 'BrightGate Academy',
            repository: _FakeTeacherClassesRepository(),
            onNavigate: (value) => destination = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Classes'), findsOneWidget);
    expect(find.text('JSS 2A'), findsWidgets);
    expect(find.text('JSS 2A · Mathematics'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'View timetable'));
    expect(destination, 'timetable');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Take attendance'));
    expect(destination, 'attendance');
  });

  testWidgets('selecting SS 1A updates selected class evidence', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherClassesPage(
            schoolName: 'BrightGate Academy',
            repository: _FakeTeacherClassesRepository(),
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('SS 1A').first);
    await tester.pump();

    expect(find.text('SS 1A · Further Mathematics'), findsOneWidget);
    expect(find.text('28 students · Room D06 · Next lesson Tue · 8:40 AM'), findsOneWidget);
    expect(find.text('Functions'), findsWidgets);
  });

  testWidgets('My Classes renders on a phone viewport without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherClassesPage(
            schoolName: 'BrightGate Academy',
            repository: _FakeTeacherClassesRepository(),
            onNavigate: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Classes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
