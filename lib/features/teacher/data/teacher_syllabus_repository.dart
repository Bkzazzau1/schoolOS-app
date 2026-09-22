import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_syllabus_models.dart';
import 'teacher_roster.dart';
import 'teacher_syllabus_demo_data.dart';

class TeacherSyllabusSnapshot {
  const TeacherSyllabusSnapshot({
    required this.rows,
    required this.classes,
    required this.progress,
    required this.events,
    required this.permissions,
  });

  final List<TeacherSyllabusRow> rows;

  /// The teacher's real assigned classes that have a scheme of work uploaded (by the Principal or the Head of the
  /// section). A real assigned class with no scheme yet is not offered here, rather than showing an empty scheme.
  final List<String> classes;

  final Map<String, TeacherSyllabusProgressRecord> progress;
  final List<TeacherSyllabusProgressEvent> events;
  final TeacherSyllabusPermissions permissions;

  TeacherSyllabusStatus effectiveStatus(TeacherSyllabusRow row) =>
      progress[row.id]?.reportedStatus ?? row.approvedStatus;

  /// Whether any row of [className] is behind where the scheme expects it to be.
  bool isBehind(String className) => rows
      .where((row) => row.className == className)
      .any((row) => effectiveStatus(row) == TeacherSyllabusStatus.behind);

  /// The share of [className]'s topics reported complete, as a whole percentage.
  int coverageOf(String className) {
    final rows = this.rows.where((row) => row.className == className).toList();
    if (rows.isEmpty) return 0;
    final done = rows.where((row) => effectiveStatus(row) == TeacherSyllabusStatus.completed).length;
    return (done * 100 / rows.length).round();
  }
}

class TeacherSyllabusActionResult {
  const TeacherSyllabusActionResult({
    required this.success,
    required this.message,
    this.record,
  });

  final bool success;
  final String message;
  final TeacherSyllabusProgressRecord? record;
}

class TeacherSyllabusRepository {
  TeacherSyllabusRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required TeacherRoster roster,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _roster = roster;

  static const _progressType = 'teacher_syllabus_progress';
  static const _eventType = 'teacher_syllabus_progress_event';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TeacherRoster _roster;

  TeacherSyllabusPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherSyllabusPermissions(
      canViewAssignedScheme: teacher,
      canReportCoverage: teacher,
      canEditApprovedScheme: false,
      canReorderTopics: false,
      canConfirmLeadershipApproval: false,
    );
  }

  /// The names of the teacher's real assigned classes that a scheme of work has been uploaded for.
  Future<Set<String>> _classesWithScheme(SchoolMembership membership) async {
    final assigned = {for (final c in await _roster.assignedClasses(membership)) c.className};
    return {for (final row in teacherSyllabusRows) row.className}.intersection(assigned);
  }

  Future<TeacherSyllabusSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final classes = await _classesWithScheme(membership);
    final rows = [for (final row in teacherSyllabusRows) if (classes.contains(row.className)) row];

    final progressRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _progressType,
    );
    final eventRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _eventType,
    );

    final progress = <String, TeacherSyllabusProgressRecord>{};
    for (final record in progressRecords) {
      final parsed = TeacherSyllabusProgressRecord.fromJson(record.payload);
      if (!classes.contains(parsed.className)) continue;
      progress[parsed.id] = parsed;
    }

    final events = eventRecords
        .map((record) => TeacherSyllabusProgressEvent.fromJson(record.payload))
        .where((event) => rows.any((row) => row.id == event.recordId))
        .toList(growable: false)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return TeacherSyllabusSnapshot(
      rows: rows,
      classes: classes.toList()..sort(),
      progress: progress,
      events: events,
      permissions: permissionsFor(membership),
    );
  }

  Future<TeacherSyllabusActionResult> markStatus({
    required TeacherSyllabusRow row,
    required TeacherSyllabusStatus status,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canReportCoverage) {
      return const TeacherSyllabusActionResult(
        success: false,
        message: 'This membership cannot report syllabus coverage.',
      );
    }
    if (status != TeacherSyllabusStatus.completed &&
        status != TeacherSyllabusStatus.inProgress) {
      return const TeacherSyllabusActionResult(
        success: false,
        message: 'Teachers can only report a topic as completed or in progress from this workspace.',
      );
    }
    if (!(await _classesWithScheme(membership)).contains(row.className)) {
      return const TeacherSyllabusActionResult(
        success: false,
        message: 'This class is not in your assigned scheme of work.',
      );
    }

    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _progressType,
      entityId: row.id,
    );
    final oldVersion = existing == null
        ? 0
        : TeacherSyllabusProgressRecord.fromJson(existing.payload).version;
    final now = DateTime.now().toUtc().toIso8601String();
    final record = TeacherSyllabusProgressRecord(
      id: row.id,
      className: row.className,
      week: row.week,
      reportedStatus: status,
      actorMembershipId: membership.id,
      version: oldVersion + 1,
      updatedAt: now,
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _progressType,
      entityId: row.id,
      payload: record.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _progressType,
      entityId: row.id,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: record.toJson(),
    );

    final action = status == TeacherSyllabusStatus.completed
        ? TeacherSyllabusProgressAction.markedComplete
        : TeacherSyllabusProgressAction.markedInProgress;
    final event = TeacherSyllabusProgressEvent(
      id: '${row.id}-${DateTime.now().microsecondsSinceEpoch}',
      recordId: row.id,
      action: action,
      actorMembershipId: membership.id,
      version: record.version,
      occurredAt: now,
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

    return TeacherSyllabusActionResult(
      success: true,
      message: status == TeacherSyllabusStatus.completed
          ? 'Coverage marked complete locally and queued for synchronization. The approved scheme itself was not changed.'
          : 'Coverage marked in progress locally and queued for synchronization. The approved scheme itself was not changed.',
      record: record,
    );
  }
}
