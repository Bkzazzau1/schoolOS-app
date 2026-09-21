import '../../../core/sync/sync_scope.dart';
import '../../proprietor/data/staff_onboarding_repository.dart';
import '../../proprietor/presentation/staff_onboarding_page.dart';
import 'package:flutter/material.dart';

import '../../../core/appearance/school_appearance_controller.dart';
import '../../../core/auth/app_capability.dart';
import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/layout/app_breakpoints.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/presentation/administrator_workspace_page.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/presentation/attendance_page.dart';
import '../../driver/presentation/driver_workspace_page.dart';
import '../../finance_office/presentation/finance_office_workspace_page.dart';
import '../../parent/presentation/parent_workspace_page.dart';
import '../../teacher/presentation/teacher_workspace_page.dart';
import '../../lesson_plans/data/lesson_plan_generation_service.dart';
import '../../lesson_plans/data/lesson_plan_repository.dart';
import '../../lesson_plans/presentation/lesson_plan_page.dart';
import '../../principal/presentation/principal_workspace_page.dart';
import '../../proprietor/presentation/proprietor_workspace_page.dart';
import '../../sync_center/presentation/sync_center_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.membership,
    required this.localDatabase,
    required this.schoolSession,
    this.schoolAppearance,
  });

  static SchoolAppearanceController? appSchoolAppearance;

  final SchoolMembership membership;
  final LocalDatabase localDatabase;
  final SchoolSessionController schoolSession;
  final SchoolAppearanceController? schoolAppearance;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SyncRefresh<DashboardPage> {
  int _selectedIndex = 0;
  int _pendingSyncCount = 0;
  late final AttendanceRepository _attendanceRepository;
  late final LessonPlanRepository _lessonPlanRepository;
  late final List<_AppDestination> _destinations;

  SchoolAppearanceController? get _appearance =>
      widget.schoolAppearance ?? DashboardPage.appSchoolAppearance;

  static const _allDestinations = <_AppDestination>[
    _AppDestination('Dashboard', Icons.dashboard_outlined,
        Icons.dashboard_rounded, AppCapability.dashboard),
    _AppDestination(
        'Students', Icons.groups_outlined, Icons.groups_rounded, AppCapability.students),
    _AppDestination('Attendance', Icons.fact_check_outlined,
        Icons.fact_check_rounded, AppCapability.attendance),
    _AppDestination('Academics', Icons.menu_book_outlined,
        Icons.menu_book_rounded, AppCapability.academics),
    _AppDestination('Messages', Icons.chat_bubble_outline_rounded,
        Icons.chat_bubble_rounded, AppCapability.messaging),
  ];

  @override
  void initState() {
    super.initState();
    _destinations = _allDestinations
        .where((item) => RolePermissions.can(widget.membership.role, item.capability))
        .toList(growable: false);
    _attendanceRepository = AttendanceRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _lessonPlanRepository = LessonPlanRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _refreshPendingCount();
  }

  @override
  void onSynced() => _refreshPendingCount();

  void _refreshPendingCount() {
    final active = widget.schoolSession.requireActiveMembership();
    if (active.id != widget.membership.id) return;
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

    final appearance = _appearance;
    final Widget page;
    if (membership.role == SchoolRole.proprietor && appearance != null) {
      page = ProprietorWorkspacePage(
        membership: membership,
        localDatabase: widget.localDatabase,
        schoolSession: widget.schoolSession,
        schoolAppearance: appearance,
      );
    } else if (membership.role == SchoolRole.administrator && appearance != null) {
      page = AdministratorWorkspacePage(
        membership: membership,
        localDatabase: widget.localDatabase,
        schoolSession: widget.schoolSession,
        schoolAppearance: appearance,
      );
    } else if (membership.role == SchoolRole.principal && appearance != null) {
      page = PrincipalWorkspacePage(
        membership: membership,
        localDatabase: widget.localDatabase,
        schoolSession: widget.schoolSession,
        schoolAppearance: appearance,
      );
    } else if (membership.role == SchoolRole.driver && appearance != null) {
      page = DriverWorkspacePage(
        membership: membership,
        localDatabase: widget.localDatabase,
        schoolSession: widget.schoolSession,
        schoolAppearance: appearance,
      );
    } else {
      page = DashboardPage(
        membership: membership,
        localDatabase: widget.localDatabase,
        schoolSession: widget.schoolSession,
        schoolAppearance: appearance,
      );
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  Widget _workspace() {
    final destination = _destinations[_selectedIndex];
    if (destination.capability == AppCapability.attendance) {
      return AttendancePage(repository: _attendanceRepository, onSaved: _refreshPendingCount);
    }
    if (destination.capability == AppCapability.academics &&
        RolePermissions.can(widget.membership.role, AppCapability.lessonPlans)) {
      return LessonPlanPage(
        membership: widget.membership,
        generationService: const LessonPlanGenerationService(),
        repository: _lessonPlanRepository,
        onQueuedForSync: _refreshPendingCount,
      );
    }
    return _Workspace(
      destination: destination,
      membership: widget.membership,
      pendingSyncCount: _pendingSyncCount,
    );
  }

  @override
  Widget build(BuildContext context) => StaffOnboardingBanner(
    repository: StaffOnboardingRepository(
      database: widget.localDatabase,
      session: widget.schoolSession,
    ),
    child: _buildWorkspace(context),
  );

  Widget _buildWorkspace(BuildContext context) {
    final appearance = _appearance;
    if (widget.membership.role == SchoolRole.accountant && appearance != null) {
      return FinanceOfficeWorkspacePage(
        membership: widget.membership,
        localDatabase: widget.localDatabase,
        schoolSession: widget.schoolSession,
        schoolAppearance: appearance,
      );
    }
    if (widget.membership.role == SchoolRole.teacher && appearance != null) {
      return TeacherWorkspacePage(
        membership: widget.membership,
        localDatabase: widget.localDatabase,
        schoolSession: widget.schoolSession,
        schoolAppearance: appearance,
      );
    }
    if (widget.membership.role == SchoolRole.parent && appearance != null) {
      return ParentWorkspacePage(
        membership: widget.membership,
        localDatabase: widget.localDatabase,
        schoolSession: widget.schoolSession,
        schoolAppearance: appearance,
      );
    }
    if (widget.membership.role == SchoolRole.administrator && appearance != null) {
      return AdministratorWorkspacePage(
        membership: widget.membership,
        localDatabase: widget.localDatabase,
        schoolSession: widget.schoolSession,
        schoolAppearance: appearance,
      );
    }
    if (widget.membership.role == SchoolRole.proprietor && appearance != null) {
      return ProprietorWorkspacePage(
        membership: widget.membership,
        localDatabase: widget.localDatabase,
        schoolSession: widget.schoolSession,
        schoolAppearance: appearance,
      );
    }
    if (widget.membership.role == SchoolRole.principal && appearance != null) {
      return PrincipalWorkspacePage(
        membership: widget.membership,
        localDatabase: widget.localDatabase,
        schoolSession: widget.schoolSession,
        schoolAppearance: appearance,
      );
    }
    if (widget.membership.role == SchoolRole.driver && appearance != null) {
      return DriverWorkspacePage(
        membership: widget.membership,
        localDatabase: widget.localDatabase,
        schoolSession: widget.schoolSession,
        schoolAppearance: appearance,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final phone = AppBreakpoints.isPhone(constraints.maxWidth);
        if (phone) {
          return Scaffold(
            appBar: AppBar(
              title: _SchoolTitle(membership: widget.membership),
              actions: _topActions(),
            ),
            body: _workspace(),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => setState(() => _selectedIndex = index),
              destinations: [
                for (final item in _destinations)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: item.label,
                  ),
              ],
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  extended: constraints.maxWidth >= 1180,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) => setState(() => _selectedIndex = index),
                  leading: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    child: _SchoolMark(membership: widget.membership),
                  ),
                  destinations: [
                    for (final item in _destinations)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: Text(item.label),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 18, 28, 12),
                        child: Row(
                          children: [
                            Expanded(child: _SchoolTitle(membership: widget.membership)),
                            ..._topActions(),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(child: _workspace()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _topActions() => [
        if (widget.schoolSession.canSwitchSchool)
          _SchoolSwitcherButton(
            activeMembership: widget.membership,
            memberships: widget.schoolSession.memberships,
            onSelected: _switchSchool,
          ),
        _SyncStatusButton(pendingCount: _pendingSyncCount, onPressed: _openSyncCenter),
        const SizedBox(width: 8),
      ];
}

class _Workspace extends StatelessWidget {
  const _Workspace({
    required this.destination,
    required this.membership,
    required this.pendingSyncCount,
  });

  final _AppDestination destination;
  final SchoolMembership membership;
  final int pendingSyncCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(destination.label,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          '${membership.roleLabel} workspace · ${membership.schoolName}',
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            const _SummaryCard(
              label: 'Offline storage',
              value: 'Encrypted',
              icon: Icons.enhanced_encryption_outlined,
            ),
            _SummaryCard(
              label: 'Pending sync',
              value: '$pendingSyncCount',
              icon: Icons.sync_rounded,
            ),
            const _SummaryCard(
              label: 'Edge AI',
              value: 'Boundary ready',
              icon: Icons.auto_awesome_outlined,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Card(
          elevation: 0,
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Offline foundation active. This workspace is filtered by the role attached to this school membership. Offline records remain tenant-scoped and encrypted before storage.',
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 18),
              Text(value,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(label),
            ],
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SchoolMark(membership: membership),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(membership.schoolName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(membership.roleLabel, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _SchoolMark extends StatelessWidget {
  const _SchoolMark({required this.membership});
  final SchoolMembership membership;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: Text(membership.schoolName.characters.first.toUpperCase()),
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
                      Text(membership.roleLabel, style: Theme.of(context).textTheme.bodySmall),
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

class _SyncStatusButton extends StatelessWidget {
  const _SyncStatusButton({required this.pendingCount, required this.onPressed});
  final int pendingCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final synced = pendingCount == 0;
    return Tooltip(
      message: synced ? 'Open Sync Center' : 'Open Sync Center · $pendingCount waiting',
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(synced ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined, size: 18),
        label: Text(synced ? 'Synced' : '$pendingCount pending'),
      ),
    );
  }
}

class _AppDestination {
  const _AppDestination(this.label, this.icon, this.selectedIcon, this.capability);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final AppCapability capability;
}
