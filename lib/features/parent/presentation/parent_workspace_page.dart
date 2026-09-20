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
import '../domain/parent_dashboard_models.dart';
import 'parent_dashboard_page.dart';

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
  String _activeKey = 'dashboard';
  int _pendingSyncCount = 0;
  late final ParentDashboardRepository _dashboardRepository;

  @override
  void initState() {
    super.initState();
    _dashboardRepository = ParentDashboardRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _refreshPendingCount();
  }

  ParentNavItem get _activeItem => parentNavigation.firstWhere(
        (item) => item.key == _activeKey,
        orElse: () => parentNavigation.first,
      );

  void _select(String key) {
    if (!parentNavigation.any((item) => item.key == key)) return;
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

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  Widget _content() => switch (_activeKey) {
        'dashboard' => ParentDashboardPage(
            repository: _dashboardRepository,
            schoolName: widget.membership.schoolName,
            onNavigate: _select,
          ),
        _ => _UpcomingParentFeature(
            item: _activeItem,
            onDashboard: () => _select('dashboard'),
          ),
      };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 720
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
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const Text('Family Portal', style: TextStyle(fontSize: 12)),
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
              tooltip: 'Family menu',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _FamilyIdentityCard(
                  schoolName: widget.membership.schoolName,
                  compact: false,
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    for (final item in parentNavigation)
                      ListTile(
                        selected: item.key == _activeKey,
                        leading: Icon(_iconFor(item.key)),
                        title: Text(item.label),
                        trailing: item.key == 'ai'
                            ? const Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text('AI'),
                              )
                            : null,
                        onTap: () {
                          Navigator.of(context).pop();
                          _select(item.key);
                        },
                      ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(14),
                child: _PrivacyBoundaryCard(compact: true),
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
            child: Text(
              _activeItem.label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
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
              width: extended ? 292 : 88,
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
                    padding: const EdgeInsets.all(14),
                    child: extended
                        ? _FamilyIdentityCard(
                            schoolName: widget.membership.schoolName,
                            compact: false,
                          )
                        : const _SchoolMark(),
                  ),
                  if (extended)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FAMILY ACCOUNT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .8,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'FAM-BGA-0042',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              '2 linked children',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: [
                        for (final item in parentNavigation)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: ListTile(
                              dense: true,
                              selected: item.key == _activeKey,
                              selectedTileColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              leading: Icon(_iconFor(item.key)),
                              title: extended ? Text(item.label) : null,
                              trailing: extended && item.key == 'ai'
                                  ? const Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text('AI'),
                                    )
                                  : null,
                              onTap: () => _select(item.key),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (extended)
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: _PrivacyBoundaryCard(compact: true),
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
                              const Text(
                                'Parent / Guardian · Family Portal',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
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
                          label: Text(
                            _pendingSyncCount == 0
                                ? 'Synced'
                                : '$_pendingSyncCount pending',
                          ),
                        ),
                        const SizedBox(width: 12),
                        const CircleAvatar(
                          child: Text(
                            'AY',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (constraints.maxWidth >= 1080) ...[
                          const SizedBox(width: 8),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alhaji Abdullahi Yusuf',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                'Parent / Guardian',
                                style: TextStyle(fontSize: 12),
                              ),
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
        'dashboard' => Icons.home_rounded,
        'children' => Icons.family_restroom_rounded,
        'progress' => Icons.trending_up_rounded,
        'weekly-learning' => Icons.menu_book_outlined,
        'attendance' => Icons.fact_check_outlined,
        'finance' => Icons.account_balance_wallet_outlined,
        'messages' => Icons.mail_outline_rounded,
        'discussions' => Icons.forum_outlined,
        'school-life' => Icons.celebration_outlined,
        'documents' => Icons.description_outlined,
        'ai' => Icons.auto_awesome_rounded,
        _ => Icons.circle_outlined,
      };
}

class _UpcomingParentFeature extends StatelessWidget {
  const _UpcomingParentFeature({
    required this.item,
    required this.onDashboard,
  });

  final ParentNavItem item;
  final VoidCallback onDashboard;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _ParentWorkspacePageState._iconFor(item.key),
                    size: 44,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This destination exists in the SchoolOS website and is preserved in the native Family Portal navigation. It will be ported feature-by-feature and is intentionally not simulated yet.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onDashboard,
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Back to family dashboard'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FamilyIdentityCard extends StatelessWidget {
  const _FamilyIdentityCard({required this.schoolName, required this.compact});

  final String schoolName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _SchoolMark(),
        if (!compact) ...[
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SchoolOS',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                Text(
                  '$schoolName · Family Portal',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SchoolMark extends StatelessWidget {
  const _SchoolMark();

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      child: const Text('S', style: TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _PrivacyBoundaryCard extends StatelessWidget {
  const _PrivacyBoundaryCard({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(compact ? 11 : 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'PRIVATE FAMILY ACCESS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            parentPrivacyBoundary,
            style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant, height: 1.35),
          ),
        ],
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
          PopupMenuItem(
            value: membership,
            enabled: membership.id != activeMembership.id,
            child: Row(
              children: [
                if (membership.id == activeMembership.id) ...[
                  const Icon(Icons.check_rounded, size: 17),
                  const SizedBox(width: 7),
                ],
                Expanded(
                  child: Text(
                    '${membership.schoolName} · ${membership.roleLabel}',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
