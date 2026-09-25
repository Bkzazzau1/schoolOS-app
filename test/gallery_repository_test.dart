import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/gallery/data/gallery_repository.dart';
import 'package:schoolos_app/features/gallery/domain/gallery_models.dart';
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
  late GalleryRepository repository;

  Future<void> actAs(SchoolRole role) async {
    final member = _member(role);
    await session.setMemberships([member]);
    await session.selectSchool(member);
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    database = _Database();
    session = SchoolSessionController(store: SchoolSessionStore());
    repository = GalleryRepository(localDatabase: database, schoolSession: session);
  });
  tearDown(() => session.dispose());

  group('permissionsFor mirrors apps.schoollife.specs.campus.GALLERY exactly', () {
    test('the owner, principal and administrator can all manage albums', () async {
      for (final role in [SchoolRole.proprietor, SchoolRole.principal, SchoolRole.administrator]) {
        await actAs(role);
        final p = repository.permissionsFor(session.requireActiveMembership());
        expect(p.canManage, isTrue, reason: role.name);
        expect(p.canCreateAlbum, isTrue, reason: role.name);
      }
    });

    test('teacher and staff can contribute but not manage', () async {
      for (final role in [SchoolRole.teacher, SchoolRole.staff]) {
        await actAs(role);
        final p = repository.permissionsFor(session.requireActiveMembership());
        expect(p.canManage, isFalse, reason: role.name);
        expect(p.canContribute, isTrue, reason: role.name);
      }
    });

    test('public showcase is a leadership call: proprietor and principal only, not administrator', () async {
      await actAs(SchoolRole.proprietor);
      expect(repository.permissionsFor(session.requireActiveMembership()).canApproveVisibility, isTrue);
      await actAs(SchoolRole.principal);
      expect(repository.permissionsFor(session.requireActiveMembership()).canApproveVisibility, isTrue);
      await actAs(SchoolRole.administrator);
      expect(repository.permissionsFor(session.requireActiveMembership()).canApproveVisibility, isFalse);
    });

    test('a parent can neither manage nor contribute', () async {
      await actAs(SchoolRole.parent);
      expect(repository.permissionsFor(session.requireActiveMembership()).canCreateAlbum, isFalse);
    });
  });

  group('load', () {
    test('offers real academic terms and classes alongside the seeded albums', () async {
      await actAs(SchoolRole.proprietor);
      final snapshot = await repository.load();
      expect(snapshot.items, isNotEmpty);
      expect(snapshot.availableTerms, isNotEmpty);
      expect(snapshot.availableClasses, isNotEmpty);
      expect(snapshot.items.every((item) => item.hasCanonicalTerm), isTrue);
      // The Robotics Showcase album is literally "the album in the excursion".
      final robotics = snapshot.items.firstWhere((item) => item.id == 'GAL-003');
      expect(robotics.excursionId, 'TRIP-004');
    });
  });

  group('createAlbum', () {
    test('a teacher can add an internal album tied to a real term', () async {
      await actAs(SchoolRole.teacher);
      final snapshot = await repository.load();
      final term = snapshot.availableTerms.first;
      final session_ = snapshot.availableSessions.firstWhere((s) => s.id == term.sessionId);

      final result = await repository.createAlbum(
        title: 'Debate Club Practice',
        album: 'Debate Club',
        owner: 'Mr. Teacher',
        date: '22 Nov 2026',
        count: 6,
        visibility: GalleryVisibility.internal,
        consent: 'Not applicable',
        note: 'Practice session photos.',
        term: term,
        session: session_,
      );

      expect(result.success, isTrue);
      final added = (await repository.load()).items.firstWhere((item) => item.title == 'Debate Club Practice');
      expect(added.termId, term.id);
      expect(added.hasCanonicalTerm, isTrue);
    });

    test('a teacher cannot publish a public showcase album', () async {
      await actAs(SchoolRole.teacher);
      final snapshot = await repository.load();
      final term = snapshot.availableTerms.first;
      final session_ = snapshot.availableSessions.firstWhere((s) => s.id == term.sessionId);

      final result = await repository.createAlbum(
        title: 'Should be refused',
        album: 'X',
        owner: 'Mr. Teacher',
        date: '22 Nov 2026',
        count: 1,
        visibility: GalleryVisibility.publicShowcase,
        consent: 'Not applicable',
        note: '',
        term: term,
        session: session_,
      );

      expect(result.success, isFalse);
    });

    test('the principal can publish a public showcase album', () async {
      await actAs(SchoolRole.principal);
      final snapshot = await repository.load();
      final term = snapshot.availableTerms.first;
      final session_ = snapshot.availableSessions.firstWhere((s) => s.id == term.sessionId);

      final result = await repository.createAlbum(
        title: 'Founders Day Highlights',
        album: 'Founders Day',
        owner: 'Principal Office',
        date: '22 Nov 2026',
        count: 30,
        visibility: GalleryVisibility.publicShowcase,
        consent: 'Approved media set',
        note: '',
        term: term,
        session: session_,
      );

      expect(result.success, isTrue);
    });

    test('a parent cannot add an album', () async {
      await actAs(SchoolRole.parent);
      final snapshot = await repository.load();
      final term = snapshot.availableTerms.first;
      final session_ = snapshot.availableSessions.firstWhere((s) => s.id == term.sessionId);

      final result = await repository.createAlbum(
        title: 'Should not exist',
        album: '',
        owner: '',
        date: '',
        count: 0,
        visibility: GalleryVisibility.internal,
        consent: '',
        note: '',
        term: term,
        session: session_,
      );

      expect(result.success, isFalse);
    });
  });
}
