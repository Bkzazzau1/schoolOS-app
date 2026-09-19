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
    final restoredMembership = services.schoolSession.activeMembership;

    return MaterialApp(
      title: 'SchoolOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
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
                )
              : DashboardPage(
                  membership: restoredMembership,
                  localDatabase: services.localDatabase,
                  schoolSession: services.schoolSession,
                ),
    );
  }
}
