import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/mandates/domain/mandate_labels.dart';
import 'package:schoolos_app/features/mandates/domain/mandate_models.dart';

import 'mandates_fixtures.dart';

void main() {
  group('the recorded server responses contain no account number and no credential', () {
    test('nothing the server sent carries a full account number or a provider secret', () {
      for (final file in Directory('test/fixtures/mandates').listSync().whereType<File>()) {
        final text = file.readAsStringSync();
        for (final account in recordedAccountNumbers) {
          expect(text, isNot(contains(account)), reason: '${file.path} has a full account number');
        }
        expect(text, isNot(contains('sandbox-key')), reason: '${file.path} has a credential');
        // A field NAMED api_key is only the form asking for one; a JSON key called that would be a secret being sent.
        expect(RegExp(r'"(api_key|api_token|accountNumber|sealed[A-Za-z]*|secretKey|password)"\s*:').hasMatch(text), isFalse, reason: '${file.path} carries a secret field');
      }
    });
  });

  group('providers', () {
    final info = MandateProvidersInfo.fromJson(real('providers'));

    test('Remita and Lendsqr are both offered, and neither is "the active provider"', () {
      expect(info.providers.map((p) => p.code), containsAll(['remita', 'lendsqr']));
      expect(jsonEncode(real('providers')).toLowerCase(), isNot(contains('isactive')));
      expect(jsonEncode(real('connections_both')).toLowerCase(), isNot(contains('isactive')));
      expect(info.secureStorageReady, isTrue);
    });

    test('Remita asks for the school\'s own merchant id, service type, API key and API token, and marks the secrets', () {
      final remita = info.provider('remita')!;
      expect(remita.credentialFields.map((f) => f.name), ['merchant_id', 'service_type_id', 'api_key', 'api_token']);
      expect(remita.credentialFields.where((f) => f.secret).map((f) => f.name), ['api_key', 'api_token']);
      expect(remita.capabilities.supportsManualDebit, isTrue);
      expect(remita.capabilities.supportsWebhooks, isTrue);
      expect(remita.environments, ['test', 'live']);
    });

    test('Lendsqr can make, activate and watch mandates but the server does not claim it can debit, and live use is gated', () {
      final lendsqr = info.provider('lendsqr')!;
      expect(lendsqr.capabilities.supportsManualDebit, isFalse);
      expect(lendsqr.capabilities.requiresProviderCustomer, isTrue);
      expect(lendsqr.capabilities.supportsTransferActivation, isTrue);
      expect(lendsqr.liveEnabled, isFalse);
      expect(lendsqr.liveWhy, isNotEmpty);
      expect(lendsqr.liveNote, contains('licensed')); // what must be true first, never a claim that this school is eligible
      expect(lendsqr.credentialFields.map((f) => f.name), ['api_key']);
    });

    test('the permissions say who may connect providers', () {
      expect(info.permissions.canManageProviders, isTrue);
      expect(info.permissions.canApprove, isTrue);
    });
  });

  group('connections', () {
    final info = MandateConnectionsInfo.fromJson(real('connections_both'));

    test('a school can hold the test provider and Remita together, each with its own mandates', () {
      expect(info.connections.map((c) => c.provider), ['sandbox', 'remita']);
      final sandbox = info.connections.first;
      expect((sandbox.activeMandates, sandbox.liveMandates, sandbox.totalMandates), (1, 2, 2));
      expect(sandbox.isSandbox, isTrue);
      expect(sandbox.usable, isTrue);
    });

    test('a callback is not called active until a real event has arrived', () {
      final remita = info.connections.last;
      expect(remita.capabilities.supportsWebhooks, isTrue);
      expect(remita.webhookStatus, 'awaiting_event');
      expect(remita.merchantReference, startsWith('****')); // masked
    });

    test('connecting answers with a connection and never a credential', () {
      final connection = MandateConnection.fromJson(Map<String, dynamic>.from(real('connect_remita')['connection'] as Map));
      expect(connection.provider, 'remita');
      expect(connection.status, 'connected');
      expect(jsonEncode(real('connect_remita')), isNot(contains('api_key')));
    });

    test('a test answers with the connection and whether it worked', () {
      final result = MandateActionResult.fromJson({'connection': real('connect_remita')['connection'], 'test': {'ok': false, 'code': 'bad_credentials', 'message': 'The provider did not accept them.'}});
      expect(result.testOk, isFalse);
      expect(result.testCode, 'bad_credentials');
      expect(result.connection!.provider, 'remita');
      expect(MandateActionResult.fromJson({'connection': real('connect_remita')['connection']}).testOk, isNull);
    });

    test('the callback setup is an address to give the provider and why it is confirmed with the provider', () {
      final hook = MandateWebhook.fromJson(Map<String, dynamic>.from(real('webhook')['webhook'] as Map));
      expect(hook.path, startsWith('mandate-webhooks/remita/'));
      expect(hook.verification, 'requery');
      expect(hook.note, contains('does not sign'));
      expect(hook.status, 'awaiting_event');
    });
  });

  group('a mandate as staff see it', () {
    final mandate = Mandate.fromJson(Map<String, dynamic>.from(real('mandate_detail')['mandate'] as Map));

    test('it belongs to a family and a payer, and shows a bank and a masked account only', () {
      expect((mandate.familyName, mandate.payer.name, mandate.payer.hasAppAccount), ('Bello family', 'Bello Parent', true));
      expect(mandate.bankName, 'Test Bank');
      expect(mandate.accountMask, '****6789');
      expect(mandate.accountMask, isNot(contains('0123')));
    });

    test('one waiting for the payer is not active, is not debit ready, and says why', () {
      expect(mandate.status, 'pending_consent');
      expect(mandate.waitingForPayer, isTrue);
      expect(mandate.debitReady, isFalse);
      expect(mandate.debitReadyReason, contains('not authorised'));
      expect(mandate.consentAt, isNull);
      expect(mandate.consentRoute, 'payer_app');
    });

    test('the maximum is a limit on the payer\'s authority, in kobo, with what it covers', () {
      expect(mandate.maximumAmountMinor, 50000000);
      expect(mandate.maximumNote, isNotEmpty);
    });

    test('its history is what the server recorded, oldest first', () {
      expect(mandate.history.map((e) => e.kind), ['started']);
      expect(mandate.history.first.to, 'pending_consent');
    });

    test('a list keeps its counts by status and who may do what', () {
      final page = MandatesPage.fromJson(real('mandates'));
      expect(page.mandates.map((m) => m.status), ['active', 'pending_consent']);
      expect(page.counts['active'], 1);
      expect(page.counts['pending_consent'], 1);
      expect(page.permissions.canManage, isTrue);
      expect(page.mandates.first.debitReady, isTrue);
    });
  });

  group('a mandate as the payer sees it', () {
    final mine = Mandate.fromJson(maps(real('my_mandates_consent')['mandates']).first);

    test('the payer is shown the school, the bank, the masked account and the exact words they are asked to agree to', () {
      expect(mine.schoolName, 'BrightGate');
      expect(mine.consentRequired, isTrue);
      expect(mine.consentText, contains('Bello Parent'));
      expect(mine.consentText, contains('6789'));
      expect(mine.consentText, isNot(contains('0123456789')));
      expect(mine.consentTextHash, hasLength(64));
      expect(mine.consentVersion, isNotEmpty);
    });

    test('after they authorise and activate, the mandate is active and debit ready, and the consent was theirs in the app', () {
      final active = Mandate.fromJson(Map<String, dynamic>.from(real('activation_confirm')['mandate'] as Map));
      expect(active.status, 'active');
      expect(active.debitReady, isTrue);
      expect(active.consentChannel, 'payer_app');
      expect(active.consentAt, isNotNull);
      expect(active.consentRequired, isFalse);
    });

    test('the one-time password field is asked for by name and label, never given', () {
      final fields = [for (final f in maps(real('activation_request')['fields'])) ActivationField.fromJson(f)];
      expect(fields.single.name, 'OTP');
      expect(fields.single.label, isNotEmpty);
    });
  });

  group('who may start a mandate', () {
    test('the payers of a family are named without contact details, and say whether they have an account in the app', () {
      final payers = [for (final p in maps(real('family_payers')['payers'])) FamilyPayer.fromJson(p)];
      expect(payers.single.name, 'Bello Parent');
      expect(payers.single.isPrimaryPayer, isTrue);
      expect(payers.single.hasAppAccount, isTrue);
      expect(jsonEncode(real('family_payers')), isNot(contains('@')));
    });

    test('the banks a provider can make a mandate on say whether the payer can activate it themselves', () {
      final banks = [for (final b in maps(real('banks')['banks'])) BankOption.fromJson(b)];
      expect(banks.map((b) => b.code), ['058', '044']);
      expect(banks.first.selfActivation, isTrue);
      expect(banks.last.selfActivation, isFalse);
    });
  });

  group('debit batches', () {
    test('a batch waiting for approval says who prepared and submitted it and what it would debit, in kobo', () {
      final detail = DebitBatchDetail.fromJson(real('batch_submitted'));
      final b = detail.batch;
      expect(b.status, 'pending_approval');
      expect(b.editable, isFalse);
      expect((b.totalItems, b.totalAmountMinor, b.totalOutstandingMinor), (2, 38000000, 38000000));
      expect(b.preparedBy!.id, makerMembership.id);
      expect(b.submittedBy!.id, makerMembership.id);
      expect(b.approvedBy, isNull);
      expect(b.snapshotHash, hasLength(64));
      expect(b.sessionName, '2026/2027');
      expect(b.termName, 'First Term');
      expect(detail.permissions.canPrepare, isTrue);
      expect(detail.permissions.canApprove, isFalse); // the maker
      expect(detail.summary.families, 2);
      expect(detail.summary.byEligibility['eligible'], 2);
    });

    test('a finished batch says who approved it and keeps the successes', () {
      final b = DebitBatchDetail.fromJson(Map<String, dynamic>.from(real('batch_progress'))).batch;
      expect(b.status, 'completed');
      expect((b.successCount, b.failedCount), (2, 0));
      expect(b.approvedBy!.id, checkerMembership.id);
      expect(b.approvedBy!.id, isNot(b.preparedBy!.id)); // a different person approved it
    });

    test('an item carries the ledger\'s figures and the mandate\'s masked account, never a full account number', () {
      final page = DebitItemsPage.fromJson(real('batch_items'));
      expect(page.items, hasLength(2));
      final bello = page.items.firstWhere((i) => i.familyName == 'Bello family');
      expect((bello.outstandingMinor, bello.proposedDebitMinor), (28000000, 28000000));
      expect(bello.accountMask, '****6789');
      expect(bello.eligibilityStatus, 'eligible');
      expect(bello.canSelect, isTrue);
      expect(bello.amountAdjusted, isFalse);
      expect(page.version, isPositive);
    });

    test('progress says how many were debited, failed, unknown and queued', () {
      final progress = DebitProgress.fromJson(Map<String, dynamic>.from(real('batch_progress')['progress'] as Map));
      expect((progress.total, progress.success, progress.failed, progress.unknown, progress.queued, progress.done), (2, 2, 0, 0, 0, true));
    });

    test('the batch history is what happened and when', () {
      final events = [for (final e in maps(real('batch_events')['events'])) BatchEvent.fromJson(e)];
      expect(events.map((e) => e.kind), ['created', 'preview_refreshed', 'selection_changed', 'submitted', 'approved', 'started']);
      expect(events.every((e) => batchEventLabel(e.kind) != e.kind), isTrue, reason: 'each has words');
    });

    test('a retry says which were retried and which need a fresh maker and checker', () {
      final retry = RetryResult.fromJson({
        'retried': ['a'],
        'needsFreshApproval': [
          {'itemId': 'b', 'family': 'Sani family', 'code': 'changed_since_approval'},
        ],
      });
      expect(retry.retried, ['a']);
      expect(retry.needsFreshApproval, ['Sani family']);
    });

    test('the batches list is the checker\'s view: they may approve and may not prepare', () {
      final batches = real('batches');
      final permissions = MandatePermissions.fromJson(Map<String, dynamic>.from(batches['permissions'] as Map));
      expect((permissions.canApprove, permissions.canPrepare), (true, false));
      expect(DebitBatch.fromJson(maps(batches['batches']).single).status, 'pending_approval');
    });
  });

  group('debits and the overview', () {
    test('a confirmed debit says it was put towards the fees, with a masked account', () {
      final rows = [for (final t in maps(real('transactions')['transactions'])) MandateTransactionRow.fromJson(t)];
      expect(rows, hasLength(2));
      expect(rows.every((t) => t.status == 'success' && t.settled), isTrue);
      expect(rows.map((t) => t.amountMinor).reduce((a, b) => a + b), 38000000);
      expect(rows.every((t) => t.accountMask.startsWith('****')), isTrue);
    });

    test('the overview counts mandates, batches and debits, and each provider says how many mandates are active on it', () {
      final o = MandatesOverview.fromJson(real('overview_after'));
      expect((o.total, o.active, o.waitingForPayer, o.failedMandates), (2, 2, 0, 0));
      expect((o.waitingForApproval, o.debiting, o.batchesWithFailures), (0, 0, 0));
      expect((o.collectedMinor, o.debitCount, o.unknownDebits, o.failedDebits), (38000000, 2, 0, 0));
      expect(o.providers.map((p) => p.provider), ['sandbox', 'remita']);
      expect(o.providers.first.activeMandates, 2);
    });
  });

  group('the words', () {
    test('every status the server can send has words a school would use', () {
      for (final s in ['draft', 'pending_consent', 'pending_activation', 'activating', 'pending_provider_setup', 'active', 'suspended', 'cancelled', 'expired', 'failed']) {
        expect(mandateStatusLabels, contains(s));
      }
      for (final s in ['draft', 'pending_approval', 'rejected', 'approved', 'processing', 'partially_successful', 'completed', 'failed', 'cancelled']) {
        expect(batchStatusLabels, contains(s));
      }
      for (final s in ['pending', 'skipped', 'debiting', 'unknown', 'success', 'failed', 'retrying', 'cancelled']) {
        expect(debitStatusLabels, contains(s));
      }
      for (final s in ['eligible', 'no_mandate', 'not_ready', 'nothing_due', 'provider_unavailable', 'provider_cannot_debit']) {
        expect(eligibilityLabels, contains(s));
      }
      for (final s in ['pending', 'success', 'failed', 'reversed', 'refunded', 'unknown', 'not_found']) {
        expect(transactionStatusLabels, contains(s));
      }
    });

    test('an unknown outcome is described as not known yet, never as a failure', () {
      expect(debitStatusLabel('unknown'), contains('not known'));
      expect(transactionStatusLabel('unknown'), contains('not known'));
    });
  });
}
