import '../core/appearance/school_appearance_controller.dart';
import '../core/auth/auth_repository.dart';
import '../core/auth/token_store.dart';
import '../core/access/access_controller.dart';
import '../core/database/local_database.dart';
import '../core/network/api_client.dart';
import '../core/network/api_config.dart';
import '../core/security/payload_cipher.dart';
import '../core/notifications/notifications_controller.dart';
import '../core/sync/http_sync_transport.dart';
import '../core/sync/round_follow_up.dart';
import '../core/sync/sync_coordinator.dart';
import '../core/sync/sync_engine.dart';
import '../features/proprietor/data/owner_access_repository.dart';
import '../features/proprietor/data/staff_server_api.dart';
import '../core/sync/sync_puller.dart';
import '../core/tenancy/school_session_controller.dart';
import '../shared/models/school_membership.dart';
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
    this.access,
    this.notifications,
    this.ownerAccess,
    this.staffServer,
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

  /// Which screens the person may use, as the owner decided. Null without a backend (everything is shown).
  final AccessController? access;

  /// The person's inbox. Null without a backend.
  final NotificationsController? notifications;

  /// The owner's calls for deciding who sees which screen. Null without a backend.
  final OwnerAccessRepository? ownerAccess;

  /// Approving proposals, invitations and staff registration, decided by the server. Null without a backend.
  final StaffServerApi? staffServer;

  bool get usesBackend => auth != null;

  /// A school has been chosen (after sign-in, or when the app opens on one):
  /// load what is kept on the device for it, and start keeping in step.
  Future<void> beginSchool(SchoolMembership membership) async {
    await access?.restore(membership);
    await notifications?.restore(membership);
    syncCoordinator?.start();
  }

  /// The person signed out: forget what belonged to them and stop syncing.
  Future<void> endSession() async {
    syncCoordinator?.stop();
    access?.clear();
    notifications?.clear();
    await auth?.signOut();
  }

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
    AccessController? access;
    NotificationsController? notifications;
    OwnerAccessRepository? ownerAccess;
    StaffServerApi? staffServer;
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

      ownerAccess = OwnerAccessRepository(api: api);
      staffServer = StaffServerApi(api: api, afterChange: () async => await syncCoordinator?.syncNow());
      access = AccessController(api: api, store: localDatabase);
      notifications = NotificationsController(api: api, store: localDatabase);
      syncCoordinator = SyncCoordinator(
        runner: syncEngine,
        auth: auth,
        afterRound: RoundFollowUp(
          access: access,
          notifications: notifications,
          unsent: _LocalUnsentWork(localDatabase),
          activeMembership: () => schoolSession.activeMembership,
        ).call,
      );
      // Every screen queues its changes through the database, so hearing about
      // them here means no screen has to remember to ask for a sync.
      localDatabase.onMutationQueued = syncCoordinator.requestSync;
    }

    final services = AppServices._(
      localDatabase: localDatabase,
      schoolSession: schoolSession,
      schoolAppearance: schoolAppearance,
      apiConfig: apiConfig,
      auth: auth,
      syncEngine: syncEngine,
      syncCoordinator: syncCoordinator,
      access: access,
      notifications: notifications,
      ownerAccess: ownerAccess,
      staffServer: staffServer,
    );
    final active = schoolSession.activeMembership;
    if (active != null) await services.beginSchool(active);
    return services;
  }
}

class _LocalUnsentWork implements UnsentWork {
  _LocalUnsentWork(this._database);

  final LocalDatabase _database;

  @override
  Future<bool> hasUnsentChanges(String tenantId) async =>
      (await _database.pendingMutations(tenantId: tenantId, limit: 1)).isNotEmpty;
}
