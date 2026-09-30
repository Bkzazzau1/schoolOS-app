enum ParentMessageDirection {
  schoolToGuardian,
  guardianToSchool;

  static ParentMessageDirection fromJson(String value) =>
      ParentMessageDirection.values.firstWhere(
        (item) => item.name == value,
        orElse: () => ParentMessageDirection.schoolToGuardian,
      );
}

enum ParentMessageState {
  received('Received'),
  queued('Queued'),
  sent('Sent'),
  delivered('Delivered'),
  read('Read');

  const ParentMessageState(this.label);

  final String label;

  static ParentMessageState fromJson(String value) =>
      ParentMessageState.values.firstWhere(
        (item) => item.name == value,
        orElse: () => ParentMessageState.received,
      );
}

class ParentMessageItem {
  const ParentMessageItem({
    required this.id,
    required this.direction,
    required this.authorLabel,
    required this.body,
    required this.timeLabel,
    required this.state,
    this.createdAt,
  });

  final String id;
  final ParentMessageDirection direction;
  final String authorLabel;
  final String body;
  final String timeLabel;
  final ParentMessageState state;
  final DateTime? createdAt;

  bool get isGuardianMessage =>
      direction == ParentMessageDirection.guardianToSchool;

  bool get isQueued => state == ParentMessageState.queued;

  Map<String, Object?> toJson() => {
        'id': id,
        'direction': direction.name,
        'authorLabel': authorLabel,
        'body': body,
        'timeLabel': timeLabel,
        'state': state.name,
        'createdAt': createdAt?.toUtc().toIso8601String(),
      };

  factory ParentMessageItem.fromJson(Map<String, dynamic> json) =>
      ParentMessageItem(
        id: json['id'] as String? ?? '',
        direction: ParentMessageDirection.fromJson(
          json['direction'] as String? ?? '',
        ),
        authorLabel: json['authorLabel'] as String? ?? '',
        body: json['body'] as String? ?? '',
        timeLabel: json['timeLabel'] as String? ?? '',
        state: ParentMessageState.fromJson(json['state'] as String? ?? ''),
        createdAt: _date(json['createdAt']),
      );

  /// Builds the UI view of one real message row from the server's own canonical shape —
  /// `{id, threadId, body, authorRole, authorMembershipId, createdAt}`, the payload
  /// `apps/schoollife/messaging/parent_messages.py` actually stores and publishes. `direction`
  /// reflects who actually wrote the message (a real guardian, or the real school side) regardless
  /// of who is viewing it; `authorLabel` and `state` do depend on the viewer, so the same row reads
  /// as "You" to whoever sent it and by their real role to everyone else, and shows this device's
  /// own not-yet-confirmed copy as queued only for the person who queued it.
  factory ParentMessageItem.fromCanonical({
    required Map<String, Object?> payload,
    required String viewerMembershipId,
    required bool isDirty,
  }) {
    final authorRole = payload['authorRole'] as String? ?? '';
    final authorMembershipId = payload['authorMembershipId'] as String? ?? '';
    final mine = authorMembershipId.isNotEmpty && authorMembershipId == viewerMembershipId;
    final createdAt = _date(payload['createdAt']);
    return ParentMessageItem(
      id: payload['id'] as String? ?? '',
      direction: authorRole == 'parent'
          ? ParentMessageDirection.guardianToSchool
          : ParentMessageDirection.schoolToGuardian,
      authorLabel: mine ? 'You' : _authorLabelFor(authorRole),
      body: payload['body'] as String? ?? '',
      timeLabel: createdAt == null ? '' : _clockLabel(createdAt),
      state: mine
          ? (isDirty ? ParentMessageState.queued : ParentMessageState.sent)
          : ParentMessageState.received,
      createdAt: createdAt,
    );
  }
}

String _authorLabelFor(String authorRole) {
  switch (authorRole) {
    case 'teacher':
      return 'Class teacher';
    case 'parent':
      return 'Guardian';
    case 'principal':
      return 'Principal';
    default:
      return 'School';
  }
}

String _clockLabel(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class ParentMessageThread {
  const ParentMessageThread({
    required this.id,
    required this.participantName,
    required this.participantRole,
    required this.childLabel,
    required this.preview,
    required this.timeLabel,
    required this.unread,
    required this.approvedParticipant,
    required this.messages,
  });

  final String id;
  final String participantName;
  final String participantRole;
  final String childLabel;
  final String preview;
  final String timeLabel;
  final bool unread;
  final bool approvedParticipant;
  final List<ParentMessageItem> messages;

  ParentMessageThread copyWith({
    String? preview,
    String? timeLabel,
    bool? unread,
    List<ParentMessageItem>? messages,
  }) =>
      ParentMessageThread(
        id: id,
        participantName: participantName,
        participantRole: participantRole,
        childLabel: childLabel,
        preview: preview ?? this.preview,
        timeLabel: timeLabel ?? this.timeLabel,
        unread: unread ?? this.unread,
        approvedParticipant: approvedParticipant,
        messages: messages ?? this.messages,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'participantName': participantName,
        'participantRole': participantRole,
        'childLabel': childLabel,
        'preview': preview,
        'timeLabel': timeLabel,
        'unread': unread,
        'approvedParticipant': approvedParticipant,
        'messages': messages.map((item) => item.toJson()).toList(),
      };

  factory ParentMessageThread.fromJson(Map<String, dynamic> json) =>
      ParentMessageThread(
        id: json['id'] as String? ?? '',
        participantName: json['participantName'] as String? ?? '',
        participantRole: json['participantRole'] as String? ?? '',
        childLabel: json['childLabel'] as String? ?? '',
        preview: json['preview'] as String? ?? '',
        timeLabel: json['timeLabel'] as String? ?? '',
        unread: json['unread'] as bool? ?? false,
        approvedParticipant: json['approvedParticipant'] as bool? ?? false,
        messages: _maps(json['messages'])
            .map(ParentMessageItem.fromJson)
            .toList(growable: false),
      );
}

class ParentMessagesSnapshot {
  const ParentMessagesSnapshot({
    required this.familyAccountId,
    required this.threads,
  });

  final String familyAccountId;
  final List<ParentMessageThread> threads;

  int get unreadCount => threads.where((thread) => thread.unread).length;

  ParentMessageThread? threadById(String id) {
    for (final thread in threads) {
      if (thread.id == id) return thread;
    }
    return null;
  }

  ParentMessagesSnapshot replaceThread(ParentMessageThread replacement) =>
      ParentMessagesSnapshot(
        familyAccountId: familyAccountId,
        threads: [
          for (final thread in threads)
            if (thread.id == replacement.id) replacement else thread,
        ],
      );

  Map<String, Object?> toJson() => {
        'familyAccountId': familyAccountId,
        'threads': threads.map((item) => item.toJson()).toList(),
      };

  factory ParentMessagesSnapshot.fromJson(Map<String, dynamic> json) =>
      ParentMessagesSnapshot(
        familyAccountId: json['familyAccountId'] as String? ?? '',
        threads: _maps(json['threads'])
            .map(ParentMessageThread.fromJson)
            .toList(growable: false),
      );
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

DateTime? _date(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}
