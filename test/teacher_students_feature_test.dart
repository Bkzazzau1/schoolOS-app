import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_students_demo_data.dart';
import 'package:schoolos_app/features/teacher/data/teacher_students_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_students_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_students_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

void main() {
  test('Students preserves exact website roster and KPI snapshot', () {
    expect(teacherStudents, hasLength(5));
    expect(teacherStudents[0].id, 'STU-J2A-001');
    expect(teacherStudents[0].name, 'Maryam Abdullahi');
    expect(teacherStudents[0].average, 86);
    expect(teacherStudents[0].attendance, 96);
    expect(teacherStudents[0].trend, 4.2);
    expect(teacherStudents[0].risk, TeacherStudentRisk.strong);
    expect(teacherStudents[1].name, 'Ibrahim Sani');
    expect(teacherStudents[1].risk, TeacherStudentRisk.watch);
    expect(teacherStudents[2].name, 'Yusuf Bello');
    expect(teacherStudents[2].average, 48);
    expect(teacherStudents[2].attendance, 79);
    expect(teacherStudents[2].risk, TeacherStudentRisk.atRisk);
    expect(teacherStudents[3].name, 'Fatima Musa');
    expect(teacherStudents[4].name, 'Abdullahi Umar');
    expect(teacherStudents[4].risk, TeacherStudentRisk.stable);

    expect(teacherStudentKpis, hasLength(4));
    expect(teacherStudentKpis[0], ('Assigned students', '150', 'Across 4 classes'));
    expect(teacherStudentKpis[1], ('Strong / stable', '128', 'Within expected range'));
    expect(teacherStudentKpis[2], ('Watch list', '14', 'Needs closer monitoring'));
    expect(teacherStudentKpis[3], ('At risk', '8', 'Academic or attendance concern'));
  });

  test('student search matches website name id and class fields only', () {
    expect(teacherStudents.where((s) => s.matches('Maryam')), hasLength(1));
    expect(teacherStudents.where((s) => s.matches('STU-J2B-001')), hasLength(1));
    expect(teacherStudents.where((s) => s.matches('JSS 2A')), hasLength(2));
    expect(teacherStudents.where((s) => s.matches('Guardian')), isEmpty);
  });

  test('teacher-safe full profile preserves exact Maryam and Yusuf academic evidence', () {
    final maryam = teacherStudentProfiles.firstWhere((p) => p.id == 'STU-J2A-001');
    expect(maryam.admissionNo, 'BGA/2023/SEC/001');
    expect(maryam.classTeacher, 'Mrs. Amina Yusuf');
    expect(maryam.subjects, hasLength(4));
    expect(maryam.subjects.first.name, 'Mathematics');
    expect(maryam.subjects.first.score, 88);
    expect(maryam.attendanceSummary.map((e) => e.value), ['96%', '2', '1', '0']);
    expect(maryam.timeline, hasLength(3));

    final yusuf = teacherStudentProfiles.firstWhere((p) => p.id == 'STU-J2B-001');
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
    final restored = TeacherStudentProfile.fromJson(teacherStudentProfiles.first.toJson());
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

  testWidgets('Students renders exact roster and search filters visible rows', (tester) async {
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
    expect(find.text('150'), findsOneWidget);

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
        students: teacherStudents,
        profiles: {for (final profile in teacherStudentProfiles) profile.id: profile},
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
