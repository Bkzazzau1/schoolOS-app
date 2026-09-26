import '../../bankconnect/domain/bank_models.dart' show CredentialField, WebhookGuide;
import '../../bankconnect/domain/json_read.dart';

/// What the signed-in person may do in Mandates & Direct Debit. The server checks every change again.
class MandatePermissions {
  const MandatePermissions({
    this.canView = false,
    this.canManageProviders = false,
    this.canManage = false,
    this.canPrepare = false,
    this.canApprove = false,
  });

  factory MandatePermissions.fromJson(Map<String, dynamic> json) => MandatePermissions(
        canView: json['canView'] == true,
        canManageProviders: json['canManageProviders'] == true,
        canManage: json['canManage'] == true,
        canPrepare: json['canPrepare'] == true,
        canApprove: json['canApprove'] == true,
      );

  final bool canView;
  final bool canManageProviders;
  final bool canManage;
  final bool canPrepare;
  final bool canApprove;
}

/// What a direct-debit provider really does. The app only offers what is switched on: it never assumes a provider can.
class MandateCapabilities {
  const MandateCapabilities({
    this.supportsManualDebit = false,
    this.supportsDebitStatus = false,
    this.supportsOtpActivation = false,
    this.supportsFormActivation = false,
    this.supportsTransferActivation = false,
    this.supportsSuspension = false,
    this.supportsReactivation = false,
    this.supportsRemoteCancellation = false,
    this.supportsWebhooks = false,
    this.requiresProviderCustomer = false,
  });

  factory MandateCapabilities.fromJson(Map<String, dynamic> json) => MandateCapabilities(
        supportsManualDebit: json['supportsManualDebit'] == true,
        supportsDebitStatus: json['supportsDebitStatus'] == true,
        supportsOtpActivation: json['supportsOtpActivation'] == true,
        supportsFormActivation: json['supportsFormActivation'] == true,
        supportsTransferActivation: json['supportsTransferActivation'] == true,
        supportsSuspension: json['supportsSuspension'] == true,
        supportsReactivation: json['supportsReactivation'] == true,
        supportsRemoteCancellation: json['supportsRemoteCancellation'] == true,
        supportsWebhooks: json['supportsWebhooks'] == true,
        requiresProviderCustomer: json['requiresProviderCustomer'] == true,
      );

  final bool supportsManualDebit;
  final bool supportsDebitStatus;
  final bool supportsOtpActivation;
  final bool supportsFormActivation;
  final bool supportsTransferActivation;
  final bool supportsSuspension;
  final bool supportsReactivation;
  final bool supportsRemoteCancellation;
  final bool supportsWebhooks;

  /// The provider needs the payer's id in its own system (Lendsqr's customer id) before a mandate can be made.
  final bool requiresProviderCustomer;
}

/// A direct-debit provider SchoolOS supports: Remita or Lendsqr. The school connects its OWN account at one or both.
class MandateProvider {
  const MandateProvider({
    required this.code,
    required this.displayName,
    required this.environments,
    required this.credentialFields,
    required this.capabilities,
    required this.onboarding,
    required this.description,
    required this.webhook,
    required this.available,
    required this.isSandbox,
    required this.liveNote,
    required this.liveEnabled,
    required this.liveWhy,
    required this.activationNote,
    required this.maximumNote,
    required this.maximumScope,
    required this.payerRequirements,
  });

  factory MandateProvider.fromJson(Map<String, dynamic> json) {
    final live = readMap(json['liveAvailability']);
    return MandateProvider(
      code: json['code'] as String,
      displayName: json['displayName'] as String? ?? json['code'] as String,
      environments: [for (final e in (json['environments'] as List? ?? const [])) e as String],
      credentialFields: [for (final f in readMaps(json['credentialFields'])) CredentialField.fromJson(f)],
      capabilities: MandateCapabilities.fromJson(readMap(json['capabilities'])),
      onboarding: json['onboarding'] as String? ?? '',
      description: json['description'] as String? ?? '',
      webhook: WebhookGuide.fromJson(readMap(json['webhook'])),
      available: json['available'] == true,
      isSandbox: json['isSandbox'] == true,
      liveNote: json['liveNote'] as String? ?? '',
      liveEnabled: live['live'] == true,
      liveWhy: live['why'] as String? ?? '',
      activationNote: json['activationNote'] as String? ?? '',
      maximumNote: json['maximumNote'] as String? ?? '',
      maximumScope: json['maximumScope'] as String? ?? 'single_debit',
      payerRequirements: [for (final r in (json['payerRequirements'] as List? ?? const [])) r as String],
    );
  }

  final String code;
  final String displayName;

  /// "live" and/or "test".
  final List<String> environments;
  final List<CredentialField> credentialFields;
  final MandateCapabilities capabilities;
  final String onboarding;
  final String description;
  final WebhookGuide webhook;
  final bool available;
  final bool isSandbox;

  /// What must be true before this provider can be used live. Never a claim that a school is eligible.
  final String liveNote;

  /// Whether live use is switched on on this server, and if not why.
  final bool liveEnabled;
  final String liveWhy;
  final String activationNote;
  final String maximumNote;
  final String maximumScope;
  final List<String> payerRequirements;
}

class MandateProvidersInfo {
  const MandateProvidersInfo({required this.providers, required this.permissions, required this.secureStorageReady});

  factory MandateProvidersInfo.fromJson(Map<String, dynamic> json) => MandateProvidersInfo(
        providers: [for (final p in readMaps(json['providers'])) MandateProvider.fromJson(p)],
        permissions: MandatePermissions.fromJson(readMap(json['permissions'])),
        secureStorageReady: json['secureStorageReady'] == true,
      );

  final List<MandateProvider> providers;
  final MandatePermissions permissions;
  final bool secureStorageReady;

  MandateProvider? provider(String code) {
    for (final p in providers) {
      if (p.code == code) return p;
    }
    return null;
  }
}

/// The school's own connection to one provider. There is no "active" one: a school may connect both.
class MandateConnection {
  const MandateConnection({
    required this.id,
    required this.provider,
    required this.providerName,
    required this.environment,
    required this.isSandbox,
    required this.merchantName,
    required this.merchantReference,
    required this.label,
    required this.status,
    required this.webhookStatus,
    required this.lastVerifiedAt,
    required this.lastErrorCode,
    required this.capabilities,
    required this.activeMandates,
    required this.liveMandates,
    required this.totalMandates,
    required this.usable,
  });

  factory MandateConnection.fromJson(Map<String, dynamic> json) {
    final counts = readMap(json['mandateCounts']);
    return MandateConnection(
      id: json['id'] as String,
      provider: json['provider'] as String? ?? '',
      providerName: json['providerName'] as String? ?? json['provider'] as String? ?? '',
      environment: json['environment'] as String? ?? 'live',
      isSandbox: json['isSandbox'] == true,
      merchantName: json['merchantName'] as String? ?? '',
      merchantReference: json['merchantReference'] as String? ?? '',
      label: json['label'] as String? ?? '',
      status: json['status'] as String? ?? '',
      webhookStatus: json['webhookStatus'] as String? ?? 'not_configured',
      lastVerifiedAt: readTime(json['lastVerifiedAt']),
      lastErrorCode: json['lastErrorCode'] as String? ?? '',
      capabilities: MandateCapabilities.fromJson(readMap(json['capabilities'])),
      activeMandates: (counts['active'] as num?)?.toInt() ?? (json['activeMandates'] as num?)?.toInt() ?? 0,
      liveMandates: (counts['live'] as num?)?.toInt() ?? 0,
      totalMandates: (counts['total'] as num?)?.toInt() ?? 0,
      usable: json['usable'] == true,
    );
  }

  final String id;
  final String provider;
  final String providerName;
  final String environment;
  final bool isSandbox;
  final String merchantName;
  final String merchantReference;
  final String label;
  final String status;
  final String webhookStatus;
  final DateTime? lastVerifiedAt;
  final String lastErrorCode;
  final MandateCapabilities capabilities;
  final int activeMandates;
  final int liveMandates;
  final int totalMandates;
  final bool usable;

  String get title => label.isNotEmpty ? label : providerName;
}

class MandateConnectionsInfo {
  const MandateConnectionsInfo({required this.connections, required this.permissions});

  factory MandateConnectionsInfo.fromJson(Map<String, dynamic> json) => MandateConnectionsInfo(
        connections: [for (final c in readMaps(json['connections'])) MandateConnection.fromJson(c)],
        permissions: MandatePermissions.fromJson(readMap(json['permissions'])),
      );

  final List<MandateConnection> connections;
  final MandatePermissions permissions;
}

/// What a test of a connection said.
class MandateActionResult {
  const MandateActionResult({required this.connection, this.testOk, this.testCode = '', this.testMessage = ''});

  factory MandateActionResult.fromJson(Map<String, dynamic> json) {
    final test = readMap(json['test']);
    return MandateActionResult(
      connection: json['connection'] is Map ? MandateConnection.fromJson(readMap(json['connection'])) : null,
      testOk: json['test'] is Map ? test['ok'] == true : null,
      testCode: test['code'] as String? ?? '',
      testMessage: test['message'] as String? ?? '',
    );
  }

  final MandateConnection? connection;
  final bool? testOk;
  final String testCode;
  final String testMessage;
}

/// Where to give the provider SchoolOS's address for its notifications, and whether it is known to work.
class MandateWebhook {
  const MandateWebhook({required this.path, required this.url, required this.status, required this.where, required this.verification, required this.note});

  factory MandateWebhook.fromJson(Map<String, dynamic> json) => MandateWebhook(
        path: json['path'] as String? ?? '',
        url: json['url'] as String? ?? '',
        status: json['status'] as String? ?? 'not_configured',
        where: json['where'] as String? ?? '',
        verification: json['verification'] as String? ?? '',
        note: json['note'] as String? ?? '',
      );

  final String path;
  final String url;
  final String status;
  final String where;
  final String verification;
  final String note;
}

class MandatePayer {
  const MandatePayer({required this.id, required this.name, required this.relationship, required this.hasAppAccount});

  factory MandatePayer.fromJson(Map<String, dynamic> json) => MandatePayer(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        relationship: json['relationship'] as String? ?? '',
        hasAppAccount: json['hasAppAccount'] == true,
      );

  final String id;
  final String name;
  final String relationship;
  final bool hasAppAccount;
}

/// How the payer activates a mandate, in the provider's own facts. Never a secret and never an account number.
class MandateActivation {
  const MandateActivation({
    required this.note,
    required this.deadline,
    required this.canActivateInApp,
    required this.formUrl,
    required this.method,
    required this.transferBank,
    required this.transferAccount,
    required this.transferAmountMinor,
  });

  factory MandateActivation.fromJson(Map<String, dynamic> json) {
    final transfer = readMap(json['transfer']);
    return MandateActivation(
      note: json['note'] as String? ?? '',
      deadline: readTime(json['deadline']),
      canActivateInApp: json['canActivateInApp'] == true,
      formUrl: json['formUrl'] as String? ?? '',
      method: json['method'] as String? ?? '',
      transferBank: transfer['toBank'] as String? ?? '',
      transferAccount: transfer['toAccount'] as String? ?? '',
      transferAmountMinor: (transfer['amountMinor'] as num?)?.toInt(),
    );
  }

  final String note;

  /// The last moment the payer can activate, when the provider says so.
  final DateTime? deadline;
  final bool canActivateInApp;
  final String formUrl;
  final String method;
  final String transferBank;
  final String transferAccount;
  final int? transferAmountMinor;

  bool get isTransfer => method == 'transfer' && transferAccount.isNotEmpty;
}

class MandateHistoryEvent {
  const MandateHistoryEvent({required this.kind, required this.from, required this.to, required this.at, required this.actor});

  factory MandateHistoryEvent.fromJson(Map<String, dynamic> json) => MandateHistoryEvent(
        kind: json['kind'] as String? ?? '',
        from: json['from'] as String? ?? '',
        to: json['to'] as String? ?? '',
        at: readTime(json['at']),
        actor: json['actor'] as String? ?? '',
      );

  final String kind;
  final String from;
  final String to;
  final DateTime? at;
  final String actor;
}

/// A payer's mandate. It carries a bank, a MASKED account number and nothing else about the account: the server never sends more.
class Mandate {
  const Mandate({
    required this.id,
    required this.familyId,
    required this.familyName,
    required this.familyCode,
    required this.payer,
    required this.provider,
    required this.providerName,
    required this.connectionId,
    required this.environment,
    required this.isSandbox,
    required this.bankCode,
    required this.bankName,
    required this.accountMask,
    required this.status,
    required this.providerStatus,
    required this.consentRoute,
    required this.consentAt,
    required this.consentChannel,
    required this.maximumAmountMinor,
    required this.maximumNote,
    required this.startDate,
    required this.endDate,
    required this.isPrimary,
    required this.debitReady,
    required this.debitReadyReason,
    required this.activatedAt,
    required this.debitReadyAt,
    required this.activationDeadline,
    required this.failureCode,
    required this.createdAt,
    required this.isLive,
    required this.activation,
    required this.history,
    this.providerCustomerRef = '',
    this.mandateCode = '',
    this.schoolName = '',
    this.consentRequired = false,
    this.consentText = '',
    this.consentVersion = '',
    this.consentTextHash = '',
  });

  factory Mandate.fromJson(Map<String, dynamic> json) {
    final consent = readMap(json['consent']);
    return Mandate(
      id: json['id'] as String,
      familyId: json['familyId'] as String? ?? '',
      familyName: json['familyName'] as String? ?? '',
      familyCode: json['familyCode'] as String? ?? '',
      payer: MandatePayer.fromJson(readMap(json['payer'])),
      provider: json['provider'] as String? ?? '',
      providerName: json['providerName'] as String? ?? '',
      connectionId: json['connectionId'] as String? ?? '',
      environment: json['environment'] as String? ?? '',
      isSandbox: json['isSandbox'] == true,
      bankCode: json['bankCode'] as String? ?? '',
      bankName: json['bankName'] as String? ?? '',
      accountMask: json['accountMask'] as String? ?? '',
      status: json['status'] as String? ?? '',
      providerStatus: json['providerStatus'] as String? ?? '',
      consentRoute: json['consentRoute'] as String? ?? '',
      consentAt: readTime(consent['at']),
      consentChannel: consent['channel'] as String? ?? '',
      maximumAmountMinor: (json['maximumAmountMinor'] as num?)?.toInt(),
      maximumNote: json['maximumNote'] as String? ?? '',
      startDate: readTime(json['startDate']),
      endDate: readTime(json['endDate']),
      isPrimary: json['isPrimary'] == true,
      debitReady: json['debitReady'] == true,
      debitReadyReason: json['debitReadyReason'] as String? ?? '',
      activatedAt: readTime(json['activatedAt']),
      debitReadyAt: readTime(json['debitReadyAt']),
      activationDeadline: readTime(json['activationDeadline']),
      failureCode: json['failureCode'] as String? ?? '',
      createdAt: readTime(json['createdAt']),
      isLive: json['isLive'] == true,
      activation: MandateActivation.fromJson(readMap(json['activation'])),
      history: [for (final e in readMaps(json['events'])) MandateHistoryEvent.fromJson(e)],
      providerCustomerRef: json['providerCustomerRef'] as String? ?? '',
      mandateCode: json['mandateCode'] as String? ?? '',
      schoolName: json['schoolName'] as String? ?? '',
      consentRequired: json['consentRequired'] == true,
      consentText: json['consentText'] as String? ?? '',
      consentVersion: json['consentVersion'] as String? ?? '',
      consentTextHash: json['consentTextHash'] as String? ?? '',
    );
  }

  final String id;
  final String familyId;
  final String familyName;
  final String familyCode;
  final MandatePayer payer;
  final String provider;
  final String providerName;
  final String connectionId;
  final String environment;
  final bool isSandbox;
  final String bankCode;
  final String bankName;
  final String accountMask;
  final String status;
  final String providerStatus;

  /// "payer_app" (the payer authorises in the SchoolOS app) or "provider" (with the provider).
  final String consentRoute;
  final DateTime? consentAt;
  final String consentChannel;
  final int? maximumAmountMinor;
  final String maximumNote;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isPrimary;

  /// Whether the provider says it can be debited now: stricter than "the payer activated it".
  final bool debitReady;
  final String debitReadyReason;
  final DateTime? activatedAt;
  final DateTime? debitReadyAt;
  final DateTime? activationDeadline;
  final String failureCode;
  final DateTime? createdAt;
  final bool isLive;
  final MandateActivation activation;
  final List<MandateHistoryEvent> history;
  final String providerCustomerRef;
  final String mandateCode;

  // What only a payer's own view carries.
  final String schoolName;
  final bool consentRequired;
  final String consentText;
  final String consentVersion;
  final String consentTextHash;

  bool get waitingForPayer => status == 'pending_consent' || status == 'pending_activation';
}

class MandatesPage {
  const MandatesPage({required this.mandates, required this.counts, required this.permissions});

  factory MandatesPage.fromJson(Map<String, dynamic> json) => MandatesPage(
        mandates: [for (final m in readMaps(json['mandates'])) Mandate.fromJson(m)],
        counts: {for (final e in readMap(json['counts']).entries) e.key: (e.value as num?)?.toInt() ?? 0},
        permissions: MandatePermissions.fromJson(readMap(json['permissions'])),
      );

  final List<Mandate> mandates;
  final Map<String, int> counts;
  final MandatePermissions permissions;
}

/// A bank a provider can make a mandate on.
class BankOption {
  const BankOption({required this.code, required this.name, required this.selfActivation, this.activationAmountMinor});

  factory BankOption.fromJson(Map<String, dynamic> json) => BankOption(
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        selfActivation: json['selfActivation'] == true,
        activationAmountMinor: (json['activationAmountMinor'] as num?)?.toInt(),
      );

  final String code;
  final String name;
  final bool selfActivation;
  final int? activationAmountMinor;
}

/// A guardian of a family who could be the payer on a mandate.
class FamilyPayer {
  const FamilyPayer({required this.id, required this.name, required this.relationship, required this.isPrimaryPayer, required this.hasAppAccount});

  factory FamilyPayer.fromJson(Map<String, dynamic> json) => FamilyPayer(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        relationship: json['relationship'] as String? ?? '',
        isPrimaryPayer: json['isPrimaryPayer'] == true,
        hasAppAccount: json['hasAppAccount'] == true,
      );

  final String id;
  final String name;
  final String relationship;
  final bool isPrimaryPayer;
  final bool hasAppAccount;
}

/// The bank details a person types to start a mandate. They go to the server once, over HTTPS, and are not kept anywhere in the app.
class StartMandateRequest {
  const StartMandateRequest({
    required this.familyId,
    required this.payerId,
    required this.connectionId,
    required this.bankCode,
    required this.accountNumber,
    required this.maximumAmountMinor,
    required this.consentRoute,
    this.maxDebits,
    this.providerCustomerRef = '',
  });

  final String familyId;
  final String payerId;
  final String connectionId;
  final String bankCode;
  final String accountNumber;
  final int maximumAmountMinor;
  final String consentRoute;
  final int? maxDebits;
  final String providerCustomerRef;
}

// -- debit batches ----------------------------------------------------------------------------------

class WhoRef {
  const WhoRef({required this.id, required this.name});

  static WhoRef? tryFrom(Object? json) {
    final map = readMap(json);
    return map.isEmpty ? null : WhoRef(id: map['id'] as String? ?? '', name: map['name'] as String? ?? '');
  }

  final String id;
  final String name;
}

class DebitBatch {
  const DebitBatch({
    required this.id,
    required this.title,
    required this.status,
    required this.version,
    required this.snapshotHash,
    required this.sessionName,
    required this.termName,
    required this.familyCount,
    required this.totalItems,
    required this.totalOutstandingMinor,
    required this.totalAmountMinor,
    required this.successCount,
    required this.failedCount,
    required this.preparedBy,
    required this.preparedAt,
    required this.submittedBy,
    required this.approvedBy,
    required this.rejectedBy,
    required this.rejectionReason,
    required this.startedAt,
    required this.completedAt,
  });

  factory DebitBatch.fromJson(Map<String, dynamic> json) => DebitBatch(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        status: json['status'] as String? ?? '',
        version: (json['version'] as num?)?.toInt() ?? 1,
        snapshotHash: json['snapshotHash'] as String? ?? '',
        sessionName: readMap(json['session'])['name'] as String? ?? '',
        termName: readMap(json['term'])['name'] as String? ?? '',
        familyCount: (json['familyCount'] as num?)?.toInt() ?? 0,
        totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
        totalOutstandingMinor: (json['totalOutstandingMinor'] as num?)?.toInt() ?? 0,
        totalAmountMinor: (json['totalAmountMinor'] as num?)?.toInt() ?? 0,
        successCount: (json['successCount'] as num?)?.toInt() ?? 0,
        failedCount: (json['failedCount'] as num?)?.toInt() ?? 0,
        preparedBy: WhoRef.tryFrom(json['preparedBy']),
        preparedAt: readTime(json['preparedAt']),
        submittedBy: WhoRef.tryFrom(json['submittedBy']),
        approvedBy: WhoRef.tryFrom(json['approvedBy']),
        rejectedBy: WhoRef.tryFrom(json['rejectedBy']),
        rejectionReason: json['rejectionReason'] as String? ?? '',
        startedAt: readTime(json['startedAt']),
        completedAt: readTime(json['completedAt']),
      );

  final String id;
  final String title;
  final String status;
  final int version;

  /// What a checker approves: a fingerprint of exactly what would be debited.
  final String snapshotHash;
  final String sessionName;
  final String termName;
  final int familyCount;
  final int totalItems;
  final int totalOutstandingMinor;
  final int totalAmountMinor;
  final int successCount;
  final int failedCount;
  final WhoRef? preparedBy;
  final DateTime? preparedAt;
  final WhoRef? submittedBy;
  final WhoRef? approvedBy;
  final WhoRef? rejectedBy;
  final String rejectionReason;
  final DateTime? startedAt;
  final DateTime? completedAt;

  bool get editable => status == 'draft' || status == 'rejected';
  String get heading => title.isNotEmpty ? title : '$sessionName${termName.isEmpty ? '' : ' - $termName'}';
}

/// One family in a batch: what it owes, what is proposed, whether it is eligible and selected, and how its debit went.
class DebitItem {
  const DebitItem({
    required this.id,
    required this.familyName,
    required this.familyCode,
    required this.payer,
    required this.provider,
    required this.bankName,
    required this.accountMask,
    required this.mandateStatus,
    required this.selected,
    required this.outstandingMinor,
    required this.proposedDebitMinor,
    required this.amountAdjusted,
    required this.eligibilityStatus,
    required this.eligibilityNote,
    required this.status,
    required this.errorCode,
    required this.errorMessage,
    required this.canSelect,
  });

  factory DebitItem.fromJson(Map<String, dynamic> json) => DebitItem(
        id: json['id'] as String,
        familyName: json['familyName'] as String? ?? '',
        familyCode: json['familyCode'] as String? ?? '',
        payer: json['payer'] as String? ?? '',
        provider: json['provider'] as String? ?? '',
        bankName: json['bankName'] as String? ?? '',
        accountMask: json['accountMask'] as String? ?? '',
        mandateStatus: json['mandateStatus'] as String? ?? '',
        selected: json['selected'] == true,
        outstandingMinor: (json['outstandingMinor'] as num?)?.toInt() ?? 0,
        proposedDebitMinor: (json['proposedDebitMinor'] as num?)?.toInt() ?? 0,
        amountAdjusted: json['amountAdjusted'] == true,
        eligibilityStatus: json['eligibilityStatus'] as String? ?? '',
        eligibilityNote: json['eligibilityNote'] as String? ?? '',
        status: json['status'] as String? ?? '',
        errorCode: json['errorCode'] as String? ?? '',
        errorMessage: json['errorMessage'] as String? ?? '',
        canSelect: json['canSelect'] == true,
      );

  final String id;
  final String familyName;
  final String familyCode;
  final String payer;
  final String provider;
  final String bankName;
  final String accountMask;
  final String mandateStatus;
  final bool selected;
  final int outstandingMinor;
  final int proposedDebitMinor;
  final bool amountAdjusted;
  final String eligibilityStatus;
  final String eligibilityNote;

  /// How the debit itself is going once the batch runs.
  final String status;
  final String errorCode;
  final String errorMessage;
  final bool canSelect;

  bool get failed => status == 'failed';
  bool get unknown => status == 'unknown';
}

class DebitItemsPage {
  const DebitItemsPage({required this.items, required this.version, required this.snapshotHash});

  factory DebitItemsPage.fromJson(Map<String, dynamic> json) => DebitItemsPage(
        items: [for (final i in readMaps(json['items'])) DebitItem.fromJson(i)],
        version: (json['version'] as num?)?.toInt() ?? 1,
        snapshotHash: json['snapshotHash'] as String? ?? '',
      );

  final List<DebitItem> items;
  final int version;
  final String snapshotHash;
}

class BatchSummary {
  const BatchSummary({required this.families, required this.selected, required this.byEligibility});

  factory BatchSummary.fromJson(Map<String, dynamic> json) => BatchSummary(
        families: (json['families'] as num?)?.toInt() ?? 0,
        selected: (json['selected'] as num?)?.toInt() ?? 0,
        byEligibility: {for (final e in readMap(json['byEligibility']).entries) e.key: (e.value as num?)?.toInt() ?? 0},
      );

  final int families;
  final int selected;
  final Map<String, int> byEligibility;
}

class DebitBatchDetail {
  const DebitBatchDetail({required this.batch, required this.permissions, required this.summary, this.retry});

  factory DebitBatchDetail.fromJson(Map<String, dynamic> json) => DebitBatchDetail(
        batch: DebitBatch.fromJson(readMap(json['batch'])),
        permissions: MandatePermissions.fromJson(readMap(json['permissions'])),
        summary: BatchSummary.fromJson(readMap(json['summary'])),
        retry: json['retry'] is Map ? RetryResult.fromJson(readMap(json['retry'])) : null,
      );

  final DebitBatch batch;
  final MandatePermissions permissions;
  final BatchSummary summary;
  final RetryResult? retry;
}

class RetryResult {
  const RetryResult({required this.retried, required this.needsFreshApproval});

  factory RetryResult.fromJson(Map<String, dynamic> json) => RetryResult(
        retried: [for (final r in (json['retried'] as List? ?? const [])) r as String],
        needsFreshApproval: [for (final n in readMaps(json['needsFreshApproval'])) n['family'] as String? ?? ''],
      );

  final List<String> retried;

  /// Families whose debit changed since it was approved: they need a fresh maker and checker.
  final List<String> needsFreshApproval;
}

class DebitProgress {
  const DebitProgress({required this.status, required this.total, required this.success, required this.failed, required this.unknown, required this.queued, required this.done});

  factory DebitProgress.fromJson(Map<String, dynamic> json) => DebitProgress(
        status: json['status'] as String? ?? '',
        total: (json['total'] as num?)?.toInt() ?? 0,
        success: (json['success'] as num?)?.toInt() ?? 0,
        failed: (json['failed'] as num?)?.toInt() ?? 0,
        unknown: (json['unknown'] as num?)?.toInt() ?? 0,
        queued: (json['queued'] as num?)?.toInt() ?? 0,
        done: json['done'] == true,
      );

  final String status;
  final int total;
  final int success;
  final int failed;
  final int unknown;
  final int queued;
  final bool done;
}

class BatchEvent {
  const BatchEvent({required this.kind, required this.at, required this.actor, required this.reason});

  factory BatchEvent.fromJson(Map<String, dynamic> json) => BatchEvent(
        kind: json['kind'] as String? ?? '',
        at: readTime(json['at']),
        actor: json['actor'] as String? ?? '',
        reason: readMap(json['detail'])['reason'] as String? ?? '',
      );

  final String kind;
  final DateTime? at;
  final String actor;
  final String reason;
}

// -- transactions and overview ----------------------------------------------------------------------

class MandateTransactionRow {
  const MandateTransactionRow({
    required this.id,
    required this.familyName,
    required this.provider,
    required this.amountMinor,
    required this.status,
    required this.providerStatus,
    required this.failureCode,
    required this.settled,
    required this.createdAt,
    required this.accountMask,
    required this.bankName,
    required this.isSandbox,
  });

  factory MandateTransactionRow.fromJson(Map<String, dynamic> json) => MandateTransactionRow(
        id: json['id'] as String,
        familyName: json['familyName'] as String? ?? '',
        provider: json['provider'] as String? ?? '',
        amountMinor: (json['amountMinor'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? '',
        providerStatus: json['providerStatus'] as String? ?? '',
        failureCode: json['failureCode'] as String? ?? '',
        settled: json['settled'] == true,
        createdAt: readTime(json['createdAt']),
        accountMask: json['accountMask'] as String? ?? '',
        bankName: json['bankName'] as String? ?? '',
        isSandbox: json['isSandbox'] == true,
      );

  final String id;
  final String familyName;
  final String provider;
  final int amountMinor;
  final String status;
  final String providerStatus;
  final String failureCode;

  /// Whether it has been put towards the family's charges. Only a confirmed debit ever is.
  final bool settled;
  final DateTime? createdAt;
  final String accountMask;
  final String bankName;
  final bool isSandbox;
}

class MandatesOverview {
  const MandatesOverview({
    required this.providers,
    required this.total,
    required this.live,
    required this.active,
    required this.waitingForPayer,
    required this.settingUp,
    required this.failedMandates,
    required this.waitingForApproval,
    required this.debiting,
    required this.batchesWithFailures,
    required this.collectedMinor,
    required this.debitCount,
    required this.unknownDebits,
    required this.failedDebits,
    required this.permissions,
  });

  factory MandatesOverview.fromJson(Map<String, dynamic> json) {
    final mandates = readMap(json['mandates']);
    final batches = readMap(json['batches']);
    final debits = readMap(json['debits']);
    int n(Map<String, dynamic> m, String k) => (m[k] as num?)?.toInt() ?? 0;
    return MandatesOverview(
      providers: [for (final p in readMaps(json['providers'])) MandateConnection.fromJson(p)],
      total: n(mandates, 'total'),
      live: n(mandates, 'live'),
      active: n(mandates, 'active'),
      waitingForPayer: n(mandates, 'waitingForPayer'),
      settingUp: n(mandates, 'settingUp'),
      failedMandates: n(mandates, 'failed'),
      waitingForApproval: n(batches, 'waitingForApproval'),
      debiting: n(batches, 'debiting'),
      batchesWithFailures: n(batches, 'withFailures'),
      collectedMinor: n(debits, 'collectedMinor'),
      debitCount: n(debits, 'count'),
      unknownDebits: n(debits, 'unknown'),
      failedDebits: n(debits, 'failed'),
      permissions: MandatePermissions.fromJson(readMap(json['permissions'])),
    );
  }

  /// The school's connections (there is no "active" one). Each says how many mandates are active on it.
  final List<MandateConnection> providers;
  final int total;
  final int live;
  final int active;
  final int waitingForPayer;
  final int settingUp;
  final int failedMandates;
  final int waitingForApproval;
  final int debiting;
  final int batchesWithFailures;
  final int collectedMinor;
  final int debitCount;
  final int unknownDebits;
  final int failedDebits;
  final MandatePermissions permissions;
}

/// What the payer is asked to type to activate a mandate in the app (for example a bank one-time password).
class ActivationField {
  const ActivationField({required this.name, required this.label, required this.description});

  factory ActivationField.fromJson(Map<String, dynamic> json) => ActivationField(
        name: json['name'] as String? ?? '',
        label: json['label'] as String? ?? '',
        description: json['description'] as String? ?? '',
      );

  final String name;
  final String label;
  final String description;
}
