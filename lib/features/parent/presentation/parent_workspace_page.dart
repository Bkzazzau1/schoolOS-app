import '../../notifications/presentation/notifications_bell.dart';
import '../../../core/sync/sync_scope.dart';
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
import '../data/parent_ai_repository.dart';
import '../data/parent_attendance_repository.dart';
import '../data/parent_children_repository.dart';
import '../data/parent_dashboard_demo_data.dart';
import '../data/parent_dashboard_repository.dart';
import '../data/parent_discussions_repository.dart';
import '../data/parent_documents_repository.dart';
import '../data/parent_finance_repository.dart';
import '../data/parent_learning_progress_repository.dart';
import '../data/parent_messages_repository.dart';
import '../data/parent_school_life_repository.dart';
import '../data/parent_weekly_learning_repository.dart';
import '../domain/parent_dashboard_models.dart';
import 'parent_ai_page.dart';
import 'parent_attendance_page.dart';
import 'parent_children_page.dart';
import 'parent_dashboard_page.dart';
import 'parent_discussions_page.dart';
import 'parent_documents_page.dart';
import 'parent_finance_page.dart';
import 'parent_learning_progress_page.dart';
import 'parent_messages_page.dart';
import 'parent_school_life_page.dart';
import 'parent_weekly_learning_page.dart';

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

class _ParentWorkspacePageState extends State<ParentWorkspacePage> with SyncRefresh<ParentWorkspacePage>, AccessAware<ParentWorkspacePage> {
  /// The screens the owner allows this person (all of them until their access is known).
  List<ParentNavItem> get _navigation =>
      visibleScreens('parent', parentNavigation, (item) => item.key);

  String _activeKey = 'dashboard';
  int _pendingSyncCount = 0;

  late final ParentDashboardRepository _dashboardRepository;
  late final ParentChildrenRepository _childrenRepository;
  late final ParentLearningProgressRepository _learningProgressRepository;
  late final ParentWeeklyLearningRepository _weeklyLearningRepository;
  late final ParentAttendanceRepository _attendanceRepository;
  late final ParentFinanceRepository _financeRepository;
  late final ParentMessagesRepository _messagesRepository;
  late final ParentDiscussionsRepository _discussionsRepository;
  late final ParentSchoolLifeRepository _schoolLifeRepository;
  late final ParentDocumentsRepository _documentsRepository;
  late final ParentAIRepository _aiRepository;

  ParentNavItem get _activeItem => _navigation.firstWhere(
        (item) => item.key == _activeKey,
        orElse: () => _navigation.first,
      );

  @override
  void initState() {
    super.initState();
    _dashboardRepository = ParentDashboardRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _childrenRepository = ParentChildrenRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _learningProgressRepository = ParentLearningProgressRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _weeklyLearningRepository = ParentWeeklyLearningRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _attendanceRepository = ParentAttendanceRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _financeRepository = ParentFinanceRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _messagesRepository = ParentMessagesRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _discussionsRepository = ParentDiscussionsRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _schoolLifeRepository = ParentSchoolLifeRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _documentsRepository = ParentDocumentsRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _aiRepository = ParentAIRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _refreshPendingCount();
  }

  void _select(String key) {
    if (key == _activeKey || !_navigation.any((item) => item.key == key)) {
      return;
    }
    setState(() => _activeKey = key);
  }

  @override
  void onSynced() => _refreshPendingCount();

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

    final Widget destination = switch (membership.role) {
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
      MaterialPageRoute<void>(builder: (_) => destination),
    );
  }

  Widget _content() => switch (_activeKey) {
        'dashboard' => ParentDashboardPage(
            repository: _dashboardRepository,
            schoolName: widget.membership.schoolName,
            onNavigate: _select,
          ),
        'children' => ParentChildrenPage(
            repository: _childrenRepository,
            schoolName: widget.membership.schoolName,
            onNavigate: _select,
          ),
        'progress' => ParentLearningProgressPage(
            repository: _learningProgressRepository,
            onNavigate: _select,
          ),
        'weekly-learning' => ParentWeeklyLearningPage(
            repository: _weeklyLearningRepository,
          ),
        'attendance' => ParentAttendancePage(
            repository: _attendanceRepository,
            onNavigate: _select,
          ),
        'finance' => ParentFinancePage(
            repository: _financeRepository,
            onQueueChanged: _refreshPendingCount,
          ),
        'messages' => ParentMessagesPage(
            repository: _messagesRepository,
            onQueueChanged: _refreshPendingCount,
            onNavigate: _select,
          ),
        'discussions' => ParentDiscussionsPage(
            repository: _discussionsRepository,
            onQueueChanged: _refreshPendingCount,
          ),
        'school-life' => ParentSchoolLifePage(
            repository: _schoolLifeRepository,
            onNavigate: _select,
          ),
        'documents' => ParentDocumentsPage(
            repository: _documentsRepository,
            onQueueChanged: _refreshPendingCount,
            onNavigate: _select,
          ),
        'ai' => ParentAIPage(
            repository: _aiRepository,
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
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) return _buildPhone();
        return _buildWide(constraints);
      },
    );
  }

  Widget _buildPhone() {
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
          NotificationsBell(membership: widget.membership),
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
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    for (final item in _navigation)
                      _ParentNavigationTile(
                        item: item,
                        selected: item.key == _activeKey,
                        showLabel: true,
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
                child: _PrivacyBoundaryCard(),
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

  Widget _buildWide(BoxConstraints constraints) {
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
                          )
                        : const _SchoolMark(),
                  ),
                  if (extended)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: _FamilyAccountSummary(),
                    ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: [
                        for (final item in _navigation)
                          _ParentNavigationTile(
                            item: item,
                            selected: item.key == _activeKey,
                            showLabel: extended,
                            onTap: () => _select(item.key),
                          ),
                      ],
                    ),
                  ),
                  if (extended)
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: _PrivacyBoundaryCard(),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              child: Column(
                children: [
                  _DesktopTopBar(
                    activeLabel: _activeItem.label,
                    pendingSyncCount: _pendingSyncCount,
                    canSwitchSchool: widget.schoolSession.canSwitchSchool,
                    membership: widget.membership,
                    memberships: widget.schoolSession.memberships,
                    onSwitchSchool: _switchSchool,
                    onOpenSyncCenter: _openSyncCenter,
                    showGuardianName: constraints.maxWidth >= 1080,
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

  static IconData iconFor(String key) => switch (key) {
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

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.activeLabel,
    required this.pendingSyncCount,
    required this.canSwitchSchool,
    required this.membership,
    required this.memberships,
    required this.onSwitchSchool,
    required this.onOpenSyncCenter,
    required this.showGuardianName,
  });

  final String activeLabel;
  final int pendingSyncCount;
  final bool canSwitchSchool;
  final SchoolMembership membership;
  final List<SchoolMembership> memberships;
  final ValueChanged<SchoolMembership> onSwitchSchool;
  final VoidCallback onOpenSyncCenter;
  final bool showGuardianName;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                Text(activeLabel),
              ],
            ),
          ),
          if (canSwitchSchool)
            _SchoolSwitcherButton(
              activeMembership: membership,
              memberships: memberships,
              onSelected: onSwitchSchool,
            ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onOpenSyncCenter,
            icon: const Icon(Icons.cloud_sync_outlined, size: 18),
            label: Text(
              pendingSyncCount == 0 ? 'Synced' : '$pendingSyncCount pending',
            ),
          ),
          const SizedBox(width: 12),
          const CircleAvatar(
            child: Text('AY', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
          if (showGuardianName) ...[
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alhaji Abdullahi Yusuf',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Text('Parent / Guardian', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ParentNavigationTile extends StatelessWidget {
  const _ParentNavigationTile({
    required this.item,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  final ParentNavItem item;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Tooltip(
        message: showLabel ? '' : item.label,
        child: ListTile(
          dense: true,
          selected: selected,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Icon(_ParentWorkspacePageState.iconFor(item.key)),
          title: showLabel ? Text(item.label) : null,
          trailing: showLabel && item.key == 'ai'
              ? const Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('AI'),
                )
              : null,
          onTap: onTap,
        ),
      ),
    );
  }
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
                    _ParentWorkspacePageState.iconFor(item.key),
                    size: 44,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
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
  const _FamilyIdentityCard({required this.schoolName});

  final String schoolName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _SchoolMark(),
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

class _FamilyAccountSummary extends StatelessWidget {
  const _FamilyAccountSummary();

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text('FAM-BGA-0042', style: TextStyle(fontWeight: FontWeight.w900)),
          Text('2 linked children', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _PrivacyBoundaryCard extends StatelessWidget {
  const _PrivacyBoundaryCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(11),
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
            style: TextStyle(
              fontSize: 10,
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
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
