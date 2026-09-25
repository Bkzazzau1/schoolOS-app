import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/excursions/data/excursion_repository.dart';
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
  late ExcursionRepository repository;

  Future<void> actAs(SchoolRole role) async {
    final member = _member(role);
    await session.setMemberships([member]);
    await session.selectSchool(member);
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    database = _Database();
    session = SchoolSessionController(store: SchoolSessionStore());
    repository = ExcursionRepository(localDatabase: database, schoolSession: session);
  });
  tearDown(() => session.dispose());

  group('permissionsFor mirrors apps.schoollife.specs.calendar.EXCURSIONS exactly', () {
    test('the owner, principal and administrator can all manage trips', () async {
      for (final role in [SchoolRole.proprietor, SchoolRole.principal, SchoolRole.administrator]) {
        await actAs(role);
        final p = repository.permissionsFor(session.requireActiveMembership());
        expect(p.canManage, isTrue, reason: role.name);
        expect(p.canCreateTrip, isTrue, reason: role.name);
      }
    });

    test('a teacher can contribute but not manage', () async {
      await actAs(SchoolRole.teacher);
      final p = repository.permissionsFor(session.requireActiveMembership());
      expect(p.canManage, isFalse);
      expect(p.canContribute, isTrue);
      expect(p.canCreateTrip, isTrue);
    });

    test('readiness review is a leadership call: proprietor and principal only, not administrator', () async {
      await actAs(SchoolRole.proprietor);
      expect(repository.permissionsFor(session.requireActiveMembership()).canReviewReadiness, isTrue);
      await actAs(SchoolRole.principal);
      expect(repository.permissionsFor(session.requireActiveMembership()).canReviewReadiness, isTrue);
      await actAs(SchoolRole.administrator);
      expect(repository.permissionsFor(session.requireActiveMembership()).canReviewReadiness, isFalse);
    });

    test('a parent can neither manage, contribute nor review', () async {
      await actAs(SchoolRole.parent);
      final p = repository.permissionsFor(session.requireActiveMembership());
      expect(p.canCreateTrip, isFalse);
      expect(p.canReviewReadiness, isFalse);
    });
  });

  group('load', () {
    test('offers real academic terms and classes alongside the seeded trips', () async {
      await actAs(SchoolRole.proprietor);
      final snapshot = await repository.load();
      expect(snapshot.trips, isNotEmpty);
      expect(snapshot.availableTerms, isNotEmpty);
      expect(snapshot.availableClasses, isNotEmpty);
      expect(snapshot.availableSessions, isNotEmpty);
      // Every seeded trip is tied to a real term, not a free-text label.
      expect(snapshot.trips.every((trip) => trip.hasCanonicalTerm), isTrue);
    });
  });

  group('createTrip', () {
    test('a teacher can add a trip tied to a real term and class', () async {
      await actAs(SchoolRole.teacher);
      final snapshot = await repository.load();
      final term = snapshot.availableTerms.first;
      final session_ = snapshot.availableSessions.firstWhere((s) => s.id == term.sessionId);
      final academicClass = snapshot.availableClasses.first;

      final result = await repository.createTrip(
        title: 'Inter-School Debate',
        date: '20 Nov 2026',
        destination: 'City Hall',
        coordinator: 'Mr. Teacher',
        students: 12,
        transport: 'Minibus',
        emergency: 'Ready',
        note: 'Debate club outing.',
        term: term,
        session: session_,
        academicClass: academicClass,
      );

      expect(result.success, isTrue);
      final trips = (await repository.load()).trips;
      final added = trips.firstWhere((trip) => trip.title == 'Inter-School Debate');
      expect(added.termId, term.id);
      expect(added.termName, term.name);
      expect(added.className, academicClass.name);
      expect(added.hasCanonicalTerm, isTrue);
    });

    test('a club trip can be added without a single class link', () async {
      await actAs(SchoolRole.teacher);
      final snapshot = await repository.load();
      final term = snapshot.availableTerms.first;
      final session_ = snapshot.availableSessions.firstWhere((s) => s.id == term.sessionId);

      final result = await repository.createTrip(
        title: 'Chess Club Meet',
        date: '21 Nov 2026',
        destination: 'Community Hall',
        coordinator: 'Mr. Teacher',
        students: 8,
        transport: 'Walking',
        emergency: 'Ready',
        note: 'Chess club fixture.',
        term: term,
        session: session_,
      );

      expect(result.success, isTrue);
      final added = (await repository.load()).trips.firstWhere((trip) => trip.title == 'Chess Club Meet');
      expect(added.classId, isEmpty);
      expect(added.hasCanonicalTerm, isTrue);
    });

    test('a parent cannot add a trip', () async {
      await actAs(SchoolRole.parent);
      final snapshot = await repository.load();
      final term = snapshot.availableTerms.first;
      final session_ = snapshot.availableSessions.firstWhere((s) => s.id == term.sessionId);

      final result = await repository.createTrip(
        title: 'Should not exist',
        date: '1 Jan 2027',
        destination: 'Nowhere',
        coordinator: 'Nobody',
        students: 0,
        transport: '',
        emergency: '',
        note: '',
        term: term,
        session: session_,
      );

      expect(result.success, isFalse);
    });
  });

  group('toggleReadinessReview', () {
    test('a principal can toggle readiness but an administrator cannot', () async {
      await actAs(SchoolRole.proprietor);
      final tripId = (await repository.load()).trips.first.id;

      await actAs(SchoolRole.administrator);
      final rejected = await repository.toggleReadinessReview(tripId);
      expect(rejected.success, isFalse);

      await actAs(SchoolRole.principal);
      final accepted = await repository.toggleReadinessReview(tripId);
      expect(accepted.success, isTrue);
    });
  });
}
