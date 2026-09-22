import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/parent_discussions_models.dart';

class ParentDiscussionsRepository {
  ParentDiscussionsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _postEntityType = 'parent_discussion_post';
  static const _reactionEntityType = 'parent_discussion_reaction';
  static const _commentEntityType = 'parent_discussion_comment_action';
  static const _followEntityType = 'parent_discussion_follow';
  static const _reportEntityType = 'parent_discussion_report';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  /// No real school-wide discussion community exists anywhere in the app (no other role has one
  /// either), so this reads only the real posts this specific family has actually queued on this
  /// device — never a fabricated feed of other families' posts, trending topics or engagement
  /// percentages. `activeDiscussions`/`parentPosts`/`commentCount` are derived live from those real
  /// posts every time, instead of a fixed starting number, so they can never drift from what is
  /// actually shown below them.
  Future<ParentDiscussionsSnapshot> load() async {
    final membership = _requireParentMembership();
    final posts = await _realPosts(membership);

    return ParentDiscussionsSnapshot(
      familyAccountId: membership.id,
      activeDiscussions: posts.length,
      // Every real post here is guardian-authored; there is no real staff or other-family source.
      parentPosts: posts.length,
      commentCount: posts.fold<int>(0, (sum, post) => sum + post.comments),
      posts: posts,
      // No real trending-topic or cross-scope engagement computation exists without a real,
      // multi-family community behind this feed.
      trends: const [],
      pulse: const [],
    );
  }

  Future<ParentDiscussionPost> queuePost({
    required String title,
    required String body,
    required ParentDiscussionScope scope,
  }) async {
    final membership = _requireParentMembership();
    final normalizedTitle = title.trim();
    final normalizedBody = body.trim();

    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Discussion title is required.');
    }
    if (normalizedBody.isEmpty) {
      throw ArgumentError.value(body, 'body', 'Discussion message is required.');
    }
    if (normalizedTitle.length > 160) {
      throw ArgumentError.value(title, 'title', 'Discussion titles cannot exceed 160 characters.');
    }
    if (normalizedBody.length > 4000) {
      throw ArgumentError.value(body, 'body', 'Discussion messages cannot exceed 4000 characters.');
    }

    final now = DateTime.now();
    final id = 'LOCAL-DISC-${membership.id}-${now.toUtc().microsecondsSinceEpoch}';
    final post = ParentDiscussionPost(
      id: id,
      // No real per-guardian display-name directory exists yet — the same reason Messages already
      // shows a guardian's own messages as "You" rather than inventing a name.
      author: 'You',
      scope: scope,
      title: normalizedTitle,
      body: normalizedBody,
      timeLabel: 'Queued locally',
      reactions: 0,
      comments: 0,
      tag: 'Parent post',
      followed: true,
      publicationState: ParentDiscussionPublicationState.queued,
    );

    await _persistPost(membership, post);
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _postEntityType,
      entityId: id,
      operation: SyncOperation.create,
      payload: {
        'postId': id,
        'familyAccountId': membership.id,
        'scope': scope.label,
        'title': normalizedTitle,
        'body': normalizedBody,
        'publicationState': ParentDiscussionPublicationState.queued.name,
        'requiresModeration': true,
        'createdAt': now.toUtc().toIso8601String(),
      },
    );
    return post;
  }

  Future<void> queueReaction(String postId) async {
    final membership = _requireParentMembership();
    final post = await _requirePost(membership, postId);
    final now = DateTime.now();

    await _persistPost(membership, post.copyWith(reactions: post.reactions + 1));
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _reactionEntityType,
      entityId: '${post.id}:${now.toUtc().microsecondsSinceEpoch}',
      operation: SyncOperation.create,
      payload: {
        'postId': post.id,
        'familyAccountId': membership.id,
        'action': 'react',
        'queuedAt': now.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> queueCommentAction(String postId) async {
    final membership = _requireParentMembership();
    final post = await _requirePost(membership, postId);
    final now = DateTime.now();

    await _persistPost(membership, post.copyWith(comments: post.comments + 1));
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _commentEntityType,
      entityId: '${post.id}:${now.toUtc().microsecondsSinceEpoch}',
      operation: SyncOperation.create,
      payload: {
        'postId': post.id,
        'familyAccountId': membership.id,
        'action': 'comment_interaction',
        'queuedAt': now.toUtc().toIso8601String(),
      },
    );
  }

  Future<bool> toggleFollow(String postId) async {
    final membership = _requireParentMembership();
    final post = await _requirePost(membership, postId);
    final next = !post.followed;

    await _persistPost(membership, post.copyWith(followed: next));
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _followEntityType,
      entityId: post.id,
      operation: SyncOperation.update,
      payload: {
        'postId': post.id,
        'familyAccountId': membership.id,
        'followed': next,
      },
    );
    return next;
  }

  Future<bool> report(String postId) async {
    final membership = _requireParentMembership();
    final post = await _requirePost(membership, postId);
    if (post.reported) return false;

    final now = DateTime.now();
    await _persistPost(membership, post.copyWith(reported: true));
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _reportEntityType,
      entityId: post.id,
      operation: SyncOperation.create,
      payload: {
        'postId': post.id,
        'familyAccountId': membership.id,
        'reason': 'guardian_reported_for_moderation',
        'queuedAt': now.toUtc().toIso8601String(),
      },
    );
    return true;
  }

  Future<List<ParentDiscussionPost>> _realPosts(SchoolMembership membership) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _postEntityType,
    );
    final posts = <ParentDiscussionPost>[];
    for (final record in records) {
      if (record.payload['membershipId'] != membership.id) continue;
      posts.add(ParentDiscussionPost.fromJson(Map<String, dynamic>.from(record.payload)));
    }
    posts.sort((a, b) => b.id.compareTo(a.id)); // newest LOCAL-DISC-...-<microsecond> id first
    return posts;
  }

  Future<ParentDiscussionPost> _requirePost(
    SchoolMembership membership,
    String postId,
  ) async {
    final id = postId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(postId, 'postId', 'Discussion id is required.');
    }
    for (final post in await _realPosts(membership)) {
      if (post.id == id) return post;
    }
    throw StateError('This discussion is not available to the active family account.');
  }

  Future<void> _persistPost(SchoolMembership membership, ParentDiscussionPost post) async {
    final payload = post.toJson()
      ..addAll(<String, Object?>{'membershipId': membership.id});
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _postEntityType,
      entityId: post.id,
      payload: payload,
      isDirty: true,
    );
  }

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError('School discussions require an active Parent membership.');
    }
    return membership;
  }
}
