import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_students_models.dart';
import 'teacher_roster.dart';

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

/// "Students": the real students in the teacher's real assigned classes, from the administrator's register.
///
/// Average, attendance rate and trend need a history of assessments and daily attendance that this module does not keep
/// yet (attendance here is a same-day snapshot per class, not a running rate), so they show as not tracked rather than a
/// made-up number, and no student is given a risk label from nothing.
class TeacherStudentsRepository {
  TeacherStudentsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required TeacherRoster roster,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _roster = roster;

  static const _noteType = 'teacher_student_note';
  static const _noteEventType = 'teacher_student_note_event';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TeacherRoster _roster;

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

  Future<List<TeacherStudentSummary>> _roll(SchoolMembership membership) async {
    final classes = await _roster.assignedClasses(membership);
    final seen = <String>{};
    final result = <TeacherStudentSummary>[];
    for (final c in classes) {
      for (final s in await _roster.studentsIn(c.className)) {
        if (!seen.add(s.id)) continue;
        result.add(TeacherStudentSummary(
          id: s.id,
          name: s.name,
          className: s.className,
          average: 0,
          attendance: 0,
          trend: 0,
          risk: TeacherStudentRisk.stable,
          intervention: '',
          attention: 'No assessment or attendance history has been recorded for this student yet.',
        ));
      }
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  Future<TeacherStudentsSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final students = await _roll(membership);

    final noteRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _noteType,
    );
    final notes = <String, TeacherStudentNote>{
      for (final record in noteRecords)
        record.entityId: TeacherStudentNote.fromJson(record.payload),
    };

    final profiles = <String, TeacherStudentProfile>{
      for (final s in students)
        s.id: TeacherStudentProfile(
          id: s.id,
          admissionNo: '',
          name: s.name,
          className: s.className,
          status: 'Active',
          average: 0,
          attendance: 0,
          trend: 0,
          classTeacher: membership.role == SchoolRole.teacher ? 'You' : '',
          attention: s.attention,
          subjects: const [],
          attendanceSummary: const [],
          timeline: const [],
        ),
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

    final assigned = (await _roll(membership)).any((student) => student.id == studentId);
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
}
