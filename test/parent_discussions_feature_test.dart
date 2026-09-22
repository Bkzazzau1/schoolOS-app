import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/parent/data/parent_discussions_repository.dart';
import 'package:schoolos_app/features/parent/domain/parent_discussions_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const parent = SchoolMembership(id: 'm-parent', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.parent);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late ParentDiscussionsRepository discussions;

  Future<void> setUpFamily() async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([parent, teacher]);
    await session.selectSchool(parent);
    discussions = ParentDiscussionsRepository(localDatabase: database, schoolSession: session);
  }

  tearDown(() => db?.close());

  test('a fresh family sees an honestly empty community: no fabricated other-family posts or trends', () async {
    await setUpFamily();
    final snapshot = await discussions.load();
    expect(snapshot.posts, isEmpty);
    expect(snapshot.activeDiscussions, 0);
    expect(snapshot.parentPosts, 0);
    expect(snapshot.commentCount, 0);
    expect(snapshot.trends, isEmpty);
    expect(snapshot.pulse, isEmpty);
  });

  test('a queued post is real, persists across a reload, and drives the KPI counts honestly', () async {
    await setUpFamily();
    final post = await discussions.queuePost(
      title: 'Reading circle ideas',
      body: 'Would other families be interested in a weekend reading circle?',
      scope: ParentDiscussionScope.parentsOnly,
    );
    expect(post.author, 'You');
    expect(post.publicationState, ParentDiscussionPublicationState.queued);

    final reloaded = await discussions.load();
    expect(reloaded.posts, hasLength(1));
    expect(reloaded.posts.single.id, post.id);
    expect(reloaded.activeDiscussions, 1);
    expect(reloaded.parentPosts, 1);
    expect(db!.pendingCount(tenantId: parent.schoolId), greaterThan(0));
  });

  test('reacting, commenting and following a real post persist and the comment count feeds the KPI', () async {
    await setUpFamily();
    final post = await discussions.queuePost(title: 'T', body: 'B', scope: ParentDiscussionScope.wholeSchool);

    await discussions.queueReaction(post.id);
    await discussions.queueCommentAction(post.id);
    final followed = await discussions.toggleFollow(post.id);
    expect(followed, isFalse, reason: 'a freshly queued post already starts followed by its author');

    final snapshot = await discussions.load();
    final reloadedPost = snapshot.postById(post.id)!;
    expect(reloadedPost.reactions, 1);
    expect(reloadedPost.comments, 1);
    expect(reloadedPost.followed, isFalse);
    expect(snapshot.commentCount, 1);
  });

  test('reporting a real post is idempotent', () async {
    await setUpFamily();
    final post = await discussions.queuePost(title: 'T', body: 'B', scope: ParentDiscussionScope.primary);
    expect(await discussions.report(post.id), isTrue);
    expect(await discussions.report(post.id), isFalse);
  });

  test('acting on an unknown post id is rejected', () async {
    await setUpFamily();
    expect(discussions.queueReaction('not-a-real-post'), throwsStateError);
  });

  test('only a Parent membership can load or post to family discussions', () async {
    await setUpFamily();
    await session.selectSchool(teacher);
    expect(discussions.load(), throwsStateError);
    expect(
      discussions.queuePost(title: 'T', body: 'B', scope: ParentDiscussionScope.wholeSchool),
      throwsStateError,
    );
  });
}
