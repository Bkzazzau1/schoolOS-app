import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/event_models.dart';
import 'event_demo_data.dart';

class EventSnapshot {
  const EventSnapshot({
    required this.events,
    required this.permissions,
  });

  final List<SchoolEvent> events;
  final EventPermissions permissions;
}

class EventActionResult {
  const EventActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class EventRepository {
  EventRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'school_event';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  EventPermissions permissionsFor(SchoolMembership membership) {
    if (membership.role == SchoolRole.proprietor) {
      return const EventPermissions(canManageAll: true);
    }
    return const EventPermissions(canManageAll: false);
  }

  Future<EventSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final event in eventWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _entityType,
          entityId: event.id,
          payload: event.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _entityType,
      );
    }

    final events = records
        .map((record) => SchoolEvent.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));

    return EventSnapshot(
      events: events,
      permissions: permissionsFor(membership),
    );
  }

  Future<EventActionResult> addEvent({
    required String title,
    required SchoolEventType type,
    required String audience,
    required String date,
    required String time,
    required String venue,
    required String owner,
    required SchoolEventStatus status,
    required String note,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canManageAll) {
      return const EventActionResult(
        success: false,
        message: 'This membership cannot create school-wide events.',
      );
    }

    final cleanTitle = title.trim();
    final cleanAudience = audience.trim();
    if (cleanTitle.isEmpty || cleanAudience.isEmpty) {
      return const EventActionResult(
        success: false,
        message: 'Event title and audience are required.',
      );
    }

    final now = DateTime.now().toUtc();
    final event = SchoolEvent(
      id: 'EV-${now.microsecondsSinceEpoch}',
      title: cleanTitle,
      type: type,
      audience: cleanAudience,
      date: date.trim().isEmpty ? 'TBD' : date.trim(),
      time: time.trim().isEmpty ? 'TBD' : time.trim(),
      venue: venue.trim().isEmpty ? 'TBD' : venue.trim(),
      owner: owner.trim().isEmpty ? membership.roleLabel : owner.trim(),
      status: status,
      note: note.trim().isEmpty ? 'School event.' : note.trim(),
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: event.id,
      payload: event.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: event.id,
      operation: SyncOperation.create,
      payload: event.toJson(),
    );

    return const EventActionResult(
      success: true,
      message: 'Event saved offline and queued for sync.',
    );
  }
}
