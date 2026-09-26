import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/smartcollect/domain/collection_models.dart';
import 'package:schoolos_app/features/smartcollect/presentation/collection_words.dart';

import 'smart_collect_fixtures.dart';

void main() {
  group('the collection policy', () {
    test('the school default carries its values, the words for every choice and what is unfinished', () {
      final p = CollectionPolicy.fromJson(policyJson(settlement: 'grace_then_close', grace: 72));
      expect(p.values['settlement_action'], 'grace_then_close');
      expect(p.values['grace_period_hours'], 72);
      expect(p.label('settlement_action'), 'When a family has paid');
      expect(p.optionLabel('settlement_action', 'grace_then_close'), 'Wait, then close it');
      expect(p.optionLabel('account_mode', 'dynamic'), 'Dynamic');
      expect(p.optionLabel('account_mode', null), 'Not set');
      expect((p.providerSwitchPolicy, p.overrideReasonPolicy), ('retire_when_settled', 'required_sensitive'));
      expect(p.problems, isEmpty);
    });

    test('a waiting period is said in days when it is whole days', () {
      expect(hoursWords(72), '3 days');
      expect(hoursWords(24), '1 day');
      expect(hoursWords(36), '36 hours');
      expect(hoursWords(1), '1 hour');
      expect(hoursWords(null), 'Not set');
    });

    test('an override says what it is for, why, and for how long', () {
      final o = PolicyOverride.fromJson(overrideJson());
      expect((o.scope, o.targetLabel, o.reason, o.active), ('family', 'Bello family', 'Pays per term', true));
      expect(o.values, {'account_mode': 'dynamic'});
      expect(o.createdBy!.name, 'Ada Owner');
      expect(expiryWords(o.expiryKind, term: o.expiryTerm), 'Until the end of First Term');
      expect(expiryWords('one_time'), 'Used once');
      expect(expiryWords('until_removed'), 'Until removed');
    });

    test('each setting says whether it uses the school default or an override', () {
      expect(scopeLabel('school'), 'Using school default');
      expect(scopeLabel('term'), 'Override for this term');
      expect(scopeLabel('family'), 'Override for this family');
      final e = EffectivePolicy.fromJson({
        'values': {'account_mode': 'dynamic'},
        'problems': <Object?>[],
        'description': {
          'fields': [
            {'field': 'account_mode', 'label': 'Account type', 'value': 'dynamic', 'inherited': false, 'source': {'scope': 'family', 'reason': 'x'}},
            {'field': 'settlement_action', 'label': 'When a family has paid', 'value': 'manual', 'inherited': true, 'source': {'scope': 'school'}},
          ],
        },
      });
      expect(e.fields.first.source.inherited, isFalse);
      expect(e.fields.last.source.inherited, isTrue);
    });

    test('the sessions and terms are read with the current ones', () {
      final periods = Periods.fromJson(periodsJson());
      expect(periods.sessions.single.terms.map((t) => t.name), ['First Term', 'Second Term']);
      expect((periods.currentSessionId, periods.currentTermId), ('ses-1', 'term-1'));
    });
  });

  group('a batch', () {
    test('its totals, provider, period and history are read', () {
      final b = CollectionBatch.fromJson(batchJson(status: 'pending_approval', previous: 5000000, current: 10000000, collection: 15000000));
      expect((b.status, b.version, b.period), ('pending_approval', 3, '2026/2027 · First Term'));
      expect((b.providerCode, b.providerName, b.providerEnvironment, b.providerIsActive), ('paystack', 'Paystack', 'live', true));
      expect((b.totals.families, b.totals.selected, b.totals.previousArrearsMinor, b.totals.collectionMinor), (3, 2, 5000000, 15000000));
      expect((b.preparedBy!.name, b.submittedBy!.name), ('Tunde Maker', 'Tunde Maker'));
      expect(b.isPending, isTrue);
      expect(b.displayTitle, 'Term one accounts');
      expect(CollectionBatch.fromJson(batchJson(title: '')).displayTitle, 'Batch for 2026/2027 · First Term');
    });

    test('what the person may do is what the server said, nothing more', () {
      final maker = CollectionBatch.fromJson(batchJson());
      expect((maker.can.edit, maker.can.submit, maker.can.approve, maker.can.start), (true, true, false, false));
      final checker = CollectionBatch.fromJson(batchJson(status: 'pending_approval', can: batchCan(approve: true, reject: true), isMaker: false));
      expect((checker.can.approve, checker.can.reject, checker.can.edit, checker.isMaker), (true, true, false, false));
      expect(CollectionBatch.fromJson({}).can.approve, isFalse);
    });

    test('a rejected batch carries the reason and who rejected it', () {
      final b = CollectionBatch.fromJson(batchJson(status: 'rejected', rejectionReason: 'Bravo should not be included'));
      expect((b.isRejected, b.rejectionReason, b.rejectedBy!.name), (true, 'Bravo should not be included', 'Chidi Checker'));
    });

    test('progress and the outcome of a generation', () {
      final b = CollectionBatch.fromJson(batchJson(
        status: 'processing',
        progress: {'status': 'processing', 'total': 10, 'successful': 4, 'failed': 1, 'waiting': 5, 'generating': 0, 'finished': false},
      ));
      expect((b.isProcessing, b.progress!.done, b.progress!.fraction), (true, 5, 0.5));
      final done = CollectionBatch.fromJson(batchJson(status: 'partially_successful', selected: 600, successful: 590, failed: 10));
      expect((done.isFinished, done.hasFailures, done.totals.successful, done.totals.failed), (true, true, 590, 10));
    });

    test('a batch that is no longer for the active provider says so', () {
      expect(CollectionBatch.fromJson(batchJson(providerActive: false)).providerIsActive, isFalse);
    });

    test('the buckets are counted', () {
      final b = CollectionBatch.fromJson(batchJson(counts: {'eligible': {'total': 5, 'selected': 4}, 'missing_details': {'total': 1, 'selected': 0}}));
      expect(b.counts['eligible']!.selected, 4);
      expect(b.counts['missing_details']!.total, 1);
    });

    test('status words', () {
      expect(batchStatusLabel('pending_approval'), 'Waiting for approval');
      expect(batchStatusLabel('partially_successful'), 'Generated with errors');
      expect(batchEventLabel('approval_invalidated'), contains('withdrawn'));
      expect(batchEventLabel('rejected'), 'Rejected');
    });
  });

  group('a family in a batch', () {
    test('an eligible family can be selected; one that needs an override cannot until it has one', () {
      expect(BatchItem.fromJson(itemJson()).canBeSelected, isTrue);
      final needs = BatchItem.fromJson(itemJson(status: 'needs_override', selected: false, previous: 10000000));
      expect((needs.needsOverride, needs.canBeSelected), (true, false));
      final overridden = BatchItem.fromJson(itemJson(status: 'needs_override', override: true, overrideReason: 'Agreed'));
      expect((overridden.canBeSelected, overridden.overrideBy!.name, overridden.overrideReason), (true, 'Tunde Maker', 'Agreed'));
    });

    test('a family whose details are missing can never be selected, and says what is missing', () {
      final i = BatchItem.fromJson(itemJson(status: 'missing_details', selected: false, missing: ['the payer\'s BVN or NIN']));
      expect(i.canBeSelected, isFalse);
      expect(i.missingDetails, ['the payer\'s BVN or NIN']);
    });

    test('the earlier balances that could be carried are kept with their amounts', () {
      final i = BatchItem.fromJson(itemJson(
        arrearsPolicy: 'custom_selection',
        previous: 8000000,
        breakdown: [
          {'receivableId': 'r1', 'label': 'Tuition', 'period': '2026/2027 · First Term', 'dueDate': '2026-11-20', 'outstandingMinor': 8000000},
        ],
        custom: ['r1'],
      ));
      expect(i.arrearsBreakdown.single['outstandingMinor'], 8000000);
      expect(i.customArrearsReceivableIds, ['r1']);
    });

    test('how generation went for the family', () {
      final ok = BatchItem.fromJson(itemJson(generation: 'success'));
      expect((ok.isGenerated, ok.providerAccountReference), (true, 'SOS-ABC'));
      final bad = BatchItem.fromJson(itemJson(generation: 'failed', error: 'provider_rejected', errorMessage: 'The provider did not accept the request.'));
      expect((bad.hasFailed, bad.errorMessage), (true, 'The provider did not accept the request.'));
    });

    test('a page of families carries its buckets and version', () {
      final page = BatchPage.fromJson(itemsJson([itemJson()], version: 7, more: true));
      expect((page.items.length, page.hasMore, page.version), (1, true, 7));
      expect(page.buckets['needs_override']!.total, 1);
    });

    test('the buckets are in the order a person works through them', () {
      expect(eligibilityBuckets.first, 'eligible');
      expect(eligibilityWords('needs_override'), 'Needs an override');
      expect(eligibilityWords('provider_conflict'), 'Account with another provider');
    });
  });

  group('a provider switch', () {
    test('it says who is switching to whom, who is affected, and what stands in the way', () {
      final s = ProviderSwitch.fromJson(switchJson(status: 'ready_to_switch', warnings: ['The new provider\'s webhook has not been confirmed yet.']));
      expect((s.currentName, s.targetName, s.families, s.accounts, s.outstandingMinor), ('Paystack', 'Monnify', 12, 12, 250000000));
      expect((s.isReady, s.isOpen, s.canApply, s.openBatches), (true, true, true, 1));
      expect(s.warnings.single, contains('webhook'));
      expect(ProviderSwitch.fromJson(switchJson(blockers: ['Monnify is not connected.'])).blockers, ['Monnify is not connected.']);
    });

    test('a scheduled switch is open but is not ready, and cannot be applied', () {
      final s = ProviderSwitch.fromJson(switchJson());
      expect((s.isOpen, s.isReady, s.canApply), (true, false, false));
      expect(ProviderSwitch.fromJson(switchJson(status: 'applied')).isOpen, isFalse);
    });

    test('what happens to the old accounts is said in words', () {
      expect(switchPolicyWords('retire_when_settled'), contains('until its family has paid'));
      expect(switchPolicyWords('retire_at_switch'), contains('all retired'));
    });
  });

  group('the overview', () {
    test('it gathers the provider, the switch, the accounts and what waits for people', () {
      final d = CollectionDashboard.fromJson(dashboardJson(
        scheduledSwitch: switchJson(),
        pending: 1,
        failed: 3,
        pendingBatches: [batchJson(status: 'pending_approval')],
      ));
      expect(d.activeProvider!.providerName, 'Paystack');
      expect(d.scheduledSwitch!.targetName, 'Monnify');
      expect((d.activeFamilies, d.familiesWithLiveAccount, d.familiesWithoutAccount), (14, 10, 4));
      expect(d.accountsByStatus['dormant'], 2);
      expect((d.pendingApproval, d.pendingApprovals.length, d.failedFamilies, d.failedBatches), (1, 1, 3, 1));
      expect((d.sessionName, d.termName), ('2026/2027', 'First Term'));
      expect(d.permissions.canApprove, isTrue);
    });

    test('a school with no active provider has none', () {
      final json = dashboardJson()..['activeProvider'] = null;
      expect(CollectionDashboard.fromJson(json).activeProvider, isNull);
    });
  });

  group('a family\'s accounts', () {
    test('an account history entry says which batch made it and why it closed', () {
      final live = FamilyAccountRecord.fromJson(accountRecordJson());
      expect((live.isLive, live.batchTitle, live.mode, live.collectionTargetMinor), (true, 'Term one accounts', 'static', 15000000));
      final closed = FamilyAccountRecord.fromJson(accountRecordJson(status: 'closed'));
      expect((closed.isLive, closed.closeReason), (false, 'Family left'));
      expect(FamilyAccountRecord.fromJson(accountRecordJson(legacy: true)).isLegacy, isTrue);
    });

    test('an identity number is only ever known to be on file', () {
      final s = PayerIdentityStatus.fromJson({'hasBvn': true, 'hasNin': false});
      expect((s.onFile, s.hasBvn, s.hasNin), (true, true, false));
      expect(PayerIdentityStatus.fromJson({}).onFile, isFalse);
    });

    test('account states in the words the finance side uses', () {
      expect(accountStatusLabel('grace'), 'In grace period');
      expect(accountStatusLabel('closing'), 'Closing');
      expect(accountStatusLabel('dormant'), 'Dormant');
    });
  });
}
