import 'package:flutter/material.dart';

import '../features/account/presentation/proprietor_account_shell.dart';
import '../features/administrator/presentation/administrator_workspace_page.dart';
import '../features/alumni/presentation/alumni_workspace_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/driver/presentation/driver_workspace_page.dart';
import '../features/finance_office/presentation/finance_office_workspace_page.dart';
import '../features/parent/presentation/parent_workspace_page.dart';
import '../features/principal/presentation/principal_workspace_page.dart';
import '../features/proprietor/presentation/proprietor_workspace_page.dart';
import '../features/teacher/presentation/teacher_workspace_page.dart';
import '../shared/models/school_membership.dart';
import 'app_services.dart';
import '../features/student/presentation/student_workspace_page.dart';

/// Chooses this school and role, starts keeping in step with the school, and opens the
/// workspace for the role. Used after signing in and after accepting an invitation.
///
/// When [preserveAccountHome] is true the school is pushed above Account Home,
/// allowing an account owner to return to My Schools without signing out.
Future<void> openMembershipHome(
  BuildContext context,
  AppServices services,
  SchoolMembership membership, {
  bool preserveAccountHome = false,
}) async {
  await services.schoolSession.selectSchool(membership);
  await services.beginSchool(membership);
  if (!context.mounted) return;

  Future<void> returnToAccountHome(BuildContext schoolContext) async {
    if (!schoolContext.mounted) return;
    Navigator.of(schoolContext).pop();
  }

  final Widget page;
  if (membership.role == SchoolRole.student) {
    page = StudentWorkspacePage(
      membership: membership,
      localDatabase: services.localDatabase,
      schoolSession: services.schoolSession,
    );
  } else if (membership.role == SchoolRole.proprietor) {
    page = preserveAccountHome
        ? ProprietorAccountShell(
            membership: membership,
            localDatabase: services.localDatabase,
            schoolSession: services.schoolSession,
            schoolAppearance: services.schoolAppearance,
            onOpenAccountHome: returnToAccountHome,
          )
        : ProprietorWorkspacePage(
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
  } else if (membership.role == SchoolRole.alumni) {
    page = AlumniWorkspacePage(
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

  if (preserveAccountHome) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => page),
    );
    services.pauseSchoolWorkspace();
    return;
  }

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (context) => page),
    (route) => false,
  );
}
