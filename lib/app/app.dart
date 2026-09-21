import 'package:flutter/material.dart';

import '../features/administrator/presentation/administrator_workspace_page.dart';
import '../features/alumni/data/alumni_server_api.dart';
import '../features/alumni/presentation/alumni_workspace_page.dart';
import '../features/authentication/presentation/login_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/driver/presentation/driver_workspace_page.dart';
import '../features/finance_office/presentation/finance_office_workspace_page.dart';
import '../features/parent/presentation/parent_workspace_page.dart';
import '../features/principal/presentation/principal_workspace_page.dart';
import '../features/proprietor/presentation/proprietor_workspace_page.dart';
import '../features/teacher/presentation/teacher_workspace_page.dart';
import '../shared/models/school_membership.dart';
import '../core/sync/sync_scope.dart';
import '../features/proprietor/data/owner_access_scope.dart';
import '../features/proprietor/data/staff_server_api.dart';
import '../features/invitations/presentation/invitation_accept_page.dart';
import 'app_services.dart';
import 'sync_status_banner.dart';

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

class SchoolOsApp extends StatelessWidget {
  const SchoolOsApp({super.key, required this.services, this.initialInvitationLink});

  final AppServices services;
  final String? initialInvitationLink;

  @override
  Widget build(BuildContext context) {
    DashboardPage.appSchoolAppearance = services.schoolAppearance;

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
        } else if (restoredMembership.role == SchoolRole.proprietor) {
          home = ProprietorWorkspacePage(
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
            final coordinator = services.syncCoordinator;
            if (coordinator == null || child == null) {
              return child ?? const SizedBox.shrink();
            }
            final scoped = SyncScope(
              coordinator: coordinator,
              child: SyncStatusBanner(
                coordinator: coordinator,
                onSignInAgain: () => _signInAgain(services),
                child: child,
              ),
            );
            final access = services.access;
            final notifications = services.notifications;
            Widget tree = scoped;
            if (access != null) tree = AccessScope(access: access, child: tree);
            final serverConfirm = services.serverConfirm;
            if (serverConfirm != null) tree = ServerConfirmScope(confirm: serverConfirm, child: tree);
            final staffServer = services.staffServer;
            if (staffServer != null) tree = StaffServerScope(api: staffServer, child: tree);
            final alumniServer = services.alumniServer;
            if (alumniServer != null) tree = AlumniServerScope(api: alumniServer, child: tree);
            final ownerAccess = services.ownerAccess;
            if (ownerAccess != null) {
              tree = OwnerAccessScope(repository: ownerAccess, child: tree);
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
