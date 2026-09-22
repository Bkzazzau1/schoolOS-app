import 'package:flutter/material.dart';

import '../../finance_office/domain/finance_payroll_models.dart';
import '../data/staff_proposal_repository.dart';
import '../domain/owner_staff_profile_models.dart';

// Each dialog here owns its text boxes and disposes them itself. Disposing them from the code that opened the dialog
// (right after it closes) is too early: the dialog is still fading out and would draw a disposed text box.

class ApprovalChoice {
  const ApprovalChoice({this.gross, this.deductions, this.systemRole});

  /// Only the owner may change these; they are null for anyone else.
  final int? gross;
  final int? deductions;
  final String? systemRole;
}

/// Asks to approve a proposed staff member. The owner may change the role and salary first.
Future<ApprovalChoice?> askApproval(BuildContext context, StaffProposal proposal, {required bool owner}) =>
    showDialog<ApprovalChoice>(
      context: context,
      builder: (context) => _ApprovalDialog(proposal: proposal, owner: owner),
    );

class _ApprovalDialog extends StatefulWidget {
  const _ApprovalDialog({required this.proposal, required this.owner});

  final StaffProposal proposal;
  final bool owner;

  @override
  State<_ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<_ApprovalDialog> {
  late final _gross = TextEditingController(text: '${widget.proposal.gross}');
  late final _deductions = TextEditingController(text: '${widget.proposal.deductions}');
  late String? _role = staffSystemRoles.containsKey(widget.proposal.systemRole) ? widget.proposal.systemRole : null;

  @override
  void dispose() {
    _gross.dispose();
    _deductions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.proposal;
    final owner = widget.owner;
    return AlertDialog(
      title: Text('Approve ${p.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            owner
                ? '${p.roleTitle} · ${p.workArea}. Approving makes them a staff member and puts them on payroll at the salary below. You may change the role and the salary.'
                : '${p.roleTitle} · ${p.workArea}. Approving makes them a ${staffSystemRoleLabel(p.systemRole)} and puts them on payroll at the proposed salary of ${financePayrollMoney(p.gross)} gross, ${financePayrollMoney(p.deductions)} deductions. Only the owner can change the role or the salary.',
          ),
          if (owner) ...[
            DropdownButtonFormField<String>(
              initialValue: _role,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Role in the system',
                helperText: 'Proposed by the person who added them.',
              ),
              items: [
                for (final e in staffSystemRoles.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _role = v),
            ),
            TextField(
              controller: _gross,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Gross salary (₦)'),
            ),
            TextField(
              controller: _deductions,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Deductions (₦)'),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: owner && _role == null
              ? null
              : () => Navigator.pop(
                    context,
                    ApprovalChoice(
                      gross: owner ? int.tryParse(_gross.text.trim()) : null,
                      deductions: owner ? int.tryParse(_deductions.text.trim()) : null,
                      systemRole: owner ? _role : null,
                    ),
                  ),
          child: const Text('Approve'),
        ),
      ],
    );
  }
}

/// Asks for an optional reason. Returns the text (possibly empty) when confirmed, or null when cancelled.
Future<String?> askReason(BuildContext context, {required String title, required String action, String label = 'Reason (optional)'}) =>
    showDialog<String>(
      context: context,
      builder: (context) => _ReasonDialog(title: title, action: action, label: label),
    );

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title, required this.action, required this.label});

  final String title;
  final String action;
  final String label;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(controller: _text, decoration: InputDecoration(labelText: widget.label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, _text.text), child: Text(widget.action)),
        ],
      );
}

class SalaryChoice {
  const SalaryChoice({required this.gross, required this.deductions, required this.onPayroll});

  final int gross;
  final int deductions;
  final bool onPayroll;
}

/// Asks for a person's monthly salary. Returns null when cancelled.
Future<SalaryChoice?> askSalary(
  BuildContext context, {
  required String personName,
  int? gross,
  int? deductions,
  bool onPayroll = true,
}) =>
    showDialog<SalaryChoice>(
      context: context,
      builder: (context) => _SalaryDialog(personName: personName, gross: gross, deductions: deductions, onPayroll: onPayroll),
    );

class _SalaryDialog extends StatefulWidget {
  const _SalaryDialog({required this.personName, required this.gross, required this.deductions, required this.onPayroll});

  final String personName;
  final int? gross;
  final int? deductions;
  final bool onPayroll;

  @override
  State<_SalaryDialog> createState() => _SalaryDialogState();
}

class _SalaryDialogState extends State<_SalaryDialog> {
  late final _gross = TextEditingController(text: widget.gross == null ? '' : '${widget.gross}');
  late final _deductions = TextEditingController(text: widget.deductions == null ? '' : '${widget.deductions}');
  late bool _onPayroll = widget.onPayroll;
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _gross.dispose();
    _deductions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Salary · ${widget.personName}'),
        content: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _gross,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monthly gross salary (₦)'),
                validator: (v) => int.tryParse(v ?? '') == null ? 'Enter a number.' : null,
              ),
              TextFormField(
                controller: _deductions,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Approved deductions (₦)'),
                validator: (v) {
                  final d = int.tryParse(v ?? '');
                  if (d == null) return 'Enter a number (0 if none).';
                  if (d > (int.tryParse(_gross.text) ?? 0)) return 'Deductions cannot exceed gross.';
                  return null;
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('On payroll'),
                value: _onPayroll,
                onChanged: (v) => setState(() => _onPayroll = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              Navigator.pop(
                context,
                SalaryChoice(
                  gross: int.tryParse(_gross.text) ?? 0,
                  deductions: int.tryParse(_deductions.text) ?? 0,
                  onPayroll: _onPayroll,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      );
}

class DocumentChoice {
  const DocumentChoice({required this.status, required this.reference});

  final StaffDocumentStatus status;
  final String reference;
}

/// Asks for a required document's status and where the original is kept. Returns null when cancelled.
Future<DocumentChoice?> askDocument(BuildContext context, StaffRequiredDocument doc, {required String Function(StaffDocumentStatus) label}) =>
    showDialog<DocumentChoice>(
      context: context,
      builder: (context) => _DocumentDialog(doc: doc, label: label),
    );

class _DocumentDialog extends StatefulWidget {
  const _DocumentDialog({required this.doc, required this.label});

  final StaffRequiredDocument doc;
  final String Function(StaffDocumentStatus) label;

  @override
  State<_DocumentDialog> createState() => _DocumentDialogState();
}

class _DocumentDialogState extends State<_DocumentDialog> {
  late final _reference = TextEditingController(text: widget.doc.reference);
  late StaffDocumentStatus _status = widget.doc.status;

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.doc.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<StaffDocumentStatus>(
            isExpanded: true,
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                for (final s in StaffDocumentStatus.values) DropdownMenuItem(value: s, child: Text(widget.label(s))),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            TextField(controller: _reference, decoration: const InputDecoration(labelText: 'Where the original is kept')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, DocumentChoice(status: _status, reference: _reference.text)),
            child: const Text('Save'),
          ),
        ],
      );
}
