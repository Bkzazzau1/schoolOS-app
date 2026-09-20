import 'package:flutter/material.dart';

import '../../../core/appearance/school_appearance_controller.dart';
import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../sync_center/presentation/sync_center_page.dart';
import '../data/driver_afternoon_run_repository.dart';
import '../data/driver_dashboard_repository.dart';
import '../data/driver_morning_run_repository.dart';
import '../data/driver_riders_repository.dart';
import '../data/driver_route_repository.dart';
import '../data/driver_vehicle_check_repository.dart';
import 'driver_afternoon_run_page.dart';
import 'driver_dashboard_page.dart';
import 'driver_morning_run_page.dart';
import 'driver_riders_page.dart';
import 'driver_route_page.dart';
import 'driver_vehicle_check_page.dart';

class DriverWorkspacePage extends StatefulWidget {
  const DriverWorkspacePage({
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
  State<DriverWorkspacePage> createState() => _DriverWorkspacePageState();
}

class _DriverWorkspacePageState extends State<DriverWorkspacePage> {
  String _activeKey = 'dashboard';
  int _pendingSyncCount = 0;
  late final DriverDashboardRepository _dashboardRepository;
  late final DriverMorningRunRepository _morningRunRepository;
  late final DriverAfternoonRunRepository _afternoonRunRepository;
  late final DriverRidersRepository _ridersRepository;
  late final DriverRouteRepository _routeRepository;
  late final DriverVehicleCheckRepository _vehicleCheckRepository;

  static const _navigation = <_DriverNavItem>[
    _DriverNavItem('dashboard', 'Dashboard', Icons.dashboard_rounded),
    _DriverNavItem('morning', 'Morning Run', Icons.wb_sunny_outlined),
    _DriverNavItem('afternoon', 'Afternoon Run', Icons.nights_stay_outlined),
    _DriverNavItem('riders', 'Riders', Icons.groups_2_outlined),
    _DriverNavItem('route', 'Route & Stops', Icons.route_outlined),
    _DriverNavItem(
      'vehicle-check',
      'Vehicle Check',
      Icons.health_and_safety_outlined,
    ),
    _DriverNavItem('incidents', 'Incidents', Icons.report_problem_outlined),
    _DriverNavItem('messages', 'Messages & Alerts', Icons.mail_outline_rounded),
    _DriverNavItem('history', 'Trip History & Profile', Icons.history_rounded),
  ];

  _DriverNavItem get _activeItem => _navigation.firstWhere(
        (item) => item.key == _activeKey,
        orElse: () => _navigation.first,
      );

  @override
  void initState() {
    super.initState();
    _dashboardRepository = DriverDashboardRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _morningRunRepository = DriverMorningRunRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _afternoonRunRepository = DriverAfternoonRunRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _ridersRepository = DriverRidersRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _routeRepository = DriverRouteRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _vehicleCheckRepository = DriverVehicleCheckRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _refreshPendingCount();
  }

  void _select(String key) {
    if (!_navigation.any((item) => item.key == key) || key == _activeKey) return;
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

    final Widget page = membership.role == SchoolRole.driver
        ? DriverWorkspacePage(
            membership: membership,
            localDatabase: widget.localDatabase,
            schoolSession: widget.schoolSession,
            schoolAppearance: widget.schoolAppearance,
          )
        : DashboardPage(
            membership: membership,
            localDatabase: widget.localDatabase,
            schoolSession: widget.schoolSession,
            schoolAppearance: widget.schoolAppearance,
          );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  Widget _content() => switch (_activeKey) {
        'dashboard' => DriverDashboardPage(
            repository: _dashboardRepository,
            onNavigate: _select,
          ),
        'morning' => DriverMorningRunPage(
            repository: _morningRunRepository,
            onRunChanged: _refreshPendingCount,
          ),
        'afternoon' => DriverAfternoonRunPage(
            repository: _afternoonRunRepository,
            onRunChanged: _refreshPendingCount,
          ),
        'riders' => DriverRidersPage(repository: _ridersRepository),
        'route' => DriverRoutePage(
            repository: _routeRepository,
            onNavigate: _select,
          ),
        'vehicle-check' => DriverVehicleCheckPage(
            repository: _vehicleCheckRepository,
            onCheckChanged: _refreshPendingCount,
          ),
        _ => _UpcomingDriverFeature(
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
            const Text('Driver Portal', style: TextStyle(fontSize: 12)),
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
              tooltip: 'Driver menu',
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
              const ListTile(
                leading: CircleAvatar(
                  child: Icon(Icons.directions_bus_outlined),
                ),
                title: Text(
                  'Driver Portal',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text('Assigned transport duties only'),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    for (final item in _navigation)
                      ListTile(
                        selected: item.key == _activeKey,
                        selectedTileColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: Icon(item.icon),
                        title: Text(item.label),
                        onTap: () {
                          Navigator.of(context).pop();
                          _select(item.key);
                        },
                      ),
                  ],
                ),
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
    final extended = constraints.maxWidth >= 1160;
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: Container(
              width: extended ? 282 : 88,
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
                        ? _DriverIdentityCard(
                            schoolName: widget.membership.schoolName,
                          )
                        : const CircleAvatar(
                            child: Icon(Icons.directions_bus_outlined),
                          ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: [
                        for (final item in _navigation)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Tooltip(
                              message: extended ? '' : item.label,
                              child: ListTile(
                                dense: true,
                                selected: item.key == _activeKey,
                                selectedTileColor:
                                    Theme.of(context).colorScheme.primaryContainer,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                leading: Icon(item.icon),
                                title: extended ? Text(item.label) : null,
                                onTap: () => _select(item.key),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (extended)
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: _DriverBoundaryCard(),
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
                                'Driver · Transport Operations',
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

class _UpcomingDriverFeature extends StatelessWidget {
  const _UpcomingDriverFeature({
    required this.item,
    required this.onDashboard,
  });

  final _DriverNavItem item;
  final VoidCallback onDashboard;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.icon,
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
                    'This Driver Portal destination is reserved for the next transport feature. It is not simulated as completed yet.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onDashboard,
                    icon: const Icon(Icons.dashboard_rounded),
                    label: const Text('Back to dashboard'),
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

class _DriverIdentityCard extends StatelessWidget {
  const _DriverIdentityCard({required this.schoolName});

  final String schoolName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(child: Icon(Icons.directions_bus_outlined)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SchoolOS',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                '$schoolName · Driver Portal',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverBoundaryCard extends StatelessWidget {
  const _DriverBoundaryCard();

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
      child: const Text(
        'Assigned route only. Student access is limited to transport operations.',
        style: TextStyle(fontSize: 11, height: 1.35),
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

class _DriverNavItem {
  const _DriverNavItem(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}
