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
    test('the two providers are listed with what each asks for and what each can really do', () {
      final info = ProvidersInfo.fromJson(providersJson());
      expect(info.providers.map((p) => p.code), ['paystack', 'monnify']);
      final paystack = info.provider('paystack')!;
      final monnify = info.provider('monnify')!;
      expect(paystack.credentialFields.map((f) => f.name), ['secret_key']);
      expect(paystack.credentialFields.single.secret, isTrue);
      expect(paystack.settingFields.single.name, 'preferred_bank');
      expect(monnify.credentialFields.map((f) => f.name), ['api_key', 'secret_key', 'contract_code']);
      expect(monnify.credentialFields.last.secret, isFalse);
      expect(monnify.capabilities.requiresCustomerKyc, isTrue);
      expect(monnify.customerRequirements, ['email', 'identity']);
      expect((monnify.capabilities.supportsStaticAccounts, monnify.capabilities.supportsDynamicAccounts), (true, true));
      expect((paystack.accountLabel, monnify.accountLabel), ('Account number', 'Account number'));
      expect(paystack.webhook.mode, 'dashboard');
      expect(monnify.webhook.verification, 'hmac_sha512');
      expect(info.provider('remita'), isNull);  // Remita is for Mandates, not Smart Money Collection
      expect(paystack.onboarding, contains('your school\'s own Paystack'));
      expect(info.canManage && info.secureStorageReady, isTrue);
      expect(info.provider('gtbank'), isNull);
    });

    test('there is nothing to say about a settlement account: none is asked for', () {
      for (final p in ProvidersInfo.fromJson(providersJson()).providers) {
        for (final f in p.credentialFields) {
          expect(f.name, isNot(contains('account_number')));
        }
      }
    });

    test('a missing or odd field never crashes the screen', () {
      final info = ProvidersInfo.fromJson({'providers': [{'code': 'x'}], 'canManage': 'yes'});
      expect(info.providers.single.displayName, 'x');
      expect(info.providers.single.available, isFalse);
      expect(info.canManage, isFalse);
      expect(ProvidersInfo.fromJson({}).providers, isEmpty);
    });

    test('provider codes are said as a school says them', () {
      expect(providerDisplayName('paystack'), 'Paystack');
      expect(providerDisplayName('monnify'), 'Monnify');
      expect(providerDisplayName(''), 'Provider');
    });
  });

  group('connections', () {
    test('a connection carries only what is safe to show', () {
      final c = ProviderConnection.fromJson(connectionJson(label: 'Main collections'));
      expect((c.providerName, c.merchantName, c.merchantReference, c.title, c.status), ('Paystack', 'BrightGate Academy', '****7855', 'Main collections', 'connected'));
      expect((c.isConnected, c.isActiveProvider, c.isLive, c.webhookActive), (true, true, true, true));
      expect(c.capabilities.supportsWebhooks, isTrue);
    });

    test('an unnamed connection is called after its provider', () {
      expect(ProviderConnection.fromJson(connectionJson(label: '')).title, 'Paystack');
    });

    test('the webhook is not active until a verified event has arrived', () {
      final waiting = ProviderConnection.fromJson(connectionJson(webhook: 'awaiting_event'));
      expect(waiting.webhookActive, isFalse);
      expect(waiting.webhookConfirmedAt, isNull);
      expect(webhookStatusLabel('awaiting_event'), 'Webhook waiting for its first event');
      expect(webhookStatusLabel('active'), 'Webhook active');
    });

    test('states', () {
      expect(ProviderConnection.fromJson(connectionJson(status: 'needs_reauth')).needsAttention, isTrue);
      expect(ProviderConnection.fromJson(connectionJson(status: 'error')).needsAttention, isTrue);
      expect(ProviderConnection.fromJson(connectionJson(status: 'revoked')).isClosed, isTrue);
      expect(ProviderConnection.fromJson(connectionJson(status: 'disabled')).isDisabled, isTrue);
      expect(ProviderConnection.fromJson(connectionJson(environment: 'test')).isLive, isFalse);
      expect(environmentLabel('live'), 'Live');
      expect(environmentLabel('test'), 'Test');
    });

    test('an action result carries the check and the webhook setup', () {
      final result = ConnectionActionResult.fromJson({
        'connection': connectionJson(),
        'test': {'ok': false, 'code': 'bad_credentials', 'message': 'The provider did not accept these credentials.'},
        'webhook': webhookJson(),
      });
      expect(result.check!.ok, isFalse);
      expect(result.check!.code, 'bad_credentials');
      expect(result.webhook!.address, 'https://school.example/api/v1/bank-webhooks/paystack/TOKEN123/');
      expect(result.webhook!.isActive, isFalse);
      expect(result.webhook!.where, contains('Paystack dashboard'));
      expect(ConnectionActionResult.fromJson({'connection': connectionJson()}).webhook, isNull);
    });

    test('a webhook address falls back to its path when the server does not know its own public address', () {
      final setup = WebhookSetup.fromJson({...webhookJson(), 'url': ''});
      expect(setup.address, 'bank-webhooks/paystack/TOKEN123/');
    });

    test('failure codes are turned into words a bursar can act on', () {
      expect(bankErrorLabel('bad_credentials'), contains('Replace them'));
      expect(bankErrorLabel('environment_mismatch'), contains('other mode'));
      expect(bankErrorLabel('live_not_configured'), contains('not set up'));
      expect(bankErrorLabel(''), '');
      expect(bankErrorLabel('weird'), contains('weird'));
    });

    test('the activity trail names what happened', () {
      expect(auditKindLabel('provider_connected'), contains('Connected'));
      expect(auditKindLabel('provider_switched'), contains('active collection provider'));
      expect(auditKindLabel('unknown_kind'), 'unknown_kind');
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

    test('a payment says which provider reported it and which family account it was paid into', () {
      final p = BankPayment.fromJson(paymentJson());
      expect((p.provider, p.receivingAccountRef), ('paystack', '9930000902'));
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
      expect(s.byProvider.single.title, 'Main collections');
      expect((s.byProvider.single.provider, s.byProvider.single.environment), ('paystack', 'live'));
      expect((s.providers.connected, s.providers.activeProvider, s.providers.activeMerchant), (1, 'paystack', 'BrightGate Academy'));
      expect((s.reconciliation.reconciledMinor, s.reconciliation.unreconciledMinor, s.reconciliation.totalMinor), (30000000, 15000000, 45000000));
      expect(s.reconciliation.pendingReviewCount, 2);
      expect(s.sandboxHidden, 3);
      expect((s.recent.single.senderName, s.recent.single.provider), ('Musa Bello', 'paystack'));
    });

    test('what is still owed is never claimed to be known', () {
      expect(CollectionsSummary.fromJson((summaryJson()['summary']) as Map<String, dynamic>).outstandingFeesAvailable, isFalse);
      expect(CollectionsSummary.fromJson(<String, dynamic>{}).outstandingFeesAvailable, isFalse);
    });

    test('what the school is owed is read by session and term, and only when the server says it is available', () {
      final s = CollectionsSummary.fromJson((summaryJson(owed: true)['summary']) as Map<String, dynamic>);
      expect(s.outstandingFeesAvailable, isTrue);
      expect((s.owed.available, s.owed.outstandingMinor, s.owed.arrearsMinor, s.owed.currentMinor, s.owed.familiesOwing), (true, 29000000, 13000000, 16000000, 2));
      expect(s.owed.creditMinor, 500000);
      expect(s.owed.periods.map((p) => p.label), ['2026/2027 · First Term', '2026/2027 · Second Term']);
      expect((s.owed.periods.first.isPast, s.owed.periods.first.collectedPercent), (true, 32));
      expect((s.owed.periods.last.isCurrent, s.owed.periods.last.collectedPercent), (true, 0));
      final none = CollectionsSummary.fromJson((summaryJson()['summary']) as Map<String, dynamic>);
      expect(none.owed.available, isFalse);
      expect(none.owed.periods, isEmpty);
    });

    test('a period with nothing payable has no percentage', () {
      expect(OwedPeriod.fromJson(<String, dynamic>{'label': 'X'}).collectedPercent, isNull);
    });

    test('with no open term there is no term total', () {
      final json = Map<String, dynamic>.from(summaryJson()['summary'] as Map)..['thisTerm'] = null;
      expect(CollectionsSummary.fromJson(json).thisTerm, isNull);
    });

    test('with no provider connected the summary says so', () {
      final s = CollectionsSummary.fromJson((summaryJson(available: false)['summary']) as Map<String, dynamic>);
      expect((s.available, s.providers.activeProvider), (false, ''));
    });
  });
}
