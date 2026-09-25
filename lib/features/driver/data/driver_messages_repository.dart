import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/driver_messages_models.dart';
import 'driver_dashboard_repository.dart';
import 'driver_messages_demo_data.dart';

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

  static const snapshotEntityType = 'driver_messages_snapshot';
  static const messageEntityType = 'driver_message';
  static const receiptEntityType = 'driver_message_receipt';
  static const alertReceiptEntityType = 'driver_alert_receipt';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final DriverDashboardRepository _dashboardRepository;

  Future<DriverMessagesSnapshot> load() async {
    final membership = _requireDriver();
    final dashboard = await _dashboardRepository.load();
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: snapshotEntityType,
      entityId: membership.id,
    );

    if (record != null) {
      final snapshot = DriverMessagesSnapshot.fromJson(record.payload);
      _validateSnapshot(snapshot, dashboard.assignment.routeId, dashboard.route.vehicle);
      return snapshot;
    }

    // The sample conversations and alerts are demo furniture. On a school with a server they were
    // never sent to this Driver, and they would be shown (and replied to) as if they had, so the
    // honest state there is none yet - the empty cards below the screen already say so.
    final seed = DriverMessagesSnapshot(
      routeId: dashboard.assignment.routeId,
      vehicle: dashboard.route.vehicle,
      threads: LocalDatabase.blockDemoSeeds ? const [] : driverMessagesWebsiteSeed.threads,
      alerts: LocalDatabase.blockDemoSeeds ? const [] : driverMessagesWebsiteSeed.alerts,
    );
    _validateSnapshot(seed, dashboard.assignment.routeId, dashboard.route.vehicle);
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: snapshotEntityType,
      entityId: membership.id,
      payload: seed.toJson(),
      isDirty: false,
    );
    return seed;
  }

  Future<DriverMessageItem> queueReply({
    required String threadId,
    required String body,
  }) async {
    final membership = _requireDriver();
    final normalizedThreadId = threadId.trim();
    final normalizedBody = body.trim();
    if (normalizedThreadId.isEmpty) {
      throw ArgumentError.value(threadId, 'threadId', 'Conversation is required.');
    }
    if (normalizedBody.isEmpty) {
      throw ArgumentError.value(body, 'body', 'Message text is required.');
    }
    if (normalizedBody.length > 2000) {
      throw ArgumentError.value(body, 'body', 'Driver messages cannot exceed 2000 characters.');
    }

    final snapshot = await load();
    final thread = snapshot.threadById(normalizedThreadId);
    if (thread == null || !thread.approvedOperationalChannel) {
      throw StateError('This is not an approved Driver operational communication channel.');
    }
    _rejectParentChannel(thread);

    final now = DateTime.now();
    final message = DriverMessageItem(
      id: 'LOCAL-${membership.id}-${now.toUtc().microsecondsSinceEpoch}',
      direction: DriverMessageDirection.driverToSchool,
      authorLabel: 'You',
      body: normalizedBody,
      timeLabel: _clockLabel(now),
      state: DriverMessageState.queued,
      createdAt: now,
    );
    final updatedThread = thread.copyWith(
      preview: normalizedBody,
      timeLabel: 'Queued',
      unread: false,
      messages: [...thread.messages, message],
    );
    final updatedSnapshot = snapshot.replaceThread(updatedThread);
    await _saveSnapshot(membership, updatedSnapshot);

    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: messageEntityType,
      entityId: message.id,
      operation: SyncOperation.create,
      payload: {
        'messageId': message.id,
        'threadId': thread.id,
        'routeId': snapshot.routeId,
        'vehicle': snapshot.vehicle,
        'participantName': thread.participantName,
        'participantRole': thread.participantRole,
        'channelLabel': thread.channelLabel,
        'body': normalizedBody,
        'deliveryState': DriverMessageState.queued.name,
        'createdAt': now.toUtc().toIso8601String(),
      },
    );
    return message;
  }

  Future<void> markThreadSeen(String threadId) async {
    final membership = _requireDriver();
    final snapshot = await load();
    final thread = snapshot.threadById(threadId.trim());
    if (thread == null || !thread.approvedOperationalChannel) {
      throw StateError('This Driver conversation is unavailable.');
    }
    if (!thread.unread) return;

    final updated = snapshot.replaceThread(thread.copyWith(unread: false));
    await _saveSnapshot(membership, updated);
    final now = DateTime.now().toUtc();
    final receiptId = '${membership.id}:thread-seen:${thread.id}:${now.microsecondsSinceEpoch}';
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: receiptEntityType,
      entityId: receiptId,
      operation: SyncOperation.create,
      payload: {
        'id': receiptId,
        'threadId': thread.id,
        'routeId': snapshot.routeId,
        'seenAt': now.toIso8601String(),
        'clientState': 'queued',
      },
    );
  }

  Future<void> markAlertRead(String alertId) async {
    final membership = _requireDriver();
    final snapshot = await load();
    DriverOperationalAlert? target;
    for (final alert in snapshot.alerts) {
      if (alert.id == alertId.trim()) {
        target = alert;
        break;
      }
    }
    if (target == null) throw StateError('This Driver alert is unavailable.');
    if (target.read) return;

    final updated = snapshot.replaceAlert(target.copyWith(read: true));
    await _saveSnapshot(membership, updated);
    final now = DateTime.now().toUtc();
    final receiptId = '${membership.id}:alert-read:${target.id}:${now.microsecondsSinceEpoch}';
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: alertReceiptEntityType,
      entityId: receiptId,
      operation: SyncOperation.create,
      payload: {
        'id': receiptId,
        'alertId': target.id,
        'routeId': snapshot.routeId,
        'readAt': now.toIso8601String(),
        'clientState': 'queued',
      },
    );
  }

  Future<void> replaceFromServer({
    required DriverMessagesSnapshot snapshot,
    required int serverVersion,
  }) async {
    final membership = _requireDriver();
    final dashboard = await _dashboardRepository.load();
    _validateSnapshot(snapshot, dashboard.assignment.routeId, dashboard.route.vehicle);
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: snapshotEntityType,
      entityId: membership.id,
      payload: snapshot.toJson(),
      serverVersion: serverVersion,
      isDirty: false,
    );
  }

  Future<void> _saveSnapshot(
    SchoolMembership membership,
    DriverMessagesSnapshot snapshot,
  ) async {
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: snapshotEntityType,
      entityId: membership.id,
      payload: snapshot.toJson(),
      isDirty: false,
    );
  }

  void _validateSnapshot(
    DriverMessagesSnapshot snapshot,
    String routeId,
    String vehicle,
  ) {
    if (snapshot.routeId != routeId || snapshot.vehicle != vehicle) {
      throw StateError('Driver messages are not scoped to the active route and vehicle.');
    }
    final threadIds = <String>{};
    final messageIds = <String>{};
    for (final thread in snapshot.threads) {
      if (thread.id.trim().isEmpty || !threadIds.add(thread.id)) {
        throw StateError('Driver messages contain an invalid conversation id.');
      }
      if (!thread.approvedOperationalChannel) {
        throw StateError('Driver messages contain an unapproved communication channel.');
      }
      _rejectParentChannel(thread);
      if (thread.participantName.trim().isEmpty ||
          thread.participantRole.trim().isEmpty ||
          thread.channelLabel.trim().isEmpty) {
        throw StateError('A Driver communication channel is missing operational scope.');
      }
      for (final message in thread.messages) {
        if (message.id.trim().isEmpty || !messageIds.add(message.id)) {
          throw StateError('Driver messages contain an invalid message id.');
        }
        if (message.body.trim().isEmpty) {
          throw StateError('Driver messages contain an empty message.');
        }
        if (message.direction == DriverMessageDirection.driverToSchool &&
            message.state == DriverMessageState.received) {
          throw StateError('A Driver-originated message cannot use the received state.');
        }
      }
    }
    final alertIds = <String>{};
    for (final alert in snapshot.alerts) {
      if (alert.id.trim().isEmpty || !alertIds.add(alert.id)) {
        throw StateError('Driver alerts contain an invalid alert id.');
      }
      if (alert.title.trim().isEmpty || alert.body.trim().isEmpty) {
        throw StateError('Driver alerts contain incomplete operational information.');
      }
    }
  }

  void _rejectParentChannel(DriverMessageThread thread) {
    final scope = '${thread.participantName} ${thread.participantRole} ${thread.channelLabel}'.toLowerCase();
    if (scope.contains('parent') || scope.contains('guardian') || scope.contains('family')) {
      throw StateError('Drivers cannot directly message parents or guardians from this workspace.');
    }
  }

  SchoolMembership _requireDriver() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.driver) {
      throw StateError('Driver messages require an active Driver membership.');
    }
    return membership;
  }

  String _clockLabel(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
