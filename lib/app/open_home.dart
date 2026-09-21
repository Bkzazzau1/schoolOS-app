import 'package:flutter/material.dart';

import '../features/administrator/presentation/administrator_workspace_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/driver/presentation/driver_workspace_page.dart';
import '../features/finance_office/presentation/finance_office_workspace_page.dart';
import '../features/parent/presentation/parent_workspace_page.dart';
import '../features/principal/presentation/principal_workspace_page.dart';
import '../features/proprietor/presentation/proprietor_workspace_page.dart';
import '../features/teacher/presentation/teacher_workspace_page.dart';
import '../shared/models/school_membership.dart';
import 'app_services.dart';

/// Chooses this school and role, starts keeping in step with the school, and opens the
/// workspace for the role. Used after signing in and after accepting an invitation.
Future<void> openMembershipHome(
  BuildContext context,
  AppServices services,
  SchoolMembership membership,
) async {
  await services.schoolSession.selectSchool(membership);
  await services.beginSchool(membership);
  // Earlier routes may have been replaced; the caller's context is the one still mounted.
  if (!context.mounted) return;

    final Widget page;
    if (membership.role == SchoolRole.proprietor) {
      page = ProprietorWorkspacePage(
        membership: membership,
        localDatabase: services.localDatabase,
        schoolSession: services.schoolSession,
        schoolAppearance: services.schoolAppearance,
      );
    } else if (membership.role == SchoolRole.administrator) {
      page = AdministratorWorkspacePage(
        membership: membership,
        localDatabase: services.localDatabase,
        schoolSession: services.schoolSession,
        schoolAppearance: services.schoolAppearance,
      );
    } else if (membership.role == SchoolRole.accountant) {
      page = FinanceOfficeWorkspacePage(
        membership: membership,
        localDatabase: services.localDatabase,
        schoolSession: services.schoolSession,
        schoolAppearance: services.schoolAppearance,
      );
    } else if (membership.role == SchoolRole.principal) {
      page = PrincipalWorkspacePage(
        membership: membership,
        localDatabase: services.localDatabase,
        schoolSession: services.schoolSession,
        schoolAppearance: services.schoolAppearance,
      );
    } else if (membership.role == SchoolRole.teacher) {
      page = TeacherWorkspacePage(
        membership: membership,
        localDatabase: services.localDatabase,
        schoolSession: services.schoolSession,
        schoolAppearance: services.schoolAppearance,
      );
    } else if (membership.role == SchoolRole.parent) {
      page = ParentWorkspacePage(
        membership: membership,
        localDatabase: services.localDatabase,
        schoolSession: services.schoolSession,
        schoolAppearance: services.schoolAppearance,
      );
    } else if (membership.role == SchoolRole.driver) {
      page = DriverWorkspacePage(
        membership: membership,
        localDatabase: services.localDatabase,
        schoolSession: services.schoolSession,
        schoolAppearance: services.schoolAppearance,
      );
    } else {
      page = DashboardPage(
        membership: membership,
        localDatabase: services.localDatabase,
        schoolSession: services.schoolSession,
        schoolAppearance: services.schoolAppearance,
      );
    }


  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (context) => page),
    (route) => false,
  );
}
