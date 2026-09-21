import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/sync/server_confirm.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/finance_office/data/finance_concessions_repository.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_concessions_models.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_payroll_models.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';
import 'package:schoolos_app/features/proprietor/data/payroll_batch_repository.dart';
import 'package:schoolos_app/features/proprietor/domain/concession_request.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const owner = SchoolMembership(
  id: '55555555-5555-5555-5555-555555555555',
  schoolId: '22222222-2222-2222-2222-222222222222',
  schoolName: 'BrightGate',
  role: SchoolRole.proprietor,
);

const finance = SchoolMembership(
  id: '99999999-9999-9999-9999-999999999999',
  schoolId: '22222222-2222-2222-2222-222222222222',
  schoolName: 'BrightGate',
  role: SchoolRole.accountant,
);

FinancePayrollRow row(String id, String name, int gross, int deductions) => FinancePayrollRow(
      staffId: id, name: name, expectedDays: 20, presentDays: 20, leaveDays: 0, unexplainedDays: 0,
      gross: gross, deductions: deductions, net: gross - deductions, status: FinancePayrollStatus.ready,
    );

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  var rounds = 0;

  /// What the server does with the next change, decided per test. 'ok' accepts it; anything else is a refusal.
  late String Function(SyncQueueItem item) serverSays;

  /// Server truth written back when the device asks again after a refusal.
  Map<String, Object?>? truth;
  late String truthType, truthId;

  ServerConfirm confirm() => ServerConfirm(
        database: db,
        syncNow: () async {
          rounds++;
          for (final item in db.syncQueueItems(tenantId: owner.schoolId).where((i) => i.status == SyncMutationStatus.pending)) {
            db.markMutationSyncing(item.id);
            final answer = serverSays(item);
            if (answer == 'ok') {
              db.markMutationSynced(item.id, serverVersion: 5);
            } else {
              db.markMutationFailed(item.id, answer);
            }
          }
          // With nothing left to send, a round downloads: the server's version of the record comes back.
          if (truth != null && db.syncQueueItems(tenantId: owner.schoolId).isEmpty) {
            await db.upsertLocalRecord(tenantId: owner.schoolId, entityType: truthType, entityId: truthId, payload: truth!, serverVersion: 4);
          }
        },
      );

  setUp(() async {
    rounds = 0;
    truth = null;
    serverSays = (_) => 'ok';
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([owner, finance]);
    await session.selectSchool(owner);
  });

  tearDown(() => db.close());

  group('payroll batches with a server', () {
    PayrollBatchRepository repo({bool server = true}) =>
        PayrollBatchRepository(database: db, session: session, confirm: server ? confirm() : null);

    Future<Map<String, Object?>?> stored() async =>
        (await db.getLocalRecord(tenantId: owner.schoolId, entityType: 'payroll_batch', entityId: '2026-09'))?.payload;

    test('preparing is sent at once, and accepted quietly', () async {
      await repo().prepare('2026-09', [row('S1', 'Aisha', 300000, 30000), row('S2', 'Musa', 200000, 20000)]);
      expect(rounds, 1);
      expect((await stored())!['status'], 'prepared');
      expect(db.syncQueueItems(tenantId: owner.schoolId), isEmpty);
    });

    test('a refusal is shown in the server\'s words and the batch is not left on this device', () async {
      serverSays = (_) => 'The amount for Aisha does not match their salary. Refresh and prepare again.';
      await expectLater(
        repo().prepare('2026-09', [row('S1', 'Aisha', 300000, 30000)]),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('does not match their salary'))),
      );
      expect(await stored(), isNull);
      expect(db.syncQueueItems(tenantId: owner.schoolId), isEmpty);
    });

    test('a refused approval goes back to what the server holds', () async {
      await db.upsertLocalRecord(
        tenantId: owner.schoolId, entityType: 'payroll_batch', entityId: '2026-09', serverVersion: 4,
        payload: {'period': '2026-09', 'status': 'prepared', 'lines': [], 'total': 450000, 'preparedByMembershipId': finance.id},
      );
      truthType = 'payroll_batch';
      truthId = '2026-09';
      truth = {'period': '2026-09', 'status': 'prepared', 'lines': [], 'total': 450000, 'preparedByMembershipId': finance.id};
      serverSays = (_) => 'The salary for Aisha Bello changed after this batch was prepared. Ask for it to be prepared again.';

      await expectLater(repo().approve('2026-09'), throwsA(isA<StateError>().having((e) => e.message, 'message', contains('changed after this batch'))));
      expect((await stored())!['status'], 'prepared');            // the screen shows the truth, not the refused approval
      expect(db.syncQueueItems(tenantId: owner.schoolId), isEmpty);
    });

    test('rejecting needs a reason when there is a server, and not on demo data', () async {
      await db.upsertLocalRecord(
        tenantId: owner.schoolId, entityType: 'payroll_batch', entityId: '2026-09', serverVersion: 4,
        payload: {'period': '2026-09', 'status': 'prepared', 'lines': [], 'total': 1, 'preparedByMembershipId': finance.id},
      );
      await expectLater(repo().reject('2026-09', '   '), throwsArgumentError);
      await repo().reject('2026-09', 'Wrong month');
      expect((await stored())!['status'], 'rejected');

      await db.upsertLocalRecord(
        tenantId: owner.schoolId, entityType: 'payroll_batch', entityId: '2026-09', serverVersion: 5,
        payload: {'period': '2026-09', 'status': 'prepared', 'lines': [], 'total': 1, 'preparedByMembershipId': finance.id},
      );
      await repo(server: false).reject('2026-09', '');             // demo: unchanged
    });
  });

  group('scholarships and discounts with a server', () {
    test('finance\'s request gets a number no other device can pick, and no demo requests are made up', () async {
      await session.selectSchool(finance);
      final requests = FinanceConcessionsRepository(localDatabase: db, schoolSession: session, confirm: confirm());
      final before = await requests.load();
      expect(before.requests, isEmpty);                              // nothing invented

      final first = await requests.submit(
        student: 'Yusuf Bello', className: 'JSS 2B', type: FinanceConcessionType.scholarship,
        grossFee: 185000, amount: 75000, reason: 'Founder Scholarship', requestedBy: 'Finance Office',
      );
      final second = await requests.submit(
        student: 'Hafsa Abdullahi', className: 'Primary 3', type: FinanceConcessionType.discount,
        grossFee: 145000, amount: 10000, reason: 'Sibling', requestedBy: 'Finance Office',
      );
      expect((first.success, second.success), (true, true));
      final ids = (await requests.load()).requests.map((r) => r.id).toList();
      expect(ids.toSet().length, 2);
      for (final id in ids) {
        expect(RegExp(r'^CNC-\d{4}-[0-9A-Z]+-[0-9A-Z]+$').hasMatch(id), isTrue, reason: id);
        expect(RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{2,63}$').hasMatch(id), isTrue, reason: 'the server accepts it');
      }
    });

    test('a request the server refuses is reported and not left behind', () async {
      await session.selectSchool(finance);
      serverSays = (_) => 'The concession cannot be more than the term fee.';
      final requests = FinanceConcessionsRepository(localDatabase: db, schoolSession: session, confirm: confirm());
      final result = await requests.submit(
        student: 'Yusuf Bello', className: 'JSS 2B', type: FinanceConcessionType.scholarship,
        grossFee: 100000, amount: 90000, reason: '', requestedBy: 'Finance Office',
      );
      expect(result.success, isFalse);
      expect(result.message, 'The concession cannot be more than the term fee.');
      expect((await requests.load()).requests, isEmpty);
    });

    test('on demo data the numbers and the sample requests are as before', () async {
      final requests = FinanceConcessionsRepository(localDatabase: db, schoolSession: session);
      expect((await requests.load()).requests, isNotEmpty);           // the sample requests
      final result = await requests.submit(
        student: 'Aisha Ibrahim', className: 'Nursery 2', type: FinanceConcessionType.discount,
        grossFee: 100000, amount: 5000, reason: '', requestedBy: 'Finance Office',
      );
      expect(result.success, isTrue);
      expect((await requests.load()).requests.any((r) => RegExp(r'^CNC-2026-\d{3}$').hasMatch(r.id)), isTrue);
    });

    Future<ConcessionRequest> pendingRequest() async {
      const request = ConcessionRequest(
        id: 'CNC-2026-900', student: 'Yusuf Bello', className: 'JSS 2B', type: ConcessionType.scholarship,
        grossFee: 185000, amount: 75000, reason: 'Founder', requestedBy: 'Finance Office', requestedByRole: 'Finance Office',
        requestedAt: '02 Sep 2026', status: ConcessionStatus.pendingApproval,
      );
      await db.upsertLocalRecord(tenantId: owner.schoolId, entityType: 'concession_request', entityId: request.id, payload: request.toJson(), serverVersion: 3);
      return request;
    }

    test('the owner\'s approval is sent at once, and a decline must say why', () async {
      final request = await pendingRequest();
      final decisions = ConcessionRepository(localDatabase: db, schoolSession: session, confirm: confirm());
      await expectLater(decisions.decide(request: request, status: ConcessionStatus.declined, note: '  '), throwsArgumentError);
      expect(rounds, 0);                                              // nothing was sent
      await decisions.decide(request: request, status: ConcessionStatus.approved, note: '');
      expect(rounds, 1);
      final stored = await db.getLocalRecord(tenantId: owner.schoolId, entityType: 'concession_request', entityId: request.id);
      expect(stored!.payload['status'], 'approved');
    });

    test('a decision the server refuses is shown, and the request goes back to what the school holds', () async {
      final request = await pendingRequest();
      truthType = 'concession_request';
      truthId = request.id;
      truth = request.toJson();
      serverSays = (_) => 'This request was already approved.';
      final decisions = ConcessionRepository(localDatabase: db, schoolSession: session, confirm: confirm());
      await expectLater(
        decisions.decide(request: request, status: ConcessionStatus.declined, note: 'No'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'This request was already approved.')),
      );
      final stored = await db.getLocalRecord(tenantId: owner.schoolId, entityType: 'concession_request', entityId: request.id);
      expect(stored!.payload['status'], 'pendingApproval');
    });

    test('on demo data a decline needs no note and nothing is sent', () async {
      final request = await pendingRequest();
      await ConcessionRepository(localDatabase: db, schoolSession: session)
          .decide(request: request, status: ConcessionStatus.declined, note: '');
      expect(rounds, 0);
    });
  });
}
