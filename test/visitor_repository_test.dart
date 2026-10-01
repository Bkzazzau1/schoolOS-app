import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/visitors/data/visitor_repository.dart';
import 'package:schoolos_app/features/visitors/domain/visitor_models.dart';
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
  late VisitorRepository repository;

  Future<void> actAs(SchoolRole role) async {
    final member = _member(role);
    await session.setMemberships([member]);
    await session.selectSchool(member);
  }

  Future<VisitorActionResult> logVisitor() => repository.create(
        visitor: 'Mrs. Zainab Ahmed',
        organization: 'Parent / Guardian',
        purpose: 'Scheduled meeting',
        host: 'Primary Office',
        area: 'Primary reception',
        arrival: '9:10 AM',
        status: VisitStatus.expected,
        pass: 'V-101',
        note: '',
      );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    database = _Database();
    session = SchoolSessionController(store: SchoolSessionStore());
    repository = VisitorRepository(localDatabase: database, schoolSession: session);
  });
  tearDown(() => session.dispose());

  test('a fresh school sees a genuinely empty visitor register, never fabricated visits', () async {
    await actAs(SchoolRole.proprietor);
    final snapshot = await repository.load();
    expect(snapshot.visits, isEmpty);
  });

  group('permissionsFor mirrors apps.schoollife.specs.campus.VISITORS exactly', () {
    test('managers and the front desk (staff) can create; only managers can manage/review', () async {
      for (final role in [SchoolRole.proprietor, SchoolRole.principal, SchoolRole.administrator]) {
        await actAs(role);
        final p = repository.permissionsFor(session.requireActiveMembership());
        expect(p.canCreate, isTrue, reason: role.name);
        expect(p.canManageAll, isTrue, reason: role.name);
        expect(p.canReviewRecords, isTrue, reason: role.name);
      }
      await actAs(SchoolRole.staff);
      final staff = repository.permissionsFor(session.requireActiveMembership());
      expect(staff.canCreate, isTrue);
      expect(staff.canManageAll, isFalse);
      expect(staff.canReviewRecords, isFalse);
    });

    test('nobody else can log, manage or review a visitor', () async {
      for (final role in [SchoolRole.teacher, SchoolRole.parent, SchoolRole.student]) {
        await actAs(role);
        final p = repository.permissionsFor(session.requireActiveMembership());
        expect(p.canCreate, isFalse, reason: role.name);
      }
    });
  });

  group('create', () {
    test('the front desk (a real contributor) can really log a visitor', () async {
      await actAs(SchoolRole.staff);
      final result = await logVisitor();
      expect(result.success, isTrue, reason: result.message);
      final visit = (await repository.load()).visits.single;
      expect(visit.visitor, 'Mrs. Zainab Ahmed');
      expect(visit.departure, '—');
      expect(visit.frontDeskReviewed, isFalse);
    });

    test('a role outside manage/contribute cannot log a visitor', () async {
      await actAs(SchoolRole.teacher);
      final result = await logVisitor();
      expect(result.success, isFalse);
    });

    test('an empty visitor name is refused', () async {
      await actAs(SchoolRole.proprietor);
      final result = await repository.create(
        visitor: '   ',
        organization: '',
        purpose: '',
        host: '',
        area: '',
        arrival: '',
        status: VisitStatus.expected,
        pass: '',
        note: '',
      );
      expect(result.success, isFalse);
    });
  });

  group('edit and review', () {
    test('a manager can really edit a visit and review it; the front desk cannot do either', () async {
      await actAs(SchoolRole.staff);
      await logVisitor();
      final id = (await repository.load()).visits.single.id;

      final deniedEdit = await repository.edit(
        id: id,
        organization: '',
        purpose: '',
        host: '',
        area: '',
        arrival: '',
        departure: '',
        status: VisitStatus.onCampus,
        pass: '',
        note: '',
      );
      expect(deniedEdit.success, isFalse);
      final deniedReview = await repository.toggleRecordReview(id);
      expect(deniedReview.success, isFalse);

      await actAs(SchoolRole.proprietor);
      final allowedEdit = await repository.edit(
        id: id,
        organization: 'Parent / Guardian',
        purpose: 'Scheduled meeting',
        host: 'Primary Office',
        area: 'Primary reception',
        arrival: '9:10 AM',
        departure: '10:02 AM',
        status: VisitStatus.checkedOut,
        pass: 'V-101',
        note: 'Checked out.',
      );
      expect(allowedEdit.success, isTrue, reason: allowedEdit.message);
      expect((await repository.load()).visits.single.status, VisitStatus.checkedOut);

      final allowedReview = await repository.toggleRecordReview(id);
      expect(allowedReview.success, isTrue, reason: allowedReview.message);
      expect((await repository.load()).visits.single.frontDeskReviewed, isTrue);
    });
  });
}
