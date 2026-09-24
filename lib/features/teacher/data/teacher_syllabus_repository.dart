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
    this.canonical = false,
  });

  final List<TeacherSyllabusRow> rows;
  final List<String> classes;
  final Map<String, TeacherSyllabusProgressRecord> progress;
  final List<TeacherSyllabusProgressEvent> events;
  final TeacherSyllabusPermissions permissions;
  final bool canonical;

  TeacherSyllabusStatus effectiveStatus(TeacherSyllabusRow row) =>
      progress[row.id]?.reportedStatus ?? row.approvedStatus;

  bool isBehind(String className) {
    if (canonical) return false;
    return rows
        .where((row) => row.className == className)
        .any((row) => effectiveStatus(row) == TeacherSyllabusStatus.behind);
  }

  int coverageOf(String className) {
    final classRows = rows.where((row) => row.className == className).toList();
    if (classRows.isEmpty) return 0;
    final done = classRows
        .where((row) => effectiveStatus(row) == TeacherSyllabusStatus.completed)
        .length;
    return (done * 100 / classRows.length).round();
  }

  TeacherSyllabusRow? nextTopic(String className) {
    final candidates = rows
        .where((row) =>
            row.className == className &&
            effectiveStatus(row) != TeacherSyllabusStatus.completed)
        .toList()
      ..sort((a, b) => a.week.compareTo(b.week));
    return candidates.isEmpty ? null : candidates.first;
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

const teacherSyllabusProgressEntityType = 'teacher_syllabus_progress';

class TeacherSyllabusRepository {
  TeacherSyllabusRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required TeacherRoster roster,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _roster = roster;

  static const _progressType = teacherSyllabusProgressEntityType;
  static const _eventType = 'teacher_syllabus_progress_event';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TeacherRoster _roster;

  TeacherSyllabusPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherSyllabusPermissions(
      canViewAssignedScheme: teacher,
      canReportCoverage: teacher && !LocalDatabase.blockDemoSeeds,
      canEditApprovedScheme: false,
      canReorderTopics: false,
      canConfirmLeadershipApproval: false,
    );
  }

  Future<List<TeacherSyllabusRow>> _approvedRows(
    SchoolMembership membership,
  ) async {
    final assigned = await _roster.assignedClasses(membership);
    if (!LocalDatabase.blockDemoSeeds) {
      final classes = {for (final item in assigned) item.className};
      return [
        for (final row in teacherSyllabusRows)
          if (classes.contains(row.className)) row,
      ];
    }

    final rows = <TeacherSyllabusRow>[];
    for (final assignment in assigned) {
      for (final topic in assignment.topics) {
        rows.add(
          TeacherSyllabusRow(
            canonicalTopicId: topic.id,
            className: assignment.className,
            week: topic.sequence,
            topic: '${assignment.subject} · ${topic.title}',
            approvedStatus: TeacherSyllabusStatus.upcoming,
            plannedLessons: assignment.periodsPerWeek > 0
                ? assignment.periodsPerWeek
                : 1,
          ),
        );
      }
    }
    rows.sort((a, b) {
      final byClass = a.className.compareTo(b.className);
      if (byClass != 0) return byClass;
      final bySequence = a.week.compareTo(b.week);
      return bySequence != 0 ? bySequence : a.topic.compareTo(b.topic);
    });
    return rows;
  }

  Future<TeacherSyllabusSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final rows = await _approvedRows(membership);
    final rowIds = {for (final row in rows) row.id};
    final classes = {for (final row in rows) row.className}.toList()..sort();

    final progressRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _progressType,
    );
    final progress = <String, TeacherSyllabusProgressRecord>{};
    for (final record in progressRecords) {
      final parsed = TeacherSyllabusProgressRecord.fromJson(record.payload);
      if (!rowIds.contains(parsed.id)) continue;
      progress[parsed.id] = parsed;
    }

    if (LocalDatabase.blockDemoSeeds) {
      return TeacherSyllabusSnapshot(
        rows: rows,
        classes: classes,
        progress: progress,
        events: const [],
        permissions: permissionsFor(membership),
        canonical: true,
      );
    }

    final eventRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _eventType,
    );
    final events = eventRecords
        .map((record) => TeacherSyllabusProgressEvent.fromJson(record.payload))
        .where((event) => rowIds.contains(event.recordId))
        .toList(growable: false)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return TeacherSyllabusSnapshot(
      rows: rows,
      classes: classes,
      progress: progress,
      events: events,
      permissions: permissionsFor(membership),
      canonical: false,
    );
  }

  Future<TeacherSyllabusActionResult> markStatus({
    required TeacherSyllabusRow row,
    required TeacherSyllabusStatus status,
  }) async {
    if (LocalDatabase.blockDemoSeeds) {
      return const TeacherSyllabusActionResult(
        success: false,
        message:
            'Canonical syllabus progress is generated from server-accepted lesson delivery. Open Lesson Plans & Delivery to record the real occurrence instead.',
      );
    }

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
        message: 'Choose Completed or In progress.',
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
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _progressType,
      entityId: row.id,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: record.toJson(),
      baseVersion: existing?.serverVersion,
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
          ? 'Demo coverage marked complete locally.'
          : 'Demo coverage marked in progress locally.',
      record: record,
    );
  }
}
