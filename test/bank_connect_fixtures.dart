// JSON exactly as the SchoolOS server sends it for the bank-connection screens, so the tests break if the
// app and the server stop agreeing about a field.

import 'package:schoolos_app/shared/models/school_membership.dart';

const schoolId = '22222222-2222-2222-2222-222222222222';

const ownerMembership = SchoolMembership(
  id: '55555555-5555-5555-5555-555555555555',
  schoolId: schoolId,
  schoolName: 'BrightGate',
  role: SchoolRole.proprietor,
);

const financeMembership = SchoolMembership(
  id: '99999999-9999-9999-9999-999999999999',
  schoolId: schoolId,
  schoolName: 'BrightGate',
  role: SchoolRole.accountant,
);

Map<String, Object?> capabilitiesJson({bool sync = true, bool webhooks = true}) => {
      'supportsTransactionSync': sync,
      'supportsWebhooks': webhooks,
      'supportsBalance': false,
      'supportsHistoricalTransactions': sync,
      'supportsRealtimeTransactions': webhooks,
      'supportsOutboundPayments': false,
      'supportsAccountVerification': true,
      'supportsTokenRefresh': true,
    };

Map<String, Object?> sandboxProviderJson() => {
      'code': 'sandbox',
      'displayName': 'Sandbox (test data)',
      'icon': 'science',
      'connectionType': 'sandbox',
      'connectMethods': ['credentials', 'authorization'],
      'credentialFields': [
        {'name': 'sandbox_key', 'label': 'Sandbox key', 'secret': true, 'required': true},
        {'name': 'account_number', 'label': 'Account number (10 digits)', 'secret': false, 'required': true},
      ],
      'capabilities': capabilitiesJson(),
      'productionStatus': 'sandbox',
      'available': true,
      'isSandbox': true,
      'description': 'Synthetic transactions for testing.',
    };

Map<String, Object?> gtbankProviderJson() => {
      'code': 'gtbank',
      'displayName': 'GTBank',
      'icon': 'bank',
      'connectionType': 'direct_bank_api',
      'connectMethods': ['credentials'],
      'credentialFields': <Object?>[],
      'capabilities': capabilitiesJson(sync: false, webhooks: false).map((k, v) => MapEntry(k, false)),
      'productionStatus': 'pending_verified_documentation',
      'available': false,
      'isSandbox': false,
      'description': 'Corporate API credentials issued by the bank.',
    };

Map<String, Object?> providersJson({bool canManage = true, bool storage = true}) => {
      'providers': [gtbankProviderJson(), sandboxProviderJson()],
      'canManage': canManage,
      'secureStorageReady': storage,
    };

Map<String, Object?> connectionJson({
  String id = 'conn-1',
  String status = 'connected',
  String label = 'Tuition Collection',
  String purpose = 'tuition',
  bool sandbox = true,
  String lastError = '',
}) =>
    {
      'id': id,
      'provider': 'sandbox',
      'providerName': 'Sandbox (test data)',
      'connectionType': 'sandbox',
      'isSandbox': sandbox,
      'bankName': 'Sandbox Bank',
      'accountName': 'SANDBOX SCHOOL ACCOUNT',
      'accountMask': '****6789',
      'purpose': purpose,
      'label': label,
      'status': status,
      'lastSyncedAt': '2026-09-25T10:00:00+01:00',
      'lastErrorCode': lastError,
      'tokenExpiresAt': null,
      'webhookConfigured': status == 'connected',
      'capabilities': capabilitiesJson(),
      'createdAt': '2026-09-20T10:00:00+01:00',
      'disconnectedAt': null,
    };

Map<String, Object?> connectionsJson(List<Map<String, Object?>> connections, {bool canManage = true}) =>
    {'connections': connections, 'canManage': canManage};

Map<String, Object?> candidateJson(String name, String code, int score, {String status = 'active'}) => {
      'kind': 'candidate',
      'studentId': 'student-$code',
      'studentName': name,
      'studentCode': code,
      'className': 'Primary 3',
      'studentStatus': status,
      'score': score,
      'signals': [
        {'signal': 'guardian_name', 'points': 35, 'detail': 'The sender\'s name matches a guardian\'s name'},
        {'signal': 'guardian_phone', 'points': 30, 'detail': 'A guardian\'s phone number appears in the narration'},
      ],
    };

Map<String, Object?> paymentJson({
  String id = 'pay-1',
  String status = 'requires_review',
  int amount = 5000000,
  String sender = 'Musa Bello',
  List<Map<String, Object?>>? reasons,
  List<Map<String, Object?>> allocations = const [],
  List<Map<String, Object?>>? decisions,
  bool sandbox = true,
}) =>
    {
      'id': id,
      'connectionId': 'conn-1',
      'provider': 'sandbox',
      'bankName': 'Sandbox Bank',
      'bankAccountName': 'SANDBOX SCHOOL ACCOUNT',
      'maskedAccountNumber': '****6789',
      'transactionReference': 'REF-9',
      'transactionType': 'transfer',
      'direction': 'credit',
      'amountMinor': amount,
      'currency': 'NGN',
      'senderName': sender,
      'senderAccountMask': '****9012',
      'senderBank': 'Zenith',
      'narration': 'school fees 08031234567',
      'transactionDate': '2026-09-25T09:30:00+01:00',
      'balanceAfterMinor': null,
      'isSandbox': sandbox,
      'reconciliationStatus': status,
      'confidence': 65,
      'matchReasons': reasons ??
          [
            candidateJson('Aisha Bello', 'BG-0042', 65),
            candidateJson('Bilal Bello', 'BG-0043', 65),
            {'kind': 'note', 'text': '2 students fit about equally well (for example siblings sharing a guardian). A person must choose.'},
          ],
      'duplicateOf': null,
      'allocations': allocations,
      if (decisions != null) 'decisions': decisions,
      'receivedAt': '2026-09-25T09:31:00+01:00',
    };

Map<String, Object?> pageJson(List<Map<String, Object?>> payments, {Map<String, int>? counts, bool more = false}) => {
      'transactions': payments,
      'total': payments.length,
      'hasMore': more,
      if (counts != null) 'counts': counts,
    };

Map<String, Object?> summaryJson({
  bool available = true,
  int today = 5000000,
  int sandboxHidden = 0,
  bool sandboxIncluded = false,
  int pending = 2,
  int otherCurrency = 0,
  bool owed = false,
}) =>
    {
      'summary': {
        'generatedAt': '2026-09-25T12:00:00+01:00',
        'currency': 'NGN',
        'period': {'key': 'term', 'label': 'First Term', 'from': '2026-09-07', 'to': '2026-12-18'},
        'available': available,
        'accounts': {'connected': available ? 1 : 0, 'needAttention': 0, 'lastSyncedAt': null},
        'today': {'amountMinor': today, 'count': today == 0 ? 0 : 1},
        'thisWeek': {'amountMinor': 15000000, 'count': 3},
        'thisTerm': {'amountMinor': 45000000, 'count': 9},
        'selected': {'amountMinor': 45000000, 'count': 9},
        'byPurpose': [
          {'purpose': 'tuition', 'amountMinor': 40000000, 'count': 8},
          {'purpose': 'transport', 'amountMinor': 5000000, 'count': 1},
        ],
        'byBank': [
          {
            'connectionId': 'conn-1', 'bankName': 'GTBank', 'accountMask': '****1111', 'label': 'Tuition Collection',
            'purpose': 'tuition', 'amountMinor': 40000000, 'count': 8,
          },
        ],
        'reconciliation': {'reconciledMinor': 30000000, 'unreconciledMinor': 15000000, 'pendingReviewCount': pending},
        'recent': [
          {
            'id': 'pay-1', 'senderName': 'Musa Bello', 'amountMinor': 5000000, 'currency': 'NGN',
            'transactionDate': '2026-09-25T09:30:00+01:00', 'bankName': 'GTBank', 'maskedAccountNumber': '****1111',
            'reconciliationStatus': 'matched', 'isSandbox': false,
          },
        ],
        'sandboxIncluded': sandboxIncluded,
        'sandboxHidden': sandboxHidden,
        'otherCurrencyTransactions': otherCurrency,
        'outstandingFeesAvailable': owed,
        if (owed)
          'receivables': {
            'available': true, 'currency': 'NGN', 'outstandingMinor': 29000000, 'overdueMinor': 13000000, 'arrearsMinor': 13000000,
            'currentMinor': 16000000, 'creditMinor': 500000, 'familiesOwing': 2,
            'periods': [
              {
                'label': '2026/2027 · First Term', 'isPast': true, 'isCurrent': false, 'isClosed': false, 'charges': 2,
                'netMinor': 19000000, 'paidMinor': 6000000, 'outstandingMinor': 13000000, 'overdueMinor': 13000000, 'familiesOwing': 2,
                'collectionRateBp': 3158,
              },
              {
                'label': '2026/2027 · Second Term', 'isPast': false, 'isCurrent': true, 'isClosed': false, 'charges': 2,
                'netMinor': 16000000, 'paidMinor': 0, 'outstandingMinor': 16000000, 'overdueMinor': 0, 'familiesOwing': 2,
                'collectionRateBp': 0,
              },
            ],
          },
      },
    };
