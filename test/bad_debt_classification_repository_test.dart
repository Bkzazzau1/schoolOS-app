import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/transferverify/data/bad_debt_classification_repository.dart';
import 'package:schoolos_app/features/transferverify/domain/bad_debt_classification_models.dart';
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
        mutations.add(a);
        return Future<String>.value('mutation-${mutations.length}');
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Database database;
  late SchoolSessionController session;
  late BadDebtClassificationRepository repository;

  const owner = SchoolMembership(id: 'owner', schoolId: 'a', schoolName: 'A', role: SchoolRole.proprietor);
  const finance = SchoolMembership(id: 'finance', schoolId: 'a', schoolName: 'A', role: SchoolRole.accountant);
  const otherSchoolOwner = SchoolMembership(id: 'owner-b', schoolId: 'b', schoolName: 'B', role: SchoolRole.proprietor);

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    database = _Database();
    session = SchoolSessionController(store: SchoolSessionStore());
    await session.setMemberships([owner, finance, otherSchoolOwner]);
    await session.selectSchool(owner);
    repository = BadDebtClassificationRepository(localDatabase: database, schoolSession: session);
  });
  tearDown(() => session.dispose());

  void giveDuty(SchoolMembership member, {String duty = badDebtClassifyDuty}) {
    database.records['${member.schoolId}/owner_job_assignment/JOB-${member.id}'] = LocalRecord(
      tenantId: member.schoolId,
      entityType: 'owner_job_assignment',
      entityId: 'JOB-${member.id}',
      payload: {'membershipId': member.id, 'duties': [duty], 'status': 'active'},
      updatedAt: DateTime.now(),
      isDirty: false,
    );
  }

  Future<String> firstStudentId() async => (await repository.students()).first.id;

  test('the owner classifies a bad debt and it is queued for sync', () async {
    final studentId = await firstStudentId();
    final result = await repository.classify(
      studentId: studentId,
      studentName: 'A Student',
      outstandingAmountMinor: 5000000,
      classifiedByName: 'Mrs Bello',
      reason: 'Withdrew without financial clearance',
    );
    expect(result.success, isTrue);
    final loaded = (await repository.load()).items.single;
    expect(loaded.studentId, studentId);
    expect(loaded.status, BadDebtStatus.outstanding);
    expect(loaded.pendingSync, isTrue);
    expect(database.mutations.last[#payload], containsPair('action', 'classify'));
  });

  test('finance without the duty cannot classify; with the duty they can', () async {
    await session.selectSchool(finance);
    final studentId = await firstStudentId();
    final refused = await repository.classify(
      studentId: studentId,
      studentName: 'A Student',
      outstandingAmountMinor: 100000,
      classifiedByName: 'Mr Finance',
    );
    expect(refused.success, isFalse);
    expect(refused.message, contains('specifically authorized'));

    giveDuty(finance);
    final ok = await repository.classify(
      studentId: studentId,
      studentName: 'A Student',
      outstandingAmountMinor: 100000,
      classifiedByName: 'Mr Finance',
    );
    expect(ok.success, isTrue);
  });

  test('a second open classification for the same student is refused', () async {
    final studentId = await firstStudentId();
    await repository.classify(studentId: studentId, studentName: 'A Student', outstandingAmountMinor: 100000, classifiedByName: 'Mrs Bello');
    final second = await repository.classify(studentId: studentId, studentName: 'A Student', outstandingAmountMinor: 200000, classifiedByName: 'Mrs Bello');
    expect(second.success, isFalse);
    expect(second.message, contains('already has an open bad debt classification'));
  });

  test('publishing requires bad-debt status, is owner-only, and can be withdrawn', () async {
    final studentId = await firstStudentId();
    await repository.classify(studentId: studentId, studentName: 'A Student', outstandingAmountMinor: 100000, classifiedByName: 'Mrs Bello');
    var item = (await repository.load()).items.single;

    // Finance holds the duty (can classify) but must not be able to publish.
    giveDuty(finance);
    await session.selectSchool(finance);
    final financeAttempt = await repository.publish(item, reason: TransferVerifyPublicationReason.withdrewWithoutClearance);
    expect(financeAttempt.success, isFalse);
    expect(financeAttempt.message, contains('Only the owner'));

    await session.selectSchool(owner);
    final tooEarly = await repository.publish(item, reason: TransferVerifyPublicationReason.withdrewWithoutClearance);
    expect(tooEarly.success, isFalse);
    expect(tooEarly.message, contains('classified as bad debt'));

    await repository.advanceStatus(item, BadDebtStatus.badDebt);
    item = (await repository.load()).items.single;
    final published = await repository.publish(item, reason: TransferVerifyPublicationReason.guardianUnreachable, note: 'No response.');
    expect(published.success, isTrue);
    item = (await repository.load()).items.single;
    expect(item.publishedToTransferVerify, isTrue);
    expect(item.publicationReason, TransferVerifyPublicationReason.guardianUnreachable);

    final editWhilePublished = await repository.update(item, notes: 'sneaky edit');
    expect(editWhilePublished.success, isFalse);
    expect(editWhilePublished.message, contains('Withdraw the publication'));

    final withdrawn = await repository.withdrawPublication(item);
    expect(withdrawn.success, isTrue);
    item = (await repository.load()).items.single;
    expect(item.publishedToTransferVerify, isFalse);
    expect(item.publicationReason, isNull);
  });

  test('classifications never cross schools', () async {
    final studentId = await firstStudentId();
    await repository.classify(studentId: studentId, studentName: 'A Student', outstandingAmountMinor: 100000, classifiedByName: 'Mrs Bello');
    await session.selectSchool(otherSchoolOwner);
    expect((await repository.load()).items, isEmpty);
  });
}
