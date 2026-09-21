import '../core/appearance/school_appearance_controller.dart';
import '../core/auth/auth_repository.dart';
import '../core/auth/token_store.dart';
import '../core/database/local_database.dart';
import '../core/network/api_client.dart';
import '../core/network/api_config.dart';
import '../core/security/payload_cipher.dart';
import '../core/sync/http_sync_transport.dart';
import '../core/sync/sync_coordinator.dart';
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
    this.syncCoordinator,
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

  /// Keeps the device and the school in step (sending, downloading, retrying). Null without a backend.
  final SyncCoordinator? syncCoordinator;

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
    SyncCoordinator? syncCoordinator;
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

      // A school chosen on an earlier visit is only usable while the sign-in
      // that chose it is still here. Without it, start at the login screen.
      if (schoolSession.hasActiveSchool && !await auth.hasSession()) {
        await schoolSession.clear();
      }

      syncCoordinator = SyncCoordinator(runner: syncEngine, auth: auth);
      // Every screen queues its changes through the database, so hearing about
      // them here means no screen has to remember to ask for a sync.
      localDatabase.onMutationQueued = syncCoordinator.requestSync;
      if (schoolSession.hasActiveSchool) syncCoordinator.start();
    }

    return AppServices._(
      localDatabase: localDatabase,
      schoolSession: schoolSession,
      schoolAppearance: schoolAppearance,
      apiConfig: apiConfig,
      auth: auth,
      syncEngine: syncEngine,
      syncCoordinator: syncCoordinator,
    );
  }
}
