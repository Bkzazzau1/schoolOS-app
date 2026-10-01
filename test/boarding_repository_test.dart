import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/boarding/data/boarding_repository.dart';
import 'package:schoolos_app/features/boarding/domain/boarding_models.dart';
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
  late BoardingRepository repository;

  Future<void> actAs(SchoolRole role) async {
    final member = _member(role);
    await session.setMemberships([member]);
    await session.selectSchool(member);
  }

  Future<BoardingActionResult> createDorm() => repository.create(
        name: 'Amina Hall',
        houseParent: 'Mrs. Grace Daniel',
        capacity: 48,
        status: DormStatus.normal,
        note: '',
      );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    database = _Database();
    session = SchoolSessionController(store: SchoolSessionStore());
    repository = BoardingRepository(localDatabase: database, schoolSession: session);
  });
  tearDown(() => session.dispose());

  test('a fresh school sees a genuinely empty dormitory list, never fabricated dorms', () async {
    await actAs(SchoolRole.proprietor);
    final snapshot = await repository.load();
    expect(snapshot.dorms, isEmpty);
  });

  group('permissionsFor mirrors apps.schoollife.specs.campus.BOARDING exactly', () {
    test('the proprietor, principal and administrator can all manage dorms', () async {
      for (final role in [SchoolRole.proprietor, SchoolRole.principal, SchoolRole.administrator]) {
        await actAs(role);
        expect(repository.permissionsFor(session.requireActiveMembership()).canManageAll, isTrue, reason: role.name);
      }
    });

    test('only the proprietor and principal (LEADERS) can review a handover, not administrator', () async {
      await actAs(SchoolRole.administrator);
      expect(repository.permissionsFor(session.requireActiveMembership()).canReviewHandover, isFalse);
      for (final role in [SchoolRole.proprietor, SchoolRole.principal]) {
        await actAs(role);
        expect(repository.permissionsFor(session.requireActiveMembership()).canReviewHandover, isTrue, reason: role.name);
      }
    });
  });

  group('create', () {
    test('a manager can really add a dorm, starting at honest zeros', () async {
      await actAs(SchoolRole.proprietor);
      final result = await createDorm();
      expect(result.success, isTrue, reason: result.message);
      final dorm = (await repository.load()).dorms.single;
      expect(dorm.name, 'Amina Hall');
      expect(dorm.occupied, 0);
      expect(dorm.handoverReviewed, isFalse);
    });

    test('a non-manager cannot add a dorm', () async {
      await actAs(SchoolRole.teacher);
      final result = await createDorm();
      expect(result.success, isFalse);
    });

    test('a duplicate dorm name is refused', () async {
      await actAs(SchoolRole.proprietor);
      await createDorm();
      final result = await createDorm();
      expect(result.success, isFalse);
    });
  });

  group('edit', () {
    test('a manager can really update occupancy and status by hand', () async {
      await actAs(SchoolRole.proprietor);
      await createDorm();
      final result = await repository.edit(
        name: 'Amina Hall',
        houseParent: 'Mrs. Grace Daniel',
        capacity: 48,
        occupied: 44,
        onCampus: 42,
        approvedLeave: 2,
        maintenance: 1,
        status: DormStatus.review,
        note: 'Updated.',
      );
      expect(result.success, isTrue, reason: result.message);
      final dorm = (await repository.load()).dorms.single;
      expect(dorm.occupied, 44);
      expect(dorm.status, DormStatus.review);
    });
  });

  group('toggleHandoverReview', () {
    test('only a leader can review a real dorm\'s handover', () async {
      await actAs(SchoolRole.proprietor);
      await createDorm();

      await actAs(SchoolRole.administrator);
      final denied = await repository.toggleHandoverReview('Amina Hall');
      expect(denied.success, isFalse);

      await actAs(SchoolRole.principal);
      final allowed = await repository.toggleHandoverReview('Amina Hall');
      expect(allowed.success, isTrue, reason: allowed.message);
      expect((await repository.load()).dorms.single.handoverReviewed, isTrue);
    });
  });
}
