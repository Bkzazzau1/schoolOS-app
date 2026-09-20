enum ParentDiscussionScope {
  wholeSchool('Whole school'),
  parentsOnly('Parents only'),
  primary('Primary'),
  secondary('Secondary'),
  jss2a('JSS 2A'),
  primary3('Primary 3');

  const ParentDiscussionScope(this.label);

  final String label;

  static ParentDiscussionScope fromJson(String value) =>
      ParentDiscussionScope.values.firstWhere(
        (item) => item.name == value || item.label == value,
        orElse: () => ParentDiscussionScope.parentsOnly,
      );
}

enum ParentDiscussionPublicationState {
  published('Published'),
  queued('Queued');

  const ParentDiscussionPublicationState(this.label);

  final String label;

  static ParentDiscussionPublicationState fromJson(String value) =>
      ParentDiscussionPublicationState.values.firstWhere(
        (item) => item.name == value,
        orElse: () => ParentDiscussionPublicationState.published,
      );
}

class ParentDiscussionPost {
  const ParentDiscussionPost({
    required this.id,
    required this.author,
    required this.scope,
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.reactions,
    required this.comments,
    required this.tag,
    required this.followed,
    required this.publicationState,
    this.reported = false,
  });

  final String id;
  final String author;
  final ParentDiscussionScope scope;
  final String title;
  final String body;
  final String timeLabel;
  final int reactions;
  final int comments;
  final String tag;
  final bool followed;
  final ParentDiscussionPublicationState publicationState;
  final bool reported;

  bool get isQueued =>
      publicationState == ParentDiscussionPublicationState.queued;

  ParentDiscussionPost copyWith({
    int? reactions,
    int? comments,
    bool? followed,
    bool? reported,
    ParentDiscussionPublicationState? publicationState,
  }) =>
      ParentDiscussionPost(
        id: id,
        author: author,
        scope: scope,
        title: title,
        body: body,
        timeLabel: timeLabel,
        reactions: reactions ?? this.reactions,
        comments: comments ?? this.comments,
        tag: tag,
        followed: followed ?? this.followed,
        publicationState: publicationState ?? this.publicationState,
        reported: reported ?? this.reported,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'author': author,
        'scope': scope.name,
        'title': title,
        'body': body,
        'timeLabel': timeLabel,
        'reactions': reactions,
        'comments': comments,
        'tag': tag,
        'followed': followed,
        'publicationState': publicationState.name,
        'reported': reported,
      };

  factory ParentDiscussionPost.fromJson(Map<String, dynamic> json) =>
      ParentDiscussionPost(
        id: json['id'] as String? ?? '',
        author: json['author'] as String? ?? '',
        scope: ParentDiscussionScope.fromJson(json['scope'] as String? ?? ''),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        timeLabel: json['timeLabel'] as String? ?? '',
        reactions: (json['reactions'] as num?)?.toInt() ?? 0,
        comments: (json['comments'] as num?)?.toInt() ?? 0,
        tag: json['tag'] as String? ?? '',
        followed: json['followed'] as bool? ?? false,
        publicationState: ParentDiscussionPublicationState.fromJson(
          json['publicationState'] as String? ?? '',
        ),
        reported: json['reported'] as bool? ?? false,
      );
}

class ParentDiscussionTrend {
  const ParentDiscussionTrend({
    required this.rank,
    required this.topic,
    required this.tag,
    required this.posts,
    required this.engagement,
    required this.note,
  });

  final int rank;
  final String topic;
  final String tag;
  final int posts;
  final String engagement;
  final String note;

  Map<String, Object?> toJson() => {
        'rank': rank,
        'topic': topic,
        'tag': tag,
        'posts': posts,
        'engagement': engagement,
        'note': note,
      };

  factory ParentDiscussionTrend.fromJson(Map<String, dynamic> json) =>
      ParentDiscussionTrend(
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        topic: json['topic'] as String? ?? '',
        tag: json['tag'] as String? ?? '',
        posts: (json['posts'] as num?)?.toInt() ?? 0,
        engagement: json['engagement'] as String? ?? '',
        note: json['note'] as String? ?? '',
      );
}

class ParentDiscussionPulse {
  const ParentDiscussionPulse({required this.label, required this.value});

  final String label;
  final int value;

  Map<String, Object?> toJson() => {'label': label, 'value': value};

  factory ParentDiscussionPulse.fromJson(Map<String, dynamic> json) =>
      ParentDiscussionPulse(
        label: json['label'] as String? ?? '',
        value: (json['value'] as num?)?.toInt() ?? 0,
      );
}

class ParentDiscussionsSnapshot {
  const ParentDiscussionsSnapshot({
    required this.familyAccountId,
    required this.activeDiscussions,
    required this.parentPosts,
    required this.commentCount,
    required this.posts,
    required this.trends,
    required this.pulse,
  });

  final String familyAccountId;
  final int activeDiscussions;
  final int parentPosts;
  final int commentCount;
  final List<ParentDiscussionPost> posts;
  final List<ParentDiscussionTrend> trends;
  final List<ParentDiscussionPulse> pulse;

  ParentDiscussionPost? postById(String id) {
    for (final post in posts) {
      if (post.id == id) return post;
    }
    return null;
  }

  ParentDiscussionsSnapshot prependPost(ParentDiscussionPost post) =>
      ParentDiscussionsSnapshot(
        familyAccountId: familyAccountId,
        activeDiscussions: activeDiscussions + 1,
        parentPosts: parentPosts + 1,
        commentCount: commentCount,
        posts: [post, ...posts],
        trends: trends,
        pulse: pulse,
      );

  ParentDiscussionsSnapshot replacePost(ParentDiscussionPost replacement) =>
      ParentDiscussionsSnapshot(
        familyAccountId: familyAccountId,
        activeDiscussions: activeDiscussions,
        parentPosts: parentPosts,
        commentCount: commentCount,
        posts: [
          for (final post in posts)
            if (post.id == replacement.id) replacement else post,
        ],
        trends: trends,
        pulse: pulse,
      );

  Map<String, Object?> toJson() => {
        'familyAccountId': familyAccountId,
        'activeDiscussions': activeDiscussions,
        'parentPosts': parentPosts,
        'commentCount': commentCount,
        'posts': posts.map((item) => item.toJson()).toList(),
        'trends': trends.map((item) => item.toJson()).toList(),
        'pulse': pulse.map((item) => item.toJson()).toList(),
      };

  factory ParentDiscussionsSnapshot.fromJson(Map<String, dynamic> json) =>
      ParentDiscussionsSnapshot(
        familyAccountId: json['familyAccountId'] as String? ?? '',
        activeDiscussions: (json['activeDiscussions'] as num?)?.toInt() ?? 0,
        parentPosts: (json['parentPosts'] as num?)?.toInt() ?? 0,
        commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
        posts: _maps(json['posts'])
            .map(ParentDiscussionPost.fromJson)
            .toList(growable: false),
        trends: _maps(json['trends'])
            .map(ParentDiscussionTrend.fromJson)
            .toList(growable: false),
        pulse: _maps(json['pulse'])
            .map(ParentDiscussionPulse.fromJson)
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
