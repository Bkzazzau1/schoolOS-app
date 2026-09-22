import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_profile_demo_data.dart';
import 'package:schoolos_app/features/teacher/data/teacher_profile_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_profile_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_profile_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

void main() {
  test('Profile preserves exact website identity payroll and tab contract', () {
    expect(TeacherProfileTab.values, hasLength(13));
    expect(teacherProfile.displayName, 'Mrs. Amina Yusuf');
    expect(teacherProfile.staffId, 'TCH-2048');
    expect(teacherProfile.payrollId, 'PAY-BGA-2048');
    expect(teacherProfile.department, 'Mathematics');
    expect(teacherProfile.jobTitle, 'Mathematics Teacher');
    expect(teacherProfile.employmentType, 'Full-time · Permanent');
    expect(teacherProfile.payslips, hasLength(3));
    expect(teacherProfile.payslips.first.reference, 'PAY/TCH-2048/2026-08');
    expect(teacherProfile.grossMonthly, 250000);
    expect(teacherProfile.monthlyDeductions, 56000);
    expect(teacherProfile.netMonthly, 194000);
    expect(teacherProfile.annualGross, 3000000);
  });

  test('Profile preserves exact website supporting records', () {
    expect(teacherProfileQualifications, hasLength(4));
    expect(teacherProfileTeachingLoad, hasLength(4));
    expect(teacherProfileLeaveHistory, hasLength(2));
    expect(teacherProfileAllowances, hasLength(4));
    expect(teacherProfileDeductions, hasLength(4));
    expect(teacherProfileLoanHistory, hasLength(3));
    expect(teacherProfileDocuments, hasLength(4));
    expect(teacherProfileTimeline, hasLength(4));
    expect(teacherProfileSecurityRows, hasLength(3));
    expect(teacherProfileLoanBalance, 75000);
    expect(teacherProfileLoanMonthlyRepayment, 25000);
    expect(teacherProfileAttendance.attendance, 96);
    expect(teacherProfileCompleteness, 96);
  });

  test('payslip arithmetic remains exact for all three website months', () {
    expect(teacherProfile.payslips[0].net, 194000);
    expect(teacherProfile.payslips[1].net, 197000);
    expect(teacherProfile.payslips[2].net, 197000);
    expect(teacherProfile.payslips[0].gross, 250000);
    expect(teacherProfile.payslips[0].deductions, 56000);
  });

  test('Profile serialization preserves confidential payroll and contact evidence', () {
    final restored = TeacherProfileSnapshotData.fromJson(teacherProfile.toJson());
    expect(restored.staffId, teacherProfile.staffId);
    expect(restored.account, '0123456789');
    expect(restored.contact.email, 'amina.yusuf@example.edu');
    expect(restored.payslips[2].month, 'June 2026');
  });

  test('teacher self-service permissions never grant employment or payroll authority', () {
    final fake = _FakeProfileRepository();
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
    expect(permissions.canViewOwnProfile, isTrue);
    expect(permissions.canUpdateOwnContact, isTrue);
    expect(permissions.canEditEmploymentAuthority, isFalse);
    expect(permissions.canEditPayroll, isFalse);
    expect(permissions.canEditTeachingAssignments, isFalse);
    expect(permissions.canViewOtherStaffPayroll, isFalse);
    expect(permissions.canSelfApproveSecurityChanges, isFalse);
    expect(fake.permissionsFor(parent).canViewOwnProfile, isFalse);
  });

  test('Profile boundaries protect payroll authority and security truth', () {
    expect(teacherProfilePayrollBoundary, contains('authorized HR'));
    expect(teacherProfileAuthorityBoundary, contains('cannot be changed'));
    expect(teacherProfileSecurityBoundary, contains('must never claim'));
  });

  testWidgets('Profile renders website overview and confidential payroll context', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherProfilePage(
            repository: _FakeProfileRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Teacher Profile'), findsOneWidget);
    expect(find.text('Mrs. Amina Yusuf'), findsOneWidget);
    expect(find.text('TCH-2048 · PAY-BGA-2048'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    // The tab body's own copy of the net-salary figure is further down the page than the huge test
    // viewport's render cache extent covers, so scroll to it rather than asserting on an unmounted widget.
    await tester.scrollUntilVisible(find.text('₦194,000').first, 400);
    await tester.pumpAndSettle();
    expect(find.text('₦194,000'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile self-service edit saves contact without changing authority fields', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = _FakeProfileRepository();
    var queued = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherProfilePage(
            repository: fake,
            onNavigate: (_) {},
            onMutationQueued: () => queued++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Edit self-service profile'));
    await tester.pumpAndSettle();
    expect(find.text('Edit self-service contact'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '+234 800 999 0000');
    await tester.tap(find.widgetWithText(FilledButton, 'Save contact'));
    await tester.pumpAndSettle();

    expect(fake.contact.phone, '+234 800 999 0000');
    expect(fake.contact.version, 1);
    expect(fake.contact.pendingSync, isTrue);
    expect(queued, 1);
    expect(teacherProfile.staffId, 'TCH-2048');
    expect(teacherProfile.netMonthly, 194000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile connected work routes to existing Teacher modules', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? destination;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherProfilePage(
            repository: _FakeProfileRepository(),
            onNavigate: (value) => destination = value,
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.widgetWithText(TextButton, 'My Classes'), 400);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'My Classes'));
    await tester.pump();
    expect(destination, 'classes');
    await tester.tap(find.widgetWithText(TextButton, 'Attendance'));
    await tester.pump();
    expect(destination, 'attendance');
    await tester.tap(find.widgetWithText(TextButton, 'My Performance'));
    await tester.pump();
    expect(destination, 'performance');
  });

  testWidgets('Profile renders on phone without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherProfilePage(
            repository: _FakeProfileRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Teacher Profile'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('PAYROLL PRIVACY'), 400);
    await tester.pumpAndSettle();
    expect(find.text('PAYROLL PRIVACY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeProfileRepository implements TeacherProfileDataSource {
  TeacherProfileContact contact = teacherProfile.contact;

  @override
  TeacherProfilePermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherProfilePermissions(
      canViewOwnProfile: teacher,
      canUpdateOwnContact: teacher,
      canEditEmploymentAuthority: false,
      canEditPayroll: false,
      canEditTeachingAssignments: false,
      canViewOtherStaffPayroll: false,
      canSelfApproveSecurityChanges: false,
    );
  }

  @override
  Future<TeacherProfileSnapshot> load() async => TeacherProfileSnapshot(
        profile: teacherProfile.copyWith(contact: contact),
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
  Future<TeacherProfileUpdateResult> saveContact(TeacherProfileContact value) async {
    contact = value.copyWith(version: contact.version + 1, pendingSync: true);
    return TeacherProfileUpdateResult(
      success: true,
      message: 'Contact changes saved locally and queued for HR synchronization.',
      contact: contact,
    );
  }
}
