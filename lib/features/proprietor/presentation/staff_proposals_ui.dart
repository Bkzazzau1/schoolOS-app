import 'package:flutter/material.dart';

import '../../finance_office/domain/finance_payroll_models.dart';
import '../data/staff_proposal_repository.dart';

String _message(Object error) => error is StateError
    ? error.message
    : error is ArgumentError
    ? '${error.message}'
    : error.toString();

/// Form for adding a staff member. For anyone but the owner this only submits
/// a proposal, and the person is not staff until the owner approves.
Future<bool?> showStaffProposalDialog(
  BuildContext context,
  StaffProposalRepository repository,
) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _StaffProposalDialog(repository: repository),
);

class _StaffProposalDialog extends StatefulWidget {
  const _StaffProposalDialog({required this.repository});
  final StaffProposalRepository repository;

  @override
  State<_StaffProposalDialog> createState() => _StaffProposalDialogState();
}

class _StaffProposalDialogState extends State<_StaffProposalDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _role = TextEditingController();
  final _area = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _nin = TextEditingController();
  final _gross = TextEditingController();
  final _deductions = TextEditingController(text: '0');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _role, _area, _email, _phone, _nin, _gross, _deductions]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.propose(
        name: _name.text,
        roleTitle: _role.text,
        workArea: _area.text,
        email: _email.text,
        phone: _phone.text,
        nin: _nin.text,
        gross: int.parse(_gross.text.trim()),
        deductions: int.parse(_deductions.text.trim()),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _message(error);
        });
      }
    }
  }

  String? _required(String? v, String message) =>
      v == null || v.trim().isEmpty ? message : null;

  String? _amount(String? v) =>
      int.tryParse((v ?? '').trim()) == null ? 'Enter a whole number.' : null;

  @override
  Widget build(BuildContext context) {
    final owner = widget.repository.isOwner;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(owner ? 'Add staff' : 'Propose new staff'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    owner
                        ? 'The person is added to the staff list and payroll straight away.'
                        : 'This is a proposal only. The person is not a staff member, and is not on payroll, until the owner approves it.',
                  ),
                  TextFormField(
                    controller: _name,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (v) => _required(v, 'Enter the full name.'),
                  ),
                  TextFormField(
                    controller: _role,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Role / job title',
                    ),
                    validator: (v) => _required(v, 'Enter the role.'),
                  ),
                  TextFormField(
                    controller: _area,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Section or work area',
                    ),
                    validator: (v) => _required(v, 'Enter the section or area.'),
                  ),
                  TextFormField(
                    controller: _phone,
                    enabled: !_saving,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      helperText: 'Must be unique to this person.',
                    ),
                    validator: (v) => _required(v, 'Enter the phone number.'),
                  ),
                  TextFormField(
                    controller: _nin,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'NIN (11 digits)',
                      helperText: 'Must be unique to this person.',
                    ),
                    validator: (v) => _required(v, 'Enter the NIN.'),
                  ),
                  TextFormField(
                    controller: _email,
                    enabled: !_saving,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      helperText:
                          'Their registration link is sent here once the owner approves.',
                    ),
                    validator: (v) => _required(v, 'Enter the email address.'),
                  ),
                  TextFormField(
                    controller: _gross,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Proposed monthly gross salary (₦)',
                    ),
                    validator: _amount,
                  ),
                  TextFormField(
                    controller: _deductions,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Proposed deductions (₦)',
                    ),
                    validator: _amount,
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving
                  ? 'Saving…'
                  : owner
                  ? 'Add staff'
                  : 'Submit for owner approval',
            ),
          ),
        ],
      ),
    );
  }
}

/// Staff proposals. The owner sees all of them and decides; everyone else
/// sees only their own and their status.
class StaffProposalsPanel extends StatefulWidget {
  const StaffProposalsPanel({
    super.key,
    required this.repository,
    required this.onChanged,
    this.onStaffAdded,
  });

  final StaffProposalRepository repository;
  final VoidCallback onChanged;

  /// Called after a proposal is approved so lists can reload.
  final VoidCallback? onStaffAdded;

  @override
  State<StaffProposalsPanel> createState() => _StaffProposalsPanelState();
}

class _StaffProposalsPanelState extends State<StaffProposalsPanel> {
  List<StaffProposal> _proposals = const [];
  bool _allowed = false;
  bool _approver = false;
  bool _canPropose = false;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final canPropose = await widget.repository.canPropose();
      final approver = await widget.repository.canApprove();
      final allowed = canPropose || approver;
      final proposals = allowed ? await widget.repository.load() : const <StaffProposal>[];
      if (mounted) {
        setState(() {
          _canPropose = canPropose;
          _approver = approver;
          _allowed = allowed;
          _proposals = proposals;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
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
          _error = _message(error);
          _busy = false;
        });
      }
    }
  }

  Future<void> _add() async {
    final saved = await showStaffProposalDialog(context, widget.repository);
    if (saved == true) {
      widget.onChanged();
      if (widget.repository.isOwner) widget.onStaffAdded?.call();
      await _load();
    }
  }

  Future<void> _approve(StaffProposal p) async {
    final gross = TextEditingController(text: '${p.gross}');
    final deductions = TextEditingController(text: '${p.deductions}');
    final owner = widget.repository.isOwner;
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Approve ${p.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              owner
                  ? '${p.roleTitle} · ${p.workArea}. Approving makes them a staff member and puts them on payroll at the salary below, which you may change.'
                  : '${p.roleTitle} · ${p.workArea}. Approving makes them a staff member and puts them on payroll at the proposed salary of ${financePayrollMoney(p.gross)} gross, ${financePayrollMoney(p.deductions)} deductions. Only the owner can change the salary.',
            ),
            if (owner) ...[
              TextField(
                controller: gross,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Gross salary (₦)'),
              ),
              TextField(
                controller: deductions,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Deductions (₦)'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    final g = owner ? int.tryParse(gross.text.trim()) : null;
    final d = owner ? int.tryParse(deductions.text.trim()) : null;
    gross.dispose();
    deductions.dispose();
    if (go != true) return;
    await _run(() async {
      await widget.repository.approve(p.id, gross: g, deductions: d);
      widget.onStaffAdded?.call();
    });
  }

  Future<void> _reject(StaffProposal p) async {
    final note = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject ${p.name}'),
        content: TextField(
          controller: note,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    final text = note.text;
    note.dispose();
    if (go == true) await _run(() => widget.repository.reject(p.id, text));
  }

  String _status(StaffProposal p) => switch (p.status) {
    StaffProposalStatus.pending => 'Awaiting owner approval',
    StaffProposalStatus.approved => 'Approved: now a staff member',
    StaffProposalStatus.rejected =>
      'Rejected${p.decisionNote.isEmpty ? '' : ': ${p.decisionNote}'}',
  };

  @override
  Widget build(BuildContext context) {
    if (!_allowed) {
      return _error == null ? const SizedBox.shrink() : Text(_error!);
    }
    final owner = widget.repository.isOwner;
    final me = widget.repository.memberId;
    final theme = Theme.of(context);
    final visible = _approver
        ? _proposals.where((p) => p.status == StaffProposalStatus.pending).toList()
        : _proposals;
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
                    owner
                        ? 'Staff awaiting your approval'
                        : _approver
                        ? 'Staff awaiting approval'
                        : 'Your staff proposals',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (_canPropose)
                  FilledButton.icon(
                    onPressed: _busy ? null : _add,
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: Text(owner ? 'Add staff' : 'Propose new staff'),
                  ),
              ],
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _approver ? 'No proposals are waiting.' : 'You have not proposed anyone yet.',
                ),
              ),
            for (final p in visible)
              ListTile(
                contentPadding: EdgeInsets.zero,
                isThreeLine: true,
                title: Text('${p.name} · ${p.roleTitle}'),
                subtitle: Text(
                  '${p.workArea} · Proposed gross ${financePayrollMoney(p.gross)}, net ${financePayrollMoney(p.net)}\n'
                  '${_status(p)}${_approver ? ' · proposed by ${p.proposedByRole}' : ''}',
                ),
                trailing: _approver &&
                        p.status == StaffProposalStatus.pending &&
                        (owner || p.proposedBy != me)
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: _busy ? null : () => _reject(p),
                            child: const Text('Reject'),
                          ),
                          FilledButton(
                            onPressed: _busy ? null : () => _approve(p),
                            child: const Text('Approve'),
                          ),
                        ],
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
