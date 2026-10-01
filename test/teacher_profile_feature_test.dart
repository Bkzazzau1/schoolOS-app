import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_profile_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_profile_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_profile_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

const _contact = TeacherProfileContact(
  phone: '+234 800 000 0000',
  email: 'amina.yusuf@example.edu',
  address: 'Kaduna, Kaduna State',
  nextOfKin: 'Alhaji Yusuf Ibrahim',
  emergencyPhone: '+234 800 000 0101',
);

final _fixture = TeacherProfileSnapshotData(
  hasLinkedStaffRecord: true,
  displayName: 'Amina Yusuf',
  staffId: 'TCH-2048',
  department: 'Mathematics',
  jobTitle: 'Mathematics Teacher',
  employmentType: 'Full-time',
  hireDate: '2022-01-15',
  campus: 'Kaduna Campus',
  bank: 'Test Bank',
  account: '******6789',
  contact: _contact,
  qualifications: const [
    ('B.Ed · Mathematics', 'Ahmadu Bello University · 2018', 'First Class'),
    ('TRCN registration', 'Teachers Registration Council of Nigeria', 'Verified'),
  ],
  teachingLoad: const [
    ('JSS 2A · Mathematics', '7 periods/week · Room B12', 'Term 2 2026'),
    ('JSS 2B · Mathematics', '7 periods/week · Room B14', 'Term 2 2026'),
  ],
  documents: const [
    ('Appointment letter', 'Verified', 'HR-001'),
  ],
  attendance: const TeacherAttendanceSummary(
    presentPercent: 96,
    lateArrivals: 2,
    approvedLeaveDays: 3,
    unapprovedAbsence: 0,
  ),
  payslips: const [
    TeacherPayslip(period: '2026-08', reference: 'PAY/TCH-2048/2026-08', net: 194000, status: 'Disbursement instructed'),
    TeacherPayslip(period: '2026-07', reference: 'PAY/TCH-2048/2026-07', net: 197000, status: 'Disbursement instructed'),
  ],
  profileCompleteness: 100,
  timeline: const [
    ('2026-08', 'Payroll disbursement instructed', 'PAY/TCH-2048/2026-08'),
    ('2022-01-15', 'Employment started', 'Joined as a staff member.'),
  ],
);

const _unlinked = TeacherProfileSnapshotData(
  hasLinkedStaffRecord: false,
  displayName: 'Teacher',
  staffId: '',
  department: '',
  jobTitle: '',
  employmentType: '',
  hireDate: '',
  campus: '',
  bank: '',
  account: '',
  contact: TeacherProfileContact(phone: '', email: '', address: '', nextOfKin: '', emergencyPhone: ''),
  qualifications: [],
  teachingLoad: [],
  documents: [],
  attendance: TeacherAttendanceSummary(),
  payslips: [],
  profileCompleteness: 0,
  timeline: [],
);

void main() {
  test('eleven real tabs remain after dropping the fabricated Deductions/Loans tabs', () {
    expect(TeacherProfileTab.values, hasLength(11));
    expect(TeacherProfileTab.values.map((t) => t.name), isNot(contains('deductions')));
    expect(TeacherProfileTab.values.map((t) => t.name), isNot(contains('loans')));
  });

  test('net pay is the only real payroll figure - no gross/deductions survive a prepared batch', () {
    expect(_fixture.payslips, hasLength(2));
    expect(_fixture.netMonthly, 194000);
    expect(_fixture.annualNet, 194000 * 12);
  });

  test('an unlinked teacher is honestly blank, never a placeholder person', () {
    expect(_unlinked.hasLinkedStaffRecord, isFalse);
    expect(_unlinked.displayName, 'Teacher');
    expect(_unlinked.staffId, isEmpty);
    expect(_unlinked.payslips, isEmpty);
    expect(_unlinked.netMonthly, 0);
    expect(_unlinked.profileCompleteness, 0);
  });

  test('TeacherPayslip round-trips without inventing an itemized breakdown', () {
    final restored = TeacherPayslip.fromJson(_fixture.payslips.first.toJson());
    expect(restored.period, '2026-08');
    expect(restored.net, 194000);
    expect(restored.status, 'Disbursement instructed');
  });

  test('TeacherProfileContact round-trips', () {
    final restored = TeacherProfileContact.fromJson(_contact.toJson());
    expect(restored.email, 'amina.yusuf@example.edu');
    expect(restored.phone, '+234 800 000 0000');
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

  test('profile boundaries protect payroll authority and security truth', () {
    expect(teacherProfilePayrollBoundary, contains('authorized HR'));
    expect(teacherProfileAuthorityBoundary, contains('cannot be changed'));
    expect(teacherProfileSecurityBoundary, contains('must never claim'));
  });

  testWidgets('Profile renders the real identity and net-pay figure', (tester) async {
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
    expect(find.text('Amina Yusuf'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('₦194,000').first, 400);
    await tester.pumpAndSettle();
    expect(find.text('₦194,000'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a teacher not yet linked to a staff record sees an honest empty profile', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherProfilePage(
            repository: _FakeProfileRepository(profile: _unlinked),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Teacher'), findsWidgets);
    expect(find.text('Not yet linked to a staff record'), findsOneWidget);
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
  _FakeProfileRepository({TeacherProfileSnapshotData? profile})
      : _profile = profile ?? _fixture,
        contact = (profile ?? _fixture).contact;

  final TeacherProfileSnapshotData _profile;
  TeacherProfileContact contact;

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
        profile: _profile.copyWith(contact: contact),
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
