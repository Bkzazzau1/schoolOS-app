import 'package:flutter/material.dart';

import '../data/administrator_staff_demo_data.dart';
import '../data/administrator_staff_repository.dart';
import '../domain/administrator_staff_models.dart';
import '../domain/support_staff_roles.dart';

class AdministratorStaffPage extends StatefulWidget {
  const AdministratorStaffPage({
    super.key,
    required this.schoolName,
    required this.repository,
  });

  final String schoolName;
  final AdministratorStaffRepository repository;

  @override
  State<AdministratorStaffPage> createState() => _AdministratorStaffPageState();
}

class _AdministratorStaffPageState extends State<AdministratorStaffPage> {
  Future<void> _registerSupportStaff() async {
    final saved = await showDialog<bool>(context: context,
      barrierDismissible: false,
      builder: (_) => _SupportStaffDialog(repository: widget.repository));
    if (saved == true && mounted) await _load();
  }
  bool _loading = true;
  String? _error;
  List<AdministratorStaffRecord> _staff = const [];
  AdministratorStaffPermissions? _permissions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _staff = snapshot.staff;
        _permissions = snapshot.permissions;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  void _review(AdministratorStaffRecord record) {
    if (!(_permissions?.canReviewOperationalFile ?? false)) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${record.name} · ${record.id}'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReviewRow(label: 'Role', value: record.role),
                _ReviewRow(label: 'Section', value: record.section),
                _ReviewRow(label: 'File status', value: record.fileStatus.label),
                const SizedBox(height: 16),
                Text(
                  'Onboarding checklist',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                for (final item in administratorStaffOnboardingChecklist)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.checklist_rounded, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              Text(item.detail),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                const _BoundaryBox(text: administratorStaffReviewBoundary),
                const SizedBox(height: 8),
                const _BoundaryBox(text: administratorStaffRestrictedBoundary),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        return ListView(
          padding: EdgeInsets.all(wide ? 28 : 16),
          children: [
            _Header(schoolName: widget.schoolName),
            if (_permissions?.canReviewOperationalFile ?? false) Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(onPressed: _registerSupportStaff,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add support staff')),
            ),
            const SizedBox(height: 18),
            if (wide)
              _WideDirectory(
                staff: _staff,
                canReview: _permissions?.canReviewOperationalFile ?? false,
                onReview: _review,
              )
            else
              _CompactDirectory(
                staff: _staff,
                canReview: _permissions?.canReviewOperationalFile ?? false,
                onReview: _review,
              ),
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(child: _ChecklistCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _BoundaryCard(staff: _staff)),
                ],
              )
            else ...[
              const _ChecklistCard(),
              const SizedBox(height: 16),
              _BoundaryCard(staff: _staff),
            ],
          ],
        );
      },
    );
  }
}

class _SupportStaffDialog extends StatefulWidget {
  const _SupportStaffDialog({required this.repository});
  final AdministratorStaffRepository repository;
  @override
  State<_SupportStaffDialog> createState() => _SupportStaffDialogState();
}

class _SupportStaffDialogState extends State<_SupportStaffDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _area = TextEditingController();
  final _email = TextEditingController();
  String _role = 'driver';
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await widget.repository.registerSupportStaff(name: _name.text, role: _role, workArea: _area.text, email: _email.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() { _saving = false; _error = error is ArgumentError ? '${error.message}' : 'Could not save the staff record. Please try again.'; });
    }
  }

  @override
  void dispose() { _name.dispose(); _area.dispose(); _email.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Add support staff'),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Form(key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Create a staff record. Login access and job duties are assigned separately in Jobs & Delegation.'),
          const SizedBox(height: 16),
          TextFormField(controller: _name, enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Full name'),
            validator: (value) => value == null || value.trim().isEmpty ? 'Enter the staff member’s name.' : null),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(initialValue: _role, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Support role'),
            items: [for (final role in supportStaffRoles.entries) DropdownMenuItem(value: role.key, child: Text(role.value))],
            onChanged: _saving ? null : (role) => setState(() => _role = role!)),
          const SizedBox(height: 12),
          TextFormField(controller: _area, enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Campus / work area', hintText: 'For example: Main campus, Bus route 1, Primary block'),
            validator: (value) => value == null || value.trim().isEmpty ? 'Enter a campus or work area.' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _email, enabled: !_saving, keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email (optional)', helperText: 'If given, an onboarding request is queued asking them to submit their details, documents, passport photo and bank details. The email is sent once delivery is connected.')),
          const SizedBox(height: 12),
          const Text('Onboarding documents will be marked as pending review.'),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ])))),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save staff record')),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.schoolName});
  final String schoolName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ADMINISTRATION · STAFF RECORDS',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 5),
        Text(
          'Staff Records',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Maintain employment files, identity documents and onboarding records without exposing restricted payroll data. · $schoolName',
        ),
      ],
    );
  }
}

class _WideDirectory extends StatelessWidget {
  const _WideDirectory({
    required this.staff,
    required this.canReview,
    required this.onReview,
  });

  final List<AdministratorStaffRecord> staff;
  final bool canReview;
  final ValueChanged<AdministratorStaffRecord> onReview;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Staff directory',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
            const SizedBox(height: 14),
            const _StaffRow(
              header: true,
              values: ['Staff ID', 'Name', 'Role', 'Section', 'File status'],
            ),
            for (final record in staff)
              _StaffDataRow(
                record: record,
                canReview: canReview,
                onReview: () => onReview(record),
              ),
          ],
        ),
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({required this.header, required this.values});

  final bool header;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final style = header
        ? const TextStyle(fontWeight: FontWeight.w900)
        : const TextStyle();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          for (final value in values)
            Expanded(child: Text(value, style: style)),
          const SizedBox(width: 92),
        ],
      ),
    );
  }
}

class _StaffDataRow extends StatelessWidget {
  const _StaffDataRow({
    required this.record,
    required this.canReview,
    required this.onReview,
  });

  final AdministratorStaffRecord record;
  final bool canReview;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(record.id, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          Expanded(child: Text(record.name)),
          Expanded(child: Text(record.role)),
          Expanded(child: Text(record.section)),
          Expanded(
            child: Text(
              record.fileStatus.label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: record.needsAttention
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
          ),
          SizedBox(
            width: 92,
            child: TextButton(
              onPressed: canReview ? onReview : null,
              child: const Text('Review'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactDirectory extends StatelessWidget {
  const _CompactDirectory({
    required this.staff,
    required this.canReview,
    required this.onReview,
  });

  final List<AdministratorStaffRecord> staff;
  final bool canReview;
  final ValueChanged<AdministratorStaffRecord> onReview;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final record in staff)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(record.id),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${record.role} · ${record.section}'),
                  const SizedBox(height: 5),
                  Text(
                    record.fileStatus.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: record.needsAttention
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: canReview ? () => onReview(record) : null,
                      child: const Text('Review'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Onboarding checklist',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
            const SizedBox(height: 12),
            for (final item in administratorStaffOnboardingChecklist)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(item.detail),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard({required this.staff});
  final List<AdministratorStaffRecord> staff;

  @override
  Widget build(BuildContext context) {
    final complete = staff
        .where((item) => item.fileStatus == AdministratorStaffFileStatus.complete)
        .length;
    final needsReview = staff.where((item) => item.needsAttention).length;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$complete complete · $needsReview missing document',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            const _BoundaryBox(text: administratorStaffRestrictedBoundary),
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

class _BoundaryBox extends StatelessWidget {
  const _BoundaryBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
    );
  }
}
