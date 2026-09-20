import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_students_models.dart';
import 'teacher_students_demo_data.dart';

class TeacherStudentsSnapshot {
  const TeacherStudentsSnapshot({
    required this.students,
    required this.profiles,
    required this.notes,
    required this.permissions,
  });

  final List<TeacherStudentSummary> students;
  final Map<String, TeacherStudentProfile> profiles;
  final Map<String, TeacherStudentNote> notes;
  final TeacherStudentsPermissions permissions;
}

class TeacherStudentNoteResult {
  const TeacherStudentNoteResult({
    required this.success,
    required this.message,
    this.note,
  });

  final bool success;
  final String message;
  final TeacherStudentNote? note;
}

class TeacherStudentsRepository {
  TeacherStudentsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _summaryType = 'teacher_student_summary';
  static const _profileType = 'teacher_student_profile';
  static const _noteType = 'teacher_student_note';
  static const _noteEventType = 'teacher_student_note_event';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

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

  Future<TeacherStudentsSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    await _seedIfNeeded(membership);

    final summaryRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _summaryType,
    );
    final profileRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _profileType,
    );
    final noteRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _noteType,
    );

    final students = summaryRecords
        .map((record) => TeacherStudentSummary.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) {
        final ai = teacherStudents.indexWhere((item) => item.id == a.id);
        final bi = teacherStudents.indexWhere((item) => item.id == b.id);
        return ai.compareTo(bi);
      });

    final profiles = <String, TeacherStudentProfile>{
      for (final record in profileRecords)
        record.entityId: TeacherStudentProfile.fromJson(record.payload),
    };
    final notes = <String, TeacherStudentNote>{
      for (final record in noteRecords)
        record.entityId: TeacherStudentNote.fromJson(record.payload),
    };

    return TeacherStudentsSnapshot(
      students: students,
      profiles: profiles,
      notes: notes,
      permissions: permissionsFor(membership),
    );
  }

  Future<TeacherStudentNoteResult> saveNote({
    required String studentId,
    required String text,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canSaveProfessionalNote) {
      return const TeacherStudentNoteResult(
        success: false,
        message: 'This membership cannot save Teacher student notes.',
      );
    }

    final assigned = teacherStudents.any((student) => student.id == studentId);
    if (!assigned) {
      return const TeacherStudentNoteResult(
        success: false,
        message: 'This student is not in the teacher-assigned roster.',
      );
    }
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      return const TeacherStudentNoteResult(
        success: false,
        message: 'Add a professional teaching or intervention note before saving.',
      );
    }

    final existingRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _noteType,
    );
    TeacherStudentNote? existing;
    for (final record in existingRecords) {
      if (record.entityId == studentId) {
        existing = TeacherStudentNote.fromJson(record.payload);
        break;
      }
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final note = TeacherStudentNote(
      studentId: studentId,
      text: cleanText,
      version: (existing?.version ?? 0) + 1,
      updatedAt: now,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _noteType,
      entityId: studentId,
      payload: note.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _noteType,
      entityId: studentId,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: note.toJson(),
    );

    final eventId = '$studentId-${DateTime.now().microsecondsSinceEpoch}';
    final event = <String, Object?>{
      'id': eventId,
      'studentId': studentId,
      'actorMembershipId': membership.id,
      'action': 'savedProfessionalNote',
      'version': note.version,
      'occurredAt': now,
    };
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _noteEventType,
      entityId: eventId,
      payload: event,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _noteEventType,
      entityId: eventId,
      operation: SyncOperation.create,
      payload: event,
    );

    return TeacherStudentNoteResult(
      success: true,
      message: 'Teacher note saved locally and queued for synchronization. Student status, marks and guardian delivery are unchanged.',
      note: note,
    );
  }

  Future<void> _seedIfNeeded(SchoolMembership membership) async {
    final summaries = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _summaryType,
    );
    if (summaries.isEmpty) {
      for (final student in teacherStudents) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _summaryType,
          entityId: student.id,
          payload: student.toJson(),
        );
      }
    }

    final profiles = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _profileType,
    );
    if (profiles.isEmpty) {
      for (final profile in teacherStudentProfiles) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _profileType,
          entityId: profile.id,
          payload: profile.toJson(),
        );
      }
    }
  }
}
