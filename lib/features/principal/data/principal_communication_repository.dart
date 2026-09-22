import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/principal_communication_models.dart';

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
  int get dueTodayCount =>
      followUps.where((item) => item.status == 'Due today').length;
  int get queuedCount => outgoing
      .where((item) => item.deliveryState == PrincipalDeliveryState.queued)
      .length;
}

class PrincipalCommunicationActionResult {
  const PrincipalCommunicationActionResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

class PrincipalCommunicationRepository {
  PrincipalCommunicationRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  }) : _localDatabase = localDatabase,
       _schoolSession = schoolSession;

  static const _outgoingType = 'principal_outgoing_communication';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  PrincipalCommunicationPermissions permissionsFor(
    SchoolMembership membership,
  ) => PrincipalCommunicationPermissions(
    canViewSecondaryCommunication: membership.role == SchoolRole.principal,
    canQueueMessages: membership.role == SchoolRole.principal,
    canMessagePrimaryOrEarlyYears: false,
    canCrossSchoolMessage: false,
  );

  Future<PrincipalCommunicationSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canViewSecondaryCommunication) {
      return PrincipalCommunicationSnapshot(
        threads: const [],
        announcements: const [],
        followUps: const [],
        outgoing: const [],
        permissions: permissionsFor(membership),
      );
    }
    final outgoingRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _outgoingType,
    );

    final outgoing =
        outgoingRecords
            .where(
              (record) =>
                  record.payload['createdByMembershipId'] == membership.id &&
                  record.payload['sectionScope'] == 'Secondary',
            )
            .map(
              (record) =>
                  PrincipalOutgoingCommunication.fromJson(record.payload),
            )
            .toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return PrincipalCommunicationSnapshot(
      threads: const [],
      announcements: [
        for (final item in outgoing.where(
          (item) => item.kind == PrincipalOutgoingKind.announcement,
        ))
          PrincipalRecentAnnouncement(
            id: item.id,
            title: item.subject ?? '',
            audience: 'Secondary: ${item.audience?.label ?? "Not recorded"}',
            channel: item.channel.label,
            sent: item.deliveryState == PrincipalDeliveryState.queued
                ? 'Queued ${item.createdAt}'
                : item.deliveryState.name,
            delivered: item.deliveryState == PrincipalDeliveryState.delivered
                ? 'Confirmed'
                : 'Not confirmed',
            read: 'Not recorded',
          ),
      ],
      followUps: const [],
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
      return const PrincipalCommunicationActionResult(
        success: false,
        message: 'Write a reply first.',
      );
    }
    return const PrincipalCommunicationActionResult(
      success: false,
      message: 'No verified conversation is connected for this Principal.',
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
    if (audience != PrincipalCommunicationAudience.staff &&
        audience != PrincipalCommunicationAudience.guardians) {
      return const PrincipalCommunicationActionResult(
        success: false,
        message:
            'Choose Secondary staff or guardians. Individual, class and whole-school routing are not connected.',
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
    return PrincipalCommunicationActionResult(
      success: true,
      message: deliveryNote,
    );
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
}
