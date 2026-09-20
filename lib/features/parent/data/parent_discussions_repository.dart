import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/parent_discussions_models.dart';
import 'parent_discussions_demo_data.dart';

class ParentDiscussionsRepository {
  ParentDiscussionsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _snapshotEntityType = 'parent_discussions_snapshot';
  static const _postEntityType = 'parent_discussion_post';
  static const _reactionEntityType = 'parent_discussion_reaction';
  static const _commentEntityType = 'parent_discussion_comment_action';
  static const _followEntityType = 'parent_discussion_follow';
  static const _reportEntityType = 'parent_discussion_report';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  Future<ParentDiscussionsSnapshot> load() async {
    final membership = _requireParentMembership();
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _snapshotEntityType,
      entityId: membership.id,
    );

    if (record != null) {
      final snapshot = ParentDiscussionsSnapshot.fromJson(record.payload);
      _validateSnapshot(snapshot);
      return snapshot;
    }

    await _saveSnapshot(membership, parentDefaultDiscussions);
    return parentDefaultDiscussions;
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

    final snapshot = await load();
    final now = DateTime.now();
    final id = 'LOCAL-DISC-${membership.id}-${now.toUtc().microsecondsSinceEpoch}';
    final post = ParentDiscussionPost(
      id: id,
      author: 'Alhaji Abdullahi Yusuf',
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

    await _saveSnapshot(membership, snapshot.prependPost(post));
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _postEntityType,
      entityId: id,
      operation: SyncOperation.create,
      payload: {
        'postId': id,
        'familyAccountId': snapshot.familyAccountId,
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
    final snapshot = await load();
    final post = _requirePost(snapshot, postId);
    final now = DateTime.now();

    await _saveSnapshot(
      membership,
      snapshot.replacePost(post.copyWith(reactions: post.reactions + 1)),
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _reactionEntityType,
      entityId: '${post.id}:${now.toUtc().microsecondsSinceEpoch}',
      operation: SyncOperation.create,
      payload: {
        'postId': post.id,
        'familyAccountId': snapshot.familyAccountId,
        'action': 'react',
        'queuedAt': now.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> queueCommentAction(String postId) async {
    final membership = _requireParentMembership();
    final snapshot = await load();
    final post = _requirePost(snapshot, postId);
    final now = DateTime.now();

    await _saveSnapshot(
      membership,
      snapshot.replacePost(post.copyWith(comments: post.comments + 1)),
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _commentEntityType,
      entityId: '${post.id}:${now.toUtc().microsecondsSinceEpoch}',
      operation: SyncOperation.create,
      payload: {
        'postId': post.id,
        'familyAccountId': snapshot.familyAccountId,
        'action': 'comment_interaction',
        'queuedAt': now.toUtc().toIso8601String(),
      },
    );
  }

  Future<bool> toggleFollow(String postId) async {
    final membership = _requireParentMembership();
    final snapshot = await load();
    final post = _requirePost(snapshot, postId);
    final next = !post.followed;

    await _saveSnapshot(
      membership,
      snapshot.replacePost(post.copyWith(followed: next)),
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _followEntityType,
      entityId: post.id,
      operation: SyncOperation.update,
      payload: {
        'postId': post.id,
        'familyAccountId': snapshot.familyAccountId,
        'followed': next,
      },
    );
    return next;
  }

  Future<bool> report(String postId) async {
    final membership = _requireParentMembership();
    final snapshot = await load();
    final post = _requirePost(snapshot, postId);
    if (post.reported) return false;

    final now = DateTime.now();
    await _saveSnapshot(
      membership,
      snapshot.replacePost(post.copyWith(reported: true)),
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _reportEntityType,
      entityId: post.id,
      operation: SyncOperation.create,
      payload: {
        'postId': post.id,
        'familyAccountId': snapshot.familyAccountId,
        'reason': 'guardian_reported_for_moderation',
        'queuedAt': now.toUtc().toIso8601String(),
      },
    );
    return true;
  }

  Future<void> replaceFromServer({
    required ParentDiscussionsSnapshot snapshot,
    required int serverVersion,
  }) async {
    final membership = _requireParentMembership();
    _validateSnapshot(snapshot);
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _snapshotEntityType,
      entityId: membership.id,
      payload: snapshot.toJson(),
      serverVersion: serverVersion,
      isDirty: false,
    );
  }

  ParentDiscussionPost _requirePost(
    ParentDiscussionsSnapshot snapshot,
    String postId,
  ) {
    final id = postId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(postId, 'postId', 'Discussion id is required.');
    }
    final post = snapshot.postById(id);
    if (post == null) {
      throw StateError('This discussion is not available to the active family account.');
    }
    return post;
  }

  Future<void> _saveSnapshot(
    SchoolMembership membership,
    ParentDiscussionsSnapshot snapshot,
  ) async {
    _validateSnapshot(snapshot);
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _snapshotEntityType,
      entityId: membership.id,
      payload: snapshot.toJson(),
    );
  }

  void _validateSnapshot(ParentDiscussionsSnapshot snapshot) {
    if (snapshot.familyAccountId.trim().isEmpty) {
      throw StateError('Family discussions are missing the family account id.');
    }
    final ids = <String>{};
    for (final post in snapshot.posts) {
      if (post.id.trim().isEmpty || !ids.add(post.id)) {
        throw StateError('Family discussions contain an invalid discussion id.');
      }
      if (post.author.trim().isEmpty || post.title.trim().isEmpty || post.body.trim().isEmpty) {
        throw StateError('A family discussion is missing required content.');
      }
      if (post.reactions < 0 || post.comments < 0) {
        throw StateError('Discussion activity counts cannot be negative.');
      }
    }
    for (final item in snapshot.pulse) {
      if (item.value < 0 || item.value > 100) {
        throw StateError('Community pulse values must stay between 0 and 100.');
      }
    }
  }

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError('School discussions require an active Parent membership.');
    }
    return membership;
  }
}
