import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/administrator/data/administrator_registration_demo_data.dart';
import 'package:schoolos_app/features/administrator/data/administrator_registration_repository.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_registration_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

class _Database implements LocalDatabase {
  final records = <String, LocalRecord>{};
  final mutations = <Map<Symbol, dynamic>>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final a = invocation.namedArguments;
    final key = '${a[#tenantId]}/${a[#entityType]}/${a[#entityId]}';
    switch (invocation.memberName) {
      case #getLocalRecord:
        return Future<LocalRecord?>.value(records[key]);
      case #getLocalRecords:
        return Future<List<LocalRecord>>.value(
          records.values
              .where((r) =>
                  r.tenantId == a[#tenantId] && r.entityType == a[#entityType])
              .toList(),
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
        mutations.add(a);
        return Future<String>.value('mutation-${mutations.length}');
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const admin = SchoolMembership(
    id: 'admin', schoolId: 'a', schoolName: 'A', role: SchoolRole.administrator,
  );
  late _Database db;
  late SchoolSessionController session;
  late AdministratorRegistrationRepository repo;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    db = _Database();
    session = SchoolSessionController(store: SchoolSessionStore());
    await session.setMemberships([admin]);
    await session.selectSchool(admin);
    repo = AdministratorRegistrationRepository(
      localDatabase: db,
      schoolSession: session,
    );
  });
  tearDown(() => session.dispose());

  StudentRegistrationRecord child(
    String id,
    String first, {
    String guardian = 'Alhaji Sani Ibrahim',
    String phone = '0803 123 4567',
  }) => administratorRegistrationWebsiteSeed.copyWith(
    registrationId: id,
    firstName: first,
    surname: 'Sani',
    primaryGuardian: guardian,
    guardianPhone: phone,
  );

  test('the guardian phone is stored normalized', () async {
    final result = await repo.saveDraft(child('REG-1', 'Aisha', phone: '+234 803 123 4567'));
    expect(result.success, isTrue);
    expect(result.record!.guardianPhone, '08031234567');
    expect(
      StudentRegistrationRecord.fromJson(db.records['a/student_registration/REG-1']!.payload)
          .guardianPhone,
      '08031234567',
    );
  });

  test('an invalid guardian phone is refused and nothing is saved', () async {
    for (final phone in ['', '12345', '0803 123', 'not a number']) {
      final result = await repo.saveDraft(child('REG-1', 'Aisha', phone: phone));
      expect(result.success, isFalse, reason: phone);
    }
    expect(db.records, isEmpty);
    expect(db.mutations, isEmpty);
  });

  test('a second child under the same guardian phone is a sibling, not a new parent', () async {
    await repo.completeRegistration(child('REG-1', 'Aisha'));
    // Same parent typed differently: another format, different case and spacing.
    final result = await repo.completeRegistration(
      child('REG-2', 'Musa', guardian: '  alhaji SANI   ibrahim ', phone: '08031234567'),
    );
    expect(result.success, isTrue);
    expect(result.message, contains('Aisha Maryam Sani'));
    expect(result.message, contains('sibling'));
    expect(db.records.keys.where((k) => k.contains('student_registration')), hasLength(2));
  });

  test('the same phone under a different guardian is refused as a conflict', () async {
    await repo.completeRegistration(child('REG-1', 'Aisha'));
    final result = await repo.completeRegistration(
      child('REG-2', 'Zainab', guardian: 'Mrs. Halima Bello', phone: '+2348031234567'),
    );
    expect(result.success, isFalse);
    expect(result.message, contains('Alhaji Sani Ibrahim'));
    expect(result.message, contains('identifies one parent'));
    expect(db.records.containsKey('a/student_registration/REG-2'), isFalse);
    expect(db.mutations, hasLength(1));
  });

  test('re-saving a child does not clash with its own record', () async {
    await repo.saveDraft(child('REG-1', 'Aisha'));
    final again = await repo.completeRegistration(child('REG-1', 'Aisha'));
    expect(again.success, isTrue);
    expect(again.message, isNot(contains('sibling')));
  });

  test('different parents with different phones register independently', () async {
    await repo.completeRegistration(child('REG-1', 'Aisha'));
    final other = await repo.completeRegistration(
      child('REG-2', 'Zainab', guardian: 'Mrs. Halima Bello', phone: '08055550000'),
    );
    expect(other.success, isTrue);
    expect(other.message, isNot(contains('sibling')));
  });
}
