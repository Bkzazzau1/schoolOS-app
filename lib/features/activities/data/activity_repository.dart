import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/activity_models.dart';
import 'activity_demo_data.dart';

class ActivitySnapshot {
  const ActivitySnapshot({
    required this.activities,
    required this.permissions,
  });

  final List<SchoolActivity> activities;
  final ActivityPermissions permissions;
}

class ActivityActionResult {
  const ActivityActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class ActivityRepository {
  ActivityRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'school_activity';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  ActivityPermissions permissionsFor(SchoolMembership membership) {
    if (membership.role == SchoolRole.proprietor) {
      return const ActivityPermissions(
        canManageAll: true,
        canTakeAttendance: true,
      );
    }
    return const ActivityPermissions(
      canManageAll: false,
      canTakeAttendance: false,
    );
  }

  Future<ActivitySnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final activity in activityWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _entityType,
          entityId: activity.id,
          payload: activity.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _entityType,
      );
    }

    final activities = records
        .map((record) => SchoolActivity.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));

    return ActivitySnapshot(
      activities: activities,
      permissions: permissionsFor(membership),
    );
  }

  Future<ActivityActionResult> addActivity({
    required String name,
    required ActivityType type,
    required String section,
    required String coordinator,
    required String schedule,
    required String venue,
    required String note,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canManageAll) {
      return const ActivityActionResult(
        success: false,
        message: 'This membership cannot create school activities.',
      );
    }

    final cleanName = name.trim();
    final cleanCoordinator = coordinator.trim();
    if (cleanName.isEmpty || cleanCoordinator.isEmpty) {
      return const ActivityActionResult(
        success: false,
        message: 'Activity name and coordinator are required.',
      );
    }

    final now = DateTime.now().toUtc();
    final activity = SchoolActivity(
      id: 'ACT-${now.microsecondsSinceEpoch}',
      name: cleanName,
      type: type,
      section: section,
      coordinator: cleanCoordinator,
      members: 0,
      schedule: schedule.trim().isEmpty ? 'Schedule not set' : schedule.trim(),
      venue: venue.trim().isEmpty ? 'Venue not set' : venue.trim(),
      attendance: 0,
      consent: 'Not required',
      status: 'Active',
      icon: switch (type) {
        ActivityType.sport => '●',
        ActivityType.club => '◆',
        ActivityType.creative => '♪',
        ActivityType.academicEnrichment => '⌘',
      },
      note: note.trim().isEmpty ? 'New co-curricular programme.' : note.trim(),
    );

    await _save(activity, SyncOperation.create);
    return const ActivityActionResult(
      success: true,
      message: 'Activity saved offline and queued for sync.',
    );
  }

  Future<ActivityActionResult> updateAttendance({
    required String activityId,
    required int attendance,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canTakeAttendance) {
      return const ActivityActionResult(
        success: false,
        message: 'This membership cannot update activity attendance.',
      );
    }
    if (attendance < 0 || attendance > 100) {
      return const ActivityActionResult(
        success: false,
        message: 'Attendance must be between 0 and 100%.',
      );
    }

    final activity = await _requireActivity(activityId);
    await _save(activity.copyWith(attendance: attendance), SyncOperation.update);
    return const ActivityActionResult(
      success: true,
      message: 'Activity attendance saved offline.',
    );
  }

  Future<SchoolActivity> _requireActivity(String activityId) async {
    final membership = _schoolSession.requireActiveMembership();
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: activityId,
    );
    if (record == null) {
      throw StateError('Activity $activityId was not found in this school.');
    }
    return SchoolActivity.fromJson(record.payload);
  }

  Future<void> _save(SchoolActivity activity, SyncOperation operation) async {
    final membership = _schoolSession.requireActiveMembership();
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: activity.id,
      payload: activity.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: activity.id,
      operation: operation,
      payload: activity.toJson(),
    );
  }
}
