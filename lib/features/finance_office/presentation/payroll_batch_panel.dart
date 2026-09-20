import 'package:flutter/material.dart';

import '../../proprietor/data/payroll_batch_repository.dart';
import '../domain/finance_payroll_models.dart';

/// Shows the current payroll batch and the approval and disbursement steps the
/// signed-in person is allowed to take. Bump [refreshToken] to reload it.
class PayrollBatchPanel extends StatefulWidget {
  const PayrollBatchPanel({
    super.key,
    required this.repository,
    required this.onChanged,
    this.refreshToken = 0,
  });

  final PayrollBatchRepository repository;
  final VoidCallback onChanged;
  final int refreshToken;

  @override
  State<PayrollBatchPanel> createState() => _PayrollBatchPanelState();
}

class _PayrollBatchPanelState extends State<PayrollBatchPanel> {
  PayrollBatch? _batch;
  Set<String> _authorities = const {};
  String? _me;
  String? _error;
  bool _busy = true;

  String get _period => PayrollBatchRepository.periodFor(DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PayrollBatchPanel old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    try {
      final me = widget.repository.session.requireActiveMembership().id;
      final authorities = await widget.repository.authorities();
      final batch = authorities.contains('view')
          ? await widget.repository.load(_period)
          : null;
      if (mounted) {
        setState(() {
          _me = me;
          _authorities = authorities;
          _batch = batch;
          _error = null;
        });
      }
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
          _error = error is StateError ? error.message : error.toString();
          _busy = false;
        });
      }
    }
  }

  Future<void> _reject() async {
    final reason = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject payroll batch'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'Reason'),
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
    final text = reason.text;
    reason.dispose();
    if (go == true) await _run(() => widget.repository.reject(_period, text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final batch = _batch;
    final canApprove =
        batch?.status == PayrollBatchStatus.prepared &&
        _authorities.contains('approve') &&
        batch?.preparedBy != _me;
    final canPay =
        batch?.status == PayrollBatchStatus.approved &&
        _authorities.contains('pay');

    final String status;
    if (batch == null) {
      status = 'No payroll batch has been prepared for $_period yet.';
    } else {
      status = switch (batch.status) {
        PayrollBatchStatus.prepared =>
          'Prepared: ${batch.lines.length} staff, ${financePayrollMoney(batch.total)}. Awaiting approval. Payment cannot be released until an authorized approver approves it.',
        PayrollBatchStatus.approved =>
          'Approved: ${batch.lines.length} staff, ${financePayrollMoney(batch.total)}. ${canPay ? 'You may instruct disbursement.' : 'Awaiting someone with payment authority to release it.'}',
        PayrollBatchStatus.rejected =>
          'Rejected${batch.rejectionReason.isEmpty ? '' : ': ${batch.rejectionReason}'}. Prepare the batch again after correcting it.',
        PayrollBatchStatus.disbursementInstructed =>
          'Disbursement instructed for ${financePayrollMoney(batch.total)}. This is an instruction only. Salaries stay unpaid until bank or payment evidence confirms them.',
      };
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment approval · $_period',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(status),
            if (batch?.status == PayrollBatchStatus.prepared &&
                _authorities.contains('approve') &&
                batch?.preparedBy == _me)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('You prepared this batch, so a different approver must approve it.'),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (canApprove) ...[
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() => widget.repository.approve(_period)),
                    child: const Text('Approve batch'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : _reject,
                    child: const Text('Reject'),
                  ),
                ],
                if (canPay)
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => widget.repository.instructDisbursement(_period),
                          ),
                    child: const Text('Instruct disbursement'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
