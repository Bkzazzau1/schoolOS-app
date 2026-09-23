import 'package:flutter/material.dart';

import '../../../core/appearance/school_appearance_controller.dart';
import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../proprietor/presentation/proprietor_workspace_page.dart';

/// Keeps account-level navigation available while the proprietor moves through
/// a school's operational workspace.
///
/// The inner Navigator is deliberate: proprietor module navigation and school
/// switching can replace/push their own routes without removing the account
/// shell. The My Schools action therefore remains available throughout the
/// school workspace without changing the proprietor feature's existing routing.
class ProprietorAccountShell extends StatefulWidget {
  const ProprietorAccountShell({
    super.key,
    required this.membership,
    required this.localDatabase,
    required this.schoolSession,
    required this.schoolAppearance,
    required this.onOpenAccountHome,
  });

  final SchoolMembership membership;
  final LocalDatabase localDatabase;
  final SchoolSessionController schoolSession;
  final SchoolAppearanceController schoolAppearance;
  final Future<void> Function(BuildContext context) onOpenAccountHome;

  @override
  State<ProprietorAccountShell> createState() => _ProprietorAccountShellState();
}

class _ProprietorAccountShellState extends State<ProprietorAccountShell> {
  bool _openingAccount = false;

  Future<void> _openAccountHome() async {
    if (_openingAccount) return;
    setState(() => _openingAccount = true);
    try {
      await widget.onOpenAccountHome(context);
    } finally {
      if (mounted) setState(() => _openingAccount = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => ProprietorWorkspacePage(
            membership: widget.membership,
            localDatabase: widget.localDatabase,
            schoolSession: widget.schoolSession,
            schoolAppearance: widget.schoolAppearance,
          ),
        ),
      ),
      floatingActionButton: SafeArea(
        child: FloatingActionButton.extended(
          heroTag: 'schoolos_my_schools',
          onPressed: _openingAccount ? null : _openAccountHome,
          icon: _openingAccount
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.domain_rounded),
          label: const Text('My Schools'),
        ),
      ),
    );
  }
}
