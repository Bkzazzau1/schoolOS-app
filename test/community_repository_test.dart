import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/community/data/community_repository.dart';
import 'package:schoolos_app/features/community/domain/community_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

class _Database implements LocalDatabase {
  final records = <String, LocalRecord>{};
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final a = invocation.namedArguments;
    final key = '${a[#tenantId]}/${a[#entityType]}/${a[#entityId]}';
    switch (invocation.memberName) {
      case #getLocalRecord:
        return Future<LocalRecord?>.value(records[key]);
      case #getLocalRecords:
        return Future<List<LocalRecord>>.value(
          records.values.where((r) => r.tenantId == a[#tenantId] && r.entityType == a[#entityType]).toList(),
        );
      case #upsertLocalRecord:
        records[key] = LocalRecord(
          tenantId: a[#tenantId],
          entityType: a[#entityType],
          entityId: a[#entityId],
          payload: Map<String, Object?>.from(a[#payload]),
          updatedAt: DateTime.now(),
          isDirty: a[#isDirty] ?? false,
        );
        return Future<void>.value();
      case #queueMutation:
        return Future<String>.value('mutation');
      case #deleteLocalRecord:
        records.remove(key);
        return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

SchoolMembership _member(SchoolRole role) => SchoolMembership(id: role.name, schoolId: 'a', schoolName: 'A', role: role);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Database database;
  late SchoolSessionController session;
  late CommunityRepository repository;

  Future<void> actAs(SchoolRole role) async {
    final member = _member(role);
    await session.setMemberships([member]);
    await session.selectSchool(member);
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    database = _Database();
    session = SchoolSessionController(store: SchoolSessionStore());
    repository = CommunityRepository(localDatabase: database, schoolSession: session);
  });
  tearDown(() => session.dispose());

  group('permissionsFor mirrors apps.schoollife.community exactly', () {
    test('the owner can post, moderate and publish to the showcase', () async {
      await actAs(SchoolRole.proprietor);
      final p = repository.permissionsFor(session.requireActiveMembership());
      expect(p.canPost, isTrue);
      expect(p.canModerate, isTrue);
      expect(p.canPublishPublicShowcase, isTrue);
      expect(p.allowedAudiences, contains(CommunityAudience.staffOnly));
    });

    test('a teacher can post and reach staffOnly, but cannot moderate or publish the showcase', () async {
      await actAs(SchoolRole.teacher);
      final p = repository.permissionsFor(session.requireActiveMembership());
      expect(p.canPost, isTrue);
      expect(p.canModerate, isFalse);
      expect(p.canPublishPublicShowcase, isFalse);
      expect(p.allowedAudiences, contains(CommunityAudience.staffOnly));
    });

    test('a driver can post but never to staffOnly', () async {
      await actAs(SchoolRole.driver);
      final p = repository.permissionsFor(session.requireActiveMembership());
      expect(p.canPost, isTrue);
      expect(p.allowedAudiences, isNot(contains(CommunityAudience.staffOnly)));
    });

    test('a parent can post but never to staffOnly', () async {
      await actAs(SchoolRole.parent);
      final p = repository.permissionsFor(session.requireActiveMembership());
      expect(p.canPost, isTrue);
      expect(p.allowedAudiences, isNot(contains(CommunityAudience.staffOnly)));
    });

    test('an alumnus can post, but only ever to their own alumni-only audience', () async {
      await actAs(SchoolRole.alumni);
      final p = repository.permissionsFor(session.requireActiveMembership());
      expect(p.canPost, isTrue);
      expect(p.allowedAudiences, [CommunityAudience.alumniOnly]);
    });

    test('nobody else is ever offered the alumni-only audience', () async {
      for (final role in [
        SchoolRole.proprietor,
        SchoolRole.teacher,
        SchoolRole.driver,
        SchoolRole.parent,
      ]) {
        await actAs(role);
        final p = repository.permissionsFor(session.requireActiveMembership());
        expect(p.allowedAudiences, isNot(contains(CommunityAudience.alumniOnly)), reason: role.name);
      }
    });

    test('a student has read-only access', () async {
      await actAs(SchoolRole.student);
      final p = repository.permissionsFor(session.requireActiveMembership());
      expect(p.canPost, isFalse);
      expect(p.allowedAudiences, isEmpty);
    });

    test('the principal and administrator can moderate too', () async {
      for (final role in [SchoolRole.principal, SchoolRole.administrator]) {
        await actAs(role);
        final p = repository.permissionsFor(session.requireActiveMembership());
        expect(p.canModerate, isTrue, reason: role.name);
      }
    });
  });

  group('publish', () {
    test('a driver can really publish a post with their own real name', () async {
      await actAs(SchoolRole.driver);
      final result = await repository.publish(
        authorName: 'Musa Ibrahim',
        title: 'Bus route update',
        body: 'The afternoon route now stops at the new estate gate.',
        audience: CommunityAudience.wholeSchool,
        visibility: CommunityVisibility.schoolOnly,
      );
      expect(result.success, isTrue);
      final posts = (await repository.load()).posts;
      expect(posts.single.author, 'Musa Ibrahim');
    });

    test('a driver cannot post to staffOnly', () async {
      await actAs(SchoolRole.driver);
      final result = await repository.publish(
        authorName: 'Musa Ibrahim',
        title: 'Title',
        body: 'Body',
        audience: CommunityAudience.staffOnly,
        visibility: CommunityVisibility.schoolOnly,
      );
      expect(result.success, isFalse);
    });

    test('an alumnus can publish to their own alumni-only audience', () async {
      await actAs(SchoolRole.alumni);
      final result = await repository.publish(
        authorName: 'A Real Alumnus',
        title: 'Reunion planning',
        body: 'Looking to organise a 2015 set reunion this year.',
        audience: CommunityAudience.alumniOnly,
        visibility: CommunityVisibility.schoolOnly,
      );
      expect(result.success, isTrue, reason: result.message);
    });

    test('an alumnus cannot publish to a general, in-school audience', () async {
      await actAs(SchoolRole.alumni);
      final result = await repository.publish(
        authorName: 'A Real Alumnus',
        title: 'Title',
        body: 'Body',
        audience: CommunityAudience.wholeSchool,
        visibility: CommunityVisibility.schoolOnly,
      );
      expect(result.success, isFalse);
    });

    test('an empty name is refused, never silently posted under a placeholder', () async {
      await actAs(SchoolRole.teacher);
      final result = await repository.publish(
        authorName: '   ',
        title: 'Title',
        body: 'Body',
        audience: CommunityAudience.wholeSchool,
        visibility: CommunityVisibility.schoolOnly,
      );
      expect(result.success, isFalse);
      expect(result.message, contains('name'));
    });

    test('a student cannot post at all', () async {
      await actAs(SchoolRole.student);
      final result = await repository.publish(
        authorName: 'A Student',
        title: 'Title',
        body: 'Body',
        audience: CommunityAudience.wholeSchool,
        visibility: CommunityVisibility.schoolOnly,
      );
      expect(result.success, isFalse);
    });
  });

  group('load', () {
    test('a fresh school sees a genuinely empty feed, never fabricated posts', () async {
      await actAs(SchoolRole.teacher);
      final snapshot = await repository.load();
      expect(snapshot.posts, isEmpty);
      expect(snapshot.postsThisWeek, 0);
      expect(snapshot.commentsThisWeek, 0);
      expect(snapshot.publicShowcaseCount, 0);
    });
  });

  group('CommunitySnapshot real stats', () {
    test('postsThisWeek and publicShowcaseCount only ever count what was really posted', () async {
      await actAs(SchoolRole.proprietor);
      await repository.publish(
        authorName: 'The Owner',
        title: 'Recent public post',
        body: 'Shared today.',
        audience: CommunityAudience.wholeSchool,
        visibility: CommunityVisibility.publicShowcase,
      );
      // A real delay, not a fake clock: publish() ids itself off DateTime.now(), so two posts made back to
      // back need real time to pass between them to get distinct ids, the same as two real people posting
      // a moment apart would.
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await repository.publish(
        authorName: 'The Owner',
        title: 'Recent private post',
        body: 'Shared today too.',
        audience: CommunityAudience.wholeSchool,
        visibility: CommunityVisibility.schoolOnly,
      );
      final snapshot = await repository.load();
      expect(snapshot.postsThisWeek, 2);
      expect(snapshot.publicShowcaseCount, 1);
    });

    test('commentsThisWeek counts real comments across every real post', () async {
      await actAs(SchoolRole.teacher);
      await repository.publish(
        authorName: 'A Teacher',
        title: 'A post',
        body: 'Body',
        audience: CommunityAudience.wholeSchool,
        visibility: CommunityVisibility.schoolOnly,
      );
      final postId = (await repository.load()).posts.single.id;
      await repository.comment(postId: postId, text: 'A real comment.');
      await repository.comment(postId: postId, text: 'Another real comment.');
      final snapshot = await repository.load();
      expect(snapshot.commentsThisWeek, 2);
    });
  });

  group('comments and reactions are their own records, never nested on the post', () {
    Future<String> publishOnePost(SchoolRole as_) async {
      await actAs(as_);
      await repository.publish(
        authorName: 'Someone',
        title: 'A post',
        body: 'Body',
        audience: CommunityAudience.wholeSchool,
        visibility: CommunityVisibility.schoolOnly,
      );
      return (await repository.load()).posts.single.id;
    }

    test('a post never carries comments/reactions in its own stored payload', () async {
      final postId = await publishOnePost(SchoolRole.teacher);
      final stored = database.records.values.singleWhere((r) => r.entityType == 'community_post');
      expect(stored.payload.containsKey('comments'), isFalse);
      expect(stored.payload.containsKey('reactions'), isFalse);
      expect(postId, isNotEmpty);
    });

    test('reacting creates a real community_reaction record owned by the real member', () async {
      final postId = await publishOnePost(SchoolRole.teacher);
      final me = session.requireActiveMembership();
      await repository.react(postId);

      final stored = database.records['${me.schoolId}/community_reaction/$postId:${me.id}'];
      expect(stored, isNotNull);
      expect(stored!.payload['postId'], postId);
      expect(stored.payload['authorMembershipId'], me.id);

      final post = (await repository.load()).posts.single;
      expect(post.reactions, 1);
      expect(post.reactedByMe, isTrue);
    });

    test('reacting a second time takes the reaction back, never stacks it', () async {
      final postId = await publishOnePost(SchoolRole.teacher);
      final me = session.requireActiveMembership();
      await repository.react(postId);
      await repository.react(postId);

      expect(database.records.containsKey('${me.schoolId}/community_reaction/$postId:${me.id}'), isFalse);
      final post = (await repository.load()).posts.single;
      expect(post.reactions, 0);
      expect(post.reactedByMe, isFalse);
    });

    test('only the real reacting member\'s own reaction counts as reactedByMe for them', () async {
      final postId = await publishOnePost(SchoolRole.teacher);
      await repository.react(postId);

      await actAs(SchoolRole.driver);
      final post = (await repository.load()).posts.single;
      expect(post.reactions, 1, reason: 'the real reaction still counts in the total');
      expect(post.reactedByMe, isFalse, reason: 'but it is not this member\'s own reaction');
    });

    test('a comment is a real community_comment record with the real post id', () async {
      final postId = await publishOnePost(SchoolRole.teacher);
      await repository.comment(postId: postId, text: 'Well done.');

      final stored = database.records.values.singleWhere((r) => r.entityType == 'community_comment');
      expect(stored.payload['postId'], postId);
      expect(stored.payload['text'], 'Well done.');

      final post = (await repository.load()).posts.single;
      expect(post.comments, hasLength(1));
      expect(post.comments.single.postId, postId);
    });
  });
}
