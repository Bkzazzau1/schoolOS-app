import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_attendance_models.dart';
import 'teacher_attendance_demo_data.dart';

class TeacherAttendanceActionResult {
  const TeacherAttendanceActionResult({
    required this.success,
    required this.message,
    this.register,
  });

  final bool success;
  final String message;
  final TeacherAttendanceRegister? register;
}

abstract class TeacherAttendanceDataSource {
  Future<TeacherAttendanceSnapshot> load();

  Future<TeacherAttendanceActionResult> setStatus({
    required String lessonId,
    required String studentId,
    required TeacherAttendanceStatus status,
  });

  Future<TeacherAttendanceActionResult> setNote({
    required String lessonId,
    required String studentId,
    required String note,
  });

  Future<TeacherAttendanceActionResult> markAllPresent({
    required String lessonId,
  });

  Future<TeacherAttendanceActionResult> submit({required String lessonId});
}

class TeacherAttendanceRepository implements TeacherAttendanceDataSource {
  TeacherAttendanceRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _registerType = 'teacher_attendance_register';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

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
    final membership = _schoolSession.requireActiveMembership();
    await _seedIfNeeded(membership);

    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _registerType,
    );

    final registers = records.map((record) {
      final register = TeacherAttendanceRegister.fromJson(record.payload);
      return register.copyWith(pendingSync: record.isDirty);
    }).toList(growable: false)
      ..sort(
        (a, b) => _lessonOrder(a.lesson.id).compareTo(_lessonOrder(b.lesson.id)),
      );

    return TeacherAttendanceSnapshot(
      registers: registers,
      permissions: permissionsFor(membership),
    );
  }

  @override
  Future<TeacherAttendanceActionResult> setStatus({
    required String lessonId,
    required String studentId,
    required TeacherAttendanceStatus status,
  }) async {
    return _editRegister(
      lessonId: lessonId,
      mutate: (register) {
        final entries = register.entries
            .map(
              (entry) => entry.studentId == studentId
                  ? entry.copyWith(status: status)
                  : entry,
            )
            .toList(growable: false);
        return register.copyWith(entries: entries, pendingSync: true);
      },
      successMessage: 'Attendance status saved locally and queued for synchronization.',
    );
  }

  @override
  Future<TeacherAttendanceActionResult> setNote({
    required String lessonId,
    required String studentId,
    required String note,
  }) async {
    return _editRegister(
      lessonId: lessonId,
      mutate: (register) {
        final entries = register.entries
            .map(
              (entry) => entry.studentId == studentId
                  ? entry.copyWith(note: note)
                  : entry,
            )
            .toList(growable: false);
        return register.copyWith(entries: entries, pendingSync: true);
      },
      successMessage: 'Attendance note saved locally and queued for synchronization.',
    );
  }

  @override
  Future<TeacherAttendanceActionResult> markAllPresent({
    required String lessonId,
  }) async {
    return _editRegister(
      lessonId: lessonId,
      mutate: (register) {
        final entries = register.entries
            .map(
              (entry) => entry.copyWith(status: TeacherAttendanceStatus.present),
            )
            .toList(growable: false);
        return register.copyWith(entries: entries, pendingSync: true);
      },
      successMessage: 'All students marked present locally. Review before submitting.',
    );
  }

  @override
  Future<TeacherAttendanceActionResult> submit({required String lessonId}) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canSubmitAssignedRegister) {
      return const TeacherAttendanceActionResult(
        success: false,
        message: 'This membership cannot submit Teacher attendance.',
      );
    }

    final register = await _readRegister(membership, lessonId);
    if (register == null) {
      return const TeacherAttendanceActionResult(
        success: false,
        message: 'Attendance register not found.',
      );
    }
    if (register.submissionState == TeacherAttendanceSubmissionState.submitted) {
      return TeacherAttendanceActionResult(
        success: false,
        message: 'This register has already been submitted. Use an audited correction workflow for later changes.',
        register: register,
      );
    }

    final submitted = register.copyWith(
      submissionState: TeacherAttendanceSubmissionState.submitted,
      submittedAt: DateTime.now().toUtc().toIso8601String(),
      submittedByMembershipId: membership.id,
      pendingSync: true,
    );
    await _persistAndQueue(membership, submitted);

    return TeacherAttendanceActionResult(
      success: true,
      message: 'Attendance submitted locally and queued for synchronization. Server acknowledgement is still pending.',
      register: submitted,
    );
  }

  Future<TeacherAttendanceActionResult> _editRegister({
    required String lessonId,
    required TeacherAttendanceRegister Function(TeacherAttendanceRegister register) mutate,
    required String successMessage,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canEditAssignedRegister) {
      return const TeacherAttendanceActionResult(
        success: false,
        message: 'This membership cannot edit Teacher attendance.',
      );
    }

    final register = await _readRegister(membership, lessonId);
    if (register == null) {
      return const TeacherAttendanceActionResult(
        success: false,
        message: 'Attendance register not found.',
      );
    }
    if (register.submissionState == TeacherAttendanceSubmissionState.submitted) {
      return TeacherAttendanceActionResult(
        success: false,
        message: 'Submitted attendance is locked. Use an audited correction workflow for later changes.',
        register: register,
      );
    }

    final updated = mutate(register).copyWith(
      submissionState: TeacherAttendanceSubmissionState.draft,
      pendingSync: true,
      clearSubmission: true,
    );
    await _persistAndQueue(membership, updated);

    return TeacherAttendanceActionResult(
      success: true,
      message: successMessage,
      register: updated,
    );
  }

  Future<TeacherAttendanceRegister?> _readRegister(
    SchoolMembership membership,
    String lessonId,
  ) async {
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _registerType,
      entityId: lessonId,
    );
    if (record == null) return null;
    return TeacherAttendanceRegister.fromJson(record.payload)
        .copyWith(pendingSync: record.isDirty);
  }

  Future<void> _persistAndQueue(
    SchoolMembership membership,
    TeacherAttendanceRegister register,
  ) async {
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _registerType,
      entityId: register.lesson.id,
      payload: register.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _registerType,
      entityId: register.lesson.id,
      operation: SyncOperation.update,
      payload: register.toJson(),
    );
  }

  Future<void> _seedIfNeeded(SchoolMembership membership) async {
    final existing = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _registerType,
    );
    if (existing.isNotEmpty) return;

    for (final lesson in teacherAttendanceLessons) {
      final register = TeacherAttendanceRegister(
        lesson: lesson,
        entries: teacherAttendanceInitialStudents,
        submissionState: TeacherAttendanceSubmissionState.draft,
      );
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: _registerType,
        entityId: lesson.id,
        payload: register.toJson(),
      );
    }
  }

  int _lessonOrder(String id) {
    final index = teacherAttendanceLessons.indexWhere((lesson) => lesson.id == id);
    return index == -1 ? teacherAttendanceLessons.length : index;
  }
}
