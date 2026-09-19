import 'package:flutter/material.dart';

import '../data/principal_teachers_demo_data.dart';
import '../data/principal_teachers_repository.dart';
import '../domain/principal_teachers_models.dart';

class PrincipalTeacherProfilePage extends StatefulWidget {
  const PrincipalTeacherProfilePage({
    super.key,
    required this.profile,
    required this.repository,
    required this.initialNote,
    required this.onActionRequested,
    required this.onQueuedForSync,
  });

  final PrincipalTeacherProfile profile;
  final PrincipalTeachersRepository repository;
  final String initialNote;
  final ValueChanged<String> onActionRequested;
  final VoidCallback onQueuedForSync;

  @override
  State<PrincipalTeacherProfilePage> createState() => _PrincipalTeacherProfilePageState();
}

class _PrincipalTeacherProfilePageState extends State<PrincipalTeacherProfilePage> {
  int _tabIndex = 0;
  late final TextEditingController _noteController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    setState(() => _saving = true);
    final result = await widget.repository.savePrivateNote(
      teacherId: widget.profile.directoryId,
      text: _noteController.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.success) widget.onQueuedForSync();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  void _openWorkspace(String key) {
    Navigator.of(context).pop();
    widget.onActionRequested(key);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(profile.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('${profile.jobTitle} · ${profile.campus}', style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _openWorkspace('communication'),
            icon: const Icon(Icons.message_outlined),
            label: const Text('Message teacher'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('PRINCIPAL · SECONDARY · STAFF PROFILE', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            _ProfileHero(profile: profile),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                segments: [
                  for (var i = 0; i < principalStaffProfileTabs.length; i++)
                    ButtonSegment(value: i, label: Text(principalStaffProfileTabs[i])),
                ],
                selected: {_tabIndex},
                onSelectionChanged: (value) => setState(() => _tabIndex = value.first),
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final content = _tabContent(context, profile);
                final side = _ProfileSide(profile: profile);
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Expanded(flex: 3, child: content), const SizedBox(width: 16), Expanded(child: side)],
                      )
                    : Column(children: [content, const SizedBox(height: 16), side]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabContent(BuildContext context, PrincipalTeacherProfile p) {
    switch (_tabIndex) {
      case 0:
        return _SectionCard(
          title: 'Staff overview',
          subtitle: 'Employment and teaching context available to section leadership.',
          children: [
            _InfoGrid(items: {
              'Staff ID': p.staffId,
              'Payroll status': 'Active · detail restricted',
              'Department': p.department,
              'Job title': p.jobTitle,
              'Hire date': p.hireDate,
              'Employment': p.employmentType,
            }),
            _Callout(label: 'Leadership support note', text: p.supportNote),
            const _Boundary(text: principalTeacherPayrollBoundary),
          ],
        );
      case 1:
        return _SectionCard(
          title: 'Employment record',
          subtitle: 'Core HR context visible to authorized section leadership.',
          children: [
            _InfoGrid(items: {
              'Status': p.employmentStatus,
              'Hire date': p.hireDate,
              'Phone': p.phone,
              'Email': p.email,
              'Next of kin': p.nextOfKin,
              'Emergency contact': p.emergencyPhone,
            }),
          ],
        );
      case 2:
        return _SectionCard(
          title: 'Qualifications & professional standing',
          subtitle: 'Use verified evidence rather than assumptions about teaching quality.',
          children: [
            _RowItem(title: p.qualification, copy: 'Primary qualification', end: 'Verified'),
            _RowItem(title: p.professionalId, copy: 'Professional registration reference · mock', end: 'Verified'),
            const _RowItem(title: 'Professional development record', copy: 'School training and CPD history', end: 'Available'),
          ],
        );
      case 3:
        return _SectionCard(
          title: 'Teaching load',
          subtitle: 'Section responsibilities and weekly periods.',
          children: [
            for (final a in p.assignments)
              _RowItem(title: '${a.className} · ${a.subject}', copy: '${a.periods} periods/week', end: a.role),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(onPressed: () => _openWorkspace('assignments'), icon: const Icon(Icons.assignment_ind_outlined), label: const Text('Open Teaching Assignments')),
            ),
          ],
        );
      case 4:
        return _SectionCard(
          title: 'Attendance context',
          subtitle: 'Operational evidence for supportive management, not an automatic employment score.',
          children: [
            _InfoGrid(items: {
              'Attendance': '${p.attendance}%',
              'Punctuality': '${p.punctuality}%',
              'Current workload': p.workload,
              'Weekly periods': '${p.weeklyPeriods}',
            }),
            const _Boundary(text: 'Attendance should be reviewed with approved leave, timetable and context before any employment decision.'),
          ],
        );
      case 5:
        return _SectionCard(
          title: 'Leave record',
          subtitle: 'Approved leave remains distinct from attendance concerns.',
          children: [
            if (p.leave.isEmpty)
              const Padding(padding: EdgeInsets.all(12), child: Text('No leave entries in this mock record.'))
            else
              for (final item in p.leave)
                _RowItem(title: item.type, copy: '${item.dates} · ${item.days} day(s)', end: item.status),
          ],
        );
      case 6:
        return _SectionCard(
          title: 'Staff documents',
          subtitle: 'Labels only in this UI prototype; no real files are stored here.',
          children: [for (final d in p.documents) _RowItem(title: d.name, copy: d.visibility, end: d.status)],
        );
      case 7:
        return _SectionCard(
          title: 'Staff timeline',
          subtitle: 'Auditable employment, support and professional-development events.',
          children: [for (final t in p.timeline) _TimelineItem(item: t)],
        );
      case 8:
        return _SectionCard(
          title: 'Private leadership notes',
          subtitle: 'Support/coaching notes are not automatically visible to the teacher or other roles.',
          children: [
            TextField(
              controller: _noteController,
              minLines: 5,
              maxLines: 8,
              decoration: const InputDecoration(hintText: 'Add factual support, observation or follow-up context...'),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveNote,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save private note'),
              ),
            ),
            const _Boundary(text: principalTeacherDecisionBoundary),
          ],
        );
      case 9:
      default:
        return const _SectionCard(
          title: 'Payroll & staff-finance boundary',
          subtitle: 'Leadership can see whether payroll records exist, not confidential amounts by default.',
          children: [
            _InfoGrid(items: {
              'Payroll record': 'Active',
              'Payslips': 'Available to staff + payroll',
              'Salary amount': 'Restricted',
              'Bank account': 'Restricted',
              'Deductions': 'Restricted',
              'Loans / advances': 'Restricted',
            }),
            _Boundary(text: 'A future HR/Finance role may receive explicit permission to manage salary, deductions, staff loans, repayment history and payslips. Principal access does not imply payroll authority.'),
          ],
        );
    }
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile});
  final PrincipalTeacherProfile profile;
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            spacing: 18,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CircleAvatar(radius: 32, child: Text(profile.name.replaceAll('Mrs. ', '').replaceAll('Mr. ', '').split(' ').map((e) => e[0]).take(2).join())),
              SizedBox(
                width: 330,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${profile.staffId} · ${profile.payrollId}', style: Theme.of(context).textTheme.bodySmall),
                  Text(profile.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  Text('${profile.department} · ${profile.employmentType}'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, children: [Chip(label: Text(profile.employmentStatus)), Chip(label: Text('${profile.workload} workload')), Chip(label: Text(profile.section))]),
                ]),
              ),
              _Metric(label: 'Attendance', value: '${profile.attendance}%'),
              _Metric(label: 'Punctuality', value: '${profile.punctuality}%'),
              _Metric(label: 'Weekly periods', value: '${profile.weeklyPeriods}'),
            ],
          ),
        ),
      );
}

class _ProfileSide extends StatelessWidget {
  const _ProfileSide({required this.profile});
  final PrincipalTeacherProfile profile;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          _SideCard(label: 'SECTION', value: profile.section, copy: profile.campus),
          _SideCard(label: 'RESPONSIBILITY', value: profile.classResponsibility, copy: profile.subjects.join(' · ')),
          _SideCard(label: 'DOCUMENTS', value: '${profile.documents.length}', copy: 'Visible HR document labels'),
          const _SideCard(label: 'PRIVACY', value: 'Restricted finance', copy: 'Payroll amounts, bank details, deductions and loan balances remain outside ordinary academic-leadership access.'),
        ],
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.subtitle, required this.children});
  final String title;
  final String subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            ...children,
          ]),
        ),
      );
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});
  final Map<String, String> items;
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final entry in items.entries) SizedBox(width: 230, child: _InfoTile(label: entry.key, value: entry.value))],
      );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.w800))]),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(width: 120, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.bodySmall), Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))]));
}

class _RowItem extends StatelessWidget {
  const _RowItem({required this.title, required this.copy, required this.end});
  final String title;
  final String copy;
  final String end;
  @override
  Widget build(BuildContext context) => ListTile(contentPadding: EdgeInsets.zero, title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(copy), trailing: Chip(label: Text(end)));
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.item});
  final PrincipalTeacherTimelineItem item;
  @override
  Widget build(BuildContext context) => ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(child: Text(item.date.substring(0, 3))), title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${item.date} · ${item.detail}'));
}

class _Callout extends StatelessWidget {
  const _Callout({required this.label, required this.text});
  final String label;
  final String text;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(top: 14), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(text)]));
}

class _Boundary extends StatelessWidget {
  const _Boundary({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(top: 14), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: .35), borderRadius: BorderRadius.circular(12)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.shield_outlined, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 10), Expanded(child: Text(text))]));
}

class _SideCard extends StatelessWidget {
  const _SideCard({required this.label, required this.value, required this.copy});
  final String label;
  final String value;
  final String copy;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(value, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(copy, style: Theme.of(context).textTheme.bodySmall)])));
}
