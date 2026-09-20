import 'package:flutter/material.dart';

import '../../administrator/domain/administrator_staff_models.dart';
import '../data/owner_staff_profile_repository.dart';
import '../data/staff_identity.dart';
import '../data/staff_proposal_repository.dart';
import '../domain/owner_staff_profile_models.dart';
import 'staff_proposals_ui.dart';

/// Staff list. Selecting a person opens their full record.
class OwnerStaffProfilesPage extends StatefulWidget {
  const OwnerStaffProfilesPage({
    super.key,
    required this.repository,
    required this.onChanged,
    this.proposals,
  });

  final OwnerStaffProfileRepository repository;
  final VoidCallback onChanged;

  /// When given, shows staff proposals and lets people propose new staff.
  final StaffProposalRepository? proposals;

  @override
  State<OwnerStaffProfilesPage> createState() => _OwnerStaffProfilesPageState();
}

class _OwnerStaffProfilesPageState extends State<OwnerStaffProfilesPage> {
  List<AdministratorStaffRecord> _people = const [];
  List<StaffDuplicateGroup> _duplicates = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final people = await widget.repository.people();
      final duplicates = await findStaffDuplicateGroups(
        widget.repository.database,
        widget.repository.session.requireActiveMembership().schoolId,
      );
      if (mounted) {
        setState(() {
          _people = people;
          _duplicates = duplicates;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Staff Profiles', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Full record for each staff member. What you can see depends on your role. The owner and principal can edit records and add reviews.',
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        const SizedBox(height: 12),
        if (_duplicates.isNotEmpty)
          Card(
            color: theme.colorScheme.errorContainer,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Possible duplicate staff',
                    style: theme.textTheme.titleLarge,
                  ),
                  const Text(
                    'Each staff member has their own phone number and NIN. These records share one, so one of them may be a duplicate or a mistake.',
                  ),
                  for (final group in _duplicates)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Same ${group.field} (${group.value}): '
                        '${group.people.map((p) => p.name).join(', ')}',
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (widget.proposals != null)
          StaffProposalsPanel(
            repository: widget.proposals!,
            onChanged: widget.onChanged,
            onStaffAdded: _load,
          ),
        for (final person in _people)
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(person.name),
              subtitle: Text('${person.role} · ${person.section}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OwnerStaffProfileDetailPage(
                      repository: widget.repository,
                      person: person,
                      onChanged: widget.onChanged,
                    ),
                  ),
                );
              },
            ),
          ),
        if (!_loading && _people.isEmpty)
          const Text('No staff records yet.'),
      ],
    );
  }
}

class OwnerStaffProfileDetailPage extends StatefulWidget {
  const OwnerStaffProfileDetailPage({
    super.key,
    required this.repository,
    required this.person,
    required this.onChanged,
  });

  final OwnerStaffProfileRepository repository;
  final AdministratorStaffRecord person;
  final VoidCallback onChanged;

  @override
  State<OwnerStaffProfileDetailPage> createState() =>
      _OwnerStaffProfileDetailPageState();
}

class _OwnerStaffProfileDetailPageState
    extends State<OwnerStaffProfileDetailPage> {
  StaffProfileView? _view;
  String? _error;
  bool _busy = true;

  String get _id => widget.person.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final view = await widget.repository.view(widget.person);
      if (mounted) setState(() => _view = view);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      widget.onChanged();
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _busy = false;
        });
      }
    }
  }

  Future<Map<String, String>?> _form(
    String title,
    Map<String, String> fields, {
    Map<String, String> initial = const {},
    String? dropdownKey,
    List<String> dropdownItems = const [],
  }) async {
    final controllers = {
      for (final f in fields.keys)
        f: TextEditingController(text: initial[f] ?? ''),
    };
    String? dropdown = dropdownKey == null ? null : initial[dropdownKey];
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dropdownKey != null)
                    DropdownButtonFormField<String>(
                      initialValue: dropdown,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: fields[dropdownKey] ?? dropdownKey,
                      ),
                      items: [
                        for (final item in dropdownItems)
                          DropdownMenuItem(value: item, child: Text(item)),
                      ],
                      onChanged: (v) => setLocal(() => dropdown = v),
                    ),
                  for (final entry in fields.entries)
                    if (entry.key != dropdownKey)
                      TextField(
                        controller: controllers[entry.key],
                        decoration: InputDecoration(labelText: entry.value),
                      ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                for (final e in controllers.entries) e.key: e.value.text.trim(),
                if (dropdownKey != null) dropdownKey: dropdown ?? '',
              }),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    for (final c in controllers.values) {
      c.dispose();
    }
    return result;
  }

  Future<void> _editPersonal(StaffPersonalInfo p) async {
    final r = await _form(
      'Personal information',
      const {
        'phone': 'Phone (unique to this person)',
        'nin': 'NIN, 11 digits (unique to this person)',
        'email': 'Email',
        'address': 'Home address',
        'dateOfBirth': 'Date of birth (yyyy-mm-dd)',
        'gender': 'Gender',
        'stateOfOrigin': 'State of origin',
        'nextOfKinName': 'Next of kin name',
        'nextOfKinPhone': 'Next of kin phone',
        'employmentDate': 'Employment date (yyyy-mm-dd)',
        'employmentType': 'Employment type (e.g. Full-time, Contract)',
      },
      initial: {for (final e in p.toJson().entries) e.key: '${e.value}'},
    );
    if (r == null) return;
    await _run(
      () => widget.repository.savePersonal(
        _id,
        StaffPersonalInfo(
          phone: r['phone']!,
          nin: r['nin']!,
          email: r['email']!,
          address: r['address']!,
          dateOfBirth: r['dateOfBirth']!,
          gender: r['gender']!,
          stateOfOrigin: r['stateOfOrigin']!,
          nextOfKinName: r['nextOfKinName']!,
          nextOfKinPhone: r['nextOfKinPhone']!,
          employmentDate: r['employmentDate']!,
          employmentType: r['employmentType']!,
        ),
      ),
    );
  }

  Future<void> _addAcademic() async {
    final r = await _form(
      'Add academic record',
      const {
        'level': 'Level of study',
        'institution': 'Institution',
        'course': 'Course / field',
        'year': 'Year completed',
        'grade': 'Grade / class (optional)',
      },
      dropdownKey: 'level',
      dropdownItems: studyLevels,
    );
    if (r == null) return;
    await _run(
      () => widget.repository.addAcademic(
        _id,
        StaffAcademicRecord(
          level: r['level']!,
          institution: r['institution']!,
          course: r['course']!,
          year: int.tryParse(r['year']!) ?? 0,
          grade: r['grade']!,
        ),
      ),
    );
  }

  Future<void> _addCredential() async {
    final r = await _form('Add credential', const {
      'title': 'Credential (e.g. TRCN licence, NIN, passport)',
      'issuer': 'Issued by',
      'number': 'Number / reference',
      'expiry': 'Expiry date (yyyy-mm-dd, blank if none)',
      'documentRef': 'Where the original is kept',
    });
    if (r == null) return;
    await _run(
      () => widget.repository.addCredential(
        _id,
        StaffCredential(
          title: r['title']!,
          issuer: r['issuer']!,
          number: r['number']!,
          expiry: r['expiry']!,
          documentRef: r['documentRef']!,
        ),
      ),
    );
  }

  Future<void> _editDocument(int index, StaffRequiredDocument doc) async {
    var status = doc.status;
    final reference = TextEditingController(text: doc.reference);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(doc.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<StaffDocumentStatus>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  for (final s in StaffDocumentStatus.values)
                    DropdownMenuItem(value: s, child: Text(_statusLabel(s))),
                ],
                onChanged: (v) => setLocal(() => status = v ?? status),
              ),
              TextField(
                controller: reference,
                decoration: const InputDecoration(
                  labelText: 'Where the original is kept',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final ref = reference.text;
    reference.dispose();
    if (saved != true) return;
    await _run(
      () => widget.repository.updateDocument(_id, index, status, ref),
    );
  }

  Future<void> _addDocument() async {
    final r = await _form('Add required document', const {'name': 'Document'});
    if (r == null) return;
    await _run(() => widget.repository.addDocument(_id, r['name']!));
  }

  Future<void> _requestOnboarding(String currentEmail) async {
    final r = await _form(
      'Send onboarding request',
      const {'email': 'Staff email address'},
      initial: {'email': currentEmail},
    );
    if (r == null) return;
    await _run(() => widget.repository.requestOnboarding(_id, r['email']!));
  }

  static String _statusLabel(StaffDocumentStatus s) => switch (s) {
    StaffDocumentStatus.requested => 'Requested',
    StaffDocumentStatus.received => 'Received',
    StaffDocumentStatus.verified => 'Verified',
  };

  Widget _onboarding(StaffProfileView view) {
    final p = view.profile;
    final status = switch (p.onboardingStatus) {
      StaffOnboardingStatus.none => 'No onboarding request has been sent.',
      StaffOnboardingStatus.invitePending =>
        'Onboarding request queued for ${p.onboardingEmail.isEmpty ? 'the staff member' : p.onboardingEmail}. It has not been confirmed as delivered, and no submission has been received.',
      StaffOnboardingStatus.submitted =>
        'The staff member has submitted their details. Review them below.',
      StaffOnboardingStatus.reviewed => 'Onboarding reviewed.',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Onboarding', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(status),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (view.access.canInvite)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _requestOnboarding(p.onboardingEmail),
                    icon: const Icon(Icons.forward_to_inbox_outlined, size: 18),
                    label: Text(
                      p.onboardingStatus == StaffOnboardingStatus.none
                          ? 'Send onboarding request'
                          : 'Resend request',
                    ),
                  ),
                if (view.access.canEdit &&
                    p.onboardingStatus != StaffOnboardingStatus.reviewed &&
                    p.onboardingStatus != StaffOnboardingStatus.none)
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => widget.repository.markOnboardingReviewed(_id),
                          ),
                    child: const Text('Mark as reviewed'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _payment(StaffPaymentDetails p) => _section('Payment details', [
    const Text(
      'Read only. Only the staff member can add or change their bank details, from their own account.',
    ),
    _kv('Bank', p.bankName),
    _kv('Account name', p.accountName),
    _kv('Account number', p.accountNumber),
  ]);

  Widget _documents(StaffProfile p) => _section(
    'Required documents',
    [
      const Text(
        'Tracks what has been received and where each original is kept. Files are not stored in the app yet.',
      ),
      if (p.documents.isEmpty) const Text('No documents requested yet.'),
      for (var i = 0; i < p.documents.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(p.documents[i].name),
          subtitle: Text(
            '${_statusLabel(p.documents[i].status)}'
            '${p.documents[i].reference.isEmpty ? '' : ' · Kept: ${p.documents[i].reference}'}',
          ),
          trailing: (_view?.access.canEdit ?? false)
              ? TextButton(
                  onPressed: _busy
                      ? null
                      : () => _editDocument(i, p.documents[i]),
                  child: const Text('Update'),
                )
              : null,
        ),
    ],
    action: TextButton.icon(
      onPressed: _busy ? null : _addDocument,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Add'),
    ),
  );

  Future<void> _addReview() async {
    final r = await _form('Add performance review', const {
      'period': 'Review period (e.g. Term 1 2026/27)',
      'rating': 'Rating 1 to 5',
      'notes': 'Notes',
    });
    if (r == null) return;
    await _run(
      () => widget.repository.addReview(
        _id,
        r['period']!,
        int.tryParse(r['rating']!) ?? 0,
        r['notes']!,
      ),
    );
  }

  Widget _section(
    String title,
    List<Widget> children, {
    Widget? action,
    bool reviewAction = false,
  }) {
    final access = _view?.access;
    final allowed = reviewAction
        ? (access?.canReview ?? false)
        : (access?.canEdit ?? false);
    action = allowed ? action : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (action != null) action,
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _kv(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 170, child: Text(label)),
        Expanded(
          child: Text(
            value.isEmpty ? 'Not recorded' : value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _metric(String label, String value, String hint) => SizedBox(
    width: 210,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(hint, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final view = _view;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.person.name)),
      body: view == null
          ? Center(
              child: _error != null
                  ? Text(_error!)
                  : const CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                Text(
                  '${widget.person.role} · ${widget.person.section} · ${widget.person.id}',
                ),
                const SizedBox(height: 12),
                _summary(view),
                const SizedBox(height: 16),
                if (view.access.canInvite || view.access.personal)
                  _onboarding(view),
                if (view.access.personal) _personal(view.profile.personal),
                if (view.access.academics) _academics(view.profile),
                if (view.access.credentials) _documents(view.profile),
                if (view.access.credentials) _credentials(view.profile),
                if (view.access.payment) _payment(view.profile.payment),
                if (view.access.performance || view.access.attendance)
                  _performance(view),
              ],
            ),
    );
  }

  Widget _summary(StaffProfileView view) {
    final p = view.profile;
    final rate = view.attendanceRate;
    final a = view.attendance;
    final access = view.access;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (access.academics)
          _metric(
            'Highest level of study',
            p.highestLevel ?? 'Not recorded',
            '${p.academics.length} academic record(s)',
          ),
        if (access.attendance)
          _metric(
            'Attendance rate',
            rate == null ? 'No data' : '${rate.toStringAsFixed(1)}%',
            a == null
                ? 'No attendance recorded'
                : '${a.present} of ${a.expected} days · ${a.late} late · ${a.unexplained} unexplained',
          ),
        if (access.performance)
          _metric(
            'Performance',
            p.averageRating == null
                ? 'No reviews'
                : '${p.averageRating!.toStringAsFixed(1)} / 5',
            '${p.reviews.length} review(s)',
          ),
        if (access.credentials)
          _metric(
            'Credentials',
            '${p.credentials.where((c) => c.verified).length} / ${p.credentials.length}',
            'verified',
          ),
      ],
    );
  }

  Widget _personal(StaffPersonalInfo p) => _section(
    'Personal information',
    [
      _kv('Phone', p.phone),
      _kv('NIN', p.nin),
      _kv('Email', p.email),
      _kv('Home address', p.address),
      _kv('Date of birth', p.dateOfBirth),
      _kv('Gender', p.gender),
      _kv('State of origin', p.stateOfOrigin),
      _kv('Next of kin', p.nextOfKinName),
      _kv('Next of kin phone', p.nextOfKinPhone),
      _kv('Employment date', p.employmentDate),
      _kv('Employment type', p.employmentType),
    ],
    action: TextButton.icon(
      onPressed: _busy ? null : () => _editPersonal(p),
      icon: const Icon(Icons.edit_outlined, size: 18),
      label: const Text('Edit'),
    ),
  );

  Widget _academics(StaffProfile p) => _section(
    'Academic records',
    [
      if (p.academics.isEmpty) const Text('No academic records yet.'),
      for (var i = 0; i < p.academics.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${p.academics[i].level} · ${p.academics[i].course}'),
          subtitle: Text(
            '${p.academics[i].institution} · ${p.academics[i].year}'
            '${p.academics[i].grade.isEmpty ? '' : ' · ${p.academics[i].grade}'}',
          ),
          trailing: IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline),
            onPressed: _busy
                ? null
                : () => _run(() => widget.repository.removeAcademic(_id, i)),
          ),
        ),
    ],
    action: TextButton.icon(
      onPressed: _busy ? null : _addAcademic,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Add'),
    ),
  );

  Widget _credentials(StaffProfile p) {
    final now = DateTime.now();
    return _section(
      'Credentials',
      [
        const Text(
          'Details of each credential are stored. Scanned copies are not stored in the app yet, so note where the original is kept.',
        ),
        if (p.credentials.isEmpty) const Text('No credentials recorded.'),
        for (var i = 0; i < p.credentials.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            isThreeLine: true,
            title: Text(
              '${p.credentials[i].title} · ${p.credentials[i].issuer}',
            ),
            subtitle: Text(
              [
                if (p.credentials[i].number.isNotEmpty)
                  'No. ${p.credentials[i].number}',
                if (p.credentials[i].expiry.isNotEmpty)
                  p.credentials[i].isExpired(now)
                      ? 'EXPIRED ${p.credentials[i].expiry}'
                      : 'Expires ${p.credentials[i].expiry}',
                if (p.credentials[i].documentRef.isNotEmpty)
                  'Kept: ${p.credentials[i].documentRef}',
                p.credentials[i].verified ? 'Verified' : 'Not yet verified',
              ].join(' · '),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: p.credentials[i].verified,
                  onChanged: _busy
                      ? null
                      : (v) => _run(
                          () => widget.repository.setCredentialVerified(
                            _id,
                            i,
                            v ?? false,
                          ),
                        ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => widget.repository.removeCredential(_id, i),
                        ),
                ),
              ],
            ),
          ),
      ],
      action: TextButton.icon(
        onPressed: _busy ? null : _addCredential,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add'),
      ),
    );
  }

  Widget _performance(StaffProfileView view) {
    final p = view.profile;
    final a = view.attendance;
    return _section(
      view.access.performance && view.access.attendance
          ? 'Performance & attendance'
          : view.access.performance
              ? 'Performance'
              : 'Attendance',
      [
        if (view.access.attendance && a != null) ...[
          _kv('Expected days', '${a.expected}'),
          _kv('Present', '${a.present}'),
          _kv('Approved leave', '${a.leave}'),
          _kv('Late', '${a.late}'),
          _kv('Unexplained absence', '${a.unexplained}'),
          const Divider(),
        ],
        if (view.access.performance && p.reviews.isEmpty)
          const Text('No performance reviews yet. Reviews are append-only.'),
        for (final r in p.reviews.reversed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${r.period} · ${r.rating} / 5'),
            subtitle: r.notes.isEmpty ? null : Text(r.notes),
          ),
      ],
      reviewAction: true,
      action: TextButton.icon(
        onPressed: _busy ? null : _addReview,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add review'),
      ),
    );
  }
}
