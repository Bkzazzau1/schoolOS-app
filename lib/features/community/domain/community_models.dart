enum CommunityAudience {
  wholeSchool,
  earlyYears,
  primary,
  secondary,
  staffOnly,
  parentsOnly,
  jss2A,
}

extension CommunityAudienceLabel on CommunityAudience {
  String get label => switch (this) {
        CommunityAudience.wholeSchool => 'Whole school',
        CommunityAudience.earlyYears => 'Early Years',
        CommunityAudience.primary => 'Primary',
        CommunityAudience.secondary => 'Secondary',
        CommunityAudience.staffOnly => 'Staff only',
        CommunityAudience.parentsOnly => 'Parents only',
        CommunityAudience.jss2A => 'JSS 2A',
      };
}

enum CommunityVisibility { schoolOnly, publicShowcase }

extension CommunityVisibilityLabel on CommunityVisibility {
  String get label => switch (this) {
        CommunityVisibility.schoolOnly => 'School only',
        CommunityVisibility.publicShowcase => 'Public showcase',
      };
}

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String author;
  final String text;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'author': author,
        'text': text,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    return CommunityComment(
      id: json['id'] as String,
      author: json['author'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.author,
    required this.role,
    required this.audience,
    required this.visibility,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.timeLabel,
    required this.reactions,
    required this.comments,
    this.mediaLabel,
  });

  final String id;
  final String author;
  final String role;
  final CommunityAudience audience;
  final CommunityVisibility visibility;
  final String title;
  final String body;
  final DateTime createdAt;
  final String timeLabel;
  final int reactions;
  final List<CommunityComment> comments;
  final String? mediaLabel;

  CommunityPost copyWith({
    int? reactions,
    List<CommunityComment>? comments,
  }) {
    return CommunityPost(
      id: id,
      author: author,
      role: role,
      audience: audience,
      visibility: visibility,
      title: title,
      body: body,
      createdAt: createdAt,
      timeLabel: timeLabel,
      reactions: reactions ?? this.reactions,
      comments: comments ?? this.comments,
      mediaLabel: mediaLabel,
    );
  }

  bool matches(String query, CommunityAudience? audienceFilter) {
    if (audienceFilter != null && audience != audienceFilter) return false;
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    final haystack = [author, role, title, body, audience.label].join(' ').toLowerCase();
    return haystack.contains(needle);
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'author': author,
        'role': role,
        'audience': audience.name,
        'visibility': visibility.name,
        'title': title,
        'body': body,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'timeLabel': timeLabel,
        'reactions': reactions,
        'comments': comments.map((item) => item.toJson()).toList(),
        'mediaLabel': mediaLabel,
      };

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    final comments = (json['comments'] as List<dynamic>? ?? const [])
        .map((item) => CommunityComment.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
    return CommunityPost(
      id: json['id'] as String,
      author: json['author'] as String,
      role: json['role'] as String,
      audience: CommunityAudience.values.byName(json['audience'] as String),
      visibility: CommunityVisibility.values.byName(json['visibility'] as String),
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      timeLabel: json['timeLabel'] as String,
      reactions: json['reactions'] as int,
      comments: comments,
      mediaLabel: json['mediaLabel'] as String?,
    );
  }
}

class CommunityReport {
  const CommunityReport({
    required this.id,
    required this.postId,
    required this.reportedByMembershipId,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String postId;
  final String reportedByMembershipId;
  final DateTime createdAt;
  final String status;

  Map<String, Object?> toJson() => {
        'id': id,
        'postId': postId,
        'reportedByMembershipId': reportedByMembershipId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'status': status,
      };
}

class CommunityPermissions {
  const CommunityPermissions({
    required this.canPost,
    required this.canPublishPublicShowcase,
    required this.canModerate,
    required this.allowedAudiences,
  });

  final bool canPost;
  final bool canPublishPublicShowcase;
  final bool canModerate;
  final List<CommunityAudience> allowedAudiences;
}
