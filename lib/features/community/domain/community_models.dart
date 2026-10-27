enum CommunityAudience {
  wholeSchool,
  earlyYears,
  primary,
  secondary,
  staffOnly,
  parentsOnly,
  jss2A,
  alumniOnly,
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
        CommunityAudience.alumniOnly => 'Alumni only',
      };
}

enum CommunityVisibility { schoolOnly, publicShowcase }

extension CommunityVisibilityLabel on CommunityVisibility {
  String get label => switch (this) {
        CommunityVisibility.schoolOnly => 'School only',
        CommunityVisibility.publicShowcase => 'Public showcase',
      };
}

/// A real `community_comment` record (apps.schoollife.community.comments.CommentHandler) - its
/// own entity, never nested inside a post's own payload.
class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.postId,
    required this.author,
    required this.authorMembershipId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String author;
  final String authorMembershipId;
  final String text;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'postId': postId,
        'author': author,
        'authorMembershipId': authorMembershipId,
        'text': text,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    return CommunityComment(
      id: json['id'] as String,
      postId: json['postId'] as String? ?? '',
      author: json['author'] as String,
      authorMembershipId: json['authorMembershipId'] as String? ?? '',
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
    required this.reactedByMe,
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

  /// The real count of `community_reaction` records for this post, and the list of real
  /// `community_comment` records for it - both their own records server-side (apps.schoollife.
  /// community.posts.PostHandler drops anything nested on the post itself), so the repository
  /// attaches them here at load time rather than storing them on the post's own payload.
  final int reactions;
  final List<CommunityComment> comments;

  /// Whether the signed-in member's own reaction exists among those real records - a reaction is
  /// a per-person toggle (apps.schoollife.community.reactions.ReactionHandler), never a counter
  /// anyone can bump more than once.
  final bool reactedByMe;
  final String? mediaLabel;

  bool matches(String query, CommunityAudience? audienceFilter) {
    if (audienceFilter != null && audience != audienceFilter) return false;
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    final haystack = [author, role, title, body, audience.label].join(' ').toLowerCase();
    return haystack.contains(needle);
  }

  /// Only the post's own fields - comments and reactions are never part of this record's payload.
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
        'mediaLabel': mediaLabel,
      };

  /// Parses only the post's own fields; [reactions]/[comments]/[reactedByMe] are attached
  /// separately by the repository once this is built.
  factory CommunityPost.fromJson(Map<String, dynamic> json) {
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
      reactions: 0,
      comments: const [],
      reactedByMe: false,
      mediaLabel: json['mediaLabel'] as String?,
    );
  }

  CommunityPost withEngagement({
    required int reactions,
    required List<CommunityComment> comments,
    required bool reactedByMe,
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
      reactions: reactions,
      comments: comments,
      reactedByMe: reactedByMe,
      mediaLabel: mediaLabel,
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
