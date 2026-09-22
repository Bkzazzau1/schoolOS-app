import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_assessment_models.dart';
import 'teacher_roster.dart';

class TeacherAssessmentSnapshot {
  const TeacherAssessmentSnapshot({
    required this.register,
    required this.sheets,
    required this.classOptions,
    required this.studentNames,
    required this.events,
    required this.permissions,
  });

  /// The teacher's own created assessments for their real assigned classes.
  final List<TeacherAssessmentRegisterItem> register;

  /// Each register item's score sheet, keyed by the item's id.
  final Map<String, TeacherAssessmentScoreSheet> sheets;

  /// The real classes the teacher is assigned to (an assessment can only be created for one of these).
  final List<String> classOptions;

  /// Real student names for every student appearing in a score sheet, by student id.
  final Map<String, String> studentNames;

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
    required TeacherRoster roster,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _roster = roster;

  static const _registerType = 'teacher_assessment_register';
  static const _sheetType = 'teacher_assessment_score_sheet';
  static const _eventType = 'teacher_assessment_event';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TeacherRoster _roster;

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

  Future<List<String>> _assignedClassNames(SchoolMembership membership) async {
    final classes = await _roster.assignedClasses(membership);
    return {for (final c in classes) c.className}.toList()..sort();
  }

  Future<TeacherAssessmentSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final assigned = await _assignedClassNames(membership);

    final registerRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _registerType,
    );
    final register = registerRecords
        .map((record) => TeacherAssessmentRegisterItem.fromJson(record.payload))
        .where((item) => assigned.contains(item.className))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));

    final sheetRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _sheetType,
    );
    final registerIds = {for (final item in register) item.id};
    final sheets = <String, TeacherAssessmentScoreSheet>{
      for (final record in sheetRecords)
        if (registerIds.contains(record.entityId))
          record.entityId: TeacherAssessmentScoreSheet.fromJson(record.payload),
    };

    final studentNames = <String, String>{};
    for (final className in assigned) {
      for (final student in await _roster.studentsIn(className)) {
        studentNames[student.id] = student.name;
      }
    }

    final eventRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _eventType,
    );
    final events = eventRecords
        .map((record) => TeacherAssessmentEvent.fromJson(record.payload))
        .where((event) => registerIds.contains(event.sheetId))
        .toList(growable: false)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return TeacherAssessmentSnapshot(
      register: register,
      sheets: sheets,
      classOptions: assigned,
      studentNames: studentNames,
      events: events,
      permissions: permissionsFor(membership),
    );
  }

  /// Creates a new assessment for a real assigned class, with one score entry (starting at 0) per real student
  /// currently in that class.
  Future<TeacherAssessmentActionResult> createAssessment({
    required String className,
    required String title,
    required int maximumScore,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canEnterScores) {
      return const TeacherAssessmentActionResult(
        success: false,
        message: 'This membership cannot create assessments.',
      );
    }
    if (!(await _assignedClassNames(membership)).contains(className)) {
      return const TeacherAssessmentActionResult(
        success: false,
        message: 'You are not assigned to this class.',
      );
    }
    if (title.trim().isEmpty) {
      return const TeacherAssessmentActionResult(success: false, message: 'Enter a title for the assessment.');
    }
    if (maximumScore <= 0) {
      return const TeacherAssessmentActionResult(success: false, message: 'Maximum score must be positive.');
    }
    final students = await _roster.studentsIn(className);
    if (students.isEmpty) {
      return const TeacherAssessmentActionResult(
        success: false,
        message: 'There are no students on the register for this class yet.',
      );
    }

    final id = 'assessment-${DateTime.now().microsecondsSinceEpoch}';
    final sheet = TeacherAssessmentScoreSheet(
      id: id,
      className: className,
      assessmentLabel: title.trim(),
      maximumScore: maximumScore,
      entries: [for (final s in students) TeacherAssessmentScoreEntry(studentId: s.id, score: 0)],
      state: TeacherAssessmentSheetState.draft,
    );
    await _persistSheet(membership, sheet);
    await _persistRegisterItem(membership, sheet);
    return TeacherAssessmentActionResult(
      success: true,
      message: 'Assessment created. Enter scores below and save progress or submit when ready.',
      sheet: sheet,
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
    if (!(await _assignedClassNames(membership)).contains(draft.className)) {
      return const TeacherAssessmentActionResult(
        success: false,
        message: 'This class is not one of your assigned classes.',
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
    await _persistRegisterItem(membership, updated);
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
    if (!(await _assignedClassNames(membership)).contains(draft.className)) {
      return const TeacherAssessmentActionResult(
        success: false,
        message: 'This class is not one of your assigned classes.',
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
    await _persistRegisterItem(membership, updated);
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
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _sheetType,
      entityId: sheet.id,
    );
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
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: sheet.toJson(),
    );
  }

  /// The register item mirrors its sheet's real progress: how many of the real students in the class have a
  /// score entered so far, and the real average. A score of exactly 0 cannot be told apart from "not entered yet"
  /// with the current score model, so "entered" counts entries with a score above zero; this is a known, honest
  /// approximation rather than a fabricated figure.
  Future<void> _persistRegisterItem(
    SchoolMembership membership,
    TeacherAssessmentScoreSheet sheet,
  ) async {
    final entered = sheet.entries.where((e) => e.score > 0).length;
    final item = TeacherAssessmentRegisterItem(
      id: sheet.id,
      title: sheet.assessmentLabel,
      className: sheet.className,
      maximumScore: sheet.maximumScore,
      entered: entered,
      total: sheet.entries.length,
      average: sheet.average,
      state: entered >= sheet.entries.length && sheet.entries.isNotEmpty
          ? TeacherAssessmentRegisterState.complete
          : TeacherAssessmentRegisterState.inProgress,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _registerType,
      entityId: item.id,
      payload: item.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _registerType,
      entityId: item.id,
      operation: SyncOperation.update,
      payload: item.toJson(),
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
}
