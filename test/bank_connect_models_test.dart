import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/bankconnect/domain/bank_labels.dart';
import 'package:schoolos_app/features/bankconnect/domain/bank_models.dart';
import 'package:schoolos_app/features/bankconnect/domain/collections_summary.dart';
import 'package:schoolos_app/features/bankconnect/domain/payment_models.dart';

import 'bank_connect_fixtures.dart';

void main() {
  group('money', () {
    test('kobo are shown as naira, with kobo only when there are some', () {
      expect(formatMoneyMinor(5000000), '₦50,000');
      expect(formatMoneyMinor(150050), '₦1,500.50');
      expect(formatMoneyMinor(5), '₦0.05');
      expect(formatMoneyMinor(0), '₦0');
      expect(formatMoneyMinor(123456789), '₦1,234,567.89');
      expect(formatMoneyMinor(100, currency: 'USD'), 'USD 1');
    });

    test('what a person types as naira becomes whole kobo, and nonsense is refused', () {
      expect(parseNairaToMinor('1500'), 150000);
      expect(parseNairaToMinor('1,500.5'), 150050);
      expect(parseNairaToMinor('1500.50'), 150050);
      expect(parseNairaToMinor('₦2,000'), 200000);
      expect(parseNairaToMinor(' 40 '), 4000);
      for (final bad in ['', 'abc', '1.234', '-5', '1e3', '1..5', '.5', '5.']) {
        expect(parseNairaToMinor(bad), isNull, reason: bad);
      }
    });

    test('how long ago is said kindly', () {
      final now = DateTime(2026, 9, 25, 12);
      expect(whenLabel(null, now: now), 'never');
      expect(whenLabel(now, now: now), 'just now');
      expect(whenLabel(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
      expect(whenLabel(now.subtract(const Duration(hours: 3)), now: now), '3 h ago');
      expect(whenLabel(now.subtract(const Duration(days: 1)), now: now), 'yesterday');
      expect(whenLabel(now.subtract(const Duration(days: 3)), now: now), '3 days ago');
      expect(whenLabel(DateTime(2026, 8, 12), now: now), '12 Aug');
      expect(whenLabel(DateTime(2025, 8, 12), now: now), '12 Aug 2025');
    });
  });

  group('providers', () {
    test('a bank SchoolOS has no documentation for is listed but cannot be used', () {
      final info = ProvidersInfo.fromJson(providersJson());
      final gtbank = info.providers.firstWhere((p) => p.code == 'gtbank');
      final sandbox = info.providers.firstWhere((p) => p.code == 'sandbox');
      expect(gtbank.available, isFalse);
      expect(gtbank.capabilities.supportsTransactionSync, isFalse);
      expect(gtbank.capabilities.supportsWebhooks, isFalse);
      expect(sandbox.available, isTrue);
      expect(sandbox.isSandbox, isTrue);
      expect(sandbox.usesCredentials && sandbox.usesAuthorization, isTrue);
      expect(sandbox.credentialFields.map((f) => f.name), ['sandbox_key', 'account_number']);
      expect(sandbox.credentialFields.first.secret, isTrue);
      expect(sandbox.credentialFields.last.secret, isFalse);
      expect(info.canManage && info.secureStorageReady, isTrue);
    });

    test('a missing or odd field never crashes the screen', () {
      final info = ProvidersInfo.fromJson({'providers': [{'code': 'x'}], 'canManage': 'yes'});
      expect(info.providers.single.displayName, 'x');
      expect(info.providers.single.available, isFalse);
      expect(info.canManage, isFalse);
      expect(ProvidersInfo.fromJson({}).providers, isEmpty);
    });
  });

  group('connections', () {
    test('a connection carries only what is safe to show', () {
      final c = BankConnection.fromJson(connectionJson());
      expect((c.bankTitle, c.accountMask, c.title, c.status), ('Sandbox Bank', '****6789', 'Tuition Collection', 'connected'));
      expect((c.isConnected, c.isPending, c.needsAttention, c.isClosed), (true, false, false, false));
      expect(c.isSandbox, isTrue);
      expect(c.capabilities.supportsTransactionSync, isTrue);
    });

    test('an unnamed account is called after what it collects', () {
      expect(BankConnection.fromJson(connectionJson(label: '', purpose: 'transport')).title, 'Transport account');
    });

    test('states', () {
      expect(BankConnection.fromJson(connectionJson(status: 'needs_reauth')).needsAttention, isTrue);
      expect(BankConnection.fromJson(connectionJson(status: 'error')).needsAttention, isTrue);
      expect(BankConnection.fromJson(connectionJson(status: 'pending')).isPending, isTrue);
      expect(BankConnection.fromJson(connectionJson(status: 'revoked')).isClosed, isTrue);
      expect(BankConnection.fromJson(connectionJson(status: 'disabled')).isDisabled, isTrue);
    });

    test('an action result carries the check, the sync and the callback address shown once', () {
      final result = ConnectionActionResult.fromJson({
        'connection': connectionJson(),
        'test': {'ok': false, 'code': 'bad_credentials', 'message': 'The provider did not accept these credentials.'},
        'sync': {'ok': true, 'fetched': 3, 'created': 2, 'duplicates': 1, 'invalid': 0, 'more': false, 'code': '', 'message': ''},
        'webhook': {'path': 'bank-webhooks/sandbox/abc/'},
        'providerRevoked': true,
      });
      expect(result.check!.ok, isFalse);
      expect(result.check!.code, 'bad_credentials');
      expect((result.sync!.created, result.sync!.duplicates), (2, 1));
      expect(result.webhookPath, 'bank-webhooks/sandbox/abc/');
      expect(result.providerRevoked, isTrue);
      expect(ConnectionActionResult.fromJson({'connection': connectionJson()}).webhookPath, isNull);
    });

    test('failure codes are turned into words a bursar can act on', () {
      expect(bankErrorLabel('bad_credentials'), contains('Reconnect'));
      expect(bankErrorLabel('account_changed'), contains('different account'));
      expect(bankErrorLabel(''), '');
      expect(bankErrorLabel('weird'), contains('weird'));
    });
  });

  group('payments', () {
    test('the engine\'s reasons are split into students and notes', () {
      final p = BankPayment.fromJson(paymentJson());
      expect(p.candidates.map((c) => c.studentName), ['Aisha Bello', 'Bilal Bello']);
      expect(p.candidates.first.signals.map((s) => s.points), [35, 30]);
      expect(p.notes.single, contains('2 students fit about equally well'));
      expect((p.status, p.confidence, p.amountMinor, p.isCredit), ('requires_review', 65, 5000000, true));
      expect(p.senderAccountMask, '****9012');
    });

    test('only current allocations count, and what is unallocated can be worked out', () {
      final p = BankPayment.fromJson(paymentJson(status: 'partially_matched', allocations: [
        {'id': 'a1', 'studentId': 's1', 'studentName': 'Aisha Bello', 'studentCode': 'BG-0042', 'purpose': 'tuition', 'amountMinor': 1000000, 'source': 'manual', 'superseded': false},
        {'id': 'a2', 'studentId': 's2', 'studentName': 'Bilal Bello', 'studentCode': 'BG-0043', 'purpose': 'tuition', 'amountMinor': 2000000, 'source': 'auto', 'superseded': true},
      ]));
      expect(p.allocations.length, 2);
      expect(p.activeAllocations.single.studentName, 'Aisha Bello');
      expect(p.allocatedMinor, 1000000);
    });

    test('an unnamed sender is said so', () {
      expect(BankPayment.fromJson(paymentJson(sender: '')).senderTitle, 'Unnamed sender');
    });

    test('a page of the review queue carries its counts', () {
      final page = PaymentPage.fromJson(pageJson([paymentJson()], counts: {'requires_review': 2, 'unmatched': 1}, more: true));
      expect((page.total, page.hasMore), (1, true));
      expect(page.counts, {'requires_review': 2, 'unmatched': 1});
    });

    test('a decision history reads back', () {
      final p = BankPayment.fromJson(paymentJson(decisions: [
        {'id': 'd1', 'action': 'assign', 'note': 'Father confirmed', 'actorName': 'Ada Owner', 'at': '2026-09-25T10:00:00+01:00', 'before': {'status': 'requires_review'}, 'after': {'status': 'matched'}},
      ]));
      expect(p.decisions.single.actorName, 'Ada Owner');
      expect((p.decisions.single.fromStatus, p.decisions.single.toStatus), ('requires_review', 'matched'));
      expect(decisionActionLabel('assign'), 'Assigned to a student');
    });

    test('a student found by search says who they are', () {
      final s = StudentHit.fromJson({'id': 's1', 'name': 'Aisha Bello', 'studentCode': 'BG-0042', 'admissionNumber': 'ADM/1', 'className': 'Primary 3', 'status': 'active'});
      expect(s.subtitle, 'BG-0042 · Primary 3');
    });
  });

  group('summary', () {
    test('it reads what the server worked out and adds nothing', () {
      final s = CollectionsSummary.fromJson((summaryJson(sandboxHidden: 3)['summary']) as Map<String, dynamic>);
      expect((s.available, s.today.amountMinor, s.thisWeek.count, s.thisTerm!.amountMinor), (true, 5000000, 3, 45000000));
      expect(s.byPurpose.first.purpose, 'tuition');
      expect(s.byBank.single.accountMask, '****1111');
      expect((s.reconciliation.reconciledMinor, s.reconciliation.unreconciledMinor, s.reconciliation.totalMinor), (30000000, 15000000, 45000000));
      expect(s.reconciliation.pendingReviewCount, 2);
      expect(s.sandboxHidden, 3);
      expect(s.recent.single.senderName, 'Musa Bello');
    });

    test('what is still owed is never claimed to be known', () {
      expect(CollectionsSummary.fromJson((summaryJson()['summary']) as Map<String, dynamic>).outstandingFeesAvailable, isFalse);
      expect(CollectionsSummary.fromJson(<String, dynamic>{}).outstandingFeesAvailable, isFalse);
    });

    test('with no open term there is no term total', () {
      final json = Map<String, dynamic>.from(summaryJson()['summary'] as Map)..['thisTerm'] = null;
      expect(CollectionsSummary.fromJson(json).thisTerm, isNull);
    });

    test('with no account connected the summary says so', () {
      expect(CollectionsSummary.fromJson((summaryJson(available: false)['summary']) as Map<String, dynamic>).available, isFalse);
    });
  });
}
