import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_assessment_models.dart';
import 'teacher_assessment_demo_data.dart';

class TeacherAssessmentSnapshot {
  const TeacherAssessmentSnapshot({
    required this.register,
    required this.sheet,
    required this.events,
    required this.permissions,
  });

  final List<TeacherAssessmentRegisterItem> register;
  final TeacherAssessmentScoreSheet sheet;
  final List<TeacherAssessmentEvent> events;
  final TeacherAssessmentPermissions permissions;
}

class TeacherAssessmentActionResult {
  const TeacherAssessmentActionResult({
    required this.success,
    required this.message,
    this.sheet,
  });

  final bool success;
  final String message;
  final TeacherAssessmentScoreSheet? sheet;
}

class TeacherAssessmentRepository {
  TeacherAssessmentRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _registerType = 'teacher_assessment_register';
  static const _sheetType = 'teacher_assessment_score_sheet';
  static const _eventType = 'teacher_assessment_event';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  TeacherAssessmentPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherAssessmentPermissions(
      canViewAssignedClassAssessments: teacher,
      canEnterScores: teacher,
      canSubmitScores: teacher,
      canLockScores: false,
      canReleaseResults: false,
      canAiAlterMarks: false,
    );
  }

  Future<TeacherAssessmentSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    await _seedIfNeeded(membership);

    final registerRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _registerType,
    );
    final sheetRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _sheetType,
    );
    final eventRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _eventType,
    );

    final register = registerRecords
        .map((record) => TeacherAssessmentRegisterItem.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    final sheet = TeacherAssessmentScoreSheet.fromJson(sheetRecords.first.payload);
    final events = eventRecords
        .map((record) => TeacherAssessmentEvent.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return TeacherAssessmentSnapshot(
      register: register,
      sheet: sheet,
      events: events,
      permissions: permissionsFor(membership),
    );
  }

  Future<TeacherAssessmentActionResult> saveProgress(
    TeacherAssessmentScoreSheet draft,
  ) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canEnterScores) {
      return const TeacherAssessmentActionResult(
        success: false,
        message: 'This membership cannot enter assessment scores.',
      );
    }
    if (!draft.teacherEditable) {
      return const TeacherAssessmentActionResult(
        success: false,
        message: 'Submitted or locked score sheets cannot be silently rewritten.',
      );
    }
    final validation = _validateScores(draft);
    if (validation != null) {
      return TeacherAssessmentActionResult(success: false, message: validation);
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final updated = draft.copyWith(
      state: TeacherAssessmentSheetState.draft,
      version: draft.version + 1,
      updatedAt: now,
    );
    await _persistSheet(membership, updated);
    await _appendEvent(
      membership,
      sheet: updated,
      action: TeacherAssessmentEventAction.savedProgress,
      occurredAt: now,
    );
    return TeacherAssessmentActionResult(
      success: true,
      message: 'Score-entry progress saved locally and queued for synchronization.',
      sheet: updated,
    );
  }

  Future<TeacherAssessmentActionResult> submitScores(
    TeacherAssessmentScoreSheet draft,
  ) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canSubmitScores) {
      return const TeacherAssessmentActionResult(
        success: false,
        message: 'This membership cannot submit assessment scores.',
      );
    }
    if (!draft.teacherEditable) {
      return const TeacherAssessmentActionResult(
        success: false,
        message: 'This score sheet is already submitted or locked.',
      );
    }
    final validation = _validateScores(draft);
    if (validation != null) {
      return TeacherAssessmentActionResult(success: false, message: validation);
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final updated = draft.copyWith(
      state: TeacherAssessmentSheetState.submittedForReview,
      version: draft.version + 1,
      updatedAt: now,
      submittedAt: now,
    );
    await _persistSheet(membership, updated);
    await _appendEvent(
      membership,
      sheet: updated,
      action: TeacherAssessmentEventAction.submittedForReview,
      occurredAt: now,
    );
    return TeacherAssessmentActionResult(
      success: true,
      message: 'Scores submitted locally for review or locking and queued for synchronization. They are not locked or released yet.',
      sheet: updated,
    );
  }

  String? _validateScores(TeacherAssessmentScoreSheet sheet) {
    if (sheet.maximumScore <= 0) return 'Assessment maximum score must be positive.';
    if (sheet.entries.isEmpty) return 'Add score entries before saving or submitting.';
    if (sheet.entries.any((entry) => entry.score < 0 || entry.score > sheet.maximumScore)) {
      return 'Every score must stay between 0 and ${sheet.maximumScore}.';
    }
    return null;
  }

  Future<void> _persistSheet(
    SchoolMembership membership,
    TeacherAssessmentScoreSheet sheet,
  ) async {
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _sheetType,
      entityId: sheet.id,
      payload: sheet.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _sheetType,
      entityId: sheet.id,
      operation: SyncOperation.update,
      payload: sheet.toJson(),
    );
  }

  Future<void> _appendEvent(
    SchoolMembership membership, {
    required TeacherAssessmentScoreSheet sheet,
    required TeacherAssessmentEventAction action,
    required String occurredAt,
  }) async {
    final event = TeacherAssessmentEvent(
      id: '${sheet.id}-${DateTime.now().microsecondsSinceEpoch}',
      sheetId: sheet.id,
      action: action,
      actorMembershipId: membership.id,
      version: sheet.version,
      occurredAt: occurredAt,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _eventType,
      entityId: event.id,
      payload: event.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _eventType,
      entityId: event.id,
      operation: SyncOperation.create,
      payload: event.toJson(),
    );
  }

  Future<void> _seedIfNeeded(SchoolMembership membership) async {
    final existing = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _sheetType,
    );
    if (existing.isNotEmpty) return;

    for (final item in teacherAssessmentRegister) {
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: _registerType,
        entityId: item.id,
        payload: item.toJson(),
      );
    }
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _sheetType,
      entityId: teacherAssessmentInitialSheet.id,
      payload: teacherAssessmentInitialSheet.toJson(),
    );
  }
}
