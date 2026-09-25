import '../core/appearance/school_appearance_controller.dart';
import 'package:flutter/material.dart';

import '../core/network/api_exceptions.dart';
import '../features/account/presentation/account_home_page.dart';
import '../features/account/presentation/proprietor_account_shell.dart';
import '../features/administrator/presentation/administrator_workspace_page.dart';
import '../features/alumni/data/alumni_server_api.dart';
import '../features/transferverify/data/transfer_verify_associations_api.dart';
import '../features/transferverify/data/transfer_verify_network_api.dart';
import '../features/alumni/presentation/alumni_workspace_page.dart';
import '../features/authentication/presentation/login_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/driver/presentation/driver_workspace_page.dart';
import '../features/finance_office/presentation/finance_office_workspace_page.dart';
import '../features/parent/presentation/parent_workspace_page.dart';
import '../features/principal/presentation/principal_workspace_page.dart';
import '../features/proprietor/presentation/proprietor_workspace_page.dart';
import '../features/staff/presentation/staff_workspace_page.dart';
import '../features/teacher/presentation/teacher_workspace_page.dart';
import '../shared/models/school_membership.dart';
import '../core/sync/sync_scope.dart';
import '../features/billing/presentation/billing_scope.dart';
import '../features/proprietor/data/owner_access_scope.dart';
import '../features/proprietor/data/staff_server_api.dart';
import '../features/invitations/presentation/invitation_accept_page.dart';
import 'app_services.dart';
import 'sync_status_banner.dart';
import '../features/student/presentation/student_workspace_page.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

Future<void> _signInAgain(AppServices services) async {
  await services.endSession();
  _navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (context) => LoginPage(services: services),
    ),
    (route) => false,
  );
}

Future<void> _signOutFromAccount(
  BuildContext context,
  AppServices services,
) async {
  await services.endSession();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (_) => LoginPage(services: services),
    ),
    (route) => false,
  );
}

Future<void> _openRestoredAccountHome(
  BuildContext context,
  AppServices services,
) async {
  final auth = services.auth;
  if (auth == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connect SchoolOS to the server to manage your school account.'),
      ),
    );
    return;
  }

  try {
    final profile = await auth.refreshProfile();
    if (!context.mounted) return;
    if (profile.organizations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This school is not connected to a SchoolOS account you manage.'),
        ),
      );
      return;
    }

    services.pauseSchoolWorkspace();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => AccountHomePage(
          profile: profile,
          services: services,
          onSignOut: (accountContext) =>
              _signOutFromAccount(accountContext, services),
        ),
      ),
      (route) => false,
    );
  } on ApiOfflineException {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not refresh your SchoolOS account. Check your connection and try again.'),
      ),
    );
  } on SessionExpiredException {
    await _signInAgain(services);
  } on ApiException catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.message)),
    );
  }
}

class SchoolOsApp extends StatelessWidget {
  const SchoolOsApp({super.key, required this.services, this.initialInvitationLink});

  final AppServices services;
  final String? initialInvitationLink;

  @override
  Widget build(BuildContext context) {
    DashboardPage.appSchoolAppearance = services.schoolAppearance;
    SchoolAppearanceController.shared = services.schoolAppearance;

    return AnimatedBuilder(
      animation: services.schoolAppearance,
      builder: (context, _) {
        final restoredMembership = services.schoolSession.activeMembership;
        final schoolTheme = services.schoolAppearance.theme;
        final primary = Color(schoolTheme.darkArgb);
        final accent = Color(schoolTheme.accentArgb);
        final baseScheme = ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        );
        final colorScheme = baseScheme.copyWith(
          primary: primary,
          secondary: accent,
          onSecondary: primary,
        );

        final Widget home;
        if (restoredMembership == null && initialInvitationLink != null && services.usesBackend) {
          home = InvitationAcceptPage(services: services, initialLink: initialInvitationLink);
        } else if (restoredMembership == null) {
          home = LoginPage(services: services);
        } else if (restoredMembership.role == SchoolRole.student) {
          home = StudentWorkspacePage(membership: restoredMembership, localDatabase: services.localDatabase, schoolSession: services.schoolSession);
        } else if (restoredMembership.role == SchoolRole.proprietor) {
          final canOpenAccount =
              restoredMembership.organizationId != null && services.auth != null;
          home = canOpenAccount
              ? ProprietorAccountShell(
                  membership: restoredMembership,
                  localDatabase: services.localDatabase,
                  schoolSession: services.schoolSession,
                  schoolAppearance: services.schoolAppearance,
                  onOpenAccountHome: (schoolContext) =>
                      _openRestoredAccountHome(schoolContext, services),
                )
              : ProprietorWorkspacePage(
                  membership: restoredMembership,
                  localDatabase: services.localDatabase,
                  schoolSession: services.schoolSession,
                  schoolAppearance: services.schoolAppearance,
                );
        } else if (restoredMembership.role == SchoolRole.administrator) {
          home = AdministratorWorkspacePage(
            membership: restoredMembership,
            localDatabase: services.localDatabase,
            schoolSession: services.schoolSession,
            schoolAppearance: services.schoolAppearance,
          );
        } else if (restoredMembership.role == SchoolRole.principal) {
          home = PrincipalWorkspacePage(
            membership: restoredMembership,
            localDatabase: services.localDatabase,
            schoolSession: services.schoolSession,
            schoolAppearance: services.schoolAppearance,
          );
        } else if (restoredMembership.role == SchoolRole.accountant) {
          home = FinanceOfficeWorkspacePage(
            membership: restoredMembership,
            localDatabase: services.localDatabase,
            schoolSession: services.schoolSession,
            schoolAppearance: services.schoolAppearance,
          );
        } else if (restoredMembership.role == SchoolRole.teacher) {
          home = TeacherWorkspacePage(
            membership: restoredMembership,
            localDatabase: services.localDatabase,
            schoolSession: services.schoolSession,
            schoolAppearance: services.schoolAppearance,
          );
        } else if (restoredMembership.role == SchoolRole.parent) {
          home = ParentWorkspacePage(
            membership: restoredMembership,
            localDatabase: services.localDatabase,
            schoolSession: services.schoolSession,
            schoolAppearance: services.schoolAppearance,
          );
        } else if (restoredMembership.role == SchoolRole.driver) {
          home = DriverWorkspacePage(
            membership: restoredMembership,
            localDatabase: services.localDatabase,
            schoolSession: services.schoolSession,
            schoolAppearance: services.schoolAppearance,
          );
        } else if (restoredMembership.role == SchoolRole.alumni) {
          home = AlumniWorkspacePage(
            membership: restoredMembership,
            localDatabase: services.localDatabase,
            schoolSession: services.schoolSession,
            schoolAppearance: services.schoolAppearance,
          );
        } else if (restoredMembership.role == SchoolRole.staff) {
          home = StaffWorkspacePage(
            membership: restoredMembership,
            localDatabase: services.localDatabase,
            schoolSession: services.schoolSession,
            schoolAppearance: services.schoolAppearance,
          );
        } else {
          home = DashboardPage(
            membership: restoredMembership,
            localDatabase: services.localDatabase,
            schoolSession: services.schoolSession,
            schoolAppearance: services.schoolAppearance,
          );
        }

        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'SchoolOS',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: colorScheme,
            scaffoldBackgroundColor: const Color(0xFFF7F9FC),
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();
            final coordinator = services.syncCoordinator;
            final Widget scoped = coordinator == null
                ? child
                : SyncScope(
                    coordinator: coordinator,
                    child: SyncStatusBanner(
                      coordinator: coordinator,
                      onSignInAgain: () => _signInAgain(services),
                      child: child,
                    ),
                  );
            final access = services.accessView;
            final notifications = services.notifications;
            Widget tree = scoped;
            if (access != null) tree = AccessScope(access: access, child: tree);
            final serverConfirm = services.serverConfirm;
            if (serverConfirm != null) tree = ServerConfirmScope(confirm: serverConfirm, child: tree);
            final staffServer = services.staffServer;
            if (staffServer != null) tree = StaffServerScope(api: staffServer, child: tree);
            final alumniServer = services.alumniServer;
            if (alumniServer != null) tree = AlumniServerScope(api: alumniServer, child: tree);
            final transferVerifyAssociations = services.transferVerifyAssociations;
            if (transferVerifyAssociations != null) {
              tree = TransferVerifyAssociationsScope(api: transferVerifyAssociations, child: tree);
            }
            final transferVerifyNetwork = services.transferVerifyNetwork;
            if (transferVerifyNetwork != null) {
              tree = TransferVerifyNetworkScope(api: transferVerifyNetwork, child: tree);
            }
            final ownerAccess = services.ownerAccess;
            if (ownerAccess != null) {
              tree = OwnerAccessScope(repository: ownerAccess, child: tree);
            }
            final billing = services.billing;
            if (billing != null) {
              tree = BillingScope(repository: billing, child: tree);
            }
            if (notifications != null) {
              tree = NotificationsScope(notifications: notifications, child: tree);
            }
            return tree;
          },
          home: home,
        );
      },
    );
  }
}
