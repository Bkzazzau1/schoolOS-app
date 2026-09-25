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
}
