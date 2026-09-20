enum DriverMessageDirection {
  schoolToDriver,
  driverToSchool;

  static DriverMessageDirection fromJson(String value) =>
      DriverMessageDirection.values.firstWhere(
        (item) => item.name == value,
        orElse: () => DriverMessageDirection.schoolToDriver,
      );
}

enum DriverMessageState {
  received('Received'),
  queued('Queued'),
  sent('Sent'),
  delivered('Delivered'),
  read('Read');

  const DriverMessageState(this.label);
  final String label;

  static DriverMessageState fromJson(String value) =>
      DriverMessageState.values.firstWhere(
        (item) => item.name == value,
        orElse: () => DriverMessageState.received,
      );
}

enum DriverAlertPriority {
  routine('Routine'),
  important('Important'),
  urgent('Urgent');

  const DriverAlertPriority(this.label);
  final String label;
}

class DriverMessageItem {
  const DriverMessageItem({
    required this.id,
    required this.direction,
    required this.authorLabel,
    required this.body,
    required this.timeLabel,
    required this.state,
    this.createdAt,
  });

  final String id;
  final DriverMessageDirection direction;
  final String authorLabel;
  final String body;
  final String timeLabel;
  final DriverMessageState state;
  final DateTime? createdAt;

  bool get isDriverMessage => direction == DriverMessageDirection.driverToSchool;
  bool get isQueued => state == DriverMessageState.queued;

  Map<String, Object?> toJson() => {
        'id': id,
        'direction': direction.name,
        'authorLabel': authorLabel,
        'body': body,
        'timeLabel': timeLabel,
        'state': state.name,
        'createdAt': createdAt?.toUtc().toIso8601String(),
      };

  factory DriverMessageItem.fromJson(Map<String, dynamic> json) =>
      DriverMessageItem(
        id: json['id'] as String? ?? '',
        direction: DriverMessageDirection.fromJson(
          json['direction'] as String? ?? '',
        ),
        authorLabel: json['authorLabel'] as String? ?? '',
        body: json['body'] as String? ?? '',
        timeLabel: json['timeLabel'] as String? ?? '',
        state: DriverMessageState.fromJson(json['state'] as String? ?? ''),
        createdAt: _date(json['createdAt']),
      );
}

class DriverMessageThread {
  const DriverMessageThread({
    required this.id,
    required this.participantName,
    required this.participantRole,
    required this.channelLabel,
    required this.preview,
    required this.timeLabel,
    required this.unread,
    required this.approvedOperationalChannel,
    required this.messages,
  });

  final String id;
  final String participantName;
  final String participantRole;
  final String channelLabel;
  final String preview;
  final String timeLabel;
  final bool unread;
  final bool approvedOperationalChannel;
  final List<DriverMessageItem> messages;

  DriverMessageThread copyWith({
    String? preview,
    String? timeLabel,
    bool? unread,
    List<DriverMessageItem>? messages,
  }) =>
      DriverMessageThread(
        id: id,
        participantName: participantName,
        participantRole: participantRole,
        channelLabel: channelLabel,
        preview: preview ?? this.preview,
        timeLabel: timeLabel ?? this.timeLabel,
        unread: unread ?? this.unread,
        approvedOperationalChannel: approvedOperationalChannel,
        messages: messages ?? this.messages,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'participantName': participantName,
        'participantRole': participantRole,
        'channelLabel': channelLabel,
        'preview': preview,
        'timeLabel': timeLabel,
        'unread': unread,
        'approvedOperationalChannel': approvedOperationalChannel,
        'messages': messages.map((item) => item.toJson()).toList(),
      };

  factory DriverMessageThread.fromJson(Map<String, dynamic> json) =>
      DriverMessageThread(
        id: json['id'] as String? ?? '',
        participantName: json['participantName'] as String? ?? '',
        participantRole: json['participantRole'] as String? ?? '',
        channelLabel: json['channelLabel'] as String? ?? '',
        preview: json['preview'] as String? ?? '',
        timeLabel: json['timeLabel'] as String? ?? '',
        unread: json['unread'] as bool? ?? false,
        approvedOperationalChannel:
            json['approvedOperationalChannel'] as bool? ?? false,
        messages: _maps(json['messages'])
            .map(DriverMessageItem.fromJson)
            .toList(growable: false),
      );
}

class DriverOperationalAlert {
  const DriverOperationalAlert({
    required this.id,
    required this.title,
    required this.body,
    required this.priority,
    required this.scopeLabel,
    required this.timeLabel,
    required this.createdAt,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final DriverAlertPriority priority;
  final String scopeLabel;
  final String timeLabel;
  final DateTime createdAt;
  final bool read;

  DriverOperationalAlert copyWith({bool? read}) => DriverOperationalAlert(
        id: id,
        title: title,
        body: body,
        priority: priority,
        scopeLabel: scopeLabel,
        timeLabel: timeLabel,
        createdAt: createdAt,
        read: read ?? this.read,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'priority': priority.name,
        'scopeLabel': scopeLabel,
        'timeLabel': timeLabel,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'read': read,
      };

  factory DriverOperationalAlert.fromJson(Map<String, dynamic> json) =>
      DriverOperationalAlert(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        priority: DriverAlertPriority.values.firstWhere(
          (item) => item.name == json['priority'],
          orElse: () => DriverAlertPriority.routine,
        ),
        scopeLabel: json['scopeLabel'] as String? ?? '',
        timeLabel: json['timeLabel'] as String? ?? '',
        createdAt: _date(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        read: json['read'] as bool? ?? false,
      );
}

class DriverMessagesSnapshot {
  const DriverMessagesSnapshot({
    required this.routeId,
    required this.vehicle,
    required this.threads,
    required this.alerts,
  });

  final String routeId;
  final String vehicle;
  final List<DriverMessageThread> threads;
  final List<DriverOperationalAlert> alerts;

  int get unreadThreads => threads.where((thread) => thread.unread).length;
  int get unreadAlerts => alerts.where((alert) => !alert.read).length;
  int get urgentUnreadAlerts => alerts
      .where((alert) => !alert.read && alert.priority == DriverAlertPriority.urgent)
      .length;

  DriverMessageThread? threadById(String id) {
    for (final thread in threads) {
      if (thread.id == id) return thread;
    }
    return null;
  }

  DriverMessagesSnapshot replaceThread(DriverMessageThread replacement) =>
      DriverMessagesSnapshot(
        routeId: routeId,
        vehicle: vehicle,
        threads: [
          for (final thread in threads)
            if (thread.id == replacement.id) replacement else thread,
        ],
        alerts: alerts,
      );

  DriverMessagesSnapshot replaceAlert(DriverOperationalAlert replacement) =>
      DriverMessagesSnapshot(
        routeId: routeId,
        vehicle: vehicle,
        threads: threads,
        alerts: [
          for (final alert in alerts)
            if (alert.id == replacement.id) replacement else alert,
        ],
      );

  Map<String, Object?> toJson() => {
        'routeId': routeId,
        'vehicle': vehicle,
        'threads': threads.map((item) => item.toJson()).toList(),
        'alerts': alerts.map((item) => item.toJson()).toList(),
      };

  factory DriverMessagesSnapshot.fromJson(Map<String, dynamic> json) =>
      DriverMessagesSnapshot(
        routeId: json['routeId'] as String? ?? '',
        vehicle: json['vehicle'] as String? ?? '',
        threads: _maps(json['threads'])
            .map(DriverMessageThread.fromJson)
            .toList(growable: false),
        alerts: _maps(json['alerts'])
            .map(DriverOperationalAlert.fromJson)
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
