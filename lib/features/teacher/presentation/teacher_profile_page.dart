import 'package:flutter/material.dart';

import '../data/teacher_profile_policy_copy.dart';
import '../data/teacher_profile_repository.dart';
import '../domain/teacher_profile_models.dart';

class TeacherProfilePage extends StatefulWidget {
  const TeacherProfilePage({
    super.key,
    required this.repository,
    required this.onNavigate,
    required this.onMutationQueued,
  });

  final TeacherProfileDataSource repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback onMutationQueued;

  @override
  State<TeacherProfilePage> createState() => _TeacherProfilePageState();
}

class _TeacherProfilePageState extends State<TeacherProfilePage> {
  TeacherProfileSnapshot? _snapshot;
  TeacherProfileTab _tab = TeacherProfileTab.overview;
  int _payslipIndex = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.repository.load();
      if (mounted) setState(() => _snapshot = snapshot);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text('Could not load Teacher Profile: $_error'));
    }
    final snapshot = _snapshot;
    if (snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final profile = snapshot.profile;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _header(profile),
        const SizedBox(height: 16),
        _hero(profile),
        const SizedBox(height: 12),
        _tabs(),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final main = _tabBody(profile, snapshot.permissions);
            if (constraints.maxWidth < 980) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [main, const SizedBox(height: 14), _side(profile)],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: main),
                const SizedBox(width: 16),
                Expanded(child: _side(profile)),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _header(TeacherProfileSnapshotData profile) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TEACHER ACCOUNT · HR & PAYROLL PROFILE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Teacher Profile',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Employment, teaching assignments, salary, payslips and staff records.'),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => widget.onNavigate('dashboard'),
                child: const Text('Dashboard'),
              ),
              OutlinedButton(
                onPressed: profile.payslips.isEmpty
                    ? null
                    : () {
                        setState(() => _tab = TeacherProfileTab.payslips);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Payslip opened. Printing/export requires the authenticated platform print service; no print was falsely recorded.')),
                        );
                      },
                child: const Text('Open latest payslip'),
              ),
              FilledButton(
                onPressed: () => _editContact(profile.contact),
                child: Text(profile.contact.pendingSync ? 'Contact sync pending' : 'Edit self-service profile'),
              ),
            ],
          ),
        ],
      );

  Widget _hero(TeacherProfileSnapshotData profile) {
    final periodsPerWeek = profile.teachingLoad.length;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 18,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CircleAvatar(radius: 32, child: Text(_initials(profile.displayName))),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 260, maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.hasLinkedStaffRecord ? profile.staffId : 'Not yet linked to a staff record',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(profile.displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  Text([profile.jobTitle, profile.department, profile.campus].where((v) => v.isNotEmpty).join(' · ')),
                  const SizedBox(height: 8),
                  if (profile.hasLinkedStaffRecord)
                    Wrap(spacing: 6, children: [
                      if (profile.employmentType.isNotEmpty) Chip(label: Text(profile.employmentType)),
                    ]),
                ],
              ),
            ),
            _metric('Net salary', _money(profile.netMonthly)),
            _metric('Attendance', '${profile.attendance.presentPercent}%'),
            _metric('Classes taught', '$periodsPerWeek'),
          ],
        ),
      ),
    );
  }

  Widget _tabs() => Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final tab in TeacherProfileTab.values)
            ChoiceChip(
              label: Text(tab.label),
              selected: _tab == tab,
              onSelected: (_) => setState(() => _tab = tab),
            ),
        ],
      );

  Widget _tabBody(
    TeacherProfileSnapshotData p,
    TeacherProfilePermissions permissions,
  ) =>
      Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: switch (_tab) {
            TeacherProfileTab.overview => _overview(p),
            TeacherProfileTab.employment => _employment(p, permissions),
            TeacherProfileTab.qualifications => _qualifications(p),
            TeacherProfileTab.teachingLoad => _teachingLoad(p),
            TeacherProfileTab.attendance => _attendance(p),
            TeacherProfileTab.salary => _salary(p),
            TeacherProfileTab.payslips => _payslips(p),
            TeacherProfileTab.payments => _payments(p),
            TeacherProfileTab.documents => _documents(p),
            TeacherProfileTab.timeline => _timeline(p),
            TeacherProfileTab.security => _security(),
          },
        ),
      );

  Widget _overview(TeacherProfileSnapshotData p) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHead('Staff overview', 'Core identity, employment and payroll context.', 'Teacher self-service'),
          if (!p.hasLinkedStaffRecord)
            _boundary('This account has not yet been linked to a staff record. Identity, employment and payroll details appear here once HR/Administrator links it.')
          else ...[
            _infoGrid([
              ('Staff ID', p.staffId),
              ('Department', p.department),
              ('Job title', p.jobTitle),
              ('Hire date', p.hireDate.isEmpty ? 'Not recorded' : p.hireDate),
              ('Employment', p.employmentType.isEmpty ? 'Not recorded' : p.employmentType),
            ]),
            const SizedBox(height: 14),
            _infoGrid([
              ('Net monthly', _money(p.netMonthly)),
              ('Annual net', _money(p.annualNet)),
            ]),
          ],
          const SizedBox(height: 14),
          _boundary(teacherProfilePayrollBoundary),
        ],
      );

  Widget _employment(TeacherProfileSnapshotData p, TeacherProfilePermissions permissions) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHead('Employment record', 'Self-service contact details plus authoritative employment context.', 'HR record'),
          _infoGrid([
            ('Display name', p.displayName),
            ('Hire date', p.hireDate.isEmpty ? 'Not recorded' : p.hireDate),
            ('Phone', p.contact.phone),
            ('Email', p.contact.email),
            ('Address', p.contact.address),
            ('Next of kin', p.contact.nextOfKin),
            ('Emergency contact', p.contact.emergencyPhone),
            ('Campus', p.campus.isEmpty ? 'Not recorded' : p.campus),
          ]),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: permissions.canUpdateOwnContact ? () => _editContact(p.contact) : null,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit contact details'),
          ),
        ],
      );

  Widget _qualifications(TeacherProfileSnapshotData p) => p.qualifications.isEmpty
      ? _emptySection('Qualifications & professional record', 'No qualification or credential has been recorded for this staff member yet.')
      : _simpleRows(
          'Qualifications & professional record',
          'Verified qualifications, certifications and development activity.',
          'Evidence-based',
          p.qualifications,
        );

  Widget _teachingLoad(TeacherProfileSnapshotData p) => p.teachingLoad.isEmpty
      ? _emptySection('Teaching load', 'No class is currently assigned to this membership.')
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHead('Teaching load', 'Assignments are read-only here and controlled by authorized academic leadership.', '${p.teachingLoad.length} ${p.teachingLoad.length == 1 ? 'class' : 'classes'}'),
            ...p.teachingLoad.map((row) => _tripleRow(row.$1, row.$2, row.$3)),
          ],
        );

  Widget _attendance(TeacherProfileSnapshotData p) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHead('Attendance & leave', 'Operational attendance and approved leave record.', 'Current term'),
          _infoGrid([
            ('Attendance', '${p.attendance.presentPercent}%'),
            ('Late arrivals', '${p.attendance.lateArrivals}'),
            ('Approved leave', '${p.attendance.approvedLeaveDays} days'),
            ('Unapproved absence', '${p.attendance.unapprovedAbsence}'),
          ]),
          const SizedBox(height: 10),
          _boundary('Attendance may support operational follow-up, but should not be converted into an automatic employment decision or opaque staff score.'),
        ],
      );

  Widget _salary(TeacherProfileSnapshotData p) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHead('Salary', 'Net payroll amount and destination.', 'Confidential payroll'),
          _infoGrid([
            ('Net salary', _money(p.netMonthly)),
          ]),
          const SizedBox(height: 10),
          _boundary('Only net pay is recorded once payroll is prepared; an itemized gross/allowance/deduction breakdown is not tracked by this app.'),
          const SizedBox(height: 14),
          const Text('Payroll destination', style: TextStyle(fontWeight: FontWeight.w900)),
          _infoGrid([
            ('Bank / provider', p.bank.isEmpty ? 'Not recorded' : p.bank),
            ('Salary account', p.account.isEmpty ? 'Not recorded' : p.account),
          ]),
          const SizedBox(height: 12),
          _boundary(teacherProfilePayrollBoundary),
        ],
      );

  Widget _payslips(TeacherProfileSnapshotData p) {
    if (p.payslips.isEmpty) {
      return _emptySection('Payslips', 'No payroll batch has included this staff member yet.');
    }
    final slip = p.payslips[_payslipIndex.clamp(0, p.payslips.length - 1)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHead('Payslip', '${slip.period} · ${p.displayName} · ${p.staffId}', slip.status),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < p.payslips.length; i++)
              ChoiceChip(
                label: Text(p.payslips[i].period),
                selected: _payslipIndex == i,
                onSelected: (_) => setState(() => _payslipIndex = i),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(slip.reference, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        _infoGrid([
          ('Net pay', _money(slip.net)),
          ('Status', slip.status),
        ]),
        const SizedBox(height: 12),
        _boundary('Payslips are available after payroll disbursement is instructed. No itemized breakdown is tracked by this app.'),
      ],
    );
  }

  Widget _payments(TeacherProfileSnapshotData p) => p.payslips.isEmpty
      ? _emptySection('Salary payment history', 'No payroll batch has included this staff member yet.')
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHead('Salary payment history', 'Auditable payroll periods and net amounts received.', 'Payroll ledger'),
            ...p.payslips.map((slip) => _tripleRow(slip.period, slip.reference, '${_money(slip.net)} · ${slip.status}')),
          ],
        );

  Widget _documents(TeacherProfileSnapshotData p) => p.documents.isEmpty
      ? _emptySection('Staff documents', 'No document has been requested from this staff member yet.')
      : _simpleRows(
          'Staff documents',
          'Document references. Files are not available here.',
          'Restricted HR',
          p.documents,
        );

  Widget _timeline(TeacherProfileSnapshotData p) => p.timeline.isEmpty
      ? _emptySection('Staff timeline', 'No staff timeline event has been recorded yet.')
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHead('Staff timeline', 'Employment and payroll events this app can really track.', 'Audit-friendly'),
            ...p.timeline.map((row) => _tripleRow(row.$2, row.$3, row.$1)),
          ],
        );

  Widget _security() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHead('Security & sessions', 'Teacher-account security controls.', 'Not implemented'),
          _boundary(teacherProfileSecurityBoundary),
        ],
      );

  Widget _emptySection(String title, String message) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _boundary(message),
        ],
      );

  Widget _side(TeacherProfileSnapshotData p) => Column(
        children: [
          _sideCard('MONTHLY NET PAY', _money(p.netMonthly), 'Most recent real payroll period for this staff member.', p.payslips.isEmpty ? null : () => setState(() => _tab = TeacherProfileTab.payslips), p.payslips.isEmpty ? null : 'View payslip'),
          _sideCard('STAFF RECORD', '${p.profileCompleteness}%', 'Real share of requested staff documents marked verified.', null, null),
          _sideCard('PAYROLL PRIVACY', '', 'Salary, bank and deduction data should be visible only to the staff member and specifically authorized HR/finance roles.', null, null),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('CONNECTED WORK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  for (final item in teacherProfileConnectedWork)
                    TextButton(onPressed: () => widget.onNavigate(item.$2), child: Text(item.$1)),
                ],
              ),
            ),
          ),
        ],
      );

  Future<void> _editContact(TeacherProfileContact contact) async {
    final phone = TextEditingController(text: contact.phone);
    final email = TextEditingController(text: contact.email);
    final address = TextEditingController(text: contact.address);
    final nextOfKin = TextEditingController(text: contact.nextOfKin);
    final emergency = TextEditingController(text: contact.emergencyPhone);
    final result = await showDialog<TeacherProfileContact>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit self-service contact'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
                TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
                TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
                TextField(controller: nextOfKin, decoration: const InputDecoration(labelText: 'Next of kin')),
                TextField(controller: emergency, decoration: const InputDecoration(labelText: 'Emergency contact')),
                const SizedBox(height: 12),
                const Text('Staff ID, payroll, contract, teaching load and salary are not editable here.', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              TeacherProfileContact(
                phone: phone.text,
                email: email.text,
                address: address.text,
                nextOfKin: nextOfKin.text,
                emergencyPhone: emergency.text,
                version: contact.version,
              ),
            ),
            child: const Text('Save contact'),
          ),
        ],
      ),
    );
    // The dialog's exit transition is still animating and reading these controllers for a frame or two
    // after showDialog's future completes, so disposing them synchronously here throws "used after
    // disposed". Dispose after that frame instead.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      phone.dispose();
      email.dispose();
      address.dispose();
      nextOfKin.dispose();
      emergency.dispose();
    });
    if (result == null || !mounted) return;
    final saved = await widget.repository.saveContact(result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved.message)));
    if (saved.success) {
      widget.onMutationQueued();
      await _load();
    }
  }

  Widget _sectionHead(String title, String copy, String badge) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  Text(copy),
                ],
              ),
            ),
            Chip(label: Text(badge)),
          ],
        ),
      );

  Widget _simpleRows(String title, String copy, String badge, List<(String, String, String)> rows) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHead(title, copy, badge),
          ...rows.map((row) => _tripleRow(row.$1, row.$2, row.$3)),
        ],
      );

  Widget _tripleRow(String title, String subtitle, String trailing) => Card(
        elevation: 0,
        child: ListTile(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(trailing, textAlign: TextAlign.right),
          ),
        ),
      );

  Widget _infoGrid(List<(String, String)> rows) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final row in rows)
            SizedBox(
              width: 220,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.$1, style: const TextStyle(fontSize: 11)),
                      const SizedBox(height: 3),
                      Text(row.$2, style: const TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );

  Widget _metric(String label, String value) => SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(label, style: const TextStyle(fontSize: 11)), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))],
        ),
      );

  Widget _boundary(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text),
      );

  Widget _sideCard(String label, String value, String copy, VoidCallback? action, String? actionLabel) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              if (value.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ],
              const SizedBox(height: 5),
              Text(copy),
              if (action != null && actionLabel != null) ...[
                const SizedBox(height: 8),
                OutlinedButton(onPressed: action, child: Text(actionLabel)),
              ],
            ],
          ),
        ),
      );

  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'T';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return (words.first.substring(0, 1) + words.last.substring(0, 1)).toUpperCase();
  }

  String _money(int value) {
    final digits = value.toString();
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return '₦$out';
  }
}
