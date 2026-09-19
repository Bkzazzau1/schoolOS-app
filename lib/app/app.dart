import 'package:flutter/material.dart';

import '../features/authentication/presentation/login_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/proprietor/presentation/proprietor_workspace_page.dart';
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
          home: restoredMembership == null
              ? LoginPage(services: services)
              : restoredMembership.role == SchoolRole.proprietor
                  ? ProprietorWorkspacePage(
                      membership: restoredMembership,
                      localDatabase: services.localDatabase,
                      schoolSession: services.schoolSession,
                      schoolAppearance: services.schoolAppearance,
                    )
                  : DashboardPage(
                      membership: restoredMembership,
                      localDatabase: services.localDatabase,
                      schoolSession: services.schoolSession,
                    ),
        );
      },
    );
  }
}
