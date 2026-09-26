import 'bank_labels.dart';
import 'json_read.dart';

/// What a provider can really do. The app only offers what is switched on: it never assumes a bank can.
class BankCapabilities {
  const BankCapabilities({
    this.supportsTransactionSync = false,
    this.supportsWebhooks = false,
    this.supportsBalance = false,
    this.supportsHistoricalTransactions = false,
    this.supportsRealtimeTransactions = false,
    this.supportsAccountVerification = false,
    this.supportsTokenRefresh = false,
  });

  factory BankCapabilities.fromJson(Map<String, dynamic> json) => BankCapabilities(
        supportsTransactionSync: json['supportsTransactionSync'] == true,
        supportsWebhooks: json['supportsWebhooks'] == true,
        supportsBalance: json['supportsBalance'] == true,
        supportsHistoricalTransactions: json['supportsHistoricalTransactions'] == true,
        supportsRealtimeTransactions: json['supportsRealtimeTransactions'] == true,
        supportsAccountVerification: json['supportsAccountVerification'] == true,
        supportsTokenRefresh: json['supportsTokenRefresh'] == true,
      );

  final bool supportsTransactionSync;
  final bool supportsWebhooks;
  final bool supportsBalance;
  final bool supportsHistoricalTransactions;
  final bool supportsRealtimeTransactions;
  final bool supportsAccountVerification;
  final bool supportsTokenRefresh;
}

class CredentialField {
  const CredentialField({required this.name, required this.label, required this.secret, required this.required});

  factory CredentialField.fromJson(Map<String, dynamic> json) => CredentialField(
        name: json['name'] as String,
        label: json['label'] as String,
        secret: json['secret'] != false,
        required: json['required'] != false,
      );

  final String name;
  final String label;

  /// Masked while typed and never shown again.
  final bool secret;
  final bool required;
}

class BankProvider {
  const BankProvider({
    required this.code,
    required this.displayName,
    required this.connectionType,
    required this.connectMethods,
    required this.credentialFields,
    required this.capabilities,
    required this.productionStatus,
    required this.available,
    required this.isSandbox,
    required this.description,
  });

  factory BankProvider.fromJson(Map<String, dynamic> json) => BankProvider(
        code: json['code'] as String,
        displayName: json['displayName'] as String? ?? json['code'] as String,
        connectionType: json['connectionType'] as String? ?? '',
        connectMethods: [for (final m in (json['connectMethods'] as List? ?? const [])) m as String],
        credentialFields: [for (final f in readMaps(json['credentialFields'])) CredentialField.fromJson(f)],
        capabilities: BankCapabilities.fromJson(readMap(json['capabilities'])),
        productionStatus: json['productionStatus'] as String? ?? '',
        available: json['available'] == true,
        isSandbox: json['isSandbox'] == true,
        description: json['description'] as String? ?? '',
      );

  final String code;
  final String displayName;
  final String connectionType;
  final List<String> connectMethods;
  final List<CredentialField> credentialFields;
  final BankCapabilities capabilities;
  final String productionStatus;

  /// False for a bank SchoolOS has not been given verified API documentation for.
  final bool available;
  final bool isSandbox;
  final String description;

  bool get usesCredentials => connectMethods.contains('credentials');
  bool get usesAuthorization => connectMethods.contains('authorization');

  /// A payment provider that reports collections it processed: not access to the school's own bank account.
  bool get isCollectionProvider => connectionType == 'collection_provider';
}

class ProvidersInfo {
  const ProvidersInfo({required this.providers, required this.canManage, required this.secureStorageReady});

  factory ProvidersInfo.fromJson(Map<String, dynamic> json) => ProvidersInfo(
        providers: [for (final p in readMaps(json['providers'])) BankProvider.fromJson(p)],
        canManage: json['canManage'] == true,
        secureStorageReady: json['secureStorageReady'] == true,
      );

  final List<BankProvider> providers;
  final bool canManage;

  /// False when the server has no key to keep bank credentials safely: nothing can be connected.
  final bool secureStorageReady;
}

/// One of the school's own accounts. Nothing on it is secret: the server never sends a credential,
/// and only the last four digits of the account.
class BankConnection {
  const BankConnection({
    required this.id,
    required this.provider,
    required this.providerName,
    required this.connectionType,
    required this.isSandbox,
    required this.bankName,
    required this.accountName,
    required this.accountMask,
    required this.purpose,
    required this.label,
    required this.status,
    required this.lastSyncedAt,
    required this.lastErrorCode,
    required this.webhookConfigured,
    required this.capabilities,
    required this.createdAt,
  });

  factory BankConnection.fromJson(Map<String, dynamic> json) => BankConnection(
        id: json['id'] as String,
        provider: json['provider'] as String? ?? '',
        providerName: json['providerName'] as String? ?? '',
        connectionType: json['connectionType'] as String? ?? '',
        isSandbox: json['isSandbox'] == true,
        bankName: json['bankName'] as String? ?? '',
        accountName: json['accountName'] as String? ?? '',
        accountMask: json['accountMask'] as String? ?? '',
        purpose: json['purpose'] as String? ?? 'general',
        label: json['label'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        lastSyncedAt: readTime(json['lastSyncedAt']),
        lastErrorCode: json['lastErrorCode'] as String? ?? '',
        webhookConfigured: json['webhookConfigured'] == true,
        capabilities: BankCapabilities.fromJson(readMap(json['capabilities'])),
        createdAt: readTime(json['createdAt']),
      );

  final String id;
  final String provider;
  final String providerName;
  final String connectionType;
  final bool isSandbox;
  final String bankName;
  final String accountName;
  final String accountMask;
  final String purpose;
  final String label;
  final String status;
  final DateTime? lastSyncedAt;
  final String lastErrorCode;
  final bool webhookConfigured;
  final BankCapabilities capabilities;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
  bool get isConnected => status == 'connected';
  bool get isDisabled => status == 'disabled';
  bool get isClosed => status == 'revoked';
  bool get needsAttention => status == 'needs_reauth' || status == 'error';

  String get title => label.isNotEmpty ? label : '${purposeLabel(purpose)} account';
  String get bankTitle => bankName.isNotEmpty ? bankName : providerName;
}

class ConnectionsInfo {
  const ConnectionsInfo({required this.connections, required this.canManage});

  factory ConnectionsInfo.fromJson(Map<String, dynamic> json) => ConnectionsInfo(
        connections: [for (final c in readMaps(json['connections'])) BankConnection.fromJson(c)],
        canManage: json['canManage'] == true,
      );

  final List<BankConnection> connections;
  final bool canManage;
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

class SyncResult {
  const SyncResult({
    required this.ok,
    required this.fetched,
    required this.created,
    required this.duplicates,
    required this.more,
    required this.code,
    required this.message,
  });

  factory SyncResult.fromJson(Map<String, dynamic> json) => SyncResult(
        ok: json['ok'] == true,
        fetched: json['fetched'] as int? ?? 0,
        created: json['created'] as int? ?? 0,
        duplicates: json['duplicates'] as int? ?? 0,
        more: json['more'] == true,
        code: json['code'] as String? ?? '',
        message: json['message'] as String? ?? '',
      );

  final bool ok;
  final int fetched;
  final int created;
  final int duplicates;
  final bool more;
  final String code;
  final String message;
}

/// What came back from an action on one connection.
class ConnectionActionResult {
  const ConnectionActionResult({required this.connection, this.check, this.sync, this.webhookPath, this.providerRevoked});

  factory ConnectionActionResult.fromJson(Map<String, dynamic> json) => ConnectionActionResult(
        connection: BankConnection.fromJson(readMap(json['connection'])),
        check: json['test'] is Map ? ConnectionCheck.fromJson(readMap(json['test'])) : null,
        sync: json['sync'] is Map ? SyncResult.fromJson(readMap(json['sync'])) : null,
        webhookPath: readMap(json['webhook'])['path'] as String?,
        providerRevoked: json['providerRevoked'] as bool?,
      );

  final BankConnection connection;
  final ConnectionCheck? check;
  final SyncResult? sync;

  /// Where the provider should send its callbacks. Shown once: only a hash is kept on the server.
  final String? webhookPath;
  final bool? providerRevoked;
}

class AuthorizationStart {
  const AuthorizationStart({required this.url, required this.state});

  factory AuthorizationStart.fromJson(Map<String, dynamic> json) =>
      AuthorizationStart(url: json['authorizationUrl'] as String, state: json['state'] as String);

  final String url;
  final String state;
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
