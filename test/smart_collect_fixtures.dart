// JSON exactly as the Smart Money Collection server sends it, so the tests break if the app and the server stop agreeing about a field.

import 'bank_connect_fixtures.dart';

List<Map<String, Object?>> _opts(List<(String, String)> pairs) => [for (final (v, l) in pairs) {'value': v, 'label': l}];

Map<String, Object?> policyJson({
  String accountMode = 'static',
  String settlement = 'dormant_immediately',
  String arrears = 'carry_forward',
  String eligibility = 'needs_override',
  int? grace,
}) =>
    {
      'values': {
        'account_mode': accountMode,
        'reuse_scope': 'until_replaced',
        'reuse_count': null,
        'reuse_until': null,
        'settlement_action': settlement,
        'grace_period_hours': grace,
        'arrears_policy': arrears,
        'eligibility_policy': eligibility,
      },
      'providerSwitchPolicy': 'retire_when_settled',
      'overrideReasonPolicy': 'required_sensitive',
      'labels': {
        'account_mode': 'Account type',
        'reuse_scope': 'How long an account is reused',
        'reuse_count': 'How many terms or sessions',
        'reuse_until': 'Reused until',
        'settlement_action': 'When a family has paid',
        'grace_period_hours': 'Waiting period (hours)',
        'arrears_policy': 'Previous balances',
        'eligibility_policy': 'Families with a previous balance',
        'provider_switch_policy': 'When the provider is switched',
        'override_reason_policy': 'Reasons for overrides',
      },
      'options': {
        'account_mode': _opts([('static', 'Static'), ('dynamic', 'Dynamic')]),
        'reuse_scope': _opts([
          ('one_term', 'One term'), ('selected_terms', 'A number of terms'), ('one_session', 'One session'), ('multiple_sessions', 'A number of sessions'),
          ('until_date', 'Until a date'), ('indefinitely', 'Indefinitely'), ('until_replaced', 'Until replaced'),
        ]),
        'settlement_action': _opts([
          ('close_immediately', 'Close it straight away'), ('dormant_immediately', 'Make it dormant straight away'),
          ('grace_then_dormant', 'Wait, then make it dormant'), ('grace_then_close', 'Wait, then close it'), ('manual', 'Leave it for a person'),
          ('provider_native', 'Let the provider decide'),
        ]),
        'arrears_policy': _opts([('carry_forward', 'Carry the previous balance forward'), ('current_term_only', 'Current term only'), ('custom_selection', 'Choose which balances to include')]),
        'eligibility_policy': _opts([
          ('exclude', 'Do not include them'), ('needs_override', 'Include them only with an override'), ('include', 'Include them'),
          ('manual_approval', 'Include them after a person approves each'),
        ]),
        'provider_switch_policy': _opts([('retire_when_settled', 'Keep each until its family has paid'), ('retire_at_switch', 'Retire them all when the switch is applied'), ('manual', 'Leave them for a person')]),
        'override_reason_policy': _opts([('optional', 'A reason is optional'), ('required_always', 'A reason is always required'), ('required_sensitive', 'A reason is required for sensitive overrides')]),
        'expiry_kind': _opts([('one_time', 'Once'), ('end_of_term', 'Until the end of the term'), ('end_of_session', 'Until the end of the session'), ('at_date', 'Until a date'), ('until_removed', 'Until it is removed')]),
      },
      'problems': <Object?>[],
      'updatedAt': '2026-09-25T10:00:00+01:00',
    };

Map<String, Object?> policyResponse({bool canManage = true, Map<String, Object?>? policy}) =>
    {'policy': policy ?? policyJson(), 'permissions': permissionsJson(policy: canManage)};

Map<String, Object?> overrideJson({String id = 'ov-1', String scope = 'family', String target = 'Bello family', bool active = true}) => {
      'id': id,
      'scope': scope,
      'targetId': 'fam-1',
      'targetLabel': target,
      'values': {'account_mode': 'dynamic'},
      'reason': 'Pays per term',
      'expiryKind': 'end_of_term',
      'expiresOn': null,
      'expiryTerm': 'First Term',
      'expirySession': null,
      'consumedAt': null,
      'createdBy': {'membershipId': 'm-1', 'name': 'Ada Owner', 'role': 'proprietor'},
      'createdAt': '2026-09-25T10:00:00+01:00',
      'removedAt': null,
      'removalReason': '',
      'active': active,
    };

Map<String, Object?> periodsJson() => {
      'sessions': [
        {
          'id': 'ses-1', 'name': '2026/2027', 'status': 'active', 'startsOn': '2026-09-07', 'endsOn': '2027-07-20',
          'terms': [
            {'id': 'term-1', 'name': 'First Term', 'sequence': 1, 'status': 'active', 'startsOn': '2026-09-07', 'endsOn': '2026-12-18'},
            {'id': 'term-2', 'name': 'Second Term', 'sequence': 2, 'status': 'planned', 'startsOn': '2027-01-11', 'endsOn': '2027-04-10'},
          ],
        },
      ],
      'current': {'sessionId': 'ses-1', 'termId': 'term-1'},
    };

Map<String, Object?> person(String name, {String role = 'accountant', String id = 'm-9'}) => {'membershipId': id, 'name': name, 'role': role};

Map<String, Object?> batchCan({
  bool edit = false,
  bool submit = false,
  bool approve = false,
  bool reject = false,
  bool start = false,
  bool retry = false,
  bool cancel = false,
}) =>
    {'edit': edit, 'submit': submit, 'approve': approve, 'reject': reject, 'start': start, 'retry': retry, 'cancel': cancel, 'overridePolicy': false};

Map<String, Object?> batchJson({
  String id = 'batch-1',
  String status = 'draft',
  int version = 3,
  String hash = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90',
  int families = 3,
  int selected = 2,
  int previous = 0,
  int current = 15000000,
  int collection = 15000000,
  int successful = 0,
  int failed = 0,
  Map<String, Object?>? can,
  bool isMaker = true,
  String? rejectionReason,
  String title = 'Term one accounts',
  bool providerActive = true,
  Map<String, Object?>? counts,
  Map<String, Object?>? progress,
  Map<String, Object?>? policy,
  Map<String, Object?>? policySources,
  List<String> policyProblems = const [],
}) =>
    {
      'id': id,
      'title': title,
      'status': status,
      'statusLabel': status,
      'version': version,
      'snapshotHash': hash,
      'approvedSnapshotHash': status == 'approved' ? hash : '',
      'session': {'id': 'ses-1', 'name': '2026/2027'},
      'term': {'id': 'term-1', 'name': 'First Term'},
      'period': '2026/2027 · First Term',
      'provider': {'connectionId': 'conn-1', 'code': 'paystack', 'name': 'Paystack', 'environment': 'live', 'isActive': providerActive},
      'policy': policy ?? policyJson()['values'],
      'policySources': policySources ?? {'account_mode': {'scope': 'school'}, 'arrears_policy': {'scope': 'batch', 'reason': 'x'}},
      'policyProblems': policyProblems,
      'preparedBy': person('Tunde Maker', id: 'm-maker'),
      'preparedAt': '2026-09-25T09:00:00+01:00',
      'submittedBy': status == 'draft' ? null : person('Tunde Maker', id: 'm-maker'),
      'submittedAt': status == 'draft' ? null : '2026-09-25T09:30:00+01:00',
      'approvedBy': status == 'approved' || status == 'processing' || status == 'completed' || status == 'partially_successful' ? person('Chidi Checker', role: 'principal', id: 'm-checker') : null,
      'approvedAt': status == 'approved' ? '2026-09-25T10:00:00+01:00' : null,
      'rejectedBy': rejectionReason == null ? null : person('Chidi Checker', role: 'principal', id: 'm-checker'),
      'rejectedAt': null,
      'rejectionReason': rejectionReason ?? '',
      'startedAt': null,
      'completedAt': null,
      'previewBuiltAt': '2026-09-25T09:00:00+01:00',
      'totals': {
        'families': families, 'selected': selected, 'previousArrearsMinor': previous, 'currentDueMinor': current, 'collectionMinor': collection,
        'successful': successful, 'failed': failed,
      },
      'can': can ?? batchCan(edit: status == 'draft' || status == 'rejected', submit: status == 'draft' || status == 'rejected', cancel: status == 'draft'),
      'isMaker': isMaker,
      if (counts != null) 'counts': counts,
      if (progress != null) 'progress': progress,
    };

Map<String, Object?> itemJson({
  String id = 'item-1',
  String family = 'Alpha family',
  String code = 'FAM-AAAA',
  String status = 'eligible',
  bool selected = true,
  int previous = 0,
  int current = 10000000,
  int proposed = 10000000,
  bool override = false,
  String overrideReason = '',
  String note = '',
  List<String> missing = const [],
  String generation = 'pending',
  String error = '',
  String errorMessage = '',
  String arrearsPolicy = 'carry_forward',
  List<Map<String, Object?>> breakdown = const [],
  List<String> custom = const [],
  bool manualNeeded = false,
}) =>
    {
      'id': id,
      'familyId': 'fam-$id',
      'familyCode': code,
      'familyName': family,
      'selected': selected,
      'previousArrearsMinor': previous,
      'currentDueMinor': current,
      'creditMinor': 0,
      'proposedCollectionMinor': proposed,
      'arrearsPolicy': arrearsPolicy,
      'arrearsBreakdown': breakdown,
      'customArrearsReceivableIds': custom,
      'eligibilityStatus': status,
      'eligibilityLabel': status,
      'eligibilityNote': note,
      'eligibilityOverride': override,
      'overrideReason': overrideReason,
      'overrideBy': override ? person('Tunde Maker', id: 'm-maker') : null,
      'manualApprovalNeeded': manualNeeded,
      'manualApprovedBy': null,
      'policy': policyJson()['values'],
      'policySources': <String, Object?>{},
      'missingDetails': missing,
      'generationStatus': generation,
      'attemptCount': generation == 'pending' ? 0 : 1,
      'providerAccountReference': generation == 'success' ? 'SOS-ABC' : '',
      'errorCode': error,
      'errorMessage': errorMessage,
      'accountId': null,
      'completedAt': null,
    };

Map<String, Object?> itemsJson(List<Map<String, Object?>> items, {int version = 3, String hash = 'a1b2', Map<String, Object?>? buckets, bool more = false}) => {
      'items': items,
      'hasMore': more,
      'version': version,
      'snapshotHash': hash,
      'buckets': buckets ??
          {
            'eligible': {'total': 2, 'selected': 2},
            'needs_override': {'total': 1, 'selected': 0},
          },
    };

Map<String, Object?> switchJson({String status = 'scheduled', List<String> blockers = const [], List<String> warnings = const []}) => {
      'id': 'sw-1',
      'status': status,
      'scheduledFor': '2026-10-05T09:00:00+01:00',
      'readyAt': status == 'ready_to_switch' ? '2026-10-05T09:00:00+01:00' : null,
      'appliedAt': null,
      'current': {'connectionId': 'conn-1', 'provider': 'paystack', 'providerName': 'Paystack', 'environment': 'live', 'merchantName': 'BrightGate Academy', 'status': 'connected', 'webhookStatus': 'active'},
      'target': {'connectionId': 'conn-2', 'provider': 'monnify', 'providerName': 'Monnify', 'environment': 'live', 'merchantName': 'BrightGate Academy', 'status': 'connected', 'webhookStatus': 'awaiting_event'},
      'affected': {'families': 12, 'accounts': 12, 'byStatus': {'active': 12}, 'outstandingMinor': 250000000},
      'batches': {'open': 1, 'processing': 0},
      'warnings': warnings,
      'blockers': blockers,
      'switchPolicy': 'retire_when_settled',
      'note': '',
      'createdBy': person('Ada Owner', role: 'proprietor'),
      'createdAt': '2026-09-25T10:00:00+01:00',
      'appliedBy': null,
      'cancelledAt': null,
      'cancelReason': '',
      'canApply': status == 'ready_to_switch',
      'reviewedAt': '2026-09-25T10:00:00+01:00',
    };

Map<String, Object?> dashboardJson({
  Map<String, Object?>? active,
  Map<String, Object?>? scheduledSwitch,
  int pending = 0,
  int failed = 0,
  List<Map<String, Object?>> pendingBatches = const [],
  Map<String, Object?>? perms,
}) =>
    {
      'activeProvider': active ?? connectionJson(),
      'connectedProviders': [active ?? connectionJson()],
      'scheduledSwitch': scheduledSwitch,
      'policy': policyJson(),
      'currentPeriod': {'session': {'id': 'ses-1', 'name': '2026/2027'}, 'term': {'id': 'term-1', 'name': 'First Term'}},
      'accounts': {'byStatus': {'active': 8, 'dormant': 2, 'closed': 3}, 'familiesWithLiveAccount': 10, 'activeFamilies': 14, 'familiesWithoutAccount': 4},
      'batches': {
        'byStatus': {'draft': 1}, 'drafts': 1, 'rejected': 0, 'pendingApproval': pending, 'processing': 0,
        'recent': <Object?>[],
      },
      'pendingApprovals': pendingBatches,
      'failedGenerations': {'families': failed, 'batches': failed == 0 ? 0 : 1},
      'recentTransactions': <Object?>[],
      'reconciliation': {'reconciledMinor': 0, 'unreconciledMinor': 0, 'pendingReviewCount': 0},
      'collected': {'today': {'amountMinor': 0, 'count': 0}},
      'permissions': perms ?? permissionsJson(),
    };

Map<String, Object?> accountRecordJson({String id = 'acc-1', String status = 'active', String number = '9930000902', String provider = 'paystack', bool legacy = false}) => {
      'id': id,
      'familyId': 'fam-1',
      'provider': provider,
      'bankName': 'Wema Bank',
      'accountNumber': number,
      'numberLabel': 'Account number',
      'accountName': 'Bello family',
      'details': <Object?>[],
      'connectionId': 'conn-1',
      'isTest': false,
      'currency': 'NGN',
      'status': status,
      'origin': legacy ? 'legacy_manual' : 'provider',
      'mode': 'static',
      'validUntil': null,
      'collectionTargetMinor': 15000000,
      'reuseScope': 'until_replaced',
      'reuseCount': null,
      'graceUntil': null,
      'afterGrace': '',
      'closedAt': status == 'closed' ? '2026-09-20T10:00:00+01:00' : null,
      'closeReason': status == 'closed' ? 'Family left' : '',
      'statusChangedAt': '2026-09-20T10:00:00+01:00',
      'batch': {'id': 'batch-1', 'title': 'Term one accounts', 'status': 'completed', 'generatedAt': '2026-09-20T10:00:00+01:00'},
    };

Map<String, Object?> familyJson({String id = 'fam-1', String name = 'Bello family', String code = 'FAM-K7Q2M9XA', List<Map<String, Object?>> accounts = const []}) => {
      'id': id,
      'code': code,
      'displayName': name,
      'status': 'active',
      'createdAt': '2026-09-01T10:00:00+01:00',
      'mergedInto': null,
      'mergedAt': null,
      'students': [
        {'id': 's1', 'name': 'Ahmad Bello'},
        {'id': 's2', 'name': 'Aisha Bello'},
      ],
      'collectionAccounts': accounts,
    };
