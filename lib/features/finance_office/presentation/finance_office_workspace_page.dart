import 'package:flutter/material.dart';

import '../../../core/appearance/school_appearance_controller.dart';
import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/presentation/administrator_workspace_page.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../principal/presentation/principal_workspace_page.dart';
import '../../proprietor/presentation/proprietor_workspace_page.dart';
import '../../sync_center/presentation/sync_center_page.dart';
import '../data/finance_concessions_repository.dart';
import '../data/finance_office_dashboard_demo_data.dart';
import '../domain/finance_office_dashboard_models.dart';
import 'finance_collections_page.dart';
import 'finance_concessions_page.dart';
import 'finance_debt_aging_page.dart';
import 'finance_family_accounts_page.dart';
import 'finance_fee_structure_page.dart';
import 'finance_mandates_page.dart';
import 'finance_office_dashboard_page.dart';
import 'finance_receipts_page.dart';
import 'finance_reconciliation_page.dart';
import 'finance_reminders_page.dart';
import 'finance_store_page.dart';

class FinanceOfficeWorkspacePage extends StatefulWidget {
  const FinanceOfficeWorkspacePage({
    super.key,
    required this.membership,
    required this.localDatabase,
    required this.schoolSession,
    required this.schoolAppearance,
  });

  final SchoolMembership membership;
  final LocalDatabase localDatabase;
  final SchoolSessionController schoolSession;
  final SchoolAppearanceController schoolAppearance;

  @override
  State<FinanceOfficeWorkspacePage> createState() =>
      _FinanceOfficeWorkspacePageState();
}

class _FinanceOfficeWorkspacePageState extends State<FinanceOfficeWorkspacePage> {
  String _activeKey = 'dashboard';
  int _pendingSyncCount = 0;
  late final FinanceConcessionsRepository _concessions;

  FinanceOfficeNavItem get _activeItem => financeOfficeNavigation.firstWhere(
        (item) => item.key == _activeKey,
        orElse: () => financeOfficeNavigation.first,
      );

  @override
  void initState() {
    super.initState();
    _concessions = FinanceConcessionsRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _refreshPendingCount();
  }

  void _select(String key) {
    if (!financeOfficeNavigation.any((item) => item.key == key)) return;
    setState(() => _activeKey = key);
  }

  void _refreshPendingCount() {
    final count = widget.localDatabase.pendingCount(
      tenantId: widget.membership.schoolId,
    );
    if (mounted) setState(() => _pendingSyncCount = count);
  }

  Future<void> _openSyncCenter() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SyncCenterPage(
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

    final Widget page = switch (membership.role) {
      SchoolRole.proprietor => ProprietorWorkspacePage(
          membership: membership,
          localDatabase: widget.localDatabase,
          schoolSession: widget.schoolSession,
          schoolAppearance: widget.schoolAppearance,
        ),
      SchoolRole.administrator => AdministratorWorkspacePage(
          membership: membership,
          localDatabase: widget.localDatabase,
          schoolSession: widget.schoolSession,
          schoolAppearance: widget.schoolAppearance,
        ),
      SchoolRole.principal => PrincipalWorkspacePage(
          membership: membership,
          localDatabase: widget.localDatabase,
          schoolSession: widget.schoolSession,
          schoolAppearance: widget.schoolAppearance,
        ),
      SchoolRole.accountant => FinanceOfficeWorkspacePage(
          membership: membership,
          localDatabase: widget.localDatabase,
          schoolSession: widget.schoolSession,
          schoolAppearance: widget.schoolAppearance,
        ),
      _ => DashboardPage(
          membership: membership,
          localDatabase: widget.localDatabase,
          schoolSession: widget.schoolSession,
          schoolAppearance: widget.schoolAppearance,
        ),
    };

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  Widget _content() => switch (_activeKey) {
        'dashboard' => FinanceOfficeDashboardPage(
            schoolName: widget.membership.schoolName,
            onNavigate: _select,
          ),
        'fee-structure' => const FinanceFeeStructurePage(),
        'scholarships' => FinanceConcessionsPage(
            repository: _concessions,
            onMutationQueued: _refreshPendingCount,
          ),
        'collections' => const FinanceCollectionsPage(),
        'reminders' => const FinanceRemindersPage(),
        'store' => const FinanceStorePage(),
        'mandates' => const FinanceMandatesPage(),
        'debt-aging' => const FinanceDebtAgingPage(),
        'receipts' => const FinanceReceiptsPage(),
        'accounts' => const FinanceFamilyAccountsPage(),
        'reconciliation' => const FinanceReconciliationPage(),
        _ => _UpcomingFinanceFeature(
            item: _activeItem,
            onDashboard: () => _select('dashboard'),
          ),
      };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 700
          ? _phone(context)
          : _wide(context, constraints),
    );
  }

  Widget _phone(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.membership.schoolName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const Text('Finance Office', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
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
              child: const Icon(Icons.cloud_sync_outlined),
            ),
          ),
          Builder(
            builder: (context) => IconButton(
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              icon: const Icon(Icons.menu_rounded),
              tooltip: 'Finance menu',
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const ListTile(
                title: Text('Finance Office', style: TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text('Finance operations'),
              ),
              const Divider(),
              for (final item in financeOfficeNavigation)
                ListTile(
                  selected: item.key == _activeKey,
                  leading: Icon(_iconFor(item.key)),
                  title: Text(item.label),
                  onTap: () {
                    Navigator.of(context).pop();
                    _select(item.key);
                  },
                ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(financeOfficeScopeBoundary, style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Text(_activeItem.label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  Widget _wide(BuildContext context, BoxConstraints constraints) {
    final extended = constraints.maxWidth >= 1180;
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: Container(
              width: extended ? 290 : 88,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: extended
                        ? const ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(child: Text('S')),
                            title: Text('SchoolOS', style: TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: Text('Finance Office'),
                          )
                        : const CircleAvatar(child: Text('S')),
                  ),
                  if (extended)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ACTIVE SCHOOL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Text(widget.membership.schoolName, style: const TextStyle(fontWeight: FontWeight.w900)),
                              const Text(financeOfficeCampusLabel, style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final item in financeOfficeNavigation)
                          ListTile(
                            selected: item.key == _activeKey,
                            selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                            leading: Icon(_iconFor(item.key)),
                            title: extended ? Text(item.label) : null,
                            trailing: extended && item.key == 'ai' ? const Chip(label: Text('AI')) : null,
                            onTap: () => _select(item.key),
                          ),
                      ],
                    ),
                  ),
                  if (extended)
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FINANCE ACCESS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                          SizedBox(height: 5),
                          Text('Fee, transaction, approved financing and payroll-processing data only.', style: TextStyle(fontSize: 12)),
                        ],
                      ),
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
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Finance Operations', style: TextStyle(fontWeight: FontWeight.w900)),
                              Text(_activeItem.label),
                            ],
                          ),
                        ),
                        if (widget.schoolSession.canSwitchSchool)
                          _SchoolSwitcherButton(
                            activeMembership: widget.membership,
                            memberships: widget.schoolSession.memberships,
                            onSelected: _switchSchool,
                          ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _openSyncCenter,
                          icon: const Icon(Icons.cloud_sync_outlined, size: 18),
                          label: Text(_pendingSyncCount == 0 ? 'Synced' : '$_pendingSyncCount pending'),
                        ),
                        const SizedBox(width: 12),
                        const CircleAvatar(child: Text('AB')),
                        if (constraints.maxWidth >= 1080) ...[
                          const SizedBox(width: 8),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(financeOfficeLeaderName, style: TextStyle(fontWeight: FontWeight.w800)),
                              Text(financeOfficeLeaderTitle, style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(child: _content()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(String key) => switch (key) {
        'dashboard' => Icons.dashboard_rounded,
        'fee-structure' => Icons.view_list_outlined,
        'scholarships' => Icons.workspace_premium_outlined,
        'collections' => Icons.payments_outlined,
        'reminders' => Icons.notifications_active_outlined,
        'store' => Icons.storefront_outlined,
        'mandates' => Icons.autorenew_rounded,
        'debt-aging' => Icons.schedule_outlined,
        'receipts' => Icons.receipt_long_outlined,
        'accounts' => Icons.account_balance_wallet_outlined,
        'reconciliation' => Icons.compare_arrows_rounded,
        'expenses' => Icons.request_quote_outlined,
        'payroll' => Icons.badge_outlined,
        'reports' => Icons.assessment_outlined,
        'ai' => Icons.auto_awesome_rounded,
        _ => Icons.circle_outlined,
      };
}

class _UpcomingFinanceFeature extends StatelessWidget {
  const _UpcomingFinanceFeature({required this.item, required this.onDashboard});

  final FinanceOfficeNavItem item;
  final VoidCallback onDashboard;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_FinanceOfficeWorkspacePageState._iconFor(item.key), size: 42),
                  const SizedBox(height: 12),
                  Text(item.label, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text('This Finance Office destination exists on the SchoolOS website and will be ported in sequence. It is intentionally not simulated yet.', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: onDashboard, icon: const Icon(Icons.dashboard_rounded), label: const Text('Back to dashboard')),
                ],
              ),
            ),
          ),
        ),
      ),
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
      itemBuilder: (_) => [
        for (final membership in memberships)
          PopupMenuItem(value: membership, child: Text('${membership.schoolName} · ${membership.roleLabel}')),
      ],
    );
  }
}
