import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_attendance_desk.dart' show sectionOfClass;
import '../../administrator/data/administrator_staff_repository.dart';
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_staff_models.dart';
import '../../administrator/domain/administrator_students_models.dart';
import '../../proprietor/data/owner_staff_profile_repository.dart';
import '../../proprietor/domain/owner_staff_profile_models.dart';
import '../../teacher/data/teacher_channel_receipts.dart';
import '../../teacher/domain/teacher_messages_models.dart';
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
       _schoolSession = schoolSession,
       _students = AdministratorStudentsRepository(
         localDatabase: localDatabase,
         schoolSession: schoolSession,
       );

  static const _outgoingType = 'principal_outgoing_communication';
  static const _messageType = 'parent_message';
  static const _leadershipMessageType = 'teacher_leadership_message';
  static const _leadershipReceiptType = 'teacher_leadership_receipt';
  static const _leadershipThreadPrefix = 'leadership-thread-';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final AdministratorStudentsRepository _students;

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

    final threads = await _leadershipThreads(membership);

    return PrincipalCommunicationSnapshot(
      threads: threads,
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

  /// Every real teacher who has a real thread to school leadership
  /// (`apps/schoollife/messaging/teacher_channels.py: TeacherLeadershipMessageHandler`) - a real
  /// Principal inbox, not the fabricated conversation this screen used to render regardless of
  /// what `threads` actually held. Shows a conversation that really exists, the same "an inbox is
  /// what was really sent to it" shape every other real messaging screen in this app already uses
  /// - not a proactive roster of every teacher, the way Transport Control's own panel is (every
  /// teacher is a potential sender here, not a fleet this office actively manages).
  Future<List<PrincipalCommunicationThread>> _leadershipThreads(SchoolMembership membership) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _leadershipMessageType,
    );
    final byThread = <String, List<TeacherMessage>>{};
    for (final record in records) {
      final threadId = record.payload['threadId'] as String?;
      if (threadId == null || !threadId.startsWith(_leadershipThreadPrefix)) continue;
      byThread.putIfAbsent(threadId, () => []).add(
            TeacherMessage.fromCanonical(
              payload: Map<String, Object?>.from(record.payload),
              viewerMembershipId: membership.id,
              isDirty: record.isDirty,
            ),
          );
    }
    if (byThread.isEmpty) return const [];

    final names = await _teacherNamesByMembershipId(membership);
    final receipts = await loadOwnChannelReceipts(
      _localDatabase,
      tenantId: membership.schoolId,
      membershipId: membership.id,
      receiptEntityType: _leadershipReceiptType,
    );

    final threads = <PrincipalCommunicationThread>[];
    for (final entry in byThread.entries) {
      final teacherMembershipId = entry.key.substring(_leadershipThreadPrefix.length);
      final messages = [...entry.value]
        ..sort((a, b) => (DateTime.tryParse(a.createdAt ?? '') ?? DateTime(0))
            .compareTo(DateTime.tryParse(b.createdAt ?? '') ?? DateTime(0)));
      final last = messages.last;
      final name = names[teacherMembershipId] ?? 'Teacher';
      threads.add(PrincipalCommunicationThread(
        id: entry.key,
        title: name,
        person: name,
        context: 'School leadership',
        time: last.timeLabel,
        unread: isChannelThreadUnread(messages, receipts[entry.key]),
        priority: PrincipalCommunicationPriority.normal,
        preview: last.body,
        messages: messages,
      ));
    }
    threads.sort((a, b) {
      if (a.unread != b.unread) return a.unread ? -1 : 1;
      return b.time.compareTo(a.time);
    });
    return threads;
  }

  /// Real teacher names for a real thread's display, the same real staff-directory cross-reference
  /// `TransportRepository.loadDriverAssignments` already uses for a real Driver roster - a linked
  /// `owner_staff_profile` gives the real membership id, `administrator_staff_directory` gives the
  /// real name.
  Future<Map<String, String>> _teacherNamesByMembershipId(SchoolMembership membership) async {
    final directoryRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: AdministratorStaffRepository.directoryEntityType,
    );
    final peopleByStaffId = {
      for (final record in directoryRecords) record.entityId: AdministratorStaffRecord.fromJson(record.payload),
    };
    final profileRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: OwnerStaffProfileRepository.entityType,
    );
    final names = <String, String>{};
    for (final record in profileRecords) {
      final profile = StaffProfile.fromJson(record.payload);
      if (profile.systemRole != 'teacher') continue;
      final teacherMembershipId = profile.linkedMembershipId.trim();
      if (teacherMembershipId.isEmpty) continue;
      final person = peopleByStaffId[profile.staffId];
      names[teacherMembershipId] = person?.name.trim().isNotEmpty == true
          ? person!.name
          : (profile.onboardingEmail.trim().isNotEmpty ? profile.onboardingEmail : 'Teacher');
    }
    return names;
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
    if (text.length > 4000) {
      return const PrincipalCommunicationActionResult(
        success: false,
        message: 'Messages cannot exceed 4000 characters.',
      );
    }
    final realThreads = await _leadershipThreads(membership);
    if (!realThreads.any((thread) => thread.id == threadId)) {
      return const PrincipalCommunicationActionResult(
        success: false,
        message: 'No verified conversation is connected for this Principal.',
      );
    }

    final now = DateTime.now().toUtc();
    final id = 'LOCAL-${membership.id}-${now.microsecondsSinceEpoch}';

    // The wire payload carries only what the Principal actually contributes; who really sent it
    // and when are the server's own stamp (see teacher_channels.py's own clean()), never taken
    // on trust from the app.
    final wirePayload = <String, Object?>{'id': id, 'threadId': threadId, 'body': text};
    final localPayload = <String, Object?>{
      ...wirePayload,
      'authorRole': membership.role.name,
      'authorMembershipId': membership.id,
      'createdAt': now.toIso8601String(),
    };

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _leadershipMessageType,
      entityId: id,
      payload: localPayload,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _leadershipMessageType,
      entityId: id,
      operation: SyncOperation.create,
      payload: wirePayload,
    );

    return const PrincipalCommunicationActionResult(
      success: true,
      message: 'Reply queued locally. Sent, delivered and read status require authoritative acknowledgement.',
    );
  }

  /// Records this Principal's own real receipt for a real teacher's leadership thread.
  Future<void> markThreadSeen(String threadId) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canViewSecondaryCommunication) return;
    if (!threadId.startsWith(_leadershipThreadPrefix)) return;

    final threads = await _leadershipThreads(membership);
    final thread = threads.where((t) => t.id == threadId).firstOrNull;
    if (thread == null || !thread.unread) return;
    await queueChannelSeenReceipt(
      _localDatabase,
      tenantId: membership.schoolId,
      membershipId: membership.id,
      threadId: threadId,
      receiptEntityType: _leadershipReceiptType,
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

    String deliveryNote;
    if (audience == PrincipalCommunicationAudience.guardians &&
        channel == PrincipalCommunicationChannel.portal) {
      final reached = await _broadcastToSecondaryGuardians(membership, cleanMessage);
      if (reached == 0) {
        return const PrincipalCommunicationActionResult(
          success: false,
          message: 'No Secondary students are on the register yet.',
        );
      }
      deliveryNote =
          'Queued for $reached real Secondary famil${reached == 1 ? 'y' : 'ies'}, one real message per family. '
          'Sent, delivered and read status require authoritative acknowledgement.';
    } else if (channel == PrincipalCommunicationChannel.portal) {
      deliveryNote = 'Portal announcement queued offline for synchronization.';
    } else {
      deliveryNote = '${channel.label} announcement queued offline; external delivery is not yet confirmed.';
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

    return PrincipalCommunicationActionResult(
      success: true,
      message: deliveryNote,
    );
  }

  /// A real announcement to every real Secondary family - through the exact same real,
  /// server-authorized `parent_message` channel `ParentMessagesRepository` and
  /// `TeacherFamilyMessagesRepository` already use, one real message per real, currently active
  /// Secondary student. No backend change was needed: a Principal is already a real class's
  /// manager-level participant in that channel (see `apps/schoollife/messaging/parent_messages.py`),
  /// the same way a real class teacher already is - this just reaches every real Secondary family
  /// at once instead of one real family's own thread.
  Future<int> _broadcastToSecondaryGuardians(SchoolMembership membership, String body) async {
    final register = (await _students.load()).students;
    final secondary = register.where(
      (student) =>
          student.status == AdministratorStudentStatus.active &&
          sectionOfClass(student.className) == 'Secondary',
    );
    var count = 0;
    for (final student in secondary) {
      await _sendParentMessage(membership, studentId: student.id, body: body);
      count += 1;
    }
    return count;
  }

  Future<void> _sendParentMessage(
    SchoolMembership membership, {
    required String studentId,
    required String body,
  }) async {
    final now = DateTime.now().toUtc();
    final messageId = 'LOCAL-${membership.id}-${now.microsecondsSinceEpoch}-$studentId';
    final threadId = 'channel-$studentId';

    // The wire payload carries only what the Principal actually contributes; who really sent it
    // and when are the server's own stamp (see ParentMessageHandler.clean), never taken from the
    // app - the same shape every other real sender into this channel already uses.
    final wirePayload = <String, Object?>{
      'id': messageId,
      'threadId': threadId,
      'body': body,
    };
    final localPayload = <String, Object?>{
      ...wirePayload,
      'authorRole': 'principal',
      'authorMembershipId': membership.id,
      'createdAt': now.toIso8601String(),
    };

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _messageType,
      entityId: messageId,
      payload: localPayload,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _messageType,
      entityId: messageId,
      operation: SyncOperation.create,
      payload: wirePayload,
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
