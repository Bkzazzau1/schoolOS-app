import '../core/appearance/school_appearance_controller.dart';
import '../core/auth/auth_repository.dart';
import '../core/auth/token_store.dart';
import '../core/access/access_controller.dart';
import '../core/database/local_database.dart';
import '../core/media/media_api.dart';
import '../core/media/media_upload_queue.dart';
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
import '../features/bankconnect/data/bank_connect_api.dart';
import '../features/familyfees/data/family_fees_api.dart';
import '../features/mandates/data/mandates_api.dart';
import '../features/smartcollect/data/smart_collect_api.dart';
import '../features/billing/data/billing_repository.dart';
import '../core/access/access_view.dart';
import '../features/proprietor/data/local_owner_access.dart';
import '../features/proprietor/data/owner_access_repository.dart';
import '../features/proprietor/data/owner_access_source.dart';
import '../features/proprietor/data/staff_server_api.dart';
import '../features/transferverify/data/transfer_verify_associations_api.dart';
import '../features/transferverify/data/transfer_verify_network_api.dart';
import '../core/sync/sync_puller.dart';
import '../core/tenancy/school_session_controller.dart';
import '../shared/models/school_membership.dart';
import '../core/tenancy/school_session_store.dart';

class AppServices {
  AppServices._({
    required this.localDatabase,
    required this.schoolSession,
    required this.schoolAppearance,
    required this.mediaQueue,
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
    this.bankConnect,
    this.smartCollect,
    this.mandates,
    this.mediaApi,
    this.familyFees,
    this.transferVerifyAssociations,
    this.transferVerifyNetwork,
    this.serverConfirm,
  });

  final LocalDatabase localDatabase;
  final SchoolSessionController schoolSession;
  final SchoolAppearanceController schoolAppearance;

  /// The durable offline upload queue for real files (photos, videos, documents). Exists in demo mode too - a
  /// file can be picked and queued without a server - but only sends once [mediaApi] exists.
  final MediaUploadQueue mediaQueue;
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

  /// The school's own collection providers (Paystack, Monnify) and the payments they report. Online only: absent without a server.
  final BankConnectApi? bankConnect;

  /// Smart Money Collection: the collection policy, batches with maker-checker approval, and provider switches. Online only.
  final SmartCollectApi? smartCollect;

  /// Mandates & Direct Debit (Remita, Lendsqr). Online only: absent without a server. Separate from Smart Money Collection.
  final MandatesApi? mandates;

  /// SchoolOS's one canonical file/media service. Online only: absent without a server. See [mediaQueue] for
  /// queuing a file while offline.
  final MediaApi? mediaApi;

  /// Families and the accounts each one pays into (the school's own accounts, never SchoolOS's). Online only.
  final FamilyFeesApi? familyFees;
  final TransferVerifyAssociationsApi? transferVerifyAssociations;
  final TransferVerifyNetworkApi? transferVerifyNetwork;
  final ServerConfirm? serverConfirm;

  bool get usesBackend => auth != null;

  Future<void> beginSchool(SchoolMembership membership) async {
    await access?.restore(membership);
    await notifications?.restore(membership);
    syncCoordinator?.start();
    mediaQueue.start();
  }

  /// Stops school-scoped background work while the signed-in person is at the
  /// account layer. The selected school and its encrypted local records remain
  /// intact, so opening a school again is immediate and safe.
  void pauseSchoolWorkspace() {
    syncCoordinator?.stop();
    mediaQueue.stop();
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

    final mediaQueue = MediaUploadQueue(database: localDatabase, schoolSession: schoolSession);
    localDatabase.onMediaUploadQueued = mediaQueue.requestRun;

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
    BankConnectApi? bankConnect;
    SmartCollectApi? smartCollect;
    MandatesApi? mandates;
    MediaApi? mediaApi;
    FamilyFeesApi? familyFees;
    TransferVerifyAssociationsApi? transferVerifyAssociations;
    TransferVerifyNetworkApi? transferVerifyNetwork;
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
      bankConnect = BankConnectApi(api: api);
      smartCollect = SmartCollectApi(api: api);
      mandates = MandatesApi(api: api);
      mediaApi = MediaApi(api: api);
      mediaQueue.api = mediaApi;
      familyFees = FamilyFeesApi(api: api);
      transferVerifyAssociations = TransferVerifyAssociationsApi(api: api);
      transferVerifyNetwork = TransferVerifyNetworkApi(api: api);
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
      mediaQueue: mediaQueue,
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
      bankConnect: bankConnect,
      smartCollect: smartCollect,
      mandates: mandates,
      mediaApi: mediaApi,
      familyFees: familyFees,
      transferVerifyAssociations: transferVerifyAssociations,
      transferVerifyNetwork: transferVerifyNetwork,
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
