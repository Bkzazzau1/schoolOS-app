import 'package:flutter/material.dart';

import '../../../core/appearance/school_appearance_controller.dart';
import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../activities/data/activity_repository.dart';
import '../../activities/presentation/activities_page.dart';
import '../../community/data/community_repository.dart';
import '../../community/presentation/community_page.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../events/data/event_repository.dart';
import '../../events/presentation/events_page.dart';
import '../../excursions/data/excursion_repository.dart';
import '../../excursions/presentation/excursions_page.dart';
import '../../gallery/data/gallery_repository.dart';
import '../../gallery/presentation/gallery_page.dart';
import '../../houses/data/house_repository.dart';
import '../../houses/presentation/houses_page.dart';
import '../../meals/data/meal_repository.dart';
import '../../meals/presentation/meals_page.dart';
import '../../noticeboard/data/noticeboard_repository.dart';
import '../../noticeboard/presentation/noticeboard_page.dart';
import '../../sync_center/presentation/sync_center_page.dart';
import '../../transport/data/transport_repository.dart';
import '../../transport/presentation/transport_page.dart';
import '../data/concession_repository.dart';
import '../data/proprietor_school_life_data.dart';
import '../data/proprietor_structure_repository.dart';
import 'proprietor_ai_page.dart';
import 'proprietor_appearance_page.dart';
import 'proprietor_campuses_page.dart';
import 'proprietor_concession_approvals_page.dart';
import 'proprietor_enrollment_page.dart';
import 'proprietor_finance_page.dart';
import 'proprietor_overview_page.dart';
import 'proprietor_reports_page.dart';
import 'proprietor_school_life_page.dart';
import 'proprietor_staff_page.dart';
import 'proprietor_structure_page.dart';

class ProprietorWorkspacePage extends StatefulWidget {
  const ProprietorWorkspacePage({
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
  State<ProprietorWorkspacePage> createState() => _ProprietorWorkspacePageState();
}

class _ProprietorWorkspacePageState extends State<ProprietorWorkspacePage> {
  int _pendingSyncCount = 0;
  String _activeModule = 'overview';
  late final ConcessionRepository _concessionRepository;
  late final ProprietorStructureRepository _structureRepository;

  static const _navigation = <_OwnerNavItem>[
    _OwnerNavItem('overview', 'Executive Overview', Icons.dashboard_rounded),
    _OwnerNavItem('finance', 'Owner Finance', Icons.account_balance_wallet_rounded),
    _OwnerNavItem('enrollment', 'Enrollment & Admissions', Icons.person_add_alt_1_rounded),
    _OwnerNavItem('staff', 'Staff & HR', Icons.groups_2_rounded),
    _OwnerNavItem('reports', 'Executive Reports', Icons.analytics_rounded),
    _OwnerNavItem('campuses', 'Campus Comparison', Icons.apartment_rounded),
    _OwnerNavItem('ai', 'Proprietor AI', Icons.auto_awesome_rounded),
    _OwnerNavItem('structure', 'Structure & Leadership', Icons.account_tree_rounded),
    _OwnerNavItem('appearance', 'School Appearance', Icons.palette_outlined),
    _OwnerNavItem('school-life', 'School Life', Icons.celebration_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _concessionRepository = ConcessionRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _structureRepository = ProprietorStructureRepository(
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
            schoolAppearance: widget.schoolAppearance,
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

  Future<void> _openSchoolLifeCapability(
    ProprietorSchoolLifeCapability capability,
  ) async {
    if (capability.key == 'community') {
      await _pushSharedModule(
        title: 'Community',
        body: CommunityPage(
          schoolName: widget.membership.schoolName,
          repository: CommunityRepository(
            localDatabase: widget.localDatabase,
            schoolSession: widget.schoolSession,
          ),
          onBack: () => Navigator.of(context).pop(),
          onCommunityChanged: _refreshPendingCount,
        ),
      );
      return;
    }

    if (capability.key == 'noticeboard') {
      await _pushSharedModule(
        title: 'Noticeboard',
        body: NoticeboardPage(
          schoolName: widget.membership.schoolName,
          repository: NoticeboardRepository(
            localDatabase: widget.localDatabase,
            schoolSession: widget.schoolSession,
          ),
          onBack: () => Navigator.of(context).pop(),
          onNoticeboardChanged: _refreshPendingCount,
        ),
      );
      return;
    }

    if (capability.key == 'activities') {
      await _pushSharedModule(
        title: 'Activities & Clubs',
        body: ActivitiesPage(
          schoolName: widget.membership.schoolName,
          repository: ActivityRepository(
            localDatabase: widget.localDatabase,
            schoolSession: widget.schoolSession,
          ),
          onBack: () => Navigator.of(context).pop(),
          onActivitiesChanged: _refreshPendingCount,
        ),
      );
      return;
    }

    if (capability.key == 'events') {
      await _pushSharedModule(
        title: 'Events & Calendar',
        body: EventsPage(
          schoolName: widget.membership.schoolName,
          repository: EventRepository(
            localDatabase: widget.localDatabase,
            schoolSession: widget.schoolSession,
          ),
          onBack: () => Navigator.of(context).pop(),
          onEventsChanged: _refreshPendingCount,
        ),
      );
      return;
    }

    if (capability.key == 'houses') {
      await _pushSharedModule(
        title: 'Houses & Teams',
        body: HousesPage(
          schoolName: widget.membership.schoolName,
          repository: HouseRepository(
            localDatabase: widget.localDatabase,
            schoolSession: widget.schoolSession,
          ),
          onBack: () => Navigator.of(context).pop(),
        ),
      );
      return;
    }

    if (capability.key == 'gallery') {
      await _pushSharedModule(
        title: 'Media Gallery',
        body: GalleryPage(
          schoolName: widget.membership.schoolName,
          repository: GalleryRepository(
            localDatabase: widget.localDatabase,
            schoolSession: widget.schoolSession,
          ),
          onBack: () => Navigator.of(context).pop(),
        ),
      );
      return;
    }

    if (capability.key == 'excursions') {
      await _pushSharedModule(
        title: 'Excursions & Consent',
        body: ExcursionsPage(
          schoolName: widget.membership.schoolName,
          repository: ExcursionRepository(
            localDatabase: widget.localDatabase,
            schoolSession: widget.schoolSession,
          ),
          onBack: () => Navigator.of(context).pop(),
          onExcursionsChanged: _refreshPendingCount,
        ),
      );
      return;
    }

    if (capability.key == 'transport') {
      await _pushSharedModule(
        title: 'School Transport',
        body: TransportPage(
          schoolName: widget.membership.schoolName,
          repository: TransportRepository(
            localDatabase: widget.localDatabase,
            schoolSession: widget.schoolSession,
          ),
          onBack: () => Navigator.of(context).pop(),
          onTransportChanged: _refreshPendingCount,
        ),
      );
      return;
    }

    if (capability.key == 'meals') {
      await _pushSharedModule(
        title: 'Meals & Cafeteria',
        body: MealsPage(
          schoolName: widget.membership.schoolName,
          repository: MealRepository(
            localDatabase: widget.localDatabase,
            schoolSession: widget.schoolSession,
          ),
          onBack: () => Navigator.of(context).pop(),
          onMealsChanged: _refreshPendingCount,
        ),
      );
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(capability.module),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                capability.level,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              Text(capability.detail),
              const SizedBox(height: 12),
              Text(
                capability.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'This shared School Life module will be ported feature-by-feature and will reuse this proprietor permission scope.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _pushSharedModule({
    required String title,
    required Widget body,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('${widget.membership.schoolName} · $title'),
            actions: [
              IconButton(
                tooltip: _pendingSyncCount == 0
                    ? 'Sync Center'
                    : 'Sync Center · $_pendingSyncCount pending',
                onPressed: _openSyncCenter,
                icon: const Icon(Icons.cloud_sync_outlined),
              ),
            ],
          ),
          body: body,
        ),
      ),
    );
    _refreshPendingCount();
  }

  _OwnerNavItem? _navItem(String key) {
    for (final item in _navigation) {
      if (item.key == key) return item;
    }
    return null;
  }

  void _selectModule(String key) {
    if (_navItem(key) == null) return;
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
      'ai' => ProprietorAiPage(
          schoolName: widget.membership.schoolName,
          onActionRequested: _selectModule,
        ),
      'structure' => ProprietorStructurePage(
          schoolName: widget.membership.schoolName,
          repository: _structureRepository,
          onActionRequested: _selectModule,
          onStructureChanged: _refreshPendingCount,
        ),
      'appearance' => ProprietorAppearancePage(
          schoolName: widget.membership.schoolName,
          controller: widget.schoolAppearance,
          onDashboard: () => setState(() => _activeModule = 'overview'),
          onAppearanceChanged: _refreshPendingCount,
        ),
      'school-life' => ProprietorSchoolLifePage(
          schoolName: widget.membership.schoolName,
          onDashboard: () => setState(() => _activeModule = 'overview'),
          onCapabilityRequested: _openSchoolLifeCapability,
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
        return phone ? _buildPhone(context) : _buildWide(context);
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
            itemBuilder: (context) => [
              for (final item in _navigation)
                PopupMenuItem<String>(
                  value: item.key,
                  child: Row(
                    children: [
                      Icon(item.icon, size: 19),
                      const SizedBox(width: 10),
                      Expanded(child: Text(item.label)),
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
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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

  Widget _buildWide(BuildContext context) {
    final extended = MediaQuery.sizeOf(context).width >= 1180;
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
                            item: item,
                            selected: _activeModule == item.key ||
                                (_activeModule == 'finance-approvals' &&
                                    item.key == 'finance'),
                            onTap: () => _selectModule(item.key),
                          ),
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
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SchoolTitle(membership: widget.membership),
                        ),
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
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final bool extended;
  final _OwnerNavItem item;
  final bool selected;
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
                Icon(item.icon),
                if (extended) ...[
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                      ),
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
  const _OwnerNavItem(this.key, this.label, this.icon);
  final String key;
  final String label;
  final IconData icon;
}
