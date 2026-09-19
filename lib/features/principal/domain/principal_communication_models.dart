enum PrincipalCommunicationPriority { normal, important, urgent }

extension PrincipalCommunicationPriorityLabel on PrincipalCommunicationPriority {
  String get label => switch (this) {
        PrincipalCommunicationPriority.normal => 'Normal',
        PrincipalCommunicationPriority.important => 'Important',
        PrincipalCommunicationPriority.urgent => 'Urgent',
      };
}

enum PrincipalCommunicationAudience { staff, guardians, classGuardians, individual, wholeSchool }

extension PrincipalCommunicationAudienceLabel on PrincipalCommunicationAudience {
  String get label => switch (this) {
        PrincipalCommunicationAudience.staff => 'Staff',
        PrincipalCommunicationAudience.guardians => 'Guardians',
        PrincipalCommunicationAudience.classGuardians => 'Class Guardians',
        PrincipalCommunicationAudience.individual => 'Individual',
        PrincipalCommunicationAudience.wholeSchool => 'Whole School',
      };

  static PrincipalCommunicationAudience fromLabel(String value) =>
      PrincipalCommunicationAudience.values.firstWhere((item) => item.label == value);
}

enum PrincipalCommunicationChannel { portal, sms, email, whatsApp }

extension PrincipalCommunicationChannelLabel on PrincipalCommunicationChannel {
  String get label => switch (this) {
        PrincipalCommunicationChannel.portal => 'Portal',
        PrincipalCommunicationChannel.sms => 'SMS',
        PrincipalCommunicationChannel.email => 'Email',
        PrincipalCommunicationChannel.whatsApp => 'WhatsApp',
      };

  static PrincipalCommunicationChannel fromLabel(String value) =>
      PrincipalCommunicationChannel.values.firstWhere((item) => item.label == value);
}

enum PrincipalOutgoingKind { reply, announcement }

enum PrincipalDeliveryState { queued, delivered, failed }

class PrincipalCommunicationThread {
  const PrincipalCommunicationThread({
    required this.id,
    required this.title,
    required this.person,
    required this.context,
    required this.time,
    required this.unread,
    required this.priority,
    required this.preview,
  });

  final String id;
  final String title;
  final String person;
  final String context;
  final String time;
  final bool unread;
  final PrincipalCommunicationPriority priority;
  final String preview;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'person': person,
        'context': context,
        'time': time,
        'unread': unread,
        'priority': priority.name,
        'preview': preview,
      };

  factory PrincipalCommunicationThread.fromJson(Map<String, Object?> json) => PrincipalCommunicationThread(
        id: json['id']! as String,
        title: json['title']! as String,
        person: json['person']! as String,
        context: json['context']! as String,
        time: json['time']! as String,
        unread: json['unread']! as bool,
        priority: PrincipalCommunicationPriority.values.byName(json['priority']! as String),
        preview: json['preview']! as String,
      );
}

class PrincipalRecentAnnouncement {
  const PrincipalRecentAnnouncement({
    required this.id,
    required this.title,
    required this.audience,
    required this.channel,
    required this.sent,
    required this.delivered,
    required this.read,
  });

  final String id;
  final String title;
  final String audience;
  final String channel;
  final String sent;
  final String delivered;
  final String read;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'audience': audience,
        'channel': channel,
        'sent': sent,
        'delivered': delivered,
        'read': read,
      };

  factory PrincipalRecentAnnouncement.fromJson(Map<String, Object?> json) => PrincipalRecentAnnouncement(
        id: json['id']! as String,
        title: json['title']! as String,
        audience: json['audience']! as String,
        channel: json['channel']! as String,
        sent: json['sent']! as String,
        delivered: json['delivered']! as String,
        read: json['read']! as String,
      );
}

class PrincipalCommunicationFollowUp {
  const PrincipalCommunicationFollowUp({
    required this.id,
    required this.title,
    required this.context,
    required this.action,
    required this.status,
    required this.targetKey,
  });

  final String id;
  final String title;
  final String context;
  final String action;
  final String status;
  final String targetKey;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'context': context,
        'action': action,
        'status': status,
        'targetKey': targetKey,
      };

  factory PrincipalCommunicationFollowUp.fromJson(Map<String, Object?> json) => PrincipalCommunicationFollowUp(
        id: json['id']! as String,
        title: json['title']! as String,
        context: json['context']! as String,
        action: json['action']! as String,
        status: json['status']! as String,
        targetKey: json['targetKey']! as String,
      );
}

class PrincipalOutgoingCommunication {
  const PrincipalOutgoingCommunication({
    required this.id,
    required this.kind,
    required this.message,
    required this.channel,
    required this.deliveryState,
    required this.sectionScope,
    required this.createdByMembershipId,
    required this.createdAt,
    this.threadId,
    this.audience,
    this.subject,
  });

  final String id;
  final PrincipalOutgoingKind kind;
  final String message;
  final PrincipalCommunicationChannel channel;
  final PrincipalDeliveryState deliveryState;
  final String sectionScope;
  final String createdByMembershipId;
  final String createdAt;
  final String? threadId;
  final PrincipalCommunicationAudience? audience;
  final String? subject;

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'message': message,
        'channel': channel.name,
        'deliveryState': deliveryState.name,
        'sectionScope': sectionScope,
        'createdByMembershipId': createdByMembershipId,
        'createdAt': createdAt,
        'threadId': threadId,
        'audience': audience?.name,
        'subject': subject,
      };

  factory PrincipalOutgoingCommunication.fromJson(Map<String, Object?> json) => PrincipalOutgoingCommunication(
        id: json['id']! as String,
        kind: PrincipalOutgoingKind.values.byName(json['kind']! as String),
        message: json['message']! as String,
        channel: PrincipalCommunicationChannel.values.byName(json['channel']! as String),
        deliveryState: PrincipalDeliveryState.values.byName(json['deliveryState']! as String),
        sectionScope: json['sectionScope']! as String,
        createdByMembershipId: json['createdByMembershipId']! as String,
        createdAt: json['createdAt']! as String,
        threadId: json['threadId'] as String?,
        audience: json['audience'] == null
            ? null
            : PrincipalCommunicationAudience.values.byName(json['audience']! as String),
        subject: json['subject'] as String?,
      );
}

class PrincipalCommunicationPermissions {
  const PrincipalCommunicationPermissions({
    required this.canViewSecondaryCommunication,
    required this.canQueueMessages,
    required this.canMessagePrimaryOrEarlyYears,
    required this.canCrossSchoolMessage,
  });

  final bool canViewSecondaryCommunication;
  final bool canQueueMessages;
  final bool canMessagePrimaryOrEarlyYears;
  final bool canCrossSchoolMessage;
}
