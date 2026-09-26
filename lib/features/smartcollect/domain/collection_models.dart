import '../../bankconnect/domain/bank_models.dart';
import '../../bankconnect/domain/collections_summary.dart' show ReconciliationTotals, RecentPayment;
import '../../bankconnect/domain/json_read.dart';

// The shapes the Smart Money Collection server sends for the policy, batches and provider switches. Each field mirrors the server's own:
// the tests break if the app and the server stop agreeing.

String _s(Object? value) => value is String ? value : '';
int _i(Object? value) => value is int ? value : 0;

/// A person as the server names them: enough to say who did something.
class PersonRef {
  const PersonRef({required this.membershipId, required this.name, required this.role});

  static PersonRef? maybe(Object? json) {
    if (json is! Map) return null;
    final m = readMap(json);
    return PersonRef(membershipId: _s(m['membershipId']), name: _s(m['name']), role: _s(m['role']));
  }

  final String membershipId;
  final String name;
  final String role;
}

class PolicyOption {
  const PolicyOption({required this.value, required this.label});

  final String value;
  final String label;
}

/// The school's default collection policy, and the choices for every field.
class CollectionPolicy {
  const CollectionPolicy({
    required this.values,
    required this.providerSwitchPolicy,
    required this.overrideReasonPolicy,
    required this.labels,
    required this.options,
    required this.problems,
  });

  factory CollectionPolicy.fromJson(Map<String, dynamic> json) => CollectionPolicy(
        values: readMap(json['values']),
        providerSwitchPolicy: _s(json['providerSwitchPolicy']),
        overrideReasonPolicy: _s(json['overrideReasonPolicy']),
        labels: {for (final e in readMap(json['labels']).entries) e.key: '${e.value}'},
        options: {
          for (final e in readMap(json['options']).entries)
            e.key: [for (final o in readMaps(e.value)) PolicyOption(value: _s(o['value']), label: _s(o['label']))],
        },
        problems: [for (final p in (json['problems'] as List? ?? const [])) '$p'],
      );

  /// account_mode, reuse_scope, reuse_count, reuse_until, settlement_action, grace_period_hours, arrears_policy, eligibility_policy.
  final Map<String, dynamic> values;
  final String providerSwitchPolicy;
  final String overrideReasonPolicy;
  final Map<String, String> labels;
  final Map<String, List<PolicyOption>> options;
  final List<String> problems;

  String label(String field) => labels[field] ?? field;

  /// The words for one choice ("dormant_immediately" -> "Make it dormant straight away").
  String optionLabel(String field, Object? value) {
    for (final o in options[field] ?? const <PolicyOption>[]) {
      if (o.value == value) return o.label;
    }
    return value == null ? 'Not set' : '$value';
  }
}

/// The school's default policy with what the signed-in person may do about it.
class PolicyInfo {
  const PolicyInfo({required this.policy, required this.permissions});

  final CollectionPolicy policy;
  final CollectionPermissions permissions;
}

/// Where one value of a resolved policy came from.
class PolicySource {
  const PolicySource({required this.scope, required this.reason, required this.expiryKind});

  factory PolicySource.fromJson(Map<String, dynamic> json) =>
      PolicySource(scope: _s(json['scope']), reason: _s(json['reason']), expiryKind: _s(json['expiryKind']));

  /// "school", "session", "term", "batch" or "family".
  final String scope;
  final String reason;
  final String expiryKind;

  bool get inherited => scope == 'school' || scope.isEmpty;
}

class EffectiveField {
  const EffectiveField({required this.field, required this.label, required this.value, required this.source});

  factory EffectiveField.fromJson(Map<String, dynamic> json) => EffectiveField(
        field: _s(json['field']),
        label: _s(json['label']),
        value: json['value'],
        source: PolicySource.fromJson(readMap(json['source'])),
      );

  final String field;
  final String label;
  final Object? value;
  final PolicySource source;
}

/// The policy that applies to a session, term, batch or family, with where each field came from.
class EffectivePolicy {
  const EffectivePolicy({required this.values, required this.fields, required this.problems});

  factory EffectivePolicy.fromJson(Map<String, dynamic> json) => EffectivePolicy(
        values: readMap(json['values']),
        fields: [for (final f in readMaps(readMap(json['description'])['fields'])) EffectiveField.fromJson(f)],
        problems: [for (final p in (json['problems'] as List? ?? const [])) '$p'],
      );

  final Map<String, dynamic> values;
  final List<EffectiveField> fields;
  final List<String> problems;
}

class PolicyOverride {
  const PolicyOverride({
    required this.id,
    required this.scope,
    required this.targetId,
    required this.targetLabel,
    required this.values,
    required this.reason,
    required this.expiryKind,
    required this.expiresOn,
    required this.expiryTerm,
    required this.expirySession,
    required this.active,
    required this.createdBy,
    required this.createdAt,
    required this.removedAt,
    required this.removalReason,
  });

  factory PolicyOverride.fromJson(Map<String, dynamic> json) => PolicyOverride(
        id: _s(json['id']),
        scope: _s(json['scope']),
        targetId: _s(json['targetId']),
        targetLabel: _s(json['targetLabel']),
        values: readMap(json['values']),
        reason: _s(json['reason']),
        expiryKind: _s(json['expiryKind']),
        expiresOn: readTime(json['expiresOn']),
        expiryTerm: json['expiryTerm'] as String?,
        expirySession: json['expirySession'] as String?,
        active: json['active'] == true,
        createdBy: PersonRef.maybe(json['createdBy']),
        createdAt: readTime(json['createdAt']),
        removedAt: readTime(json['removedAt']),
        removalReason: _s(json['removalReason']),
      );

  final String id;
  final String scope;
  final String targetId;
  final String targetLabel;
  final Map<String, dynamic> values;
  final String reason;
  final String expiryKind;
  final DateTime? expiresOn;
  final String? expiryTerm;
  final String? expirySession;
  final bool active;
  final PersonRef? createdBy;
  final DateTime? createdAt;
  final DateTime? removedAt;
  final String removalReason;
}

/// A session and its terms, for choosing what a batch or an override is for.
class PeriodTerm {
  const PeriodTerm({required this.id, required this.name, required this.status});

  final String id;
  final String name;
  final String status;
}

class PeriodSession {
  const PeriodSession({required this.id, required this.name, required this.status, required this.terms});

  final String id;
  final String name;
  final String status;
  final List<PeriodTerm> terms;
}

class Periods {
  const Periods({required this.sessions, required this.currentSessionId, required this.currentTermId});

  factory Periods.fromJson(Map<String, dynamic> json) {
    final current = readMap(json['current']);
    return Periods(
      sessions: [
        for (final s in readMaps(json['sessions']))
          PeriodSession(
            id: _s(s['id']),
            name: _s(s['name']),
            status: _s(s['status']),
            terms: [for (final t in readMaps(s['terms'])) PeriodTerm(id: _s(t['id']), name: _s(t['name']), status: _s(t['status']))],
          ),
      ],
      currentSessionId: current['sessionId'] as String?,
      currentTermId: current['termId'] as String?,
    );
  }

  final List<PeriodSession> sessions;
  final String? currentSessionId;
  final String? currentTermId;
}

class BatchTotals {
  const BatchTotals({
    required this.families,
    required this.selected,
    required this.previousArrearsMinor,
    required this.currentDueMinor,
    required this.collectionMinor,
    required this.successful,
    required this.failed,
  });

  factory BatchTotals.fromJson(Map<String, dynamic> json) => BatchTotals(
        families: _i(json['families']),
        selected: _i(json['selected']),
        previousArrearsMinor: _i(json['previousArrearsMinor']),
        currentDueMinor: _i(json['currentDueMinor']),
        collectionMinor: _i(json['collectionMinor']),
        successful: _i(json['successful']),
        failed: _i(json['failed']),
      );

  final int families;
  final int selected;
  final int previousArrearsMinor;
  final int currentDueMinor;
  final int collectionMinor;
  final int successful;
  final int failed;
}

/// What the signed-in person may do with THIS batch right now (the server checks again when they do it).
class BatchCan {
  const BatchCan({
    this.edit = false,
    this.submit = false,
    this.approve = false,
    this.reject = false,
    this.start = false,
    this.retry = false,
    this.cancel = false,
    this.overridePolicy = false,
  });

  factory BatchCan.fromJson(Map<String, dynamic> json) => BatchCan(
        edit: json['edit'] == true,
        submit: json['submit'] == true,
        approve: json['approve'] == true,
        reject: json['reject'] == true,
        start: json['start'] == true,
        retry: json['retry'] == true,
        cancel: json['cancel'] == true,
        overridePolicy: json['overridePolicy'] == true,
      );

  final bool edit;
  final bool submit;
  final bool approve;
  final bool reject;
  final bool start;
  final bool retry;
  final bool cancel;
  final bool overridePolicy;
}

class BucketCount {
  const BucketCount({required this.total, required this.selected});

  final int total;
  final int selected;
}

class BatchProgress {
  const BatchProgress({
    required this.status,
    required this.total,
    required this.successful,
    required this.failed,
    required this.waiting,
    required this.generating,
    required this.finished,
  });

  factory BatchProgress.fromJson(Map<String, dynamic> json) => BatchProgress(
        status: _s(json['status']),
        total: _i(json['total']),
        successful: _i(json['successful']),
        failed: _i(json['failed']),
        waiting: _i(json['waiting']),
        generating: _i(json['generating']),
        finished: json['finished'] == true,
      );

  final String status;
  final int total;
  final int successful;
  final int failed;
  final int waiting;
  final int generating;
  final bool finished;

  int get done => successful + failed;
  double get fraction => total == 0 ? 0 : done / total;
}

class CollectionBatch {
  const CollectionBatch({
    required this.id,
    required this.title,
    required this.status,
    required this.statusLabel,
    required this.version,
    required this.snapshotHash,
    required this.sessionId,
    required this.sessionName,
    required this.termId,
    required this.termName,
    required this.period,
    required this.providerCode,
    required this.providerName,
    required this.providerEnvironment,
    required this.providerIsActive,
    required this.policy,
    required this.policySources,
    required this.policyProblems,
    required this.preparedBy,
    required this.preparedAt,
    required this.submittedBy,
    required this.submittedAt,
    required this.approvedBy,
    required this.approvedAt,
    required this.rejectedBy,
    required this.rejectionReason,
    required this.totals,
    required this.can,
    required this.isMaker,
    required this.counts,
    required this.progress,
  });

  factory CollectionBatch.fromJson(Map<String, dynamic> json) {
    final session = readMap(json['session']);
    final term = readMap(json['term']);
    final provider = readMap(json['provider']);
    final counts = readMap(json['counts']);
    return CollectionBatch(
      id: _s(json['id']),
      title: _s(json['title']),
      status: _s(json['status']),
      statusLabel: _s(json['statusLabel']),
      version: _i(json['version']),
      snapshotHash: _s(json['snapshotHash']),
      sessionId: _s(session['id']),
      sessionName: _s(session['name']),
      termId: json['term'] is Map ? _s(term['id']) : null,
      termName: json['term'] is Map ? _s(term['name']) : null,
      period: _s(json['period']),
      providerCode: _s(provider['code']),
      providerName: _s(provider['name']),
      providerEnvironment: _s(provider['environment']),
      providerIsActive: provider['isActive'] == true,
      policy: readMap(json['policy']),
      policySources: {for (final e in readMap(json['policySources']).entries) e.key: PolicySource.fromJson(readMap(e.value))},
      policyProblems: [for (final p in (json['policyProblems'] as List? ?? const [])) '$p'],
      preparedBy: PersonRef.maybe(json['preparedBy']),
      preparedAt: readTime(json['preparedAt']),
      submittedBy: PersonRef.maybe(json['submittedBy']),
      submittedAt: readTime(json['submittedAt']),
      approvedBy: PersonRef.maybe(json['approvedBy']),
      approvedAt: readTime(json['approvedAt']),
      rejectedBy: PersonRef.maybe(json['rejectedBy']),
      rejectionReason: _s(json['rejectionReason']),
      totals: BatchTotals.fromJson(readMap(json['totals'])),
      can: BatchCan.fromJson(readMap(json['can'])),
      isMaker: json['isMaker'] == true,
      counts: {for (final e in counts.entries) e.key: BucketCount(total: _i(readMap(e.value)['total']), selected: _i(readMap(e.value)['selected']))},
      progress: json['progress'] is Map ? BatchProgress.fromJson(readMap(json['progress'])) : null,
    );
  }

  final String id;
  final String title;
  final String status;
  final String statusLabel;

  /// Rises whenever what would be generated changes. A screen sends the version it saw; a stale one is refused.
  final int version;
  final String snapshotHash;
  final String sessionId;
  final String sessionName;
  final String? termId;
  final String? termName;
  final String period;
  final String providerCode;
  final String providerName;
  final String providerEnvironment;
  final bool providerIsActive;
  final Map<String, dynamic> policy;
  final Map<String, PolicySource> policySources;
  final List<String> policyProblems;
  final PersonRef? preparedBy;
  final DateTime? preparedAt;
  final PersonRef? submittedBy;
  final DateTime? submittedAt;
  final PersonRef? approvedBy;
  final DateTime? approvedAt;
  final PersonRef? rejectedBy;
  final String rejectionReason;
  final BatchTotals totals;
  final BatchCan can;

  /// The signed-in person prepared, changed or submitted this batch, so cannot approve it.
  final bool isMaker;

  /// Eligibility bucket -> how many families are in it and how many are selected. Only on a batch opened on its own.
  final Map<String, BucketCount> counts;
  final BatchProgress? progress;

  String get displayTitle => title.isNotEmpty ? title : 'Batch for $period';

  bool get isDraft => status == 'draft';
  bool get isRejected => status == 'rejected';
  bool get isPending => status == 'pending_approval';
  bool get isApproved => status == 'approved';
  bool get isProcessing => status == 'processing';
  bool get isFinished => status == 'completed' || status == 'partially_successful' || status == 'failed';
  bool get hasFailures => totals.failed > 0;
}

class BatchItem {
  const BatchItem({
    required this.id,
    required this.familyId,
    required this.familyCode,
    required this.familyName,
    required this.selected,
    required this.previousArrearsMinor,
    required this.currentDueMinor,
    required this.proposedCollectionMinor,
    required this.arrearsPolicy,
    required this.arrearsBreakdown,
    required this.customArrearsReceivableIds,
    required this.eligibilityStatus,
    required this.eligibilityLabel,
    required this.eligibilityNote,
    required this.eligibilityOverride,
    required this.overrideReason,
    required this.overrideBy,
    required this.manualApprovalNeeded,
    required this.manualApprovedBy,
    required this.missingDetails,
    required this.generationStatus,
    required this.attemptCount,
    required this.errorCode,
    required this.errorMessage,
    required this.providerAccountReference,
  });

  factory BatchItem.fromJson(Map<String, dynamic> json) => BatchItem(
        id: _s(json['id']),
        familyId: _s(json['familyId']),
        familyCode: _s(json['familyCode']),
        familyName: _s(json['familyName']),
        selected: json['selected'] == true,
        previousArrearsMinor: _i(json['previousArrearsMinor']),
        currentDueMinor: _i(json['currentDueMinor']),
        proposedCollectionMinor: _i(json['proposedCollectionMinor']),
        arrearsPolicy: _s(json['arrearsPolicy']),
        arrearsBreakdown: readMaps(json['arrearsBreakdown']),
        customArrearsReceivableIds: [for (final r in (json['customArrearsReceivableIds'] as List? ?? const [])) '$r'],
        eligibilityStatus: _s(json['eligibilityStatus']),
        eligibilityLabel: _s(json['eligibilityLabel']),
        eligibilityNote: _s(json['eligibilityNote']),
        eligibilityOverride: json['eligibilityOverride'] == true,
        overrideReason: _s(json['overrideReason']),
        overrideBy: PersonRef.maybe(json['overrideBy']),
        manualApprovalNeeded: json['manualApprovalNeeded'] == true,
        manualApprovedBy: PersonRef.maybe(json['manualApprovedBy']),
        missingDetails: [for (final m in (json['missingDetails'] as List? ?? const [])) '$m'],
        generationStatus: _s(json['generationStatus']),
        attemptCount: _i(json['attemptCount']),
        errorCode: _s(json['errorCode']),
        errorMessage: _s(json['errorMessage']),
        providerAccountReference: _s(json['providerAccountReference']),
      );

  final String id;
  final String familyId;
  final String familyCode;
  final String familyName;
  final bool selected;
  final int previousArrearsMinor;
  final int currentDueMinor;
  final int proposedCollectionMinor;
  final String arrearsPolicy;

  /// The earlier balances that could be carried, each `{receivableId, label, period, dueDate, outstandingMinor}`.
  final List<Map<String, dynamic>> arrearsBreakdown;
  final List<String> customArrearsReceivableIds;
  final String eligibilityStatus;
  final String eligibilityLabel;
  final String eligibilityNote;
  final bool eligibilityOverride;
  final String overrideReason;
  final PersonRef? overrideBy;
  final bool manualApprovalNeeded;
  final PersonRef? manualApprovedBy;
  final List<String> missingDetails;
  final String generationStatus;
  final int attemptCount;
  final String errorCode;
  final String errorMessage;
  final String providerAccountReference;

  bool get needsOverride => eligibilityStatus == 'needs_override' || eligibilityStatus == 'excluded';
  bool get canBeSelected =>
      eligibilityStatus == 'eligible' ||
      eligibilityStatus == 'nothing_due' ||
      eligibilityStatus == 'manual_approval' ||
      (needsOverride && eligibilityOverride);
  bool get isGenerated => generationStatus == 'success';
  bool get hasFailed => generationStatus == 'failed';
}

class BatchPage {
  const BatchPage({required this.items, required this.hasMore, required this.version, required this.snapshotHash, required this.buckets});

  factory BatchPage.fromJson(Map<String, dynamic> json) => BatchPage(
        items: [for (final i in readMaps(json['items'])) BatchItem.fromJson(i)],
        hasMore: json['hasMore'] == true,
        version: _i(json['version']),
        snapshotHash: _s(json['snapshotHash']),
        buckets: {
          for (final e in readMap(json['buckets']).entries) e.key: BucketCount(total: _i(readMap(e.value)['total']), selected: _i(readMap(e.value)['selected'])),
        },
      );

  final List<BatchItem> items;
  final bool hasMore;
  final int version;
  final String snapshotHash;
  final Map<String, BucketCount> buckets;
}

class BatchEvent {
  const BatchEvent({required this.kind, required this.version, required this.actor, required this.detail, required this.at});

  factory BatchEvent.fromJson(Map<String, dynamic> json) => BatchEvent(
        kind: _s(json['kind']),
        version: _i(json['version']),
        actor: PersonRef.maybe(json['actor']),
        detail: readMap(json['detail']),
        at: readTime(json['at']),
      );

  final String kind;
  final int version;
  final PersonRef? actor;
  final Map<String, dynamic> detail;
  final DateTime? at;
}

/// A change of the school's active provider: scheduled, ready when its date has come, and applied only by a person.
class ProviderSwitch {
  const ProviderSwitch({
    required this.id,
    required this.status,
    required this.scheduledFor,
    required this.currentProvider,
    required this.currentName,
    required this.targetProvider,
    required this.targetName,
    required this.families,
    required this.accounts,
    required this.outstandingMinor,
    required this.openBatches,
    required this.warnings,
    required this.blockers,
    required this.switchPolicy,
    required this.canApply,
    required this.note,
  });

  factory ProviderSwitch.fromJson(Map<String, dynamic> json) {
    final current = readMap(json['current']);
    final target = readMap(json['target']);
    final affected = readMap(json['affected']);
    return ProviderSwitch(
      id: _s(json['id']),
      status: _s(json['status']),
      scheduledFor: readTime(json['scheduledFor']),
      currentProvider: _s(current['provider']),
      currentName: _s(current['providerName']),
      targetProvider: _s(target['provider']),
      targetName: _s(target['providerName']),
      families: _i(affected['families']),
      accounts: _i(affected['accounts']),
      outstandingMinor: _i(affected['outstandingMinor']),
      openBatches: _i(readMap(json['batches'])['open']),
      warnings: [for (final w in (json['warnings'] as List? ?? const [])) '$w'],
      blockers: [for (final b in (json['blockers'] as List? ?? const [])) '$b'],
      switchPolicy: _s(json['switchPolicy']),
      canApply: json['canApply'] == true,
      note: _s(json['note']),
    );
  }

  final String id;

  /// "scheduled", "ready_to_switch", "applied", "cancelled" or "failed".
  final String status;
  final DateTime? scheduledFor;
  final String currentProvider;
  final String currentName;
  final String targetProvider;
  final String targetName;
  final int families;
  final int accounts;
  final int outstandingMinor;
  final int openBatches;
  final List<String> warnings;
  final List<String> blockers;
  final String switchPolicy;
  final bool canApply;
  final String note;

  bool get isOpen => status == 'scheduled' || status == 'ready_to_switch';
  bool get isReady => status == 'ready_to_switch';
}

class SwitchesInfo {
  const SwitchesInfo({required this.open, required this.history, required this.permissions});

  factory SwitchesInfo.fromJson(Map<String, dynamic> json) => SwitchesInfo(
        open: json['open'] is Map ? ProviderSwitch.fromJson(readMap(json['open'])) : null,
        history: [for (final s in readMaps(json['history'])) ProviderSwitch.fromJson(s)],
        permissions: CollectionPermissions.fromJson(readMap(json['permissions'])),
      );

  final ProviderSwitch? open;
  final List<ProviderSwitch> history;
  final CollectionPermissions permissions;
}

/// Smart Money Collection at a glance.
class CollectionDashboard {
  const CollectionDashboard({
    required this.activeProvider,
    required this.connectedProviders,
    required this.scheduledSwitch,
    required this.policy,
    required this.sessionName,
    required this.termName,
    required this.accountsByStatus,
    required this.familiesWithLiveAccount,
    required this.activeFamilies,
    required this.familiesWithoutAccount,
    required this.drafts,
    required this.rejected,
    required this.pendingApproval,
    required this.processing,
    required this.recentBatches,
    required this.pendingApprovals,
    required this.failedFamilies,
    required this.failedBatches,
    required this.recentTransactions,
    required this.reconciliation,
    required this.permissions,
  });

  factory CollectionDashboard.fromJson(Map<String, dynamic> json) {
    final period = readMap(json['currentPeriod']);
    final accounts = readMap(json['accounts']);
    final batches = readMap(json['batches']);
    final failed = readMap(json['failedGenerations']);
    return CollectionDashboard(
      activeProvider: json['activeProvider'] is Map ? ProviderConnection.fromJson(readMap(json['activeProvider'])) : null,
      connectedProviders: [for (final c in readMaps(json['connectedProviders'])) ProviderConnection.fromJson(c)],
      scheduledSwitch: json['scheduledSwitch'] is Map ? ProviderSwitch.fromJson(readMap(json['scheduledSwitch'])) : null,
      policy: CollectionPolicy.fromJson(readMap(json['policy'])),
      sessionName: _s(readMap(period['session'])['name']),
      termName: _s(readMap(period['term'])['name']),
      accountsByStatus: {for (final e in readMap(accounts['byStatus']).entries) e.key: _i(e.value)},
      familiesWithLiveAccount: _i(accounts['familiesWithLiveAccount']),
      activeFamilies: _i(accounts['activeFamilies']),
      familiesWithoutAccount: _i(accounts['familiesWithoutAccount']),
      drafts: _i(batches['drafts']),
      rejected: _i(batches['rejected']),
      pendingApproval: _i(batches['pendingApproval']),
      processing: _i(batches['processing']),
      recentBatches: [for (final b in readMaps(batches['recent'])) CollectionBatch.fromJson(b)],
      pendingApprovals: [for (final b in readMaps(json['pendingApprovals'])) CollectionBatch.fromJson(b)],
      failedFamilies: _i(failed['families']),
      failedBatches: _i(failed['batches']),
      recentTransactions: [for (final r in readMaps(json['recentTransactions'])) RecentPayment.fromJson(r)],
      reconciliation: ReconciliationTotals.fromJson(readMap(json['reconciliation'])),
      permissions: CollectionPermissions.fromJson(readMap(json['permissions'])),
    );
  }

  final ProviderConnection? activeProvider;
  final List<ProviderConnection> connectedProviders;
  final ProviderSwitch? scheduledSwitch;
  final CollectionPolicy policy;
  final String sessionName;
  final String termName;
  final Map<String, int> accountsByStatus;
  final int familiesWithLiveAccount;
  final int activeFamilies;
  final int familiesWithoutAccount;
  final int drafts;
  final int rejected;
  final int pendingApproval;
  final int processing;
  final List<CollectionBatch> recentBatches;
  final List<CollectionBatch> pendingApprovals;
  final int failedFamilies;
  final int failedBatches;
  final List<RecentPayment> recentTransactions;
  final ReconciliationTotals reconciliation;
  final CollectionPermissions permissions;
}

/// One account a family has had, with the provider's own name for its number.
class FamilyAccountRecord {
  const FamilyAccountRecord({
    required this.id,
    required this.provider,
    required this.numberLabel,
    required this.accountNumber,
    required this.bankName,
    required this.status,
    required this.origin,
    required this.mode,
    required this.validUntil,
    required this.collectionTargetMinor,
    required this.reuseScope,
    required this.reuseCount,
    required this.graceUntil,
    required this.closedAt,
    required this.closeReason,
    required this.batchId,
    required this.batchTitle,
    required this.createdAtStatus,
  });

  factory FamilyAccountRecord.fromJson(Map<String, dynamic> json) {
    final batch = readMap(json['batch']);
    return FamilyAccountRecord(
      id: _s(json['id']),
      provider: _s(json['provider']),
      numberLabel: _s(json['numberLabel']).isEmpty ? 'Account number' : _s(json['numberLabel']),
      accountNumber: _s(json['accountNumber']),
      bankName: _s(json['bankName']),
      status: _s(json['status']),
      origin: _s(json['origin']),
      mode: _s(json['mode']),
      validUntil: readTime(json['validUntil']),
      collectionTargetMinor: json['collectionTargetMinor'] as int?,
      reuseScope: _s(json['reuseScope']),
      reuseCount: json['reuseCount'] as int?,
      graceUntil: readTime(json['graceUntil']),
      closedAt: readTime(json['closedAt']),
      closeReason: _s(json['closeReason']),
      batchId: json['batch'] is Map ? _s(batch['id']) : null,
      batchTitle: json['batch'] is Map ? _s(batch['title']) : null,
      createdAtStatus: readTime(json['statusChangedAt']),
    );
  }

  final String id;
  final String provider;
  final String numberLabel;
  final String accountNumber;
  final String bankName;
  final String status;
  final String origin;
  final String mode;
  final DateTime? validUntil;
  final int? collectionTargetMinor;
  final String reuseScope;
  final int? reuseCount;
  final DateTime? graceUntil;
  final DateTime? closedAt;
  final String closeReason;
  final String? batchId;
  final String? batchTitle;
  final DateTime? createdAtStatus;

  bool get isLive => !const {'closed', 'failed'}.contains(status);
  bool get isLegacy => origin == 'legacy_manual';
}

/// Whether an identity number (BVN / NIN) is on file for a family's payer. The number itself is never sent to the app.
class PayerIdentityStatus {
  const PayerIdentityStatus({required this.hasBvn, required this.hasNin});

  factory PayerIdentityStatus.fromJson(Map<String, dynamic> json) =>
      PayerIdentityStatus(hasBvn: json['hasBvn'] == true, hasNin: json['hasNin'] == true);

  final bool hasBvn;
  final bool hasNin;

  bool get onFile => hasBvn || hasNin;
}
