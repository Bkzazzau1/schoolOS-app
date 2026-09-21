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
import '../core/sync/server_confirm.dart';
import '../core/sync/round_follow_up.dart';
import '../core/sync/sync_coordinator.dart';
import '../core/sync/sync_engine.dart';
import '../features/alumni/data/alumni_server_api.dart';
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
    this.alumniServer,
    this.serverConfirm,
  });

  final LocalDatabase localDatabase;
  final SchoolSessionController schoolSession;
  final SchoolAppearanceController schoolAppearance;
  final ApiConfig apiConfig;

  final AuthRepository? auth;
  final SyncEngine? syncEngine;
  final SyncCoordinator? syncCoordinator;
  final AccessController? access;
  final NotificationsController? notifications;
  final OwnerAccessRepository? ownerAccess;
  final StaffServerApi? staffServer;

  /// Alumni identity, profile and school-verification calls. Null without a backend.
  final AlumniServerApi? alumniServer;

  final ServerConfirm? serverConfirm;

  bool get usesBackend => auth != null;

  Future<void> beginSchool(SchoolMembership membership) async {
    await access?.restore(membership);
    await notifications?.restore(membership);
    syncCoordinator?.start();
  }

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
    AlumniServerApi? alumniServer;
    ServerConfirm? serverConfirm;
    LocalDatabase.blockDemoSeeds = apiConfig.enabled;
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

      if (schoolSession.hasActiveSchool && !await auth.hasSession()) {
        await schoolSession.clear();
      }

      serverConfirm = ServerConfirm(
        database: localDatabase,
        syncNow: () async => await syncCoordinator?.syncNow(),
      );
      ownerAccess = OwnerAccessRepository(api: api);
      staffServer = StaffServerApi(
        api: api,
        afterChange: () async => await syncCoordinator?.syncNow(),
      );
      alumniServer = AlumniServerApi(api: api);
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
      alumniServer: alumniServer,
      serverConfirm: serverConfirm,
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
