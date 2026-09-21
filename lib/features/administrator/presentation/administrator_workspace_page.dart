import '../../notifications/presentation/notifications_bell.dart';
import '../../../core/sync/sync_scope.dart';
import '../../proprietor/data/owner_staff_profile_repository.dart';
import '../../proprietor/data/payroll_batch_repository.dart';
import '../../proprietor/data/staff_proposal_repository.dart';
import '../../proprietor/presentation/owner_staff_profiles_page.dart';
import 'package:flutter/material.dart';

import '../../../core/appearance/school_appearance_controller.dart';
import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../proprietor/presentation/proprietor_workspace_page.dart';
import '../../sync_center/presentation/sync_center_page.dart';
import '../data/administrator_admissions_repository.dart';
import '../data/administrator_attendance_repository.dart';
import '../data/administrator_dashboard_demo_data.dart';
import '../data/administrator_lifecycle_repository.dart';
import '../data/administrator_notices_repository.dart';
import '../data/administrator_operations_repository.dart';
import '../data/administrator_records_repository.dart';
import '../data/administrator_registration_repository.dart';
import '../data/administrator_staff_attendance_repository.dart';
import '../data/administrator_staff_repository.dart';
import '../data/administrator_students_repository.dart';
import '../data/administrator_website_repository.dart';
import '../domain/administrator_admissions_models.dart';
import '../domain/administrator_dashboard_models.dart';
import 'administrator_admissions_page.dart';
import 'administrator_attendance_page.dart';
import 'administrator_dashboard_page.dart';
import 'administrator_lifecycle_page.dart';
import 'administrator_notices_page.dart';
import 'administrator_operations_page.dart';
import 'administrator_records_page.dart';
import 'administrator_registration_page.dart';
import 'administrator_staff_attendance_page.dart';
import 'administrator_staff_page.dart';
import 'administrator_students_page.dart';
import 'administrator_website_page.dart';

class AdministratorWorkspacePage extends StatefulWidget {
  const AdministratorWorkspacePage({
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
  State<AdministratorWorkspacePage> createState() =>
      _AdministratorWorkspacePageState();
}

class _AdministratorWorkspacePageState extends State<AdministratorWorkspacePage> with SyncRefresh<AdministratorWorkspacePage>, AccessAware<AdministratorWorkspacePage> {
  /// The screens the owner allows this person (all of them until their access is known).
  List<AdministratorNavItem> get _navigation =>
      visibleScreens('administrator', administratorNavigation, (item) => item.key);

  String _activeKey = 'dashboard';
  int _pendingSyncCount = 0;
  AdmissionApplicant? _registrationApplicant;
  late final AdministratorAdmissionsRepository _admissionsRepository;
  late final AdministratorAttendanceRepository _attendanceRepository;
  late final AdministratorLifecycleRepository _lifecycleRepository;
  late final AdministratorNoticesRepository _noticesRepository;
  late final AdministratorOperationsRepository _operationsRepository;
  late final AdministratorRecordsRepository _recordsRepository;
  late final AdministratorRegistrationRepository _registrationRepository;
  late final AdministratorStaffAttendanceRepository _staffAttendanceRepository;
  late final AdministratorStaffRepository _staffRepository;
  late final AdministratorStudentsRepository _studentsRepository;
  late final AdministratorWebsiteRepository _websiteRepository;

  @override
  void initState() {
    super.initState();
    _admissionsRepository = AdministratorAdmissionsRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _attendanceRepository = AdministratorAttendanceRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _lifecycleRepository = AdministratorLifecycleRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _noticesRepository = AdministratorNoticesRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _operationsRepository = AdministratorOperationsRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _recordsRepository = AdministratorRecordsRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _registrationRepository = AdministratorRegistrationRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _staffAttendanceRepository = AdministratorStaffAttendanceRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _staffRepository = AdministratorStaffRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _studentsRepository = AdministratorStudentsRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _websiteRepository = AdministratorWebsiteRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _refreshPendingCount();
  }

  @override
  void onSynced() => _refreshPendingCount();

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
    } else {
      page = DashboardPage(
        membership: membership,
        localDatabase: widget.localDatabase,
        schoolSession: widget.schoolSession,
        schoolAppearance: widget.schoolAppearance,
      );
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (context) => page),
    );
  }

  void _select(String key) {
    if (key == 'scholarships') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Scholarship / discount requests will connect to the shared concession workflow; only the Proprietor can approve them.',
          ),
        ),
      );
      return;
    }

    final exists = _navigation.any((item) => item.key == key);
    if (!exists) return;
    setState(() {
      if (key == 'registration') _registrationApplicant = null;
      _activeKey = key;
    });
  }

  void _openPublicAdmissionsWebsite() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'The public admissions website is an online web surface. Website Manager controls its public content; offline Administrator work remains available here.',
        ),
      ),
    );
  }

  void _handoffToRegistration(AdmissionApplicant applicant) {
    setState(() {
      _registrationApplicant = applicant;
      _activeKey = 'registration';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${applicant.name} · ${applicant.reference} handed to Student Registration. The registration remains in progress until completion.',
        ),
      ),
    );
  }

  AdministratorNavItem get _activeItem => _navigation.firstWhere(
        (item) => item.key == _activeKey,
        orElse: () => _navigation.first,
      );

  Widget _buildContent() {
    if (_activeKey == 'dashboard') {
      return AdministratorDashboardPage(
        schoolName: widget.membership.schoolName,
        onActionRequested: _select,
      );
    }

    if (_activeKey == 'admissions') {
      return AdministratorAdmissionsPage(
        schoolName: widget.membership.schoolName,
        repository: _admissionsRepository,
        onRegistrationRequested: _handoffToRegistration,
        onOpenPublicWebsite: _openPublicAdmissionsWebsite,
        onAdmissionsChanged: _refreshPendingCount,
      );
    }

    if (_activeKey == 'website') {
      return AdministratorWebsitePage(
        schoolName: widget.membership.schoolName,
        repository: _websiteRepository,
        onSettingsChanged: _refreshPendingCount,
      );
    }

    if (_activeKey == 'registration') {
      return AdministratorRegistrationPage(
        schoolName: widget.membership.schoolName,
        repository: _registrationRepository,
        sourceApplicant: _registrationApplicant,
        onRegistrationChanged: _refreshPendingCount,
      );
    }

    if (_activeKey == 'students') {
      return AdministratorStudentsPage(
        schoolName: widget.membership.schoolName,
        repository: _studentsRepository,
        onRegisterStudent: () => _select('registration'),
      );
    }

    if (_activeKey == 'staff') {
      return AdministratorStaffPage(
        schoolName: widget.membership.schoolName,
        repository: _staffRepository,
        proposals: StaffProposalRepository(
          database: widget.localDatabase,
          session: widget.schoolSession,
        ),
      );
    }

    if (_activeKey == 'staff-profiles') {
      return OwnerStaffProfilesPage(
        repository: OwnerStaffProfileRepository(
          database: widget.localDatabase,
          session: widget.schoolSession,
        ),
        proposals: StaffProposalRepository(
          database: widget.localDatabase,
          session: widget.schoolSession,
        ),
        payrollBatches: PayrollBatchRepository(
          database: widget.localDatabase,
          session: widget.schoolSession,
        ),
        onChanged: _refreshPendingCount,
      );
    }

    if (_activeKey == 'staff-attendance') {
      return AdministratorStaffAttendancePage(
        schoolName: widget.membership.schoolName,
        repository: _staffAttendanceRepository,
        onAttendanceChanged: _refreshPendingCount,
      );
    }

    if (_activeKey == 'records') {
      return AdministratorRecordsPage(
        schoolName: widget.membership.schoolName,
        repository: _recordsRepository,
      );
    }

    if (_activeKey == 'lifecycle') {
      return AdministratorLifecyclePage(
        schoolName: widget.membership.schoolName,
        repository: _lifecycleRepository,
      );
    }

    if (_activeKey == 'attendance') {
      return AdministratorAttendancePage(
        schoolName: widget.membership.schoolName,
        repository: _attendanceRepository,
      );
    }

    if (_activeKey == 'operations') {
      return AdministratorOperationsPage(
        schoolName: widget.membership.schoolName,
        repository: _operationsRepository,
      );
    }

    if (_activeKey == 'notices') {
      return AdministratorNoticesPage(
        schoolName: widget.membership.schoolName,
        repository: _noticesRepository,
        onNoticesChanged: _refreshPendingCount,
      );
    }

    return _UpcomingAdministratorFeature(
      item: _activeItem,
      onDashboard: () => setState(() => _activeKey = 'dashboard'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final phone = constraints.maxWidth < 700;
        return phone ? _buildPhone(context) : _buildWide(context, constraints);
      },
    );
  }

  Widget _buildPhone(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _SchoolTitle(membership: widget.membership),
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
              child: Icon(
                _pendingSyncCount == 0
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_upload_outlined,
              ),
            ),
          ),
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Administration menu',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              const ListTile(
                title: Text(
                  'Administration',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(administratorAcademicYear),
              ),
              const Divider(),
              for (final item in _navigation)
                ListTile(
                  selected: _activeKey == item.key,
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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _activeItem.label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const Badge(
                  label: Text('5'),
                  child: Icon(Icons.notifications_outlined),
                ),
              ],
            ),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildWide(BuildContext context, BoxConstraints constraints) {
    final extended = constraints.maxWidth >= 1180;
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: Container(
              width: extended ? 278 : 88,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _AdminBrand(extended: extended),
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
                              const Text(
                                'ACTIVE SCHOOL',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.membership.schoolName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                administratorCampusLabel,
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 12),
                      children: [
                        for (final item in _navigation)
                          _AdminNavTile(
                            extended: extended,
                            item: item,
                            selected: item.key == _activeKey,
                            onTap: () => _select(item.key),
                          ),
                      ],
                    ),
                  ),
                  if (extended)
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        'ROLE BOUNDARY\nOperational records and workflows only. Academic decisions, proprietor governance and confidential payroll remain with authorized roles.',
                        style: theme.textTheme.bodySmall,
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
                              const Text(
                                'Administration Workspace',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              const Text(administratorAcademicYear),
                            ],
                          ),
                        ),
                        if (constraints.maxWidth >= 980)
                          SizedBox(
                            width: 300,
                            child: TextField(
                              readOnly: true,
                              onTap: () => _select('students'),
                              decoration: const InputDecoration(
                                isDense: true,
                                prefixIcon: Icon(Icons.search_rounded),
                                hintText:
                                    'Search student, guardian, staff, document...',
                              ),
                            ),
                          ),
                        if (constraints.maxWidth >= 980)
                          const SizedBox(width: 10),
                        Badge(
                          label: const Text('5'),
                          child: IconButton(
                            tooltip: 'Notifications',
                            onPressed: () {},
                            icon: const Icon(Icons.notifications_outlined),
                          ),
                        ),
                        if (widget.schoolSession.canSwitchSchool) ...[
                          const SizedBox(width: 6),
                          _SchoolSwitcherButton(
                            activeMembership: widget.membership,
                            memberships: widget.schoolSession.memberships,
                            onSelected: _switchSchool,
                          ),
                        ],
                        const SizedBox(width: 6),
                        NotificationsBell(membership: widget.membership),
                        const SizedBox(width: 6),
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

  static IconData _iconFor(String key) {
    return switch (key) {
      'dashboard' => Icons.dashboard_rounded,
      'admissions' => Icons.filter_alt_outlined,
      'website' => Icons.language_rounded,
      'registration' => Icons.person_add_alt_1_rounded,
      'students' => Icons.groups_rounded,
      'staff' => Icons.badge_outlined,
      'staff-attendance' => Icons.schedule_rounded,
      'staff-profiles' => Icons.folder_shared_outlined,
      'records' => Icons.folder_copy_outlined,
      'lifecycle' => Icons.swap_horiz_rounded,
      'attendance' => Icons.fact_check_outlined,
      'operations' => Icons.hub_outlined,
      'notices' => Icons.campaign_outlined,
      _ => Icons.circle_outlined,
    };
  }
}

class _UpcomingAdministratorFeature extends StatelessWidget {
  const _UpcomingAdministratorFeature({
    required this.item,
    required this.onDashboard,
  });

  final AdministratorNavItem item;
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
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _AdministratorWorkspacePageState._iconFor(item.key),
                    size: 42,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This administrator feature is visible in the real website navigation and will be ported next in sequence. It is intentionally not simulated here.',
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

class _AdminBrand extends StatelessWidget {
  const _AdminBrand({required this.extended});

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
      alignment: Alignment.center,
      child: Text(
        'S',
        style: TextStyle(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w900,
          fontSize: 20,
        ),
      ),
    );
    if (!extended) return mark;
    return Row(
      children: [
        mark,
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SchoolOS', style: TextStyle(fontWeight: FontWeight.w900)),
              Text('Administration Desk'),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminNavTile extends StatelessWidget {
  const _AdminNavTile({
    required this.extended,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final bool extended;
  final AdministratorNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      child: ListTile(
        selected: selected,
        selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(_AdministratorWorkspacePageState._iconFor(item.key)),
        title: extended ? Text(item.label) : null,
        contentPadding: EdgeInsets.symmetric(horizontal: extended ? 12 : 14),
        onTap: onTap,
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
        CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
              const Text('Administrator'),
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
