import 'package:flutter/material.dart';

import '../features/administrator/presentation/administrator_workspace_page.dart';
import '../features/authentication/presentation/login_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/finance_office/presentation/finance_office_workspace_page.dart';
import '../features/principal/presentation/principal_workspace_page.dart';
import '../features/proprietor/presentation/proprietor_workspace_page.dart';
import '../features/teacher/presentation/teacher_workspace_page.dart';
import '../shared/models/school_membership.dart';
import 'app_services.dart';

class SchoolOsApp extends StatelessWidget {
  const SchoolOsApp({
    super.key,
    required this.services,
  });

  final AppServices services;

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
        if (restoredMembership == null) {
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
        } else {
          home = DashboardPage(
            membership: restoredMembership,
            localDatabase: services.localDatabase,
            schoolSession: services.schoolSession,
            schoolAppearance: services.schoolAppearance,
          );
        }

        return MaterialApp(
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
          home: home,
        );
      },
    );
  }
}
