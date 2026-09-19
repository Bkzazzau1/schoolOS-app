import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../sync_center/presentation/sync_center_page.dart';
import '../data/concession_repository.dart';
import 'proprietor_campuses_page.dart';
import 'proprietor_concession_approvals_page.dart';
import 'proprietor_enrollment_page.dart';
import 'proprietor_finance_page.dart';
import 'proprietor_overview_page.dart';
import 'proprietor_reports_page.dart';
import 'proprietor_staff_page.dart';

class ProprietorWorkspacePage extends StatefulWidget {
  const ProprietorWorkspacePage({
    super.key,
    required this.membership,
    required this.localDatabase,
    required this.schoolSession,
  });

  final SchoolMembership membership;
  final LocalDatabase localDatabase;
  final SchoolSessionController schoolSession;

  @override
  State<ProprietorWorkspacePage> createState() => _ProprietorWorkspacePageState();
}

class _ProprietorWorkspacePageState extends State<ProprietorWorkspacePage> {
  int _pendingSyncCount = 0;
  String _activeModule = 'overview';
  late final ConcessionRepository _concessionRepository;

  static const _navigation = <_OwnerNavItem>[
    _OwnerNavItem('overview', 'Executive Overview', Icons.dashboard_rounded, true),
    _OwnerNavItem('finance', 'Owner Finance', Icons.account_balance_wallet_rounded, true),
    _OwnerNavItem('enrollment', 'Enrollment & Admissions', Icons.person_add_alt_1_rounded, true),
    _OwnerNavItem('staff', 'Staff & HR', Icons.groups_2_rounded, true),
    _OwnerNavItem('reports', 'Executive Reports', Icons.analytics_rounded, true),
    _OwnerNavItem('campuses', 'Campus Comparison', Icons.apartment_rounded, true),
    _OwnerNavItem('ai', 'Proprietor AI', Icons.auto_awesome_rounded, false),
    _OwnerNavItem('structure', 'Structure & Leadership', Icons.account_tree_rounded, false),
    _OwnerNavItem('appearance', 'School Appearance', Icons.palette_outlined, false),
    _OwnerNavItem('school-life', 'School Life', Icons.celebration_outlined, false),
  ];

  @override
  void initState() {
    super.initState();
    _concessionRepository = ConcessionRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _refreshPendingCount();
  }

  void _refreshPendingCount() {
    final count = widget.localDatabase.pendingCount(
      tenantId: widget.membership.schoolId,
    );
    if (!mounted) return;
    setState(() => _pendingSyncCount = count);
  }

  Future<void> _openSyncCenter() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SyncCenterPage(
          localDatabase: widget.localDatabase,
          membership: widget.membership,
        ),
      ),
    );
    _refreshPendingCount();
  }

  Future<void> _switchSchool(SchoolMembership membership) async {
    if (membership.id == widget.membership.id) return;
    await widget.schoolSession.selectSchool(membership);
    if (!mounted) return;

    final page = membership.role == SchoolRole.proprietor
        ? ProprietorWorkspacePage(
            membership: membership,
            localDatabase: widget.localDatabase,
            schoolSession: widget.schoolSession,
          )
        : DashboardPage(
            membership: membership,
            localDatabase: widget.localDatabase,
            schoolSession: widget.schoolSession,
          );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (context) => page),
    );
  }

  _OwnerNavItem? _navItem(String key) {
    for (final item in _navigation) {
      if (item.key == key) return item;
    }
    return null;
  }

  void _selectModule(String key) {
    final item = _navItem(key);
    if (item == null) return;
    if (!item.implemented) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.label} is the next proprietor feature to be ported.'),
        ),
      );
      return;
    }
    setState(() => _activeModule = key);
  }

  void _handleFinanceAction(String key) {
    if (key == 'overview') {
      setState(() => _activeModule = 'overview');
      return;
    }
    if (key == 'approvals' || key == 'concessions') {
      setState(() => _activeModule = 'finance-approvals');
      return;
    }

    final label = switch (key) {
      'collections' => 'Smart Collections',
      'finance-office' => 'Finance Office',
      'fee-structure' => 'Fee Structure',
      'store' => 'School Store',
      'aging' => 'Outstanding & Aging',
      _ => 'Finance workflow',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label belongs to the Finance Office feature and will be ported with that role.',
        ),
      ),
    );
  }

  void _handleStaffAction(String key) {
    if (key == 'overview') {
      setState(() => _activeModule = 'overview');
      return;
    }
    _selectModule(key);
  }

  Widget _buildContent() {
    return switch (_activeModule) {
      'finance' => ProprietorFinancePage(
          schoolName: widget.membership.schoolName,
          onActionRequested: _handleFinanceAction,
        ),
      'finance-approvals' => ProprietorConcessionApprovalsPage(
          repository: _concessionRepository,
          onBack: () => setState(() => _activeModule = 'finance'),
          onDecisionSaved: _refreshPendingCount,
        ),
      'enrollment' => ProprietorEnrollmentPage(
          schoolName: widget.membership.schoolName,
          onActionRequested: _selectModule,
        ),
      'staff' => ProprietorStaffPage(
          schoolName: widget.membership.schoolName,
          onActionRequested: _handleStaffAction,
        ),
      'reports' => ProprietorReportsPage(
          schoolName: widget.membership.schoolName,
          onActionRequested: _selectModule,
        ),
      'campuses' => ProprietorCampusesPage(
          schoolName: widget.membership.schoolName,
          onActionRequested: _selectModule,
        ),
      _ => ProprietorOverviewPage(
          schoolName: widget.membership.schoolName,
          onModuleRequested: _selectModule,
        ),
    };
  }

  String get _activeLabel {
    if (_activeModule == 'finance-approvals') return 'Concession Approvals';
    return _navItem(_activeModule)?.label ?? 'Executive Overview';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final phone = constraints.maxWidth < 700;
        final extended = constraints.maxWidth >= 1180;
        return phone ? _buildPhone(context) : _buildWide(context, extended);
      },
    );
  }

  Widget _buildPhone(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _SchoolTitle(membership: widget.membership),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Owner workspace',
            onSelected: _selectModule,
            icon: const Icon(Icons.menu_rounded),
            itemBuilder: (context) => [
              for (final item in _navigation)
                PopupMenuItem<String>(
                  value: item.key,
                  child: Row(
                    children: [
                      Icon(item.icon, size: 19),
                      const SizedBox(width: 10),
                      Expanded(child: Text(item.label)),
                      if (!item.implemented)
                        Text('Soon', style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
            ],
          ),
          if (widget.schoolSession.canSwitchSchool)
            _SchoolSwitcherButton(
              activeMembership: widget.membership,
              memberships: widget.schoolSession.memberships,
              onSelected: _switchSchool,
            ),
          IconButton(
            tooltip: _pendingSyncCount == 0
                ? 'Sync Center'
                : 'Sync Center · $_pendingSyncCount pending',
            onPressed: _openSyncCenter,
            icon: Badge(
              isLabelVisible: _pendingSyncCount > 0,
              label: Text('$_pendingSyncCount'),
              child: Icon(
                _pendingSyncCount == 0
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_upload_outlined,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Text(
              _activeLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildWide(BuildContext context, bool extended) {
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: Container(
              width: extended ? 268 : 88,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: _OwnerBrand(extended: extended),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 12),
                      children: [
                        for (final item in _navigation)
                          _OwnerNavigationTile(
                            extended: extended,
                            icon: item.icon,
                            label: item.label,
                            selected: _activeModule == item.key ||
                                (_activeModule == 'finance-approvals' &&
                                    item.key == 'finance'),
                            implemented: item.implemented,
                            onTap: () => _selectModule(item.key),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: extended
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'OWNER WORKSPACE',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.membership.schoolName,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                'Whole-school authority',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          )
                        : const Icon(Icons.admin_panel_settings_outlined),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
                    child: Row(
                      children: [
                        Expanded(child: _SchoolTitle(membership: widget.membership)),
                        Text(
                          _activeLabel,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(width: 14),
                        if (widget.schoolSession.canSwitchSchool) ...[
                          _SchoolSwitcherButton(
                            activeMembership: widget.membership,
                            memberships: widget.schoolSession.memberships,
                            onSelected: _switchSchool,
                          ),
                          const SizedBox(width: 8),
                        ],
                        OutlinedButton.icon(
                          onPressed: _openSyncCenter,
                          icon: Icon(
                            _pendingSyncCount == 0
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_upload_outlined,
                            size: 18,
                          ),
                          label: Text(
                            _pendingSyncCount == 0
                                ? 'Synced'
                                : '$_pendingSyncCount pending',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerBrand extends StatelessWidget {
  const _OwnerBrand({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mark = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.school_rounded, color: theme.colorScheme.onPrimary),
    );

    if (!extended) return mark;
    return Row(
      children: [
        mark,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SchoolOS',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text('Owner Command Center', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _OwnerNavigationTile extends StatelessWidget {
  const _OwnerNavigationTile({
    required this.extended,
    required this.icon,
    required this.label,
    required this.selected,
    required this.implemented,
    required this.onTap,
  });

  final bool extended;
  final IconData icon;
  final String label;
  final bool selected;
  final bool implemented;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: selected ? theme.colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: extended ? 13 : 10,
              vertical: 11,
            ),
            child: Row(
              mainAxisAlignment: extended
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: implemented ? null : theme.colorScheme.onSurfaceVariant,
                ),
                if (extended) ...[
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                        color: implemented
                            ? null
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (!implemented)
                    Text(
                      'Soon',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SchoolTitle extends StatelessWidget {
  const _SchoolTitle({required this.membership});

  final SchoolMembership membership;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Text(membership.schoolName.characters.first.toUpperCase()),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                membership.schoolName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text('Proprietor', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _SchoolSwitcherButton extends StatelessWidget {
  const _SchoolSwitcherButton({
    required this.activeMembership,
    required this.memberships,
    required this.onSelected,
  });

  final SchoolMembership activeMembership;
  final List<SchoolMembership> memberships;
  final ValueChanged<SchoolMembership> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SchoolMembership>(
      tooltip: 'Switch school',
      onSelected: onSelected,
      icon: const Icon(Icons.swap_horiz_rounded),
      itemBuilder: (context) => [
        for (final membership in memberships)
          PopupMenuItem<SchoolMembership>(
            value: membership,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: membership.id == activeMembership.id
                      ? const Icon(Icons.check_rounded, size: 18)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(membership.schoolName),
                      Text(
                        membership.roleLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _OwnerNavItem {
  const _OwnerNavItem(this.key, this.label, this.icon, this.implemented);

  final String key;
  final String label;
  final IconData icon;
  final bool implemented;
}
