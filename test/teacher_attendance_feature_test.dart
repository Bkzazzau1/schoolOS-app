import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_attendance_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_attendance_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_attendance_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

const _fixtureLessons = <TeacherAttendanceLesson>[
  TeacherAttendanceLesson(
    id: 'MON-0800-J2A',
    className: 'JSS 2A',
    subject: 'Mathematics',
    time: '8:00–8:40',
    room: 'B12',
    topic: 'Linear equations',
  ),
  TeacherAttendanceLesson(
    id: 'MON-0920-J2B',
    className: 'JSS 2B',
    subject: 'Mathematics',
    time: '9:20–10:00',
    room: 'B14',
    topic: 'Linear equations',
  ),
  TeacherAttendanceLesson(
    id: 'MON-1100-J3A',
    className: 'JSS 3A',
    subject: 'Mathematics',
    time: '11:00–11:40',
    room: 'C04',
    topic: 'Simultaneous equations',
  ),
];

const _fixtureStudents = <TeacherAttendanceStudentEntry>[
  TeacherAttendanceStudentEntry(id: 1, code: 'Student 001', studentId: 'STU-0001', status: TeacherAttendanceStatus.present, note: '', attendanceRate: 96),
  TeacherAttendanceStudentEntry(id: 2, code: 'Student 002', studentId: 'STU-0002', status: TeacherAttendanceStatus.present, note: '', attendanceRate: 88),
  TeacherAttendanceStudentEntry(id: 3, code: 'Student 003', studentId: 'STU-0003', status: TeacherAttendanceStatus.absent, note: 'Follow-up pending', attendanceRate: 79),
  TeacherAttendanceStudentEntry(id: 4, code: 'Student 004', studentId: 'STU-0004', status: TeacherAttendanceStatus.present, note: '', attendanceRate: 98),
  TeacherAttendanceStudentEntry(id: 5, code: 'Student 005', studentId: 'STU-0005', status: TeacherAttendanceStatus.late, note: 'Arrived after lesson start', attendanceRate: 92),
  TeacherAttendanceStudentEntry(id: 6, code: 'Student 006', studentId: 'STU-0006', status: TeacherAttendanceStatus.present, note: '', attendanceRate: 95),
  TeacherAttendanceStudentEntry(id: 7, code: 'Student 007', studentId: 'STU-0007', status: TeacherAttendanceStatus.excused, note: 'Approved absence', attendanceRate: 90),
  TeacherAttendanceStudentEntry(id: 8, code: 'Student 008', studentId: 'STU-0008', status: TeacherAttendanceStatus.present, note: '', attendanceRate: 94),
];

void main() {
  test('attendance register computes percentage and review count from real entries', () {
    final register = TeacherAttendanceRegister(
      lesson: _fixtureLessons.first,
      entries: _fixtureStudents,
      submissionState: TeacherAttendanceSubmissionState.draft,
    );

    expect(register.presentPercent, 63);
    expect(register.reviewCount, 2);
    expect(register.count(TeacherAttendanceStatus.present), 5);
  });

  test('attendance register serializes submission evidence without losing rows', () {
    final original = TeacherAttendanceRegister(
      lesson: _fixtureLessons.first,
      entries: _fixtureStudents,
      submissionState: TeacherAttendanceSubmissionState.submitted,
      submittedAt: '2026-09-14T08:42:00Z',
      submittedByMembershipId: 'membership-teacher',
    );

    final restored = TeacherAttendanceRegister.fromJson(original.toJson());
    expect(restored.lesson.id, 'MON-0800-J2A');
    expect(restored.entries, hasLength(8));
    expect(restored.entries[2].status, TeacherAttendanceStatus.absent);
    expect(restored.submissionState, TeacherAttendanceSubmissionState.submitted);
    expect(restored.submittedAt, '2026-09-14T08:42:00Z');
    expect(restored.submittedByMembershipId, 'membership-teacher');
  });

  test('teacher permissions never grant cross-teacher or unsynced-final authority', () {
    final fake = _FakeAttendanceRepository();
    const teacher = SchoolMembership(
      id: 'teacher-membership',
      schoolId: 'school-1',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.teacher,
    );
    const principal = SchoolMembership(
      id: 'principal-membership',
      schoolId: 'school-1',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.principal,
    );

    final teacherPermissions = fake.permissionsFor(teacher);
    expect(teacherPermissions.canViewAssignedRegisters, isTrue);
    expect(teacherPermissions.canEditAssignedRegister, isTrue);
    expect(teacherPermissions.canSubmitAssignedRegister, isTrue);
    expect(teacherPermissions.canEditOtherTeachersRegisters, isFalse);
    expect(teacherPermissions.canFinalizeUnsyncedAbsence, isFalse);

    final principalPermissions = fake.permissionsFor(principal);
    expect(principalPermissions.canEditAssignedRegister, isFalse);
  });

  testWidgets('attendance search filters by student ID', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = _FakeAttendanceRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherAttendancePage(
            repository: fake,
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Student 001'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'STU-0003');
    await tester.pump();

    expect(find.text('Student 003'), findsOneWidget);
    expect(find.text('Student 001'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('submit locks the local register and keeps sync pending', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = _FakeAttendanceRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherAttendancePage(
            repository: fake,
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Submit attendance'));
    await tester.tap(find.text('Submit attendance'));
    await tester.pumpAndSettle();

    expect(find.text('Submitted · sync pending'), findsOneWidget);
    expect(
      find.textContaining('Server acknowledgement is still pending'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Attendance renders on a phone-sized viewport without exceptions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherAttendancePage(
            repository: _FakeAttendanceRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Take class attendance'), findsOneWidget);
    expect(find.text('JSS 2A attendance register'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeAttendanceRepository implements TeacherAttendanceRepository {
  _FakeAttendanceRepository()
      : _registers = [
          for (final lesson in _fixtureLessons)
            TeacherAttendanceRegister(
              lesson: lesson,
              entries: _fixtureStudents,
              submissionState: TeacherAttendanceSubmissionState.draft,
            ),
        ];

  List<TeacherAttendanceRegister> _registers;

  @override
  TeacherAttendancePermissions permissionsFor(SchoolMembership membership) {
    final isTeacher = membership.role == SchoolRole.teacher;
    return TeacherAttendancePermissions(
      canViewAssignedRegisters: isTeacher,
      canEditAssignedRegister: isTeacher,
      canSubmitAssignedRegister: isTeacher,
      canEditOtherTeachersRegisters: false,
      canFinalizeUnsyncedAbsence: false,
    );
  }

  @override
  Future<TeacherAttendanceSnapshot> load() async {
    return TeacherAttendanceSnapshot(
      registers: _registers,
      permissions: permissionsFor(
        const SchoolMembership(
          id: 'teacher-membership',
          schoolId: 'school-1',
          schoolName: 'BrightGate Academy',
          role: SchoolRole.teacher,
        ),
      ),
    );
  }

  @override
  Future<TeacherAttendanceActionResult> markAllPresent({
    required String lessonId,
  }) async {
    final register = _find(lessonId);
    final updated = register.copyWith(
      entries: register.entries
          .map(
            (entry) => entry.copyWith(status: TeacherAttendanceStatus.present),
          )
          .toList(growable: false),
      pendingSync: true,
    );
    _replace(updated);
    return TeacherAttendanceActionResult(
      success: true,
      message: 'All students marked present locally. Review before submitting.',
      register: updated,
    );
  }

  @override
  Future<TeacherAttendanceActionResult> setNote({
    required String lessonId,
    required String studentId,
    required String note,
  }) async {
    final register = _find(lessonId);
    final updated = register.copyWith(
      entries: register.entries
          .map(
            (entry) => entry.studentId == studentId
                ? entry.copyWith(note: note)
                : entry,
          )
          .toList(growable: false),
      pendingSync: true,
    );
    _replace(updated);
    return TeacherAttendanceActionResult(
      success: true,
      message: 'Attendance note saved locally and queued for synchronization.',
      register: updated,
    );
  }

  @override
  Future<TeacherAttendanceActionResult> setTopic({
    required String lessonId,
    required String topicId,
  }) async {
    final register = _find(lessonId);
    final selected = register.lesson.topicOptions.where((item) => item.id == topicId);
    final title = selected.isEmpty ? '' : selected.first.title;
    final updated = register.copyWith(
      lesson: register.lesson.copyWith(topicId: topicId, topic: title),
      pendingSync: true,
    );
    _replace(updated);
    return TeacherAttendanceActionResult(
      success: true,
      message: topicId.isEmpty
          ? 'Curriculum topic cleared locally and queued for synchronization.'
          : 'Curriculum topic linked to this lesson occurrence and queued for synchronization.',
      register: updated,
    );
  }

  @override
  Future<TeacherAttendanceActionResult> setStatus({
    required String lessonId,
    required String studentId,
    required TeacherAttendanceStatus status,
  }) async {
    final register = _find(lessonId);
    final updated = register.copyWith(
      entries: register.entries
          .map(
            (entry) => entry.studentId == studentId
                ? entry.copyWith(status: status)
                : entry,
          )
          .toList(growable: false),
      pendingSync: true,
    );
    _replace(updated);
    return TeacherAttendanceActionResult(
      success: true,
      message: 'Attendance status saved locally and queued for synchronization.',
      register: updated,
    );
  }

  @override
  Future<TeacherAttendanceActionResult> submit({required String lessonId}) async {
    final register = _find(lessonId);
    final updated = register.copyWith(
      submissionState: TeacherAttendanceSubmissionState.submitted,
      submittedAt: '2026-09-14T08:42:00Z',
      submittedByMembershipId: 'teacher-membership',
      pendingSync: true,
    );
    _replace(updated);
    return TeacherAttendanceActionResult(
      success: true,
      message: 'Attendance submitted locally and queued for synchronization. Server acknowledgement is still pending.',
      register: updated,
    );
  }

  TeacherAttendanceRegister _find(String lessonId) =>
      _registers.firstWhere((register) => register.lesson.id == lessonId);

  void _replace(TeacherAttendanceRegister updated) {
    _registers = [
      for (final register in _registers)
        if (register.lesson.id == updated.lesson.id) updated else register,
    ];
  }
}
