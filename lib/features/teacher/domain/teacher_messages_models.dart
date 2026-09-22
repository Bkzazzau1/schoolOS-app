enum TeacherMessageChannelType { parentGroup, schoolLeadership, staffChannel }

enum TeacherMessageDirection { outgoing, incoming }

enum TeacherMessageDeliveryState { queued, sent, delivered, read, received }

enum TeacherMessageEventAction { queued }

class TeacherMessageThread {
  const TeacherMessageThread({
    required this.id,
    required this.name,
    required this.type,
    required this.preview,
    required this.timeLabel,
    required this.unread,
    this.className,
  });

  final String id;
  final String name;
  final TeacherMessageChannelType type;
  final String preview;
  final String timeLabel;
  final int unread;

  /// For a [TeacherMessageChannelType.parentGroup] thread, the real class it belongs to. A teacher only ever sees
  /// a guardian group for a class they are really assigned to. Other channel types are not class-scoped.
  final String? className;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '$name ${teacherMessageChannelTypeLabel(type)} $preview'
        .toLowerCase()
        .contains(q);
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'preview': preview,
        'timeLabel': timeLabel,
        'unread': unread,
        'className': className,
      };

  factory TeacherMessageThread.fromJson(Map<String, dynamic> json) =>
      TeacherMessageThread(
        id: json['id'] as String,
        name: json['name'] as String,
        type: TeacherMessageChannelType.values.byName(json['type'] as String),
        preview: json['preview'] as String,
        timeLabel: json['timeLabel'] as String,
        unread: (json['unread'] as num).toInt(),
        className: json['className'] as String?,
      );
}

class TeacherMessage {
  const TeacherMessage({
    required this.id,
    required this.threadId,
    required this.direction,
    required this.body,
    required this.timeLabel,
    required this.deliveryState,
    this.createdAt,
    this.serverMessageId,
    this.attachmentName,
  });

  final String id;
  final String threadId;
  final TeacherMessageDirection direction;
  final String body;
  final String timeLabel;
  final TeacherMessageDeliveryState deliveryState;
  final String? createdAt;
  final String? serverMessageId;
  final String? attachmentName;

  bool get isOutgoing => direction == TeacherMessageDirection.outgoing;

  TeacherMessage copyWith({
    String? body,
    String? timeLabel,
    TeacherMessageDeliveryState? deliveryState,
    String? createdAt,
    String? serverMessageId,
    String? attachmentName,
  }) =>
      TeacherMessage(
        id: id,
        threadId: threadId,
        direction: direction,
        body: body ?? this.body,
        timeLabel: timeLabel ?? this.timeLabel,
        deliveryState: deliveryState ?? this.deliveryState,
        createdAt: createdAt ?? this.createdAt,
        serverMessageId: serverMessageId ?? this.serverMessageId,
        attachmentName: attachmentName ?? this.attachmentName,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'threadId': threadId,
        'direction': direction.name,
        'body': body,
        'timeLabel': timeLabel,
        'deliveryState': deliveryState.name,
        'createdAt': createdAt,
        'serverMessageId': serverMessageId,
        'attachmentName': attachmentName,
      };

  factory TeacherMessage.fromJson(Map<String, dynamic> json) => TeacherMessage(
        id: json['id'] as String,
        threadId: json['threadId'] as String,
        direction: TeacherMessageDirection.values.byName(json['direction'] as String),
        body: json['body'] as String,
        timeLabel: json['timeLabel'] as String,
        deliveryState:
            TeacherMessageDeliveryState.values.byName(json['deliveryState'] as String),
        createdAt: json['createdAt'] as String?,
        serverMessageId: json['serverMessageId'] as String?,
        attachmentName: json['attachmentName'] as String?,
      );
}

class TeacherMessageEvent {
  const TeacherMessageEvent({
    required this.id,
    required this.messageId,
    required this.threadId,
    required this.action,
    required this.actorMembershipId,
    required this.occurredAt,
  });

  final String id;
  final String messageId;
  final String threadId;
  final TeacherMessageEventAction action;
  final String actorMembershipId;
  final String occurredAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'messageId': messageId,
        'threadId': threadId,
        'action': action.name,
        'actorMembershipId': actorMembershipId,
        'occurredAt': occurredAt,
      };
}

class TeacherMessagePermissions {
  const TeacherMessagePermissions({
    required this.canViewApprovedChannels,
    required this.canQueueMessages,
    required this.canViewPrivateContactDetails,
    required this.canConfirmSent,
    required this.canConfirmDelivered,
    required this.canConfirmRead,
    required this.canUseAiDraft,
  });

  final bool canViewApprovedChannels;
  final bool canQueueMessages;
  final bool canViewPrivateContactDetails;
  final bool canConfirmSent;
  final bool canConfirmDelivered;
  final bool canConfirmRead;
  final bool canUseAiDraft;
}

String teacherMessageChannelTypeLabel(TeacherMessageChannelType type) =>
    switch (type) {
      TeacherMessageChannelType.parentGroup => 'Parent group',
      TeacherMessageChannelType.schoolLeadership => 'School leadership',
      TeacherMessageChannelType.staffChannel => 'Staff channel',
    };

String teacherMessageDeliveryLabel(TeacherMessageDeliveryState state) =>
    switch (state) {
      TeacherMessageDeliveryState.queued => 'Queued',
      TeacherMessageDeliveryState.sent => 'Sent',
      TeacherMessageDeliveryState.delivered => 'Delivered',
      TeacherMessageDeliveryState.read => 'Read',
      TeacherMessageDeliveryState.received => 'Received',
    };
