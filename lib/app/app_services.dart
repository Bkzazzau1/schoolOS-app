import '../core/appearance/school_appearance_controller.dart';
import '../core/auth/auth_repository.dart';
import '../core/auth/token_store.dart';
import '../core/database/local_database.dart';
import '../core/network/api_client.dart';
import '../core/network/api_config.dart';
import '../core/security/payload_cipher.dart';
import '../core/sync/http_sync_transport.dart';
import '../core/sync/sync_engine.dart';
import '../core/sync/sync_puller.dart';
import '../core/tenancy/school_session_controller.dart';
import '../core/tenancy/school_session_store.dart';

class AppServices {
  AppServices._({
    required this.localDatabase,
    required this.schoolSession,
    required this.schoolAppearance,
    required this.apiConfig,
    this.auth,
    this.syncEngine,
  });

  final LocalDatabase localDatabase;
  final SchoolSessionController schoolSession;
  final SchoolAppearanceController schoolAppearance;
  final ApiConfig apiConfig;

  /// Sign-in against the SchoolOS backend. Null when no backend is configured
  /// (the app then runs on its demo data, as before).
  final AuthRepository? auth;

  /// Sends queued changes to the backend and downloads what changed. Null without a backend.
  final SyncEngine? syncEngine;

  bool get usesBackend => auth != null;

  static Future<AppServices> bootstrap({
    ApiConfig apiConfig = ApiConfig.fromEnvironment,
  }) async {
    final cipher = PayloadCipher();
    final localDatabase = LocalDatabase(cipher: cipher);
    await localDatabase.initialize();

    final schoolSession = SchoolSessionController(store: SchoolSessionStore());
    await schoolSession.restore();

    final schoolAppearance = SchoolAppearanceController(
      localDatabase: localDatabase,
      schoolSession: schoolSession,
    );
    await schoolAppearance.initialize();

    AuthRepository? auth;
    SyncEngine? syncEngine;
    if (apiConfig.enabled) {
      final tokens = SecureTokenStore();
      final api = ApiClient(config: apiConfig, tokens: tokens);
      auth = AuthRepository(
        api: api,
        tokens: tokens,
        schoolSession: schoolSession,
      );
      syncEngine = SyncEngine(
        localDatabase: localDatabase,
        schoolSession: schoolSession,
        transport: HttpSyncTransport(api),
        puller: SyncPuller(api: api, store: localDatabase),
      );
    }

    return AppServices._(
      localDatabase: localDatabase,
      schoolSession: schoolSession,
      schoolAppearance: schoolAppearance,
      apiConfig: apiConfig,
      auth: auth,
      syncEngine: syncEngine,
    );
  }
}
