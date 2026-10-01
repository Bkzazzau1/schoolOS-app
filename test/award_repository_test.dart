import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/awards/data/award_repository.dart';
import 'package:schoolos_app/features/awards/domain/award_models.dart';
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
  late AwardRepository repository;

  Future<void> actAs(SchoolRole role) async {
    final member = _member(role);
    await session.setMemberships([member]);
    await session.selectSchool(member);
  }

  Future<AwardActionResult> addDraft() => repository.addDraft(
        title: 'Teacher of the Term',
        recipient: 'Mrs. Fatima Bello',
        recipientType: AwardRecipientType.teacher,
        section: 'Secondary',
        category: 'Teaching Excellence',
        citation: '',
        issuer: '',
      );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    database = _Database();
    session = SchoolSessionController(store: SchoolSessionStore());
    repository = AwardRepository(localDatabase: database, schoolSession: session);
  });
  tearDown(() => session.dispose());

  test('a fresh school sees a genuinely empty recognition wall, never fabricated awards', () async {
    await actAs(SchoolRole.proprietor);
    final snapshot = await repository.load();
    expect(snapshot.awards, isEmpty);
  });

  group('permissionsFor mirrors apps.schoollife.specs.programmes.AWARDS exactly', () {
    test('the proprietor, principal and teacher can all create drafts', () async {
      for (final role in [SchoolRole.proprietor, SchoolRole.principal, SchoolRole.teacher]) {
        await actAs(role);
        expect(repository.permissionsFor(session.requireActiveMembership()).canCreateDrafts, isTrue, reason: role.name);
      }
    });

    test('the administrator (not a LEADERS role here) cannot create drafts', () async {
      await actAs(SchoolRole.administrator);
      expect(repository.permissionsFor(session.requireActiveMembership()).canCreateDrafts, isFalse);
    });

    test('nobody else can create a draft', () async {
      for (final role in [SchoolRole.parent, SchoolRole.student, SchoolRole.driver]) {
        await actAs(role);
        expect(repository.permissionsFor(session.requireActiveMembership()).canCreateDrafts, isFalse, reason: role.name);
      }
    });
  });

  group('addDraft', () {
    test('a teacher (a real contributor) can really add a draft, always starting internal only', () async {
      await actAs(SchoolRole.teacher);
      final result = await addDraft();
      expect(result.success, isTrue, reason: result.message);
      final award = (await repository.load()).awards.single;
      expect(award.title, 'Teacher of the Term');
      expect(award.visibility, AwardVisibility.internalOnly);
    });

    test('a role outside leaders/contribute cannot add a draft', () async {
      await actAs(SchoolRole.parent);
      final result = await addDraft();
      expect(result.success, isFalse);
    });

    test('an empty title or recipient is refused', () async {
      await actAs(SchoolRole.proprietor);
      final result = await repository.addDraft(
        title: '   ',
        recipient: '',
        recipientType: AwardRecipientType.student,
        section: '',
        category: '',
        citation: '',
        issuer: '',
      );
      expect(result.success, isFalse);
    });
  });
}
