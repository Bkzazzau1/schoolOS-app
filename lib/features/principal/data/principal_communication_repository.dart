import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_attendance_desk.dart' show sectionOfClass;
import '../../administrator/data/administrator_staff_repository.dart';
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_staff_models.dart';
import '../../administrator/domain/administrator_students_models.dart';
import '../../parent/data/parent_message_receipts.dart' show parentMessageReceiptEntityType;
import '../../proprietor/data/owner_staff_profile_repository.dart';
import '../../proprietor/domain/owner_staff_profile_models.dart';
import '../../teacher/data/teacher_channel_receipts.dart';
import '../../teacher/domain/teacher_messages_models.dart';
import '../domain/principal_communication_models.dart';

class PrincipalCommunicationSnapshot {
  const PrincipalCommunicationSnapshot({
    required this.threads,
    required this.families,
    required this.announcements,
    required this.followUps,
    required this.outgoing,
    required this.permissions,
  });

  final List<PrincipalCommunicationThread> threads;

  /// Every real, currently active Secondary student on the register - who the Principal can look
  /// up and message individually from this same screen (`familyThread`/`queueFamilyReply`), not a
  /// bulk inbox of every family's conversation: the Principal picks one real family on purpose,
  /// the same way the leadership inbox is a list of threads that were really sent to, not a
  /// roster the Principal is assumed to be watching by default.
  final List<AdministratorStudentRecord> families;
  final List<PrincipalRecentAnnouncement> announcements;
  final List<PrincipalCommunicationFollowUp> followUps;
  final List<PrincipalOutgoingCommunication> outgoing;
  final PrincipalCommunicationPermissions permissions;

  int get unreadCount => threads.where((thread) => thread.unread).length;

  /// Every real follow-up this Principal currently has - there is no real due-date tracking
  /// behind a reply, so "due today" means "currently awaiting a reply" rather than a finer,
  /// unbuilt urgency split.
  int get dueTodayCount => followUps.length;
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
        families: const [],
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
    final families = await secondaryFamilies();

    return PrincipalCommunicationSnapshot(
      threads: threads,
      families: families,
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
      followUps: [
        for (final thread in threads.where((item) => item.unread))
          PrincipalCommunicationFollowUp(
            id: thread.id,
            title: 'Reply to ${thread.title}',
            context: thread.context,
            action: 'Reply',
            status: 'Awaiting your reply',
            targetKey: thread.id,
          ),
      ],
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

    await _sendLeadershipMessage(membership, threadId: threadId, body: text);
    return const PrincipalCommunicationActionResult(
      success: true,
      message: 'Reply queued locally. Sent, delivered and read status require authoritative acknowledgement.',
    );
  }

  /// Writes one real message into a real `teacher_leadership_message` thread - the exact wire
  /// shape `queueReply` always sent, pulled out so a staff-wide announcement can send the same
  /// real write once per real Secondary teacher's own thread instead of duplicating it.
  Future<void> _sendLeadershipMessage(
    SchoolMembership membership, {
    required String threadId,
    required String body,
  }) async {
    final now = DateTime.now().toUtc();
    final id = 'LOCAL-${membership.id}-${now.microsecondsSinceEpoch}-$threadId';

    // The wire payload carries only what the Principal actually contributes; who really sent it
    // and when are the server's own stamp (see teacher_channels.py's own clean()), never taken
    // on trust from the app.
    final wirePayload = <String, Object?>{'id': id, 'threadId': threadId, 'body': body};
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

  /// Every real, currently active Secondary student on the register - the lookup list behind
  /// "message a family", the same real source `_broadcastToSecondaryGuardians` already reads.
  Future<List<AdministratorStudentRecord>> secondaryFamilies() async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canViewSecondaryCommunication) return const [];
    final register = (await _students.load()).students;
    final secondary = register
        .where(
          (student) =>
              student.status == AdministratorStudentStatus.active &&
              sectionOfClass(student.className) == 'Secondary',
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return secondary;
  }

  /// One specific real guardian's own real `parent_message` thread, read through the exact same
  /// `MANAGERS` oversight access `_broadcastToSecondaryGuardians` already relies on to write into
  /// it - a targeted lookup of a real family this Principal picked, never a bulk inbox of every
  /// family's conversation.
  Future<PrincipalCommunicationThread?> familyThread(String studentId) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canViewSecondaryCommunication) return null;
    final families = await secondaryFamilies();
    final student = families.where((item) => item.id == studentId).firstOrNull;
    if (student == null) return null;

    final threadId = 'channel-$studentId';
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _messageType,
    );
    final messages = [
      for (final record in records)
        if (record.payload['threadId'] == threadId)
          TeacherMessage.fromCanonical(
            payload: Map<String, Object?>.from(record.payload),
            viewerMembershipId: membership.id,
            isDirty: record.isDirty,
          ),
    ]..sort((a, b) => (DateTime.tryParse(a.createdAt ?? '') ?? DateTime(0))
        .compareTo(DateTime.tryParse(b.createdAt ?? '') ?? DateTime(0)));

    final receipts = await loadOwnChannelReceipts(
      _localDatabase,
      tenantId: membership.schoolId,
      membershipId: membership.id,
      receiptEntityType: parentMessageReceiptEntityType,
    );
    final guardianLabel = student.primaryGuardian.trim().isEmpty ? 'Guardian' : student.primaryGuardian;

    return PrincipalCommunicationThread(
      id: threadId,
      title: guardianLabel,
      person: guardianLabel,
      context: 'Guardian · ${student.className} · ${student.name}',
      time: messages.isEmpty ? '' : messages.last.timeLabel,
      unread: isChannelThreadUnread(messages, receipts[threadId]),
      priority: PrincipalCommunicationPriority.normal,
      preview: messages.isEmpty ? 'No messages yet' : messages.last.body,
      messages: messages,
    );
  }

  /// Records this Principal's own real receipt for one real guardian's thread.
  Future<void> markFamilyThreadSeen(String studentId) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canViewSecondaryCommunication) return;
    final thread = await familyThread(studentId);
    if (thread == null || !thread.unread) return;
    await queueChannelSeenReceipt(
      _localDatabase,
      tenantId: membership.schoolId,
      membershipId: membership.id,
      threadId: thread.id,
      receiptEntityType: parentMessageReceiptEntityType,
    );
  }

  /// Sends into one specific real guardian's own thread - the targeted counterpart to
  /// `_broadcastToSecondaryGuardians`'s "every family" send, through the exact same real,
  /// server-authorized channel.
  Future<PrincipalCommunicationActionResult> queueFamilyReply({
    required String studentId,
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
    final families = await secondaryFamilies();
    if (!families.any((item) => item.id == studentId)) {
      return const PrincipalCommunicationActionResult(
        success: false,
        message: 'Choose a real, currently active Secondary student on the register.',
      );
    }

    await _sendParentMessage(membership, studentId: studentId, body: text);
    return const PrincipalCommunicationActionResult(
      success: true,
      message: 'Reply queued locally. Sent, delivered and read status require authoritative acknowledgement.',
    );
  }

  /// Every real, currently active Secondary teacher's own linked membership id - the same real
  /// directory/profile cross-reference `_teacherNamesByMembershipId` already uses, filtered to who
  /// a "Secondary staff" announcement can actually reach.
  Future<List<String>> _secondaryTeacherMembershipIds(SchoolMembership membership) async {
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
    final ids = <String>[];
    for (final record in profileRecords) {
      final profile = StaffProfile.fromJson(record.payload);
      if (profile.systemRole != 'teacher') continue;
      final teacherMembershipId = profile.linkedMembershipId.trim();
      if (teacherMembershipId.isEmpty) continue;
      final person = peopleByStaffId[profile.staffId];
      if (person == null || person.section != 'Secondary') continue;
      ids.add(teacherMembershipId);
    }
    return ids;
  }

  /// A real announcement to every real Secondary teacher's own school-leadership thread - the
  /// staff-audience counterpart to `_broadcastToSecondaryGuardians`, through the exact same real
  /// `teacher_leadership_message` channel `queueReply` already writes into.
  Future<int> _broadcastToSecondaryStaff(SchoolMembership membership, String body) async {
    final teacherIds = await _secondaryTeacherMembershipIds(membership);
    var count = 0;
    for (final teacherId in teacherIds) {
      await _sendLeadershipMessage(membership, threadId: '$_leadershipThreadPrefix$teacherId', body: body);
      count += 1;
    }
    return count;
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
    } else if (audience == PrincipalCommunicationAudience.staff &&
        channel == PrincipalCommunicationChannel.portal) {
      final reached = await _broadcastToSecondaryStaff(membership, cleanMessage);
      if (reached == 0) {
        return const PrincipalCommunicationActionResult(
          success: false,
          message: 'No Secondary teachers are linked to an active account yet.',
        );
      }
      deliveryNote =
          'Queued for $reached real Secondary teacher${reached == 1 ? '' : 's'}, one real message per teacher\'s '
          'own leadership thread. Sent, delivered and read status require authoritative acknowledgement.';
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
