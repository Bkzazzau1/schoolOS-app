import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/principal_communication_models.dart';
import 'principal_communication_demo_data.dart';

class PrincipalCommunicationSnapshot {
  const PrincipalCommunicationSnapshot({
    required this.threads,
    required this.announcements,
    required this.followUps,
    required this.outgoing,
    required this.permissions,
  });

  final List<PrincipalCommunicationThread> threads;
  final List<PrincipalRecentAnnouncement> announcements;
  final List<PrincipalCommunicationFollowUp> followUps;
  final List<PrincipalOutgoingCommunication> outgoing;
  final PrincipalCommunicationPermissions permissions;

  int get unreadCount => threads.where((thread) => thread.unread).length;
  int get dueTodayCount => followUps.where((item) => item.status == 'Due today').length;
  int get queuedCount => outgoing.where((item) => item.deliveryState == PrincipalDeliveryState.queued).length;
}

class PrincipalCommunicationActionResult {
  const PrincipalCommunicationActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class PrincipalCommunicationRepository {
  PrincipalCommunicationRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _threadType = 'principal_communication_thread';
  static const _announcementType = 'principal_recent_announcement';
  static const _followUpType = 'principal_communication_followup';
  static const _outgoingType = 'principal_outgoing_communication';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  PrincipalCommunicationPermissions permissionsFor(SchoolMembership membership) => PrincipalCommunicationPermissions(
        canViewSecondaryCommunication: membership.role == SchoolRole.principal,
        canQueueMessages: membership.role == SchoolRole.principal,
        canMessagePrimaryOrEarlyYears: false,
        canCrossSchoolMessage: false,
      );

  Future<PrincipalCommunicationSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    await _seedIfNeeded(membership);

    final threadRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _threadType,
    );
    final announcementRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _announcementType,
    );
    final followUpRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _followUpType,
    );
    final outgoingRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _outgoingType,
    );

    final threads = threadRecords
        .map((record) => PrincipalCommunicationThread.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    final announcements = announcementRecords
        .map((record) => PrincipalRecentAnnouncement.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => b.id.compareTo(a.id));
    final followUps = followUpRecords
        .map((record) => PrincipalCommunicationFollowUp.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    final outgoing = outgoingRecords
        .map((record) => PrincipalOutgoingCommunication.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return PrincipalCommunicationSnapshot(
      threads: threads,
      announcements: announcements,
      followUps: followUps,
      outgoing: outgoing,
      permissions: permissionsFor(membership),
    );
  }

  Future<PrincipalCommunicationActionResult> queueReply({
    required String threadId,
    required String message,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canQueueMessages) {
      return const PrincipalCommunicationActionResult(
        success: false,
        message: 'This membership cannot send Secondary communication.',
      );
    }
    final text = message.trim();
    if (text.isEmpty) {
      return const PrincipalCommunicationActionResult(success: false, message: 'Write a reply first.');
    }
    final thread = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _threadType,
      entityId: threadId,
    );
    if (thread == null) {
      return const PrincipalCommunicationActionResult(success: false, message: 'Conversation not found in this school.');
    }

    final createdAt = DateTime.now().toUtc().toIso8601String();
    final outgoing = PrincipalOutgoingCommunication(
      id: 'reply-${DateTime.now().microsecondsSinceEpoch}',
      kind: PrincipalOutgoingKind.reply,
      message: text,
      channel: PrincipalCommunicationChannel.portal,
      deliveryState: PrincipalDeliveryState.queued,
      sectionScope: 'Secondary',
      createdByMembershipId: membership.id,
      createdAt: createdAt,
      threadId: threadId,
    );
    await _persistOutgoing(membership, outgoing);
    return const PrincipalCommunicationActionResult(
      success: true,
      message: 'Reply queued offline. Delivery will be confirmed only after synchronization.',
    );
  }

  Future<PrincipalCommunicationActionResult> queueAnnouncement({
    required PrincipalCommunicationAudience audience,
    required PrincipalCommunicationChannel channel,
    required String subject,
    required String message,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canQueueMessages) {
      return const PrincipalCommunicationActionResult(
        success: false,
        message: 'This membership cannot send Secondary communication.',
      );
    }
    final cleanSubject = subject.trim();
    final cleanMessage = message.trim();
    if (cleanSubject.isEmpty || cleanMessage.isEmpty) {
      return const PrincipalCommunicationActionResult(
        success: false,
        message: 'Add both a subject and message first.',
      );
    }

    final createdAt = DateTime.now().toUtc().toIso8601String();
    final outgoing = PrincipalOutgoingCommunication(
      id: 'announcement-${DateTime.now().microsecondsSinceEpoch}',
      kind: PrincipalOutgoingKind.announcement,
      message: cleanMessage,
      channel: channel,
      deliveryState: PrincipalDeliveryState.queued,
      sectionScope: 'Secondary',
      createdByMembershipId: membership.id,
      createdAt: createdAt,
      audience: audience,
      subject: cleanSubject,
    );
    await _persistOutgoing(membership, outgoing);

    final deliveryNote = channel == PrincipalCommunicationChannel.portal
        ? 'Portal announcement queued offline for synchronization.'
        : '${channel.label} announcement queued offline; external delivery is not yet confirmed.';
    return PrincipalCommunicationActionResult(success: true, message: deliveryNote);
  }

  Future<void> _persistOutgoing(
    SchoolMembership membership,
    PrincipalOutgoingCommunication outgoing,
  ) async {
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _outgoingType,
      entityId: outgoing.id,
      payload: outgoing.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _outgoingType,
      entityId: outgoing.id,
      operation: SyncOperation.create,
      payload: outgoing.toJson(),
    );
  }

  Future<void> _seedIfNeeded(SchoolMembership membership) async {
    if ((await _localDatabase.getLocalRecords(
          tenantId: membership.schoolId,
          entityType: _threadType,
        ))
        .isEmpty) {
      for (final item in principalCommunicationThreads) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _threadType,
          entityId: item.id,
          payload: item.toJson(),
        );
      }
    }
    if ((await _localDatabase.getLocalRecords(
          tenantId: membership.schoolId,
          entityType: _announcementType,
        ))
        .isEmpty) {
      for (final item in principalRecentAnnouncements) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _announcementType,
          entityId: item.id,
          payload: item.toJson(),
        );
      }
    }
    if ((await _localDatabase.getLocalRecords(
          tenantId: membership.schoolId,
          entityType: _followUpType,
        ))
        .isEmpty) {
      for (final item in principalCommunicationFollowUps) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _followUpType,
          entityId: item.id,
          payload: item.toJson(),
        );
      }
    }
  }
}
