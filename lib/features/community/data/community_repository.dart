import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/community_models.dart';
import 'community_demo_data.dart';

class CommunitySnapshot {
  const CommunitySnapshot({
    required this.posts,
    required this.localReportsAwaitingReview,
    required this.permissions,
  });

  final List<CommunityPost> posts;
  final int localReportsAwaitingReview;
  final CommunityPermissions permissions;
}

class CommunityActionResult {
  const CommunityActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class CommunityRepository {
  CommunityRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _postEntity = 'community_post';
  static const _reportEntity = 'community_report';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  Future<CommunitySnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var postRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _postEntity,
    );

    if (postRecords.isEmpty) {
      await _seed(membership.schoolId);
      postRecords = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _postEntity,
      );
    }

    final posts = postRecords
        .map((record) => CommunityPost.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final reports = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _reportEntity,
    );

    return CommunitySnapshot(
      posts: posts,
      localReportsAwaitingReview: reports.length,
      permissions: permissionsFor(membership),
    );
  }

  CommunityPermissions permissionsFor(SchoolMembership membership) {
    if (membership.role == SchoolRole.proprietor) {
      return const CommunityPermissions(
        canPost: true,
        canPublishPublicShowcase: true,
        canModerate: true,
        allowedAudiences: CommunityAudience.values,
      );
    }

    return const CommunityPermissions(
      canPost: false,
      canPublishPublicShowcase: false,
      canModerate: false,
      allowedAudiences: [],
    );
  }

  Future<CommunityActionResult> publish({
    required String title,
    required String body,
    required CommunityAudience audience,
    required CommunityVisibility visibility,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canPost) {
      return const CommunityActionResult(
        success: false,
        message: 'This membership cannot publish Community posts.',
      );
    }
    if (!permissions.allowedAudiences.contains(audience)) {
      return const CommunityActionResult(
        success: false,
        message: 'This audience is outside your Community scope.',
      );
    }
    if (visibility == CommunityVisibility.publicShowcase &&
        !permissions.canPublishPublicShowcase) {
      return const CommunityActionResult(
        success: false,
        message: 'Public showcase publishing requires additional authority.',
      );
    }

    final cleanTitle = title.trim();
    final cleanBody = body.trim();
    if (cleanTitle.isEmpty || cleanBody.isEmpty) {
      return const CommunityActionResult(
        success: false,
        message: 'Add a title and post message first.',
      );
    }

    final now = DateTime.now().toUtc();
    final id = 'POST-${now.microsecondsSinceEpoch}';
    final post = CommunityPost(
      id: id,
      author: 'Ibrahim Bashir Yahaya',
      role: '${membership.roleLabel} workspace',
      audience: audience,
      visibility: visibility,
      title: cleanTitle,
      body: cleanBody,
      createdAt: now,
      timeLabel: 'Just now · offline',
      reactions: 0,
      comments: const [],
    );

    await _savePost(post, SyncOperation.create);
    return CommunityActionResult(
      success: true,
      message: 'Post saved offline and queued for sync.',
    );
  }

  Future<CommunityActionResult> react(String postId) async {
    final post = await _requirePost(postId);
    final updated = post.copyWith(reactions: post.reactions + 1);
    await _savePost(updated, SyncOperation.update);
    return const CommunityActionResult(
      success: true,
      message: 'Reaction saved offline.',
    );
  }

  Future<CommunityActionResult> comment({
    required String postId,
    required String text,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      return const CommunityActionResult(
        success: false,
        message: 'Write a comment first.',
      );
    }

    final membership = _schoolSession.requireActiveMembership();
    final post = await _requirePost(postId);
    final now = DateTime.now().toUtc();
    final comment = CommunityComment(
      id: '$postId-C-${now.microsecondsSinceEpoch}',
      author: membership.roleLabel,
      text: cleanText,
      createdAt: now,
    );
    final updated = post.copyWith(comments: [...post.comments, comment]);
    await _savePost(updated, SyncOperation.update);
    return const CommunityActionResult(
      success: true,
      message: 'Comment saved offline.',
    );
  }

  Future<CommunityActionResult> report(String postId) async {
    final membership = _schoolSession.requireActiveMembership();
    await _requirePost(postId);
    final now = DateTime.now().toUtc();
    final report = CommunityReport(
      id: 'REPORT-${now.microsecondsSinceEpoch}',
      postId: postId,
      reportedByMembershipId: membership.id,
      createdAt: now,
      status: 'awaitingReview',
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _reportEntity,
      entityId: report.id,
      payload: report.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _reportEntity,
      entityId: report.id,
      operation: SyncOperation.create,
      payload: report.toJson(),
    );

    return CommunityActionResult(
      success: true,
      message: '$postId reported to moderation. Saved offline.',
    );
  }

  Future<void> _savePost(CommunityPost post, SyncOperation requestedOperation) async {
    final membership = _schoolSession.requireActiveMembership();
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _postEntity,
      entityId: post.id,
    );
    final operation = existing == null ? SyncOperation.create : requestedOperation;

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _postEntity,
      entityId: post.id,
      payload: post.toJson(),
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _postEntity,
      entityId: post.id,
      operation: operation,
      payload: post.toJson(),
      baseVersion: existing?.serverVersion,
    );
  }

  Future<CommunityPost> _requirePost(String postId) async {
    final membership = _schoolSession.requireActiveMembership();
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _postEntity,
      entityId: postId,
    );
    if (record == null) {
      throw StateError('Community post $postId is not available offline.');
    }
    return CommunityPost.fromJson(record.payload);
  }

  Future<void> _seed(String tenantId) async {
    for (final post in communitySeedPosts) {
      await _localDatabase.upsertLocalRecord(
        tenantId: tenantId,
        entityType: _postEntity,
        entityId: post.id,
        payload: post.toJson(),
      );
    }
  }
}
