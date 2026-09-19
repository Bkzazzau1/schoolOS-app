enum NoticePriority {
  normal('Normal'),
  important('Important'),
  emergency('Emergency');

  const NoticePriority(this.label);
  final String label;
}

enum NoticeAudience {
  wholeSchool('Whole school'),
  earlyYears('Early Years'),
  primary('Primary'),
  secondary('Secondary'),
  staffOnly('Staff only'),
  parentsOnly('Parents only'),
  jss3('JSS 3');

  const NoticeAudience(this.label);
  final String label;
}

class NoticeboardNotice {
  const NoticeboardNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.author,
    required this.role,
    required this.priority,
    required this.audience,
    required this.publishedLabel,
    required this.expiresLabel,
    required this.acknowledgementRequired,
    required this.readCount,
    required this.totalRecipients,
    required this.pinned,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String author;
  final String role;
  final NoticePriority priority;
  final NoticeAudience audience;
  final String publishedLabel;
  final String expiresLabel;
  final bool acknowledgementRequired;
  final int readCount;
  final int totalRecipients;
  final bool pinned;
  final DateTime createdAt;

  double get readRate => totalRecipients == 0 ? 0 : readCount / totalRecipients;

  NoticeboardNotice copyWith({
    String? title,
    String? body,
    NoticePriority? priority,
    NoticeAudience? audience,
    String? expiresLabel,
    bool? acknowledgementRequired,
    int? readCount,
    int? totalRecipients,
    bool? pinned,
  }) {
    return NoticeboardNotice(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      author: author,
      role: role,
      priority: priority ?? this.priority,
      audience: audience ?? this.audience,
      publishedLabel: publishedLabel,
      expiresLabel: expiresLabel ?? this.expiresLabel,
      acknowledgementRequired:
          acknowledgementRequired ?? this.acknowledgementRequired,
      readCount: readCount ?? this.readCount,
      totalRecipients: totalRecipients ?? this.totalRecipients,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'author': author,
        'role': role,
        'priority': priority.name,
        'audience': audience.name,
        'publishedLabel': publishedLabel,
        'expiresLabel': expiresLabel,
        'acknowledgementRequired': acknowledgementRequired,
        'readCount': readCount,
        'totalRecipients': totalRecipients,
        'pinned': pinned,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory NoticeboardNotice.fromJson(Map<String, Object?> json) {
    return NoticeboardNotice(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      author: json['author'] as String,
      role: json['role'] as String,
      priority: NoticePriority.values.byName(json['priority'] as String),
      audience: NoticeAudience.values.byName(json['audience'] as String),
      publishedLabel: json['publishedLabel'] as String,
      expiresLabel: json['expiresLabel'] as String,
      acknowledgementRequired: json['acknowledgementRequired'] as bool,
      readCount: json['readCount'] as int,
      totalRecipients: json['totalRecipients'] as int,
      pinned: json['pinned'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
    );
  }
}

class NoticeboardPermissions {
  const NoticeboardPermissions({
    required this.canPublish,
    required this.canPin,
    required this.canEdit,
    required this.canViewDeliveryReport,
    required this.allowedAudiences,
  });

  final bool canPublish;
  final bool canPin;
  final bool canEdit;
  final bool canViewDeliveryReport;
  final List<NoticeAudience> allowedAudiences;
}

List<NoticeboardNotice> filterNotices({
  required List<NoticeboardNotice> notices,
  String query = '',
  NoticeAudience? audience,
  NoticePriority? priority,
}) {
  final normalized = query.trim().toLowerCase();
  final visible = notices.where((notice) {
    final matchesQuery = normalized.isEmpty ||
        '${notice.title} ${notice.body} ${notice.author} ${notice.role}'
            .toLowerCase()
            .contains(normalized);
    final matchesAudience = audience == null || notice.audience == audience;
    final matchesPriority = priority == null || notice.priority == priority;
    return matchesQuery && matchesAudience && matchesPriority;
  }).toList(growable: false);

  return [...visible]
    ..sort((a, b) {
      final pinnedComparison = (b.pinned ? 1 : 0).compareTo(a.pinned ? 1 : 0);
      if (pinnedComparison != 0) return pinnedComparison;
      return b.createdAt.compareTo(a.createdAt);
    });
}
