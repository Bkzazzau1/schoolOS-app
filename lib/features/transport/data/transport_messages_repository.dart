import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../driver/domain/driver_messages_models.dart';
import '../domain/transport_messages_models.dart';
import 'transport_repository.dart';

/// Transport Control's own side of the real channel with each real, currently assigned Driver
/// (`apps/transport/driver_messages.py`) - one real thread per real Driver, built from the same
/// real driver roster `TransportDriverAssignmentsPanel` already reads
/// (`TransportRepository.loadDriverAssignments`), not a second, separate roster. Deliberately a
/// new, separate repository from `DriverMessagesRepository` - both read and write the exact same
/// server-side rows, just from the other real participant's point of view.
class TransportMessagesRepository {
  TransportMessagesRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required TransportRepository transport,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _transport = transport;

  static const _messageEntityType = 'driver_message';
  static const _threadPrefix = 'driver-thread-';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TransportRepository _transport;

  Future<TransportMessagesSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = _transport.permissionsFor(membership);
    if (!permissions.canViewOperationsControl) {
      return const TransportMessagesSnapshot(threads: [], canReply: false);
    }

    final assignments = await _transport.loadDriverAssignments();
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _messageEntityType,
    );
    final byThread = <String, List<DriverMessageItem>>{};
    for (final record in records) {
      final threadId = record.payload['threadId'] as String?;
      if (threadId == null) continue;
      byThread.putIfAbsent(threadId, () => []).add(
            DriverMessageItem.fromCanonical(
              payload: Map<String, Object?>.from(record.payload),
              viewerMembershipId: membership.id,
              isDirty: record.isDirty,
            ),
          );
    }

    final threads = <DriverMessageThread>[];
    for (final driver in assignments.drivers.where((d) => d.assigned)) {
      final threadId = '$_threadPrefix${driver.membershipId}';
      final messages = [...(byThread[threadId] ?? const <DriverMessageItem>[])]
        ..sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
      threads.add(DriverMessageThread(
        id: threadId,
        participantName: driver.name,
        participantRole: '${driver.routeName} · ${driver.vehicle}',
        channelLabel: 'Assigned route operations',
        preview: messages.isEmpty ? 'No messages yet' : messages.last.body,
        timeLabel: messages.isEmpty ? '' : messages.last.timeLabel,
        unread: false,
        approvedOperationalChannel: true,
        messages: messages,
      ));
    }

    return TransportMessagesSnapshot(threads: threads, canReply: permissions.canManageDriverAssignments);
  }

  Future<DriverMessageItem> queueReply({
    required String threadId,
    required String body,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    final normalizedThreadId = threadId.trim();
    final normalizedBody = body.trim();
    if (normalizedBody.isEmpty) {
      throw ArgumentError.value(body, 'body', 'Message text is required.');
    }
    if (normalizedBody.length > 2000) {
      throw ArgumentError.value(body, 'body', 'Messages cannot exceed 2000 characters.');
    }

    final snapshot = await load();
    if (!snapshot.canReply) {
      throw StateError('This membership cannot send transport messages.');
    }
    final thread = snapshot.threadById(normalizedThreadId);
    if (thread == null) {
      throw StateError('This Driver conversation is unavailable.');
    }
    final driverMembershipId = normalizedThreadId.substring(_threadPrefix.length);

    final now = DateTime.now().toUtc();
    final messageId = 'LOCAL-${membership.id}-${now.microsecondsSinceEpoch}';

    // The wire payload carries only what Transport Control actually contributes - which real
    // Driver's thread this is for, and the message itself; who really sent it and when are the
    // server's own stamp (see DriverMessageHandler.clean), never taken from the app.
    final wirePayload = <String, Object?>{
      'messageId': messageId,
      'threadId': thread.id,
      'driverMembershipId': driverMembershipId,
      'body': normalizedBody,
    };
    final localPayload = <String, Object?>{
      ...wirePayload,
      'senderMembershipId': membership.id,
      'senderRole': membership.role.name,
      'receivedAt': now.toIso8601String(),
    };

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _messageEntityType,
      entityId: messageId,
      payload: localPayload,
      isDirty: true,
    );

    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _messageEntityType,
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
}
