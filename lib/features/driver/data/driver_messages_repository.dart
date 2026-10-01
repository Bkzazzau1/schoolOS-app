import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/driver_messages_models.dart';
import 'driver_alert_receipts.dart';
import 'driver_dashboard_repository.dart';
import 'driver_message_receipts.dart';

class DriverMessagesRepository {
  DriverMessagesRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _dashboardRepository = DriverDashboardRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        );

  static const messageEntityType = 'driver_message';
  static const alertEntityType = 'driver_alert';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final DriverDashboardRepository _dashboardRepository;

  /// The one real channel between this Driver and Transport Control
  /// (`apps/transport/driver_messages.py`) - never a pre-populated conversation. Operational
  /// alerts are a real, school-wide broadcast from Transport Control
  /// (`apps/transport/driver_messages.py: DriverAlertHandler`); every real Driver reads the same
  /// real rows, newest first.
  Future<DriverMessagesSnapshot> load() async {
    final membership = _requireDriver();
    final dashboard = await _dashboardRepository.load();

    final threadId = _threadId(membership.id);
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: messageEntityType,
    );
    final messages = [
      for (final record in records)
        if (record.payload['threadId'] == threadId)
          DriverMessageItem.fromCanonical(
            payload: Map<String, Object?>.from(record.payload),
            viewerMembershipId: membership.id,
            isDirty: record.isDirty,
          ),
    ]..sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
    final receipts = await loadOwnDriverThreadReceipts(
      _localDatabase,
      tenantId: membership.schoolId,
      membershipId: membership.id,
    );

    final thread = DriverMessageThread(
      id: threadId,
      participantName: 'Transport Control',
      participantRole: 'Transport Operations',
      channelLabel: 'Assigned route operations',
      preview: messages.isEmpty ? 'No messages yet' : messages.last.body,
      timeLabel: messages.isEmpty ? '' : messages.last.timeLabel,
      unread: isDriverThreadUnread(messages, receipts[threadId]),
      approvedOperationalChannel: true,
      messages: messages,
    );

    final alertRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: alertEntityType,
    );
    final readAlertIds = await loadOwnReadAlertIds(
      _localDatabase,
      tenantId: membership.schoolId,
      membershipId: membership.id,
    );
    final alerts = [
      for (final record in alertRecords)
        if (record.payload['id'] != null)
          DriverOperationalAlert.fromCanonical(
            payload: Map<String, Object?>.from(record.payload),
            read: readAlertIds.contains(record.payload['id']),
          ),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return DriverMessagesSnapshot(
      routeId: dashboard.assignment.routeId,
      vehicle: dashboard.route.vehicle,
      threads: [thread],
      alerts: alerts,
    );
  }

  Future<DriverMessageItem> queueReply({
    required String threadId,
    required String body,
  }) async {
    final membership = _requireDriver();
    final ownThreadId = _threadId(membership.id);
    final normalizedBody = body.trim();
    if (threadId.trim() != ownThreadId) {
      throw StateError('This is not an approved Driver operational communication channel.');
    }
    if (normalizedBody.isEmpty) {
      throw ArgumentError.value(body, 'body', 'Message text is required.');
    }
    if (normalizedBody.length > 2000) {
      throw ArgumentError.value(body, 'body', 'Driver messages cannot exceed 2000 characters.');
    }

    final dashboard = await _dashboardRepository.load();
    final now = DateTime.now().toUtc();
    final messageId = 'LOCAL-${membership.id}-${now.microsecondsSinceEpoch}';

    // The wire payload carries only what a Driver actually contributes; who really sent it and
    // when are the server's own stamp (see DriverMessageHandler.clean), never taken from the app.
    final wirePayload = <String, Object?>{
      'messageId': messageId,
      'threadId': ownThreadId,
      'body': normalizedBody,
    };
    final localPayload = <String, Object?>{
      ...wirePayload,
      'driverMembershipId': membership.id,
      'routeId': dashboard.assignment.routeId,
      'vehicle': dashboard.route.vehicle,
      'senderMembershipId': membership.id,
      'senderRole': 'driver',
      'receivedAt': now.toIso8601String(),
    };

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: messageEntityType,
      entityId: messageId,
      payload: localPayload,
      isDirty: true,
    );

    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: messageEntityType,
      entityId: messageId,
      operation: SyncOperation.create,
      payload: wirePayload,
    );

    return DriverMessageItem.fromCanonical(
      payload: localPayload,
      viewerMembershipId: membership.id,
      isDirty: true,
    );
  }

  Future<void> markThreadSeen(String threadId) async {
    final membership = _requireDriver();
    final ownThreadId = _threadId(membership.id);
    if (threadId.trim() != ownThreadId) {
      throw StateError('This Driver conversation is unavailable.');
    }
    final snapshot = await load();
    if (!snapshot.threads.single.unread) return;
    await queueDriverThreadSeenReceipt(
      _localDatabase,
      tenantId: membership.schoolId,
      membershipId: membership.id,
      threadId: ownThreadId,
      driverMembershipId: membership.id,
    );
  }

  /// Records this Driver's own real receipt for a real operational alert.
  Future<void> markAlertRead(String alertId) async {
    final membership = _requireDriver();
    final snapshot = await load();
    DriverOperationalAlert? alert;
    for (final item in snapshot.alerts) {
      if (item.id == alertId) {
        alert = item;
        break;
      }
    }
    if (alert == null) {
      throw StateError('This operational alert is unavailable.');
    }
    if (alert.read) return;
    await queueAlertReadReceipt(
      _localDatabase,
      tenantId: membership.schoolId,
      membershipId: membership.id,
      alertId: alertId,
      routeId: snapshot.routeId,
    );
  }

  String _threadId(String driverMembershipId) => 'driver-thread-$driverMembershipId';

  SchoolMembership _requireDriver() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.driver) {
      throw StateError('Driver messages require an active Driver membership.');
    }
    return membership;
  }
}
