import 'package:flutter/material.dart';

import '../../../core/appearance/school_appearance_controller.dart';
import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_scope.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_students_models.dart';
import '../../administrator/presentation/administrator_workspace_page.dart';
import '../../community/data/community_repository.dart';
import '../../community/presentation/community_page.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../finance_office/presentation/finance_office_workspace_page.dart';
import '../../notifications/presentation/notifications_bell.dart';
import '../../principal/presentation/principal_workspace_page.dart';
import '../../proprietor/data/owner_staff_profile_repository.dart';
import '../../proprietor/data/staff_onboarding_repository.dart';
import '../../proprietor/data/staff_server_api.dart';
import '../../proprietor/domain/owner_staff_profile_models.dart';
import '../../proprietor/presentation/proprietor_workspace_page.dart';
import '../../proprietor/presentation/staff_onboarding_page.dart';
import '../../sync_center/presentation/sync_center_page.dart';
import '../../teacher/presentation/teacher_workspace_page.dart';
import '../data/staff_self_service_repository.dart';

class StaffWorkspacePage extends StatefulWidget {
  const StaffWorkspacePage({
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
  State<StaffWorkspacePage> createState() => _StaffWorkspacePageState();
}

enum _StaffTab { profile, students, community }

class _StaffWorkspacePageState extends State<StaffWorkspacePage> with SyncRefresh<StaffWorkspacePage> {
  late final StaffSelfServiceRepository _repository;
  late final AdministratorStudentsRepository _students;
  _StaffTab _tab = _StaffTab.profile;
  int _pendingSyncCount = 0;

  @override
  void initState() {
    super.initState();
    _repository = StaffSelfServiceRepository(
      database: widget.localDatabase,
      session: widget.schoolSession,
    );
    _students = AdministratorStudentsRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _refreshPendingCount();
  }

  @override
  void onSynced() => _refreshPendingCount();

  void _refreshPendingCount() {
    final count = widget.localDatabase.pendingCount(tenantId: widget.membership.schoolId);
    if (mounted) setState(() => _pendingSyncCount = count);
  }

  Future<void> _openSyncCenter() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SyncCenterPage(localDatabase: widget.localDatabase, membership: widget.membership),
      ),
    );
    _refreshPendingCount();
  }

  /// A Staff login can hold extra roles the owner has appointed them to (see
  /// ExtraRolesSection) - for example a "director" appointment with the full
  /// Administrator or Principal workspace, not a cut-down copy of it. Those
  /// appear as ordinary additional memberships in the same session, switched
  /// to exactly the way every other role already switches between schools.
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
      _ => DashboardPage(
          membership: membership,
          localDatabase: widget.localDatabase,
          schoolSession: widget.schoolSession,
          schoolAppearance: widget.schoolAppearance,
        ),
    };
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) => StaffOnboardingBanner(
        repository: StaffOnboardingRepository(
          database: widget.localDatabase,
          session: widget.schoolSession,
          remote: StaffServerScope.maybeOf(context),
        ),
        child: _shell(),
      );

  List<Widget> _topActions() => [
        if (widget.schoolSession.canSwitchSchool)
          _SchoolSwitcherButton(memberships: widget.schoolSession.memberships, onSelected: _switchSchool),
        NotificationsBell(membership: widget.membership),
        IconButton(
          tooltip: _pendingSyncCount == 0 ? 'Sync Center' : 'Sync Center · $_pendingSyncCount pending',
          onPressed: _openSyncCenter,
          icon: Badge(
            isLabelVisible: _pendingSyncCount > 0,
            label: Text('$_pendingSyncCount'),
            child: const Icon(Icons.cloud_sync_outlined),
          ),
        ),
      ];

  Widget _shell() {
    final destinations = const [
      NavigationDestination(icon: Icon(Icons.badge_outlined), selectedIcon: Icon(Icons.badge_rounded), label: 'My Profile'),
      NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups_rounded), label: 'Students'),
      NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum_rounded), label: 'Community'),
    ];
    final content = switch (_tab) {
      _StaffTab.profile => _ProfileTab(repository: _repository),
      _StaffTab.students => _StudentsTab(repository: _students),
      _StaffTab.community => CommunityPage(
          schoolName: widget.membership.schoolName,
          repository: CommunityRepository(localDatabase: widget.localDatabase, schoolSession: widget.schoolSession),
          onBack: () => setState(() => _tab = _StaffTab.profile),
          onCommunityChanged: _refreshPendingCount,
        ),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (wide)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.membership.schoolName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    ..._topActions(),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Expanded(child: content),
          ],
        );
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    extended: constraints.maxWidth >= 1180,
                    selectedIndex: _tab.index,
                    onDestinationSelected: (index) => setState(() => _tab = _StaffTab.values[index]),
                    leading: const Padding(
                      padding: EdgeInsets.fromLTRB(12, 12, 12, 24),
                      child: Icon(Icons.badge_outlined),
                    ),
                    destinations: [
                      for (final item in destinations)
                        NavigationRailDestination(icon: item.icon, selectedIcon: item.selectedIcon, label: Text(item.label)),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: SafeArea(child: body)),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.membership.schoolName} · Staff'),
            actions: _topActions(),
          ),
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab.index,
            onDestinationSelected: (index) => setState(() => _tab = _StaffTab.values[index]),
            destinations: destinations,
          ),
        );
      },
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({required this.repository});
  final StaffSelfServiceRepository repository;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late Future<StaffProfileView?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadOwn();
  }

  void _reload() => setState(() => _future = widget.repository.loadOwn());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StaffProfileView?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final view = snapshot.data;
        if (snapshot.hasError || view == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Your employment record has not been linked to this login yet. Contact the school office.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }
        return _profile(view);
      },
    );
  }

  Widget _profile(StaffProfileView view) {
    final profile = view.profile;
    final person = view.person;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.all(constraints.maxWidth < 700 ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MY PROFILE', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
            const SizedBox(height: 5),
            Text(person.name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('${person.role} · ${person.section}'),
            const SizedBox(height: 18),
            _kpis(view),
            const SizedBox(height: 18),
            _personalCard(profile),
            const SizedBox(height: 16),
            _academicsCard(profile),
            const SizedBox(height: 16),
            _credentialsCard(profile),
            const SizedBox(height: 16),
            _documentsCard(profile),
            const SizedBox(height: 16),
            _reviewsCard(profile),
            const SizedBox(height: 16),
            _paymentCard(view),
            const SizedBox(height: 16),
            const Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Your bank account is the only thing here you can change yourself. Everything else is set by the school and kept accurate because you can see it.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpis(StaffProfileView view) {
    final profile = view.profile;
    final expiring = profile.credentials.where((c) => c.expiryDate != null && c.isExpired(DateTime.now())).length;
    final pendingDocs = profile.documents.where((d) => d.status != StaffDocumentStatus.verified).length;
    final tiles = <(String, String, String)>[
      ('Highest qualification', profile.highestLevel ?? '—', profile.academics.isEmpty ? 'None on file yet' : '${profile.academics.length} record(s)'),
      ('Credentials', '${profile.credentials.length}', expiring == 0 ? 'None expired' : '$expiring expired'),
      ('Documents', '$pendingDocs pending', profile.documents.isEmpty ? 'None requested' : '${profile.documents.length} required'),
      (
        'Attendance',
        view.attendanceRate == null ? '—' : '${view.attendanceRate!.round()}%',
        view.attendanceRate == null ? 'No attendance recorded yet' : 'this period',
      ),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final tile in tiles)
          SizedBox(
            width: 220,
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tile.$1),
                    const SizedBox(height: 5),
                    Text(tile.$2, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(tile.$3, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _personalCard(StaffProfile profile) {
    final p = profile.personal;
    final rows = <(String, String)>[
      ('Phone', p.phone),
      ('Email', p.email),
      ('Address', p.address),
      ('Date of birth', p.dateOfBirth),
      ('Gender', p.gender),
      ('State of origin', p.stateOfOrigin),
      ('Next of kin', p.nextOfKinName.isEmpty ? '' : '${p.nextOfKinName} · ${p.nextOfKinPhone}'),
      ('Employment date', p.employmentDate),
      ('Employment type', p.employmentType),
    ];
    return _sectionCard(
      title: 'Personal details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in rows)
            if (row.$2.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${row.$1}: ${row.$2}'),
              ),
          if (rows.every((row) => row.$2.isEmpty)) const Text('The school has not entered your details yet.'),
        ],
      ),
    );
  }

  Widget _academicsCard(StaffProfile profile) => _sectionCard(
        title: 'Academic records',
        child: profile.academics.isEmpty
            ? const Text('No academic records on file yet.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final record in profile.academics)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${record.level} · ${record.course}, ${record.institution} (${record.year})'),
                    ),
                ],
              ),
      );

  Widget _credentialsCard(StaffProfile profile) => _sectionCard(
        title: 'Credentials',
        child: profile.credentials.isEmpty
            ? const Text('No credentials on file yet.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final credential in profile.credentials)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${credential.title} · ${credential.issuer}'
                        '${credential.expiry.isEmpty ? '' : ' · expires ${credential.expiry}'}'
                        '${credential.verified ? ' · verified' : ' · not yet verified'}'
                        '${credential.isExpired(DateTime.now()) ? ' · EXPIRED' : ''}',
                      ),
                    ),
                ],
              ),
      );

  Widget _documentsCard(StaffProfile profile) => _sectionCard(
        title: 'Documents',
        child: profile.documents.isEmpty
            ? const Text('No documents requested yet.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final document in profile.documents)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${document.name}: ${_documentStatusLabel(document.status)}'),
                    ),
                ],
              ),
      );

  Widget _reviewsCard(StaffProfile profile) => _sectionCard(
        title: 'Performance reviews',
        child: profile.reviews.isEmpty
            ? const Text('No performance reviews recorded yet.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final review in profile.reviews.reversed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${review.period}: ${review.rating}/5${review.notes.isEmpty ? '' : ' · ${review.notes}'}'),
                    ),
                ],
              ),
      );

  Widget _paymentCard(StaffProfileView view) {
    final payment = view.profile.payment;
    return _sectionCard(
      title: 'Bank account for salary',
      trailing: TextButton(onPressed: () => _editPaymentAndReload(view), child: const Text('Edit')),
      child: payment.isEmpty
          ? const Text('You have not entered your bank details yet.')
          : Text('${payment.bankName} · ${payment.accountName} · ${payment.maskedAccountNumber}'),
    );
  }

  Future<void> _editPaymentAndReload(StaffProfileView view) async {
    final updated = await showDialog<StaffPaymentDetails>(
      context: context,
      builder: (context) => _PaymentDialog(current: view.profile.payment),
    );
    if (updated == null || !mounted) return;
    try {
      await widget.repository.saveOwnPayment(view.person.id, updated);
      _reload();
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Bank details saved and queued for synchronization.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Widget _sectionCard({required String title, required Widget child, Widget? trailing}) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                  if (trailing != null) trailing,
                ],
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      );

  String _documentStatusLabel(StaffDocumentStatus status) => switch (status) {
        StaffDocumentStatus.requested => 'Requested',
        StaffDocumentStatus.received => 'Received, awaiting verification',
        StaffDocumentStatus.verified => 'Verified',
      };
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.current});
  final StaffPaymentDetails current;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final _bank = TextEditingController(text: widget.current.bankName);
  late final _accountName = TextEditingController(text: widget.current.accountName);
  late final _accountNumber = TextEditingController(text: widget.current.accountNumber);
  String? _error;

  @override
  void dispose() {
    _bank.dispose();
    _accountName.dispose();
    _accountNumber.dispose();
    super.dispose();
  }

  void _submit() {
    if (_bank.text.trim().isEmpty || _accountName.text.trim().isEmpty) {
      setState(() => _error = 'Enter the bank and the account name.');
      return;
    }
    if (!RegExp(r'^\d{10}$').hasMatch(_accountNumber.text.trim())) {
      setState(() => _error = 'Enter a 10-digit account number.');
      return;
    }
    Navigator.of(context).pop(
      StaffPaymentDetails(
        bankName: _bank.text.trim(),
        accountName: _accountName.text.trim(),
        accountNumber: _accountNumber.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Bank account for salary'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _bank, decoration: const InputDecoration(labelText: 'Bank')),
              const SizedBox(height: 8),
              TextField(controller: _accountName, decoration: const InputDecoration(labelText: 'Account name')),
              const SizedBox(height: 8),
              TextField(
                controller: _accountNumber,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Account number (10 digits)'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: _submit, child: const Text('Save')),
        ],
      );
}

class _StudentsTab extends StatefulWidget {
  const _StudentsTab({required this.repository});
  final AdministratorStudentsRepository repository;

  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab> {
  late Future<AdministratorStudentsSnapshot> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdministratorStudentsSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load the student directory.'));
        }
        final students = snapshot.requireData.students.where((s) {
          if (_query.trim().isEmpty) return true;
          final q = _query.trim().toLowerCase();
          return s.name.toLowerCase().contains(q) || s.className.toLowerCase().contains(q);
        }).toList(growable: false);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student directory', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text(administratorStudentProfileBoundary),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(labelText: 'Search by name or class', prefixIcon: Icon(Icons.search)),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: students.isEmpty
                    ? const Center(child: Text('No students match.'))
                    : ListView.builder(
                        itemCount: students.length,
                        itemBuilder: (context, index) {
                          final student = students[index];
                          return ListTile(
                            title: Text(student.name),
                            subtitle: Text('${student.className} · ${student.status.label}'),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SchoolSwitcherButton extends StatelessWidget {
  const _SchoolSwitcherButton({required this.memberships, required this.onSelected});

  final List<SchoolMembership> memberships;
  final ValueChanged<SchoolMembership> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<SchoolMembership>(
        tooltip: 'Switch school or role',
        onSelected: onSelected,
        icon: const Icon(Icons.swap_horiz_rounded),
        itemBuilder: (_) => [
          for (final membership in memberships)
            PopupMenuItem(
              value: membership,
              child: Text('${membership.schoolName} · ${membership.roleLabel}'),
            ),
        ],
      );
}
