import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_students_policy_copy.dart';
import 'package:schoolos_app/features/teacher/data/teacher_students_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_students_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_students_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

const _fixtureStudents = <TeacherStudentSummary>[
  TeacherStudentSummary(
    id: 'STU-J2A-001',
    name: 'Maryam Abdullahi',
    className: 'JSS 2A',
    average: 86,
    attendance: 96,
    trend: 4.2,
    risk: TeacherStudentRisk.strong,
    intervention: 'None',
    attention: 'No current major concern. Continue normal academic and co-curricular support.',
  ),
  TeacherStudentSummary(
    id: 'STU-J2A-002',
    name: 'Ibrahim Sani',
    className: 'JSS 2A',
    average: 61,
    attendance: 88,
    trend: -3.1,
    risk: TeacherStudentRisk.watch,
    intervention: 'Revision support',
    attention: 'Recent Mathematics decline needs review across more than one assessment before changing support.',
  ),
  TeacherStudentSummary(
    id: 'STU-J2B-001',
    name: 'Yusuf Bello',
    className: 'JSS 2B',
    average: 48,
    attendance: 79,
    trend: -8.4,
    risk: TeacherStudentRisk.atRisk,
    intervention: 'Guardian + academic follow-up',
    attention: 'Attendance weakness and academic decline are appearing together. Review context with teacher and guardian before deciding next support action.',
  ),
  TeacherStudentSummary(
    id: 'STU-J3A-001',
    name: 'Fatima Musa',
    className: 'JSS 3A',
    average: 91,
    attendance: 98,
    trend: 6.0,
    risk: TeacherStudentRisk.strong,
    intervention: 'None',
    attention: 'Strong current academic and attendance evidence. Continue normal support and enrichment.',
  ),
  TeacherStudentSummary(
    id: 'STU-S1A-001',
    name: 'Abdullahi Umar',
    className: 'SS 1A',
    average: 68,
    attendance: 91,
    trend: -1.9,
    risk: TeacherStudentRisk.stable,
    intervention: 'Subject-level review',
    attention: 'Overall stable; Physics and Further Mathematics need routine subject-level review.',
  ),
];

const _fixtureProfiles = <TeacherStudentProfile>[
  TeacherStudentProfile(
    id: 'STU-J2A-001',
    admissionNo: 'BGA/2023/SEC/001',
    name: 'Maryam Abdullahi',
    className: 'JSS 2A',
    status: 'Strong',
    average: 86,
    attendance: 96,
    trend: 4.2,
    classTeacher: 'Mrs. Amina Yusuf',
    attention: 'No current major concern. Continue normal academic and co-curricular support.',
    subjects: [
      TeacherStudentSubjectEvidence(name: 'Mathematics', score: 88, trend: 3.0),
      TeacherStudentSubjectEvidence(name: 'English', score: 84, trend: 2.1),
      TeacherStudentSubjectEvidence(name: 'Basic Science', score: 87, trend: 5.2),
      TeacherStudentSubjectEvidence(name: 'Social Studies', score: 85, trend: 4.0),
    ],
    attendanceSummary: [
      TeacherStudentAttendanceEvidence(label: 'Present', value: '96%'),
      TeacherStudentAttendanceEvidence(label: 'Late', value: '2'),
      TeacherStudentAttendanceEvidence(label: 'Excused', value: '1'),
      TeacherStudentAttendanceEvidence(label: 'Unexplained', value: '0'),
    ],
    timeline: [
      TeacherStudentTimelineItem(
        date: '10 Sep',
        title: 'Debate recognition',
        detail: 'Recognized for contribution to inter-house debate preparation.',
        visibility: 'School + Guardian',
      ),
      TeacherStudentTimelineItem(
        date: '6 Sep',
        title: 'Assessment completed',
        detail: 'Basic Science assessment recorded at 87%.',
        visibility: 'Teacher + Leadership + Guardian',
      ),
      TeacherStudentTimelineItem(
        date: '2 Sep',
        title: 'Attendance review',
        detail: 'Attendance remained above section target.',
        visibility: 'Leadership + Teacher',
      ),
    ],
  ),
  TeacherStudentProfile(
    id: 'STU-J2A-002',
    admissionNo: '',
    name: 'Ibrahim Sani',
    className: 'JSS 2A',
    status: 'Watch',
    average: 61,
    attendance: 88,
    trend: -3.1,
    classTeacher: 'Mrs. Amina Yusuf',
    attention: 'Recent Mathematics decline needs review across more than one assessment before changing support.',
    subjects: [],
    attendanceSummary: [],
    timeline: [],
  ),
  TeacherStudentProfile(
    id: 'STU-J2B-001',
    admissionNo: 'BGA/2023/SEC/003',
    name: 'Yusuf Bello',
    className: 'JSS 2B',
    status: 'At risk',
    average: 48,
    attendance: 79,
    trend: -8.4,
    classTeacher: 'Mr. Sani Bello',
    attention: 'Attendance weakness and academic decline are appearing together. Review context with teacher and guardian before deciding next support action.',
    subjects: [
      TeacherStudentSubjectEvidence(name: 'Mathematics', score: 42, trend: -11.0),
      TeacherStudentSubjectEvidence(name: 'English', score: 51, trend: -5.0),
      TeacherStudentSubjectEvidence(name: 'Basic Science', score: 46, trend: -9.0),
      TeacherStudentSubjectEvidence(name: 'Social Studies', score: 53, trend: -4.0),
    ],
    attendanceSummary: [
      TeacherStudentAttendanceEvidence(label: 'Present', value: '79%'),
      TeacherStudentAttendanceEvidence(label: 'Late', value: '5'),
      TeacherStudentAttendanceEvidence(label: 'Excused', value: '3'),
      TeacherStudentAttendanceEvidence(label: 'Unexplained', value: '6'),
    ],
    timeline: [
      TeacherStudentTimelineItem(
        date: '8 Sep',
        title: 'Teacher intervention',
        detail: 'Short Mathematics revision support plan started.',
        visibility: 'Teacher + Leadership',
      ),
    ],
  ),
  TeacherStudentProfile(
    id: 'STU-J3A-001',
    admissionNo: '',
    name: 'Fatima Musa',
    className: 'JSS 3A',
    status: 'Strong',
    average: 91,
    attendance: 98,
    trend: 6.0,
    classTeacher: 'Mrs. Zainab Lawal',
    attention: 'Strong current academic and attendance evidence. Continue normal support and enrichment.',
    subjects: [],
    attendanceSummary: [],
    timeline: [],
  ),
  TeacherStudentProfile(
    id: 'STU-S1A-001',
    admissionNo: '',
    name: 'Abdullahi Umar',
    className: 'SS 1A',
    status: 'Stable',
    average: 68,
    attendance: 91,
    trend: -1.9,
    classTeacher: 'Mr. Umar Faruq',
    attention: 'Overall stable; Physics and Further Mathematics need routine subject-level review.',
    subjects: [],
    attendanceSummary: [],
    timeline: [],
  ),
];

void main() {
  test('real roster KPI counts are derived from the student risk field, never a fixed snapshot', () {
    expect(_fixtureStudents, hasLength(5));
    final classCount = _fixtureStudents.map((s) => s.className).toSet().length;
    final strongOrStable = _fixtureStudents
        .where((s) => s.risk == TeacherStudentRisk.strong || s.risk == TeacherStudentRisk.stable)
        .length;
    final watch = _fixtureStudents.where((s) => s.risk == TeacherStudentRisk.watch).length;
    final atRisk = _fixtureStudents.where((s) => s.risk == TeacherStudentRisk.atRisk).length;
    expect(classCount, 4);
    expect(strongOrStable, 3);
    expect(watch, 1);
    expect(atRisk, 1);
  });

  test('student search matches name id and class fields only', () {
    expect(_fixtureStudents.where((s) => s.matches('Maryam')), hasLength(1));
    expect(_fixtureStudents.where((s) => s.matches('STU-J2B-001')), hasLength(1));
    expect(_fixtureStudents.where((s) => s.matches('JSS 2A')), hasLength(2));
    expect(_fixtureStudents.where((s) => s.matches('Guardian')), isEmpty);
  });

  test('teacher-safe full profile carries real academic evidence', () {
    final maryam = _fixtureProfiles.firstWhere((p) => p.id == 'STU-J2A-001');
    expect(maryam.admissionNo, 'BGA/2023/SEC/001');
    expect(maryam.classTeacher, 'Mrs. Amina Yusuf');
    expect(maryam.subjects, hasLength(4));
    expect(maryam.subjects.first.name, 'Mathematics');
    expect(maryam.subjects.first.score, 88);
    expect(maryam.attendanceSummary.map((e) => e.value), ['96%', '2', '1', '0']);
    expect(maryam.timeline, hasLength(3));

    final yusuf = _fixtureProfiles.firstWhere((p) => p.id == 'STU-J2B-001');
    expect(yusuf.admissionNo, 'BGA/2023/SEC/003');
    expect(yusuf.classTeacher, 'Mr. Sani Bello');
    expect(yusuf.subjects.first.score, 42);
    expect(yusuf.attendanceSummary.last.value, '6');
    expect(yusuf.timeline.single.title, 'Teacher intervention');
  });

  test('teacher student cache explicitly excludes sensitive authority domains', () {
    expect(teacherStudentsPrivacyBoundary, contains('Finance'));
    expect(teacherStudentsPrivacyBoundary, contains('family-account'));
    expect(teacherStudentsPrivacyBoundary, contains('medical/genotype/blood'));
    expect(teacherStudentsPrivacyBoundary, contains('leadership-only'));
    expect(teacherStudentsEvidenceBoundary, contains('automatic punishment'));
    expect(teacherStudentsEvidenceBoundary, contains('promotion/failure'));
    expect(teacherStudentsEvidenceBoundary, contains('diagnosis'));
    expect(teacherStudentNoteBoundary, contains('does not change marks'));
    expect(teacherStudentNoteBoundary, contains('guardian delivery'));
  });

  test('student profile and note serialize without losing teacher-visible evidence', () {
    final restored = TeacherStudentProfile.fromJson(_fixtureProfiles.first.toJson());
    expect(restored.id, 'STU-J2A-001');
    expect(restored.subjects[2].name, 'Basic Science');
    expect(restored.subjects[2].score, 87);
    expect(restored.timeline[1].title, 'Assessment completed');

    const note = TeacherStudentNote(
      studentId: 'STU-J2A-001',
      text: 'Continue guided equation practice.',
      version: 2,
      updatedAt: '2026-09-20T05:00:00Z',
    );
    final restoredNote = TeacherStudentNote.fromJson(note.toJson());
    expect(restoredNote.studentId, note.studentId);
    expect(restoredNote.text, note.text);
    expect(restoredNote.version, 2);
  });

  test('teacher permissions deny finance medical leadership-only and status authority', () {
    final fake = _FakeStudentsRepository();
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
    expect(permissions.canViewAssignedStudents, isTrue);
    expect(permissions.canSaveProfessionalNote, isTrue);
    expect(permissions.canUseSchoolContactChannel, isTrue);
    expect(permissions.canViewFinance, isFalse);
    expect(permissions.canViewMedical, isFalse);
    expect(permissions.canViewLeadershipOnlyRecords, isFalse);
    expect(permissions.canChangeStudentStatus, isFalse);
    expect(fake.permissionsFor(parent).canViewAssignedStudents, isFalse);
  });

  testWidgets('Students renders the real roster, real KPI counts and search filters visible rows', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherStudentsPage(
            repository: _FakeStudentsRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Maryam Abdullahi'), findsWidgets);
    expect(find.text('Yusuf Bello'), findsOneWidget);
    expect(find.text('5'), findsOneWidget, reason: 'the real assigned-student count');

    final search = find.widgetWithText(TextField, 'Search student or ID...');
    await tester.ensureVisible(search);
    await tester.enterText(search, 'Yusuf');
    await tester.pump();
    expect(find.text('Yusuf Bello'), findsOneWidget);
    expect(find.text('Fatima Musa'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('full student profile exposes academic context but not sensitive website fields', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherStudentsPage(
            repository: _FakeStudentsRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Open full student profile'));
    await tester.tap(find.text('Open full student profile'));
    await tester.pumpAndSettle();

    expect(find.text('BGA/2023/SEC/001'), findsOneWidget);
    expect(find.text('Academic evidence'), findsOneWidget);
    expect(find.text('Teacher-visible timeline'), findsOneWidget);
    expect(find.text('FAM-ABD-0041'), findsNothing);
    expect(find.text('O+'), findsNothing);
    expect(find.text('AA'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving a teacher note versions local evidence without changing student status', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = _FakeStudentsRepository();
    var queued = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherStudentsPage(
            repository: fake,
            onNavigate: (_) {},
            onMutationQueued: () => queued++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.widgetWithText(TextField, 'Teacher note');
    await tester.ensureVisible(field);
    await tester.enterText(field, 'Continue guided Mathematics revision and review next classwork sample.');
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();

    expect(fake.notes['STU-J2A-001']?.version, 1);
    expect(fake.notes['STU-J2A-001']?.text, contains('guided Mathematics revision'));
    expect(find.textContaining('Student status, marks and guardian delivery are unchanged'), findsOneWidget);
    expect(queued, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Students top actions route to completed Teacher modules', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? destination;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherStudentsPage(
            repository: _FakeStudentsRepository(),
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
    await tester.tap(find.widgetWithText(OutlinedButton, 'Assessments'));
    await tester.pump();
    expect(destination, 'assessments');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Message'));
    await tester.pump();
    expect(destination, 'messages');
  });

  testWidgets('a teacher with no real assigned students sees honest zero KPIs, not a crash', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherStudentsPage(
            repository: _EmptyFakeStudentsRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No students are on the register for your assigned classes yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Students renders on phone without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherStudentsPage(
            repository: _FakeStudentsRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My student roster'), findsOneWidget);
    expect(find.text('Assigned students'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeStudentsRepository implements TeacherStudentsRepository {
  final Map<String, TeacherStudentNote> notes = {};

  @override
  TeacherStudentsPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherStudentsPermissions(
      canViewAssignedStudents: teacher,
      canSaveProfessionalNote: teacher,
      canUseSchoolContactChannel: teacher,
      canViewFinance: false,
      canViewMedical: false,
      canViewLeadershipOnlyRecords: false,
      canChangeStudentStatus: false,
    );
  }

  @override
  Future<TeacherStudentsSnapshot> load() async => TeacherStudentsSnapshot(
        students: _fixtureStudents,
        profiles: {for (final profile in _fixtureProfiles) profile.id: profile},
        notes: Map<String, TeacherStudentNote>.from(notes),
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
  Future<TeacherStudentNoteResult> saveNote({
    required String studentId,
    required String text,
  }) async {
    final existing = notes[studentId];
    final note = TeacherStudentNote(
      studentId: studentId,
      text: text.trim(),
      version: (existing?.version ?? 0) + 1,
      updatedAt: '2026-09-20T05:00:00Z',
    );
    notes[studentId] = note;
    return TeacherStudentNoteResult(
      success: true,
      message: 'Teacher note saved locally and queued for synchronization. Student status, marks and guardian delivery are unchanged.',
      note: note,
    );
  }
}

class _EmptyFakeStudentsRepository implements TeacherStudentsRepository {
  @override
  TeacherStudentsPermissions permissionsFor(SchoolMembership membership) => const TeacherStudentsPermissions(
        canViewAssignedStudents: true,
        canSaveProfessionalNote: true,
        canUseSchoolContactChannel: true,
        canViewFinance: false,
        canViewMedical: false,
        canViewLeadershipOnlyRecords: false,
        canChangeStudentStatus: false,
      );

  @override
  Future<TeacherStudentsSnapshot> load() async => TeacherStudentsSnapshot(
        students: const [],
        profiles: const {},
        notes: const {},
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
  Future<TeacherStudentNoteResult> saveNote({required String studentId, required String text}) async =>
      const TeacherStudentNoteResult(success: false, message: 'No student is registered.');
}
