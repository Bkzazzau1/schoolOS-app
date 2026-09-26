// JSON exactly as the SchoolOS server sends it for the collection-provider screens, so the tests break if the
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

Map<String, Object?> permissionsJson({
  bool view = true,
  bool providers = true,
  bool policy = true,
  bool prepare = true,
  bool approve = true,
}) =>
    {'canView': view, 'canManageProviders': providers, 'canManagePolicy': policy, 'canPrepare': prepare, 'canApprove': approve};

Map<String, Object?> capabilitiesJson({
  bool family = true,
  bool static = true,
  bool dynamic = true,
  bool webhooks = true,
  bool kyc = false,
}) =>
    {
      'supportsFamilyCollectionAccounts': family,
      'supportsStaticAccounts': static,
      'supportsDynamicAccounts': dynamic,
      'supportsAccountDeactivation': static,
      'supportsAccountReactivation': false,
      'supportsAccountClosure': family,
      'supportsWebhooks': webhooks,
      'supportsTransactionRequery': true,
      'supportsDirectDebitMandates': false,
      'requiresCustomerKyc': kyc,
    };

Map<String, Object?> paystackProviderJson() => {
      'code': 'paystack',
      'displayName': 'Paystack',
      'icon': 'payments',
      'environments': ['live', 'test'],
      'credentialFields': [
        {'name': 'secret_key', 'label': 'Secret key', 'secret': true, 'required': true, 'help': 'From Settings > API Keys in your own Paystack dashboard.'},
      ],
      'settingFields': [
        {'name': 'preferred_bank', 'label': 'Bank the family accounts are issued from', 'choices': <Object?>[], 'default': '', 'required': false},
      ],
      'capabilities': capabilitiesJson(),
      'onboarding': 'Create and verify your school\'s own Paystack business first, then enter the secret key Paystack issued to your school.',
      'webhook': {'mode': 'dashboard', 'where': 'Settings > API Keys & Webhooks in your Paystack dashboard', 'verification': 'hmac_sha512', 'events': ['charge.success'], 'note': ''},
      'productionStatus': 'implemented',
      'available': true,
      'isSandbox': false,
      'description': 'Family payment accounts issued as Paystack Dedicated Virtual Accounts.',
      'accountLabel': 'Account number',
      'payerNote': 'Pay by bank transfer to this account number.',
      'customerRequirements': ['email'],
      'requiresAmount': false,
    };

Map<String, Object?> monnifyProviderJson() => {
      'code': 'monnify',
      'displayName': 'Monnify',
      'icon': 'payments',
      'environments': ['live', 'test'],
      'credentialFields': [
        {'name': 'api_key', 'label': 'API key', 'secret': true, 'required': true, 'help': ''},
        {'name': 'secret_key', 'label': 'Secret key', 'secret': true, 'required': true, 'help': ''},
        {'name': 'contract_code', 'label': 'Contract code', 'secret': false, 'required': true, 'help': 'From the same page.'},
      ],
      'settingFields': <Object?>[],
      'capabilities': capabilitiesJson(kyc: true),
      'onboarding': 'Create and verify your school\'s own Monnify merchant account first.',
      'webhook': {'mode': 'dashboard', 'where': 'Developers > Webhook URLs in your Monnify dashboard', 'verification': 'hmac_sha512', 'events': ['SUCCESSFUL_TRANSACTION'], 'note': 'Monnify signs live notifications.'},
      'productionStatus': 'implemented',
      'available': true,
      'isSandbox': false,
      'description': 'Family payment accounts issued as Monnify Customer Reserved Accounts.',
      'accountLabel': 'Account number',
      'payerNote': '',
      'customerRequirements': ['email', 'identity'],
      'requiresAmount': false,
    };

Map<String, Object?> remitaProviderJson() => {
      'code': 'remita',
      'displayName': 'Remita',
      'icon': 'payments',
      'environments': ['live', 'test'],
      'credentialFields': [
        {'name': 'merchant_id', 'label': 'Merchant ID', 'secret': false, 'required': true, 'help': ''},
        {'name': 'api_key', 'label': 'API key', 'secret': true, 'required': true, 'help': ''},
        {'name': 'service_type_id', 'label': 'Service type ID', 'secret': false, 'required': true, 'help': ''},
      ],
      'settingFields': <Object?>[],
      'capabilities': capabilitiesJson(static: false),
      'onboarding': 'Register your school\'s own Remita account first.',
      'webhook': {'mode': 'dashboard', 'where': 'The API Keys and Webhooks page of your Remita account', 'verification': 'requery', 'events': <Object?>[], 'note': 'Remita does not sign its notifications.'},
      'productionStatus': 'implemented',
      'available': true,
      'isSandbox': false,
      'description': 'Family payment references made as Remita invoices.',
      'accountLabel': 'Remita Retrieval Reference (RRR)',
      'payerNote': '',
      'customerRequirements': ['name', 'email', 'phone'],
      'requiresAmount': true,
    };

Map<String, Object?> providersJson({bool canManage = true, bool storage = true, String? activeId, List<Map<String, Object?>>? providers}) => {
      'providers': providers ?? [paystackProviderJson(), monnifyProviderJson(), remitaProviderJson()],
      'permissions': permissionsJson(providers: canManage),
      'canManage': canManage,
      'secureStorageReady': storage,
      'activeConnectionId': activeId,
    };

Map<String, Object?> connectionJson({
  String id = 'conn-1',
  String provider = 'paystack',
  String status = 'connected',
  String label = '',
  bool active = true,
  String environment = 'live',
  String webhook = 'active',
  bool sandbox = false,
  String lastError = '',
}) =>
    {
      'id': id,
      'provider': provider,
      'providerName': provider == 'paystack' ? 'Paystack' : (provider == 'monnify' ? 'Monnify' : 'Remita'),
      'environment': environment,
      'isSandbox': sandbox,
      'merchantName': 'BrightGate Academy',
      'merchantReference': '****7855',
      'label': label,
      'status': status,
      'isActiveProvider': active,
      'webhookStatus': webhook,
      'webhookConfirmedAt': webhook == 'active' ? '2026-09-25T10:00:00+01:00' : null,
      'lastVerifiedAt': '2026-09-25T10:00:00+01:00',
      'lastErrorCode': lastError,
      'settings': <String, Object?>{},
      'capabilities': capabilitiesJson(),
      'createdAt': '2026-09-20T10:00:00+01:00',
      'disconnectedAt': null,
    };

Map<String, Object?> connectionsJson(List<Map<String, Object?>> connections, {bool canManage = true}) =>
    {'connections': connections, 'canManage': canManage, 'permissions': permissionsJson(providers: canManage)};

Map<String, Object?> webhookJson({String status = 'awaiting_event', String provider = 'paystack'}) => {
      'path': 'bank-webhooks/$provider/TOKEN123/',
      'url': 'https://school.example/api/v1/bank-webhooks/$provider/TOKEN123/',
      'status': status,
      'confirmedAt': status == 'active' ? '2026-09-25T10:00:00+01:00' : null,
      'mode': 'dashboard',
      'where': 'Settings > API Keys & Webhooks in your Paystack dashboard',
      'verification': 'hmac_sha512',
      'events': ['charge.success'],
      'note': '',
    };

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
  bool sandbox = false,
}) =>
    {
      'id': id,
      'connectionId': 'conn-1',
      'provider': 'paystack',
      'transactionReference': 'REF-9',
      'transactionType': 'dedicated_nuban',
      'direction': 'credit',
      'amountMinor': amount,
      'currency': 'NGN',
      'senderName': sender,
      'senderAccountMask': '****9012',
      'senderBank': 'Zenith',
      'narration': 'school fees 08031234567',
      'transactionDate': '2026-09-25T09:30:00+01:00',
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
      'familyId': null,
      'receivingAccountRef': '9930000902',
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
  int needAttention = 0,
}) =>
    {
      'summary': {
        'generatedAt': '2026-09-25T12:00:00+01:00',
        'currency': 'NGN',
        'period': {'key': 'term', 'label': 'First Term', 'from': '2026-09-07', 'to': '2026-12-18'},
        'available': available,
        'providers': {
          'connected': available ? 1 : 0,
          'needAttention': needAttention,
          'active': available ? {'connectionId': 'conn-1', 'provider': 'paystack', 'environment': 'live', 'merchantName': 'BrightGate Academy'} : null,
        },
        'today': {'amountMinor': today, 'count': today == 0 ? 0 : 1},
        'thisWeek': {'amountMinor': 15000000, 'count': 3},
        'thisTerm': {'amountMinor': 45000000, 'count': 9},
        'selected': {'amountMinor': 45000000, 'count': 9},
        'byProvider': [
          {
            'connectionId': 'conn-1', 'provider': 'paystack', 'merchantName': 'BrightGate Academy', 'label': 'Main collections',
            'environment': 'live', 'amountMinor': 40000000, 'count': 8,
          },
        ],
        'reconciliation': {'reconciledMinor': 30000000, 'unreconciledMinor': 15000000, 'pendingReviewCount': pending},
        'recent': [
          {
            'id': 'pay-1', 'senderName': 'Musa Bello', 'amountMinor': 5000000, 'currency': 'NGN',
            'transactionDate': '2026-09-25T09:30:00+01:00', 'provider': 'paystack', 'reconciliationStatus': 'matched', 'isSandbox': false,
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
