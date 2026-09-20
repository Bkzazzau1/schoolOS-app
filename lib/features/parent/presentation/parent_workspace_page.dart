import 'package:flutter/material.dart';

import '../../../core/appearance/school_appearance_controller.dart';
import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/presentation/administrator_workspace_page.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../finance_office/presentation/finance_office_workspace_page.dart';
import '../../principal/presentation/principal_workspace_page.dart';
import '../../proprietor/presentation/proprietor_workspace_page.dart';
import '../../sync_center/presentation/sync_center_page.dart';
import '../../teacher/presentation/teacher_workspace_page.dart';
import '../data/parent_dashboard_demo_data.dart';
import '../data/parent_dashboard_repository.dart';
import 'parent_home_page.dart';

class ParentWorkspacePage extends StatefulWidget {
  const ParentWorkspacePage({
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
  State<ParentWorkspacePage> createState() => _ParentWorkspacePageState();
}

class _ParentWorkspacePageState extends State<ParentWorkspacePage> {
  String _activeKey = 'home';
  int _pendingSyncCount = 0;
  late final ParentDashboardRepository _dashboard;

  ParentNavItem get _activeItem => parentNavigation.firstWhere(
        (item) => item.key == _activeKey,
        orElse: () => parentNavigation.first,
      );

  @override
  void initState() {
    super.initState();
    _dashboard = ParentDashboardRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _refreshPendingCount();
  }

  void _select(String key) {
    if (!parentNavigation.any((item) => item.key == key)) return;
    setState(() => _activeKey = key);
  }

  void _refreshPendingCount() {
    final count = widget.localDatabase.pendingCount(tenantId: widget.membership.schoolId);
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
      SchoolRole.teacher => TeacherWorkspacePage(
          membership: membership,
          localDatabase: widget.localDatabase,
          schoolSession: widget.schoolSession,
          schoolAppearance: widget.schoolAppearance,
        ),
      SchoolRole.parent => ParentWorkspacePage(
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

    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => page));
  }

  Widget _content() => switch (_activeKey) {
        'home' => ParentHomePage(
            repository: _dashboard,
            schoolName: widget.membership.schoolName,
            onNavigate: _select,
          ),
        _ => _ParentPlaceholderPage(item: _activeItem),
      };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) return _phone();
        return _wide(constraints);
      },
    );
  }

  Widget _phone() {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.membership.schoolName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
            const Text('Family Portal', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          if (widget.schoolSession.canSwitchSchool)
            _SchoolSwitcherButton(
              memberships: widget.schoolSession.memberships,
              onSelected: _switchSchool,
            ),
          IconButton(
            tooltip: _pendingSyncCount == 0 ? 'Sync Center' : 'Sync Center · $_pendingSyncCount pending',
            onPressed: _openSyncCenter,
            icon: Badge(
              isLabelVisible: _pendingSyncCount > 0,
              label: Text('$_pendingSyncCount'),
              child: const Icon(Icons.cloud_sync_outlined),
            ),
          ),
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Family menu',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const ListTile(
                leading: CircleAvatar(child: Text('AY')),
                title: Text(parentGuardianName, style: TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text('Parent / Guardian'),
              ),
              const Divider(),
              for (final item in parentNavigation)
                ListTile(
                  selected: item.key == _activeKey,
                  leading: Icon(item.icon),
                  title: Text(item.label),
                  trailing: item.key == 'ai' ? const Chip(label: Text('AI')) : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    _select(item.key);
                  },
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
            child: Text(_activeItem.label, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  Widget _wide(BoxConstraints constraints) {
    final extended = constraints.maxWidth >= 1160;
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: Container(
              width: extended ? 292 : 90,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(right: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
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
                            subtitle: Text('Family Portal'),
                          )
                        : const CircleAvatar(child: Text('S')),
                  ),
                  if (extended)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .45),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('FAMILY ACCOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                            SizedBox(height: 4),
                            Text(parentFamilyId, style: TextStyle(fontWeight: FontWeight.w900)),
                            SizedBox(height: 3),
                            Text('$parentGuardianName · 2 linked children', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: [
                        if (extended)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
                            child: Text('FAMILY WORKSPACE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                          ),
                        for (final item in parentNavigation)
                          ListTile(
                            selected: item.key == _activeKey,
                            selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            leading: Icon(item.icon),
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
                      child: _FamilyPrivacyCard(),
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
                              Text(widget.membership.schoolName, style: const TextStyle(fontWeight: FontWeight.w900)),
                              const Text('$parentCampusLabel · 2026/2027 Term 1'),
                            ],
                          ),
                        ),
                        if (widget.schoolSession.canSwitchSchool)
                          _SchoolSwitcherButton(
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
                        const CircleAvatar(child: Text('AY')),
                        if (constraints.maxWidth >= 1040) ...[
                          const SizedBox(width: 8),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(parentGuardianName, style: TextStyle(fontWeight: FontWeight.w800)),
                              Text('Parent / Guardian', style: TextStyle(fontSize: 12)),
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
}

class ParentNavItem {
  const ParentNavItem({required this.key, required this.label, required this.icon});

  final String key;
  final String label;
  final IconData icon;
}

const parentNavigation = <ParentNavItem>[
  ParentNavItem(key: 'home', label: 'Home', icon: Icons.home_outlined),
  ParentNavItem(key: 'children', label: 'My Children', icon: Icons.family_restroom_outlined),
  ParentNavItem(key: 'progress', label: 'Learning Progress', icon: Icons.trending_up_rounded),
  ParentNavItem(key: 'weekly-learning', label: 'Weekly Learning', icon: Icons.menu_book_outlined),
  ParentNavItem(key: 'attendance', label: 'Attendance', icon: Icons.fact_check_outlined),
  ParentNavItem(key: 'finance', label: 'Finance & Payments', icon: Icons.account_balance_wallet_outlined),
  ParentNavItem(key: 'messages', label: 'Messages', icon: Icons.mail_outline_rounded),
  ParentNavItem(key: 'discussions', label: 'School Discussions', icon: Icons.forum_outlined),
  ParentNavItem(key: 'school-life', label: 'School Life', icon: Icons.auto_awesome_outlined),
  ParentNavItem(key: 'documents', label: 'Documents & Consent', icon: Icons.description_outlined),
  ParentNavItem(key: 'ai', label: 'Parent AI', icon: Icons.psychology_alt_outlined),
];

class _ParentPlaceholderPage extends StatelessWidget {
  const _ParentPlaceholderPage({required this.item});

  final ParentNavItem item;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 52, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(item.label, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text(
                'This Family Portal destination is intentionally staged for the next feature-by-feature port from the SchoolOS website.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyPrivacyCard extends StatelessWidget {
  const _FamilyPrivacyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.lock_outline_rounded, size: 16), SizedBox(width: 6), Text('PRIVATE FAMILY ACCESS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))]),
          SizedBox(height: 6),
          Text('Only linked children and approved family records are visible. Staff-private notes, other families and restricted safeguarding records stay hidden.', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _SchoolSwitcherButton extends StatelessWidget {
  const _SchoolSwitcherButton({required this.memberships, required this.onSelected});

  final List<SchoolMembership> memberships;
  final ValueChanged<SchoolMembership> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SchoolMembership>(
      tooltip: 'Switch school or role',
      onSelected: onSelected,
      itemBuilder: (context) => memberships
          .map(
            (membership) => PopupMenuItem<SchoolMembership>(
              value: membership,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(membership.schoolName, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(membership.roleLabel, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          )
          .toList(growable: false),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.swap_horiz_rounded, size: 18), SizedBox(width: 5), Text('Switch')]),
      ),
    );
  }
}
