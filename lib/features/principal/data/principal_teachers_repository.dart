import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/principal_teachers_models.dart';
import 'principal_teachers_demo_data.dart';

class PrincipalTeachersSnapshot {
  const PrincipalTeachersSnapshot({
    required this.teachers,
    required this.profiles,
    required this.notes,
    required this.permissions,
  });

  final List<PrincipalTeacher> teachers;
  final List<PrincipalTeacherProfile> profiles;
  final Map<String, PrincipalTeacherNote> notes;
  final PrincipalTeacherPermissions permissions;
}

class PrincipalTeacherActionResult {
  const PrincipalTeacherActionResult({required this.success, required this.message});
  final bool success;
  final String message;
}

class PrincipalTeachersRepository {
  PrincipalTeachersRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _teacherEntity = 'principal_teacher';
  static const _profileEntity = 'principal_teacher_profile';
  static const _noteEntity = 'principal_teacher_note';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  PrincipalTeacherPermissions permissionsFor(SchoolMembership membership) => PrincipalTeacherPermissions(
        canReviewSecondaryTeachers: membership.role == SchoolRole.principal,
        canSavePrivateNotes: membership.role == SchoolRole.principal,
        canViewConfidentialPayroll: false,
      );

  Future<PrincipalTeachersSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var teacherRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _teacherEntity,
    );
    if (teacherRecords.isEmpty) {
      for (final teacher in principalTeachersWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _teacherEntity,
          entityId: teacher.id,
          payload: teacher.toJson(),
        );
      }
      teacherRecords = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _teacherEntity,
      );
    }

    var profileRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _profileEntity,
    );
    if (profileRecords.isEmpty) {
      for (final profile in principalTeacherProfilesWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _profileEntity,
          entityId: profile.directoryId,
          payload: profile.toJson(),
        );
      }
      profileRecords = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _profileEntity,
      );
    }

    final noteRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _noteEntity,
    );

    final teachers = teacherRecords.map((e) => PrincipalTeacher.fromJson(e.payload)).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final profiles = profileRecords.map((e) => PrincipalTeacherProfile.fromJson(e.payload)).toList()
      ..sort((a, b) => a.directoryId.compareTo(b.directoryId));
    final notes = <String, PrincipalTeacherNote>{
      for (final record in noteRecords)
        PrincipalTeacherNote.fromJson(record.payload).teacherId: PrincipalTeacherNote.fromJson(record.payload),
    };

    return PrincipalTeachersSnapshot(
      teachers: teachers,
      profiles: profiles,
      notes: notes,
      permissions: permissionsFor(membership),
    );
  }

  Future<PrincipalTeacherActionResult> savePrivateNote({
    required String teacherId,
    required String text,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canSavePrivateNotes) {
      return const PrincipalTeacherActionResult(
        success: false,
        message: 'This membership cannot save private Principal notes.',
      );
    }
    final normalized = text.trim();
    final note = PrincipalTeacherNote(teacherId: teacherId, text: normalized);
    final existing = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _noteEntity,
    );
    final alreadyExists = existing.any((record) => record.entityId == teacherId);

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _noteEntity,
      entityId: teacherId,
      payload: note.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _noteEntity,
      entityId: teacherId,
      operation: alreadyExists ? SyncOperation.update : SyncOperation.create,
      payload: note.toJson(),
    );

    return PrincipalTeacherActionResult(
      success: true,
      message: normalized.isEmpty
          ? 'Private Principal note cleared offline and queued for sync.'
          : 'Private Principal note saved offline and queued for sync.',
    );
  }
}
