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
import '../features/account/data/organization_repository.dart';
import '../features/alumni/data/alumni_server_api.dart';
import '../features/billing/data/billing_repository.dart';
import '../core/access/access_view.dart';
import '../features/proprietor/data/local_owner_access.dart';
import '../features/proprietor/data/owner_access_repository.dart';
import '../features/proprietor/data/owner_access_source.dart';
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
    this.organizations,
    this.billing,
    this.syncEngine,
    this.syncCoordinator,
    this.access,
    this.notifications,
    this.ownerAccess,
    this.localAccess,
    this.staffServer,
    this.alumniServer,
    this.serverConfirm,
  });

  final LocalDatabase localDatabase;
  final SchoolSessionController schoolSession;
  final SchoolAppearanceController schoolAppearance;
  final ApiConfig apiConfig;

  final AuthRepository? auth;

  /// Commercial/account-level operations above individual school tenants.
  /// Present only when the real SchoolOS backend is configured.
  final OrganizationRepository? organizations;

  /// Read-only commercial plan, subscription and entitlement state. Payment
  /// provider actions remain server-side and are intentionally not inferred by
  /// the native app.
  final BillingRepository? billing;

  final SyncEngine? syncEngine;
  final SyncCoordinator? syncCoordinator;
  final AccessController? access;
  final NotificationsController? notifications;
  final OwnerAccessSource? ownerAccess;

  /// Who-sees-what for the demo (no server): the same rules, kept on the device.
  final LocalOwnerAccess? localAccess;

  /// What decides the menus: the server's answer, or the demo's decisions.
  AccessView? get accessView => access ?? localAccess;
  final StaffServerApi? staffServer;
  final AlumniServerApi? alumniServer;
  final ServerConfirm? serverConfirm;

  bool get usesBackend => auth != null;

  Future<void> beginSchool(SchoolMembership membership) async {
    await access?.restore(membership);
    await notifications?.restore(membership);
    syncCoordinator?.start();
  }

  /// Stops school-scoped background work while the signed-in person is at the
  /// account layer. The selected school and its encrypted local records remain
  /// intact, so opening a school again is immediate and safe.
  void pauseSchoolWorkspace() {
    syncCoordinator?.stop();
    access?.clear();
    notifications?.clear();
  }

  Future<void> endSession() async {
    pauseSchoolWorkspace();
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
    OrganizationRepository? organizations;
    BillingRepository? billing;
    SyncEngine? syncEngine;
    SyncCoordinator? syncCoordinator;
    AccessController? access;
    NotificationsController? notifications;
    OwnerAccessSource? ownerAccess;
    StaffServerApi? staffServer;
    AlumniServerApi? alumniServer;
    ServerConfirm? serverConfirm;
    LocalOwnerAccess? localAccess;
    LocalDatabase.blockDemoSeeds = apiConfig.enabled;
    if (apiConfig.enabled) {
      final tokens = SecureTokenStore();
      final api = ApiClient(config: apiConfig, tokens: tokens);
      auth = AuthRepository(
        api: api,
        tokens: tokens,
        schoolSession: schoolSession,
      );
      organizations = OrganizationRepository(api: api, auth: auth);
      billing = BillingRepository(api: api);
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
      alumniServer = AlumniServerApi(
        api: api,
        schoolSession: schoolSession,
      );
      access = AccessController(api: api, store: localDatabase);
      notifications = NotificationsController(api: api, store: localDatabase);
      final followUp = RoundFollowUp(
        access: access,
        notifications: notifications,
        unsent: _LocalUnsentWork(localDatabase),
        activeMembership: () => schoolSession.activeMembership,
      );
      syncCoordinator = SyncCoordinator(
        runner: syncEngine,
        auth: auth,
        afterRound: (summary) async {
          await followUp.call(summary);
          // The owner may have changed the school's colours or logo on another device.
          await schoolAppearance.reload();
        },
      );
      localDatabase.onMutationQueued = syncCoordinator.requestSync;
    } else {
      localAccess = LocalOwnerAccess(store: localDatabase, session: schoolSession);
      ownerAccess = localAccess;
      await localAccess.restore();
    }

    final services = AppServices._(
      localDatabase: localDatabase,
      schoolSession: schoolSession,
      schoolAppearance: schoolAppearance,
      apiConfig: apiConfig,
      auth: auth,
      organizations: organizations,
      billing: billing,
      syncEngine: syncEngine,
      syncCoordinator: syncCoordinator,
      access: access,
      notifications: notifications,
      ownerAccess: ownerAccess,
      localAccess: localAccess,
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
