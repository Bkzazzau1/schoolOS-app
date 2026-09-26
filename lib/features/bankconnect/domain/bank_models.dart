import 'json_read.dart';

/// What a collection provider can really do. The app only offers what is switched on: it never assumes a provider can.
class CollectionCapabilities {
  const CollectionCapabilities({
    this.supportsFamilyCollectionAccounts = false,
    this.supportsStaticAccounts = false,
    this.supportsDynamicAccounts = false,
    this.supportsAccountDeactivation = false,
    this.supportsAccountReactivation = false,
    this.supportsAccountClosure = false,
    this.supportsWebhooks = false,
    this.supportsTransactionRequery = false,
    this.supportsDirectDebitMandates = false,
    this.requiresCustomerKyc = false,
  });

  factory CollectionCapabilities.fromJson(Map<String, dynamic> json) => CollectionCapabilities(
        supportsFamilyCollectionAccounts: json['supportsFamilyCollectionAccounts'] == true,
        supportsStaticAccounts: json['supportsStaticAccounts'] == true,
        supportsDynamicAccounts: json['supportsDynamicAccounts'] == true,
        supportsAccountDeactivation: json['supportsAccountDeactivation'] == true,
        supportsAccountReactivation: json['supportsAccountReactivation'] == true,
        supportsAccountClosure: json['supportsAccountClosure'] == true,
        supportsWebhooks: json['supportsWebhooks'] == true,
        supportsTransactionRequery: json['supportsTransactionRequery'] == true,
        supportsDirectDebitMandates: json['supportsDirectDebitMandates'] == true,
        requiresCustomerKyc: json['requiresCustomerKyc'] == true,
      );

  final bool supportsFamilyCollectionAccounts;
  final bool supportsStaticAccounts;
  final bool supportsDynamicAccounts;
  final bool supportsAccountDeactivation;
  final bool supportsAccountReactivation;
  final bool supportsAccountClosure;
  final bool supportsWebhooks;
  final bool supportsTransactionRequery;
  final bool supportsDirectDebitMandates;

  /// The provider needs the payer's BVN or NIN before it will make a family's account.
  final bool requiresCustomerKyc;
}

/// One thing the school types in to connect a provider: a credential the provider issued to the school.
class CredentialField {
  const CredentialField({required this.name, required this.label, required this.secret, required this.required, this.help = ''});

  factory CredentialField.fromJson(Map<String, dynamic> json) => CredentialField(
        name: json['name'] as String,
        label: json['label'] as String,
        secret: json['secret'] != false,
        required: json['required'] != false,
        help: json['help'] as String? ?? '',
      );

  final String name;
  final String label;

  /// Masked while typed and never shown again.
  final bool secret;
  final bool required;
  final String help;
}

/// A non-secret choice for a provider (for example which bank its family accounts are issued from).
class SettingField {
  const SettingField({required this.name, required this.label, required this.choices, required this.defaultValue, required this.required});

  factory SettingField.fromJson(Map<String, dynamic> json) => SettingField(
        name: json['name'] as String,
        label: json['label'] as String,
        choices: [for (final c in (json['choices'] as List? ?? const [])) c as String],
        defaultValue: json['default'] as String? ?? '',
        required: json['required'] == true,
      );

  final String name;
  final String label;
  final List<String> choices;
  final String defaultValue;
  final bool required;
}

/// How the provider is to tell SchoolOS about payments, and what the school must do about it.
class WebhookGuide {
  const WebhookGuide({required this.mode, required this.where, required this.verification, required this.events, required this.note});

  factory WebhookGuide.fromJson(Map<String, dynamic> json) => WebhookGuide(
        mode: json['mode'] as String? ?? 'dashboard',
        where: json['where'] as String? ?? '',
        verification: json['verification'] as String? ?? '',
        events: [for (final e in (json['events'] as List? ?? const [])) e as String],
        note: json['note'] as String? ?? '',
      );

  /// "dashboard": the school pastes SchoolOS's address into the provider's own dashboard.
  final String mode;
  final String where;

  /// "hmac_sha512": the provider signs each event. "requery": it does not, so SchoolOS confirms each one with the provider.
  final String verification;
  final List<String> events;
  final String note;
}

/// A collection provider SchoolOS supports: Paystack, Monnify or Remita. The school connects its OWN account at one of them.
class CollectionProvider {
  const CollectionProvider({
    required this.code,
    required this.displayName,
    required this.environments,
    required this.credentialFields,
    required this.settingFields,
    required this.capabilities,
    required this.onboarding,
    required this.webhook,
    required this.available,
    required this.isSandbox,
    required this.description,
    required this.accountLabel,
    required this.payerNote,
    required this.customerRequirements,
    required this.requiresAmount,
  });

  factory CollectionProvider.fromJson(Map<String, dynamic> json) => CollectionProvider(
        code: json['code'] as String,
        displayName: json['displayName'] as String? ?? json['code'] as String,
        environments: [for (final e in (json['environments'] as List? ?? const [])) e as String],
        credentialFields: [for (final f in readMaps(json['credentialFields'])) CredentialField.fromJson(f)],
        settingFields: [for (final f in readMaps(json['settingFields'])) SettingField.fromJson(f)],
        capabilities: CollectionCapabilities.fromJson(readMap(json['capabilities'])),
        onboarding: json['onboarding'] as String? ?? '',
        webhook: WebhookGuide.fromJson(readMap(json['webhook'])),
        available: json['available'] == true,
        isSandbox: json['isSandbox'] == true,
        description: json['description'] as String? ?? '',
        accountLabel: json['accountLabel'] as String? ?? 'Account number',
        payerNote: json['payerNote'] as String? ?? '',
        customerRequirements: [for (final r in (json['customerRequirements'] as List? ?? const [])) r as String],
        requiresAmount: json['requiresAmount'] == true,
      );

  final String code;
  final String displayName;

  /// "live" and/or "test".
  final List<String> environments;
  final List<CredentialField> credentialFields;
  final List<SettingField> settingFields;
  final CollectionCapabilities capabilities;

  /// One line telling the school what to do at the provider before it enters credentials.
  final String onboarding;
  final WebhookGuide webhook;
  final bool available;
  final bool isSandbox;
  final String description;

  /// What this provider calls the number a payer uses ("Account number", "Remita Retrieval Reference (RRR)").
  final String accountLabel;
  final String payerNote;

  /// What it needs to know about a family's payer: "name", "email", "phone", "identity" (a BVN or NIN).
  final List<String> customerRequirements;

  /// It makes an account for an amount (Remita), so a family with nothing to collect has nothing to generate.
  final bool requiresAmount;
}

/// What the signed-in person may do in Smart Money Collection. The server checks every change again.
class CollectionPermissions {
  const CollectionPermissions({
    this.canView = false,
    this.canManageProviders = false,
    this.canManagePolicy = false,
    this.canPrepare = false,
    this.canApprove = false,
  });

  factory CollectionPermissions.fromJson(Map<String, dynamic> json) => CollectionPermissions(
        canView: json['canView'] == true,
        canManageProviders: json['canManageProviders'] == true,
        canManagePolicy: json['canManagePolicy'] == true,
        canPrepare: json['canPrepare'] == true,
        canApprove: json['canApprove'] == true,
      );

  final bool canView;
  final bool canManageProviders;
  final bool canManagePolicy;
  final bool canPrepare;
  final bool canApprove;
}

class ProvidersInfo {
  const ProvidersInfo({
    required this.providers,
    required this.canManage,
    required this.secureStorageReady,
    required this.activeConnectionId,
    required this.permissions,
  });

  factory ProvidersInfo.fromJson(Map<String, dynamic> json) => ProvidersInfo(
        providers: [for (final p in readMaps(json['providers'])) CollectionProvider.fromJson(p)],
        canManage: json['canManage'] == true,
        secureStorageReady: json['secureStorageReady'] == true,
        activeConnectionId: json['activeConnectionId'] as String?,
        permissions: CollectionPermissions.fromJson(readMap(json['permissions'])),
      );

  final List<CollectionProvider> providers;
  final bool canManage;

  /// False when the server has no key to keep credentials safely: nothing can be connected.
  final bool secureStorageReady;
  final String? activeConnectionId;
  final CollectionPermissions permissions;

  CollectionProvider? provider(String code) {
    for (final p in providers) {
      if (p.code == code) return p;
    }
    return null;
  }
}

/// The school's own connection to one collection provider. Nothing on it is secret: the server never sends a credential,
/// and SchoolOS never asks for (or shows) a settlement account.
class ProviderConnection {
  const ProviderConnection({
    required this.id,
    required this.provider,
    required this.providerName,
    required this.environment,
    required this.isSandbox,
    required this.merchantName,
    required this.merchantReference,
    required this.label,
    required this.status,
    required this.isActiveProvider,
    required this.webhookStatus,
    required this.webhookConfirmedAt,
    required this.lastVerifiedAt,
    required this.lastErrorCode,
    required this.settings,
    required this.capabilities,
    required this.createdAt,
  });

  factory ProviderConnection.fromJson(Map<String, dynamic> json) => ProviderConnection(
        id: json['id'] as String,
        provider: json['provider'] as String? ?? '',
        providerName: json['providerName'] as String? ?? '',
        environment: json['environment'] as String? ?? 'live',
        isSandbox: json['isSandbox'] == true,
        merchantName: json['merchantName'] as String? ?? '',
        merchantReference: json['merchantReference'] as String? ?? '',
        label: json['label'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        isActiveProvider: json['isActiveProvider'] == true,
        webhookStatus: json['webhookStatus'] as String? ?? 'not_configured',
        webhookConfirmedAt: readTime(json['webhookConfirmedAt']),
        lastVerifiedAt: readTime(json['lastVerifiedAt']),
        lastErrorCode: json['lastErrorCode'] as String? ?? '',
        settings: {for (final e in readMap(json['settings']).entries) e.key: '${e.value}'},
        capabilities: CollectionCapabilities.fromJson(readMap(json['capabilities'])),
        createdAt: readTime(json['createdAt']),
      );

  final String id;
  final String provider;
  final String providerName;

  /// "live" or "test".
  final String environment;
  final bool isSandbox;
  final String merchantName;

  /// A masked identifier the provider gave for the merchant (never a secret).
  final String merchantReference;
  final String label;
  final String status;

  /// The school's ONE active collection provider: the one that makes new family accounts.
  final bool isActiveProvider;

  /// "not_configured", "awaiting_event" or "active". Active only after a verified event has really arrived.
  final String webhookStatus;
  final DateTime? webhookConfirmedAt;
  final DateTime? lastVerifiedAt;
  final String lastErrorCode;
  final Map<String, String> settings;
  final CollectionCapabilities capabilities;
  final DateTime? createdAt;

  bool get isConnected => status == 'connected';
  bool get isDisabled => status == 'disabled';
  bool get isClosed => status == 'revoked';
  bool get needsAttention => status == 'needs_reauth' || status == 'error';
  bool get isLive => environment == 'live';
  bool get webhookActive => webhookStatus == 'active';

  String get title => label.isNotEmpty ? label : providerName;
}

class ConnectionsInfo {
  const ConnectionsInfo({required this.connections, required this.canManage, required this.permissions});

  factory ConnectionsInfo.fromJson(Map<String, dynamic> json) => ConnectionsInfo(
        connections: [for (final c in readMaps(json['connections'])) ProviderConnection.fromJson(c)],
        canManage: json['canManage'] == true,
        permissions: CollectionPermissions.fromJson(readMap(json['permissions'])),
      );

  final List<ProviderConnection> connections;
  final bool canManage;
  final CollectionPermissions permissions;
}

class ConnectionCheck {
  const ConnectionCheck({required this.ok, required this.code, required this.message});

  factory ConnectionCheck.fromJson(Map<String, dynamic> json) => ConnectionCheck(
        ok: json['ok'] == true,
        code: json['code'] as String? ?? '',
        message: json['message'] as String? ?? '',
      );

  final bool ok;
  final String code;
  final String message;
}

/// Where the school gives the provider SchoolOS's address for payment notifications, and whether it is known to work.
class WebhookSetup {
  const WebhookSetup({
    required this.path,
    required this.url,
    required this.status,
    required this.confirmedAt,
    required this.mode,
    required this.where,
    required this.verification,
    required this.events,
    required this.note,
  });

  factory WebhookSetup.fromJson(Map<String, dynamic> json) => WebhookSetup(
        path: json['path'] as String? ?? '',
        url: json['url'] as String? ?? '',
        status: json['status'] as String? ?? 'not_configured',
        confirmedAt: readTime(json['confirmedAt']),
        mode: json['mode'] as String? ?? 'dashboard',
        where: json['where'] as String? ?? '',
        verification: json['verification'] as String? ?? '',
        events: [for (final e in (json['events'] as List? ?? const [])) e as String],
        note: json['note'] as String? ?? '',
      );

  /// The address relative to the school's server (`bank-webhooks/<provider>/<token>/`).
  final String path;

  /// The full public address, when the server knows its own public address; otherwise empty and [path] is what to add to it.
  final String url;
  final String status;
  final DateTime? confirmedAt;
  final String mode;
  final String where;
  final String verification;
  final List<String> events;
  final String note;

  bool get isActive => status == 'active';

  /// What to paste at the provider.
  String get address => url.isNotEmpty ? url : path;
}

/// What came back from an action on one connection.
class ConnectionActionResult {
  const ConnectionActionResult({required this.connection, this.check, this.webhook});

  factory ConnectionActionResult.fromJson(Map<String, dynamic> json) => ConnectionActionResult(
        connection: ProviderConnection.fromJson(readMap(json['connection'])),
        check: json['test'] is Map ? ConnectionCheck.fromJson(readMap(json['test'])) : null,
        webhook: json['webhook'] is Map ? WebhookSetup.fromJson(readMap(json['webhook'])) : null,
      );

  final ProviderConnection connection;
  final ConnectionCheck? check;
  final WebhookSetup? webhook;
}

class ConnectionAuditEvent {
  const ConnectionAuditEvent({required this.kind, required this.detail, required this.at});

  factory ConnectionAuditEvent.fromJson(Map<String, dynamic> json) => ConnectionAuditEvent(
        kind: json['kind'] as String? ?? '',
        detail: readMap(json['detail']),
        at: readTime(json['at']),
      );

  final String kind;
  final Map<String, dynamic> detail;
  final DateTime? at;
}
