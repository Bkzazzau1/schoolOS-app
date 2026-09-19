import 'package:flutter/material.dart';

import '../../../core/appearance/school_appearance_controller.dart';
import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/presentation/administrator_workspace_page.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../proprietor/presentation/proprietor_workspace_page.dart';
import '../../sync_center/presentation/sync_center_page.dart';
import '../data/principal_academics_repository.dart';
import '../data/principal_approvals_repository.dart';
import '../data/principal_assignments_repository.dart';
import '../data/principal_attendance_repository.dart';
import '../data/principal_dashboard_demo_data.dart';
import '../data/principal_results_repository.dart';
import '../data/principal_students_repository.dart';
import '../data/principal_teachers_repository.dart';
import '../domain/principal_dashboard_models.dart';
import 'principal_academics_page.dart';
import 'principal_approvals_page.dart';
import 'principal_assignments_page.dart';
import 'principal_attendance_page.dart';
import 'principal_dashboard_page.dart';
import 'principal_results_page.dart';
import 'principal_students_page.dart';
import 'principal_teachers_page.dart';

class PrincipalWorkspacePage extends StatefulWidget {
  const PrincipalWorkspacePage({
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
  State<PrincipalWorkspacePage> createState() => _PrincipalWorkspacePageState();
}

class _PrincipalWorkspacePageState extends State<PrincipalWorkspacePage> {
  String _activeKey = 'dashboard';
  int _pendingSyncCount = 0;
  late final PrincipalTeachersRepository _teachersRepository;
  late final PrincipalAssignmentsRepository _assignmentsRepository;
  late final PrincipalAcademicsRepository _academicsRepository;
  late final PrincipalStudentsRepository _studentsRepository;
  late final PrincipalAttendanceRepository _attendanceRepository;
  late final PrincipalApprovalsRepository _approvalsRepository;
  late final PrincipalResultsRepository _resultsRepository;

  @override
  void initState() {
    super.initState();
    _teachersRepository = PrincipalTeachersRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _assignmentsRepository = PrincipalAssignmentsRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _academicsRepository = PrincipalAcademicsRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _studentsRepository = PrincipalStudentsRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _attendanceRepository = PrincipalAttendanceRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _approvalsRepository = PrincipalApprovalsRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _resultsRepository = PrincipalResultsRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _refreshPendingCount();
  }

  PrincipalNavItem get _activeItem => principalNavigation.firstWhere(
        (item) => item.key == _activeKey,
        orElse: () => principalNavigation.first,
      );

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

    final Widget page;
    if (membership.role == SchoolRole.proprietor) {
      page = ProprietorWorkspacePage(
        membership: membership,
        localDatabase: widget.localDatabase,
        schoolSession: widget.schoolSession,
        schoolAppearance: widget.schoolAppearance,
      );
    } else if (membership.role == SchoolRole.administrator) {
      page = AdministratorWorkspacePage(
        membership: membership,
        localDatabase: widget.localDatabase,
        schoolSession: widget.schoolSession,
        schoolAppearance: widget.schoolAppearance,
      );
    } else if (membership.role == SchoolRole.principal) {
      page = PrincipalWorkspacePage(
        membership: membership,
        localDatabase: widget.localDatabase,
        schoolSession: widget.schoolSession,
        schoolAppearance: widget.schoolAppearance,
      );
    } else {
      page = DashboardPage(
        membership: membership,
        localDatabase: widget.localDatabase,
        schoolSession: widget.schoolSession,
        schoolAppearance: widget.schoolAppearance,
      );
    }

    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _select(String key) {
    if (!principalNavigation.any((item) => item.key == key)) return;
    setState(() => _activeKey = key);
  }

  Widget _content() {
    if (_activeKey == 'dashboard') {
      return PrincipalDashboardPage(
        schoolName: widget.membership.schoolName,
        onActionRequested: _select,
      );
    }
    if (_activeKey == 'teachers') {
      return PrincipalTeachersPage(
        repository: _teachersRepository,
        onActionRequested: _select,
        onQueuedForSync: _refreshPendingCount,
      );
    }
    if (_activeKey == 'assignments') {
      return PrincipalAssignmentsPage(
        repository: _assignmentsRepository,
        onNavigate: _select,
        onMutationQueued: _refreshPendingCount,
      );
    }
    if (_activeKey == 'academics') {
      return PrincipalAcademicsPage(
        repository: _academicsRepository,
        onNavigate: _select,
      );
    }
    if (_activeKey == 'students') {
      return PrincipalStudentsPage(
        repository: _studentsRepository,
        onNavigate: _select,
        onMutationQueued: _refreshPendingCount,
      );
    }
    if (_activeKey == 'attendance') {
      return PrincipalAttendancePage(
        repository: _attendanceRepository,
        onNavigate: _select,
        onMutationQueued: _refreshPendingCount,
      );
    }
    if (_activeKey == 'approvals') {
      return PrincipalApprovalsPage(
        repository: _approvalsRepository,
        onNavigate: _select,
        onMutationQueued: _refreshPendingCount,
      );
    }
    if (_activeKey == 'results') {
      return PrincipalResultsPage(
        repository: _resultsRepository,
        onNavigate: _select,
        onMutationQueued: _refreshPendingCount,
      );
    }
    return _UpcomingPrincipalFeature(
      item: _activeItem,
      onDashboard: () => _select('dashboard'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final phone = constraints.maxWidth < 700;
        return phone ? _phone(context) : _wide(context, constraints);
      },
    );
  }

  Widget _phone(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.membership.schoolName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            const Text('Principal · Secondary', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          if (widget.schoolSession.canSwitchSchool)
            _SchoolSwitcherButton(activeMembership: widget.membership, memberships: widget.schoolSession.memberships, onSelected: _switchSchool),
          IconButton(
            tooltip: _pendingSyncCount == 0 ? 'Sync Center' : 'Sync Center · $_pendingSyncCount pending',
            onPressed: _openSyncCenter,
            icon: Badge(isLabelVisible: _pendingSyncCount > 0, label: Text('$_pendingSyncCount'), child: const Icon(Icons.cloud_sync_outlined)),
          ),
          Builder(builder: (context) => IconButton(onPressed: () => Scaffold.of(context).openEndDrawer(), icon: const Icon(Icons.menu_rounded), tooltip: 'Principal menu')),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const ListTile(title: Text('Principal Portal', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Secondary School')),
              const Divider(),
              for (final item in principalNavigation)
                ListTile(
                  selected: item.key == _activeKey,
                  leading: Icon(_iconFor(item.key)),
                  title: Text(item.label),
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
              width: extended ? 282 : 88,
              decoration: BoxDecoration(border: Border(right: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: extended
                        ? const ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(child: Text('S')), title: Text('SchoolOS', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Principal Portal'))
                        : const CircleAvatar(child: Text('S')),
                  ),
                  if (extended)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('ACTIVE LEADERSHIP SCOPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(widget.membership.schoolName, style: const TextStyle(fontWeight: FontWeight.w900)),
                            const Text(principalCampusLabel, style: TextStyle(fontSize: 12)),
                          ]),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final item in principalNavigation)
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
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Secondary section health', style: TextStyle(fontSize: 12)),
                        const Text('86%', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                        const LinearProgressIndicator(value: .86),
                        const SizedBox(height: 6),
                        Text('Academics, attendance, staff & compliance', style: Theme.of(context).textTheme.bodySmall),
                      ]),
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
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Principal · Secondary School', style: TextStyle(fontWeight: FontWeight.w900)), Text(_activeItem.label)])),
                      if (widget.schoolSession.canSwitchSchool)
                        _SchoolSwitcherButton(activeMembership: widget.membership, memberships: widget.schoolSession.memberships, onSelected: _switchSchool),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(onPressed: _openSyncCenter, icon: const Icon(Icons.cloud_sync_outlined, size: 18), label: Text(_pendingSyncCount == 0 ? 'Synced' : '$_pendingSyncCount pending')),
                      const SizedBox(width: 12),
                      const CircleAvatar(child: Text('PD')),
                      if (constraints.maxWidth >= 1080) ...[
                        const SizedBox(width: 8),
                        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(principalLeaderName, style: TextStyle(fontWeight: FontWeight.w800)), Text('Principal · Secondary', style: TextStyle(fontSize: 12))]),
                      ],
                    ]),
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

  static IconData _iconFor(String key) {
    return switch (key) {
      'dashboard' => Icons.dashboard_rounded,
      'teachers' => Icons.badge_outlined,
      'assignments' => Icons.assignment_ind_outlined,
      'academics' => Icons.menu_book_rounded,
      'students' => Icons.groups_rounded,
      'attendance' => Icons.fact_check_outlined,
      'approvals' => Icons.approval_outlined,
      'results' => Icons.assessment_outlined,
      'timetable' => Icons.calendar_month_outlined,
      'communication' => Icons.forum_outlined,
      'incidents' => Icons.report_problem_outlined,
      'ai' => Icons.auto_awesome_rounded,
      'performance' => Icons.insights_rounded,
      'profile' => Icons.person_outline_rounded,
      _ => Icons.circle_outlined,
    };
  }
}

class _UpcomingPrincipalFeature extends StatelessWidget {
  const _UpcomingPrincipalFeature({required this.item, required this.onDashboard});
  final PrincipalNavItem item;
  final VoidCallback onDashboard;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_PrincipalWorkspacePageState._iconFor(item.key), size: 42),
                  const SizedBox(height: 12),
                  Text(item.label, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('This Principal feature exists in the website navigation and will be ported next in sequence. It is intentionally not simulated yet.', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: onDashboard, icon: const Icon(Icons.dashboard_rounded), label: const Text('Back to dashboard')),
                ]),
              ),
            ),
          ),
        ),
      );
}

class _SchoolSwitcherButton extends StatelessWidget {
  const _SchoolSwitcherButton({required this.activeMembership, required this.memberships, required this.onSelected});
  final SchoolMembership activeMembership;
  final List<SchoolMembership> memberships;
  final ValueChanged<SchoolMembership> onSelected;
  @override
  Widget build(BuildContext context) => PopupMenuButton<SchoolMembership>(
        tooltip: 'Switch school',
        onSelected: onSelected,
        icon: const Icon(Icons.swap_horiz_rounded),
        itemBuilder: (_) => [for (final membership in memberships) PopupMenuItem(value: membership, child: Text('${membership.schoolName} · ${membership.roleLabel}'))],
      );
}
