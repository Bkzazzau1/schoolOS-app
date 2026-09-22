import 'package:flutter/material.dart';

import '../data/teacher_profile_demo_data.dart';
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
                Text('Employment, teaching assignments, salary, deductions, loans, payslips and staff records.'),
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
                onPressed: () {
                  setState(() => _tab = TeacherProfileTab.payslips);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payslip opened. Printing/export requires the authenticated platform print service; no print was falsely recorded.')),
                  );
                },
                child: const Text('Print current payslip'),
              ),
              FilledButton(
                onPressed: () => _editContact(profile.contact),
                child: Text(profile.contact.pendingSync ? 'Contact sync pending' : 'Edit self-service profile'),
              ),
            ],
          ),
        ],
      );

  Widget _hero(TeacherProfileSnapshotData profile) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            spacing: 18,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const CircleAvatar(radius: 32, child: Text('AY')),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 260, maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${profile.staffId} · ${profile.payrollId}', style: const TextStyle(fontSize: 12)),
                    Text(profile.displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    Text('${profile.jobTitle} · ${profile.department} · ${profile.campus}'),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, children: [
                      Chip(label: Text(profile.employmentStatus)),
                      Chip(label: Text(profile.employmentType)),
                      const Chip(label: Text('Payroll active')),
                    ]),
                  ],
                ),
              ),
              _metric('Net salary', _money(profile.netMonthly)),
              _metric('Attendance', '${teacherProfileAttendance.attendance}%'),
              _metric('Loan balance', _money(teacherProfileLoanBalance)),
            ],
          ),
        ),
      );

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
            TeacherProfileTab.qualifications => _qualifications(),
            TeacherProfileTab.teachingLoad => _teachingLoad(),
            TeacherProfileTab.attendance => _attendance(),
            TeacherProfileTab.salary => _salary(p),
            TeacherProfileTab.payslips => _payslips(p),
            TeacherProfileTab.deductions => _deductions(p),
            TeacherProfileTab.loans => _loans(),
            TeacherProfileTab.payments => _payments(p),
            TeacherProfileTab.documents => _documents(),
            TeacherProfileTab.timeline => _timeline(),
            TeacherProfileTab.security => _security(),
          },
        ),
      );

  Widget _overview(TeacherProfileSnapshotData p) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHead('Staff overview', 'Core identity, employment and payroll context.', 'Teacher self-service'),
          _infoGrid([
            ('Staff ID', p.staffId),
            ('Payroll ID', p.payrollId),
            ('Department', p.department),
            ('Job title', p.jobTitle),
            ('Hire date', p.hireDate),
            ('Employment', p.employmentType),
          ]),
          const SizedBox(height: 14),
          _infoGrid([
            ('Gross monthly', _money(p.grossMonthly)),
            ('Total deductions', _money(p.monthlyDeductions)),
            ('Net monthly', _money(p.netMonthly)),
            ('Annual gross', _money(p.annualGross)),
          ]),
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
            ('Employment status', p.employmentStatus),
            ('Hire date', p.hireDate),
            ('Phone', p.contact.phone),
            ('Email', p.contact.email),
            ('Address', p.contact.address),
            ('Next of kin', p.contact.nextOfKin),
            ('Emergency contact', p.contact.emergencyPhone),
            ('Campus', p.campus),
          ]),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: permissions.canUpdateOwnContact ? () => _editContact(p.contact) : null,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit contact details'),
          ),
          const SizedBox(height: 12),
          _boundary(teacherProfileAuthorityBoundary),
        ],
      );

  Widget _qualifications() => _simpleRows(
        'Qualifications & professional record',
        'Verified qualifications, certifications and development activity.',
        'Evidence-based',
        teacherProfileQualifications,
      );

  Widget _teachingLoad() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHead('Teaching load', 'Assignments are read-only here and controlled by authorized academic leadership.', '28 periods / week'),
          ...teacherProfileTeachingLoad.map((row) => _tripleRow(row.$1, row.$2, row.$3)),
          const SizedBox(height: 10),
          _boundary('Teaching assignments cannot be changed from Teacher Profile. Academic leadership remains authoritative.'),
        ],
      );

  Widget _attendance() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHead('Attendance & leave', 'Operational attendance and approved leave record.', 'Current term'),
          _infoGrid([
            ('Attendance', '${teacherProfileAttendance.attendance}%'),
            ('Late arrivals', '${teacherProfileAttendance.lateArrivals}'),
            ('Approved leave', '${teacherProfileAttendance.approvedLeaveDays} days'),
            ('Unapproved absence', '${teacherProfileAttendance.unapprovedAbsence}'),
          ]),
          const SizedBox(height: 14),
          const Text('Leave history', style: TextStyle(fontWeight: FontWeight.w900)),
          ...teacherProfileLeaveHistory.map((row) => _tripleRow(row.$1, row.$2, row.$3)),
          const SizedBox(height: 10),
          _boundary('Attendance may support operational follow-up, but should not be converted into an automatic employment decision or opaque staff score.'),
        ],
      );

  Widget _salary(TeacherProfileSnapshotData p) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHead('Salary structure', 'Current monthly payroll composition.', 'Confidential payroll'),
          _infoGrid([
            ('Basic salary', _money(p.payslips.first.basic)),
            ('Total allowances', _money(65000)),
            ('Gross salary', _money(p.grossMonthly)),
            ('Net salary', _money(p.netMonthly)),
          ]),
          const SizedBox(height: 14),
          const Text('Allowances', style: TextStyle(fontWeight: FontWeight.w900)),
          ...teacherProfileAllowances.map((row) => _pairRow(row.$1, _money(row.$2))),
          const SizedBox(height: 14),
          const Text('Payroll destination', style: TextStyle(fontWeight: FontWeight.w900)),
          _infoGrid([
            ('Bank / provider', p.bank),
            ('Salary account', p.account),
            ('Pension ID', p.pensionId),
            ('Tax ID', p.taxId),
          ]),
          const SizedBox(height: 12),
          _boundary(teacherProfilePayrollBoundary),
        ],
      );

  Widget _payslips(TeacherProfileSnapshotData p) {
    final slip = p.payslips[_payslipIndex.clamp(0, p.payslips.length - 1)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHead('BrightGate Academy · Payslip', '${slip.month} · ${p.displayName} · ${p.staffId}', slip.status),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < p.payslips.length; i++)
              ChoiceChip(
                label: Text(p.payslips[i].month),
                selected: _payslipIndex == i,
                onSelected: (_) => setState(() => _payslipIndex = i),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(slip.reference, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        _infoGrid([
          ('Basic salary', _money(slip.basic)),
          ('Housing', _money(slip.housing)),
          ('Transport', _money(slip.transport)),
          ('Responsibility', _money(slip.responsibility)),
          ('Gross', _money(slip.gross)),
          ('Pension', _money(slip.pension)),
          ('PAYE / Tax', _money(slip.tax)),
          ('Loan repayment', _money(slip.loan)),
          ('Other', _money(slip.other)),
          ('Total deductions', _money(slip.deductions)),
          ('Net pay', _money(slip.net)),
        ]),
        const SizedBox(height: 12),
        _boundary('Production payslips require payroll approval, immutable payroll reference, payment date and audit history. Local display never changes payroll status.'),
      ],
    );
  }

  Widget _deductions(TeacherProfileSnapshotData p) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHead('Deductions', 'Every deduction should be named, traceable and visible to the staff member.', '${_money(p.monthlyDeductions)} this month'),
          ...teacherProfileDeductions.map((row) => _tripleRow(row.$1, row.$3, _money(row.$2))),
          const SizedBox(height: 10),
          _boundary('No unexplained payroll deduction should be hidden inside a combined number. Adjustments, reversals and arrears need their own ledger entries.'),
        ],
      );

  Widget _loans() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHead('Staff loans & salary advances', 'Approved facilities, repayment schedule and outstanding amount.', 'Human approval required'),
          _boundary('ACTIVE STAFF LOAN · STL-26014\n${_money(teacherProfileLoanBalance)} outstanding · Original principal ${_money(teacherProfileLoanPrincipal)} · Monthly payroll repayment ${_money(teacherProfileLoanMonthlyRepayment)} · Expected completion $teacherProfileLoanCompletion'),
          const SizedBox(height: 10),
          ...teacherProfileLoanHistory.map((row) => _tripleRow('${row.$1} · ${row.$2}', '${_money(row.$3)} payroll repayment', '${_money(row.$4)} balance · ${row.$5}')),
          const SizedBox(height: 10),
          _boundary('Loan applications remain separate from teacher-performance metrics. SchoolOS must not infer creditworthiness from teaching performance or student results.'),
        ],
      );

  Widget _payments(TeacherProfileSnapshotData p) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHead('Salary payment history', 'Auditable payroll payments and net amounts received.', 'Payroll ledger'),
          ...p.payslips.map((slip) => _tripleRow('${slip.month} · ${slip.reference}', 'Gross ${_money(slip.gross)} · Deductions ${_money(slip.deductions)}', '${_money(slip.net)} · ${slip.status}')),
        ],
      );

  Widget _documents() => _simpleRows(
        'Staff documents',
        'Document labels only in this UI prototype.',
        'Restricted HR',
        teacherProfileDocuments,
      );

  Widget _timeline() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHead('Staff timeline', 'Employment, payroll and professional-development events.', 'Audit-friendly'),
          ...teacherProfileTimeline.map((row) => _tripleRow(row.$2, row.$3, row.$1)),
        ],
      );

  Widget _security() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHead('Security & sessions', 'Teacher-account security controls.', 'Self-service'),
          for (final row in teacherProfileSecurityRows)
            Card(
              elevation: 0,
              child: ListTile(
                title: Text(row.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(row.$2),
                trailing: OutlinedButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${row.$3} requires the authenticated account-security service. No security state was changed offline.')),
                  ),
                  child: Text(row.$3),
                ),
              ),
            ),
          const SizedBox(height: 10),
          _boundary(teacherProfileSecurityBoundary),
        ],
      );

  Widget _side(TeacherProfileSnapshotData p) => Column(
        children: [
          _sideCard('MONTHLY NET PAY', _money(p.netMonthly), 'Current mock payroll after pension, tax, loan and other deductions.', () => setState(() => _tab = TeacherProfileTab.payslips), 'View payslip'),
          _sideCard('ACTIVE LOAN', _money(teacherProfileLoanBalance), '${_money(teacherProfileLoanMonthlyRepayment)} monthly payroll repayment. Expected completion $teacherProfileLoanCompletion.', () => setState(() => _tab = TeacherProfileTab.loans), 'Open loan ledger'),
          _sideCard('STAFF RECORD', '$teacherProfileCompleteness%', 'Mock profile completeness across HR, payroll, qualifications and assignments.', null, null),
          _sideCard('PAYROLL PRIVACY', '', 'Salary, bank, loan and deduction data should be visible only to the staff member and specifically authorized HR/finance roles.', null, null),
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

  Widget _pairRow(String title, String value) => ListTile(
        dense: true,
        title: Text(title),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
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
