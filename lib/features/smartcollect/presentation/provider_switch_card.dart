import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../bankconnect/domain/bank_labels.dart';
import '../../bankconnect/presentation/bank_widgets.dart';
import '../data/smart_collect_api.dart';
import '../domain/collection_models.dart';
import 'collection_words.dart';

/// A planned change of the school's active provider. It never happens by itself: when its date has come and nothing stands in the way it
/// says READY TO SWITCH, and a person reviews it and applies it.
class ProviderSwitchCard extends StatefulWidget {
  const ProviderSwitchCard({super.key, required this.api, required this.membership, required this.provider, required this.canManage, required this.onChanged});

  final SmartCollectApi api;
  final SchoolMembership membership;
  final ProviderSwitch provider;
  final bool canManage;

  /// Called after the switch was applied or cancelled, so the screen behind can reload.
  final VoidCallback onChanged;

  @override
  State<ProviderSwitchCard> createState() => _ProviderSwitchCardState();
}

class _ProviderSwitchCardState extends State<ProviderSwitchCard> {
  bool _busy = false;

  Future<void> _review() async {
    setState(() => _busy = true);
    ProviderSwitch fresh;
    try {
      fresh = await widget.api.switchDetail(widget.membership, widget.provider.id);
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showBankMessage(context, describeBankError(error));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final apply = await showDialog<bool>(context: context, builder: (_) => _ReviewDialog(provider: fresh, canApply: widget.canManage));
    if (apply != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.applySwitch(widget.membership, fresh.id);
      if (mounted) showBankMessage(context, '${fresh.targetName} is now the active collection provider.');
      widget.onChanged();
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
      widget.onChanged();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Cancel this switch?'),
        content: TextField(controller: reason, decoration: const InputDecoration(labelText: 'Why (optional)')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: const Text('Keep it')),
          FilledButton(onPressed: () => Navigator.of(dialog).pop(true), child: const Text('Cancel the switch')),
        ],
      ),
    );
    final text = reason.text;
    reason.dispose();
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.cancelSwitch(widget.membership, widget.provider.id, reason: text);
      widget.onChanged();
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.provider;
    return BankSection(
      title: 'Scheduled provider switch',
      trailing: StatusChip(label: s.isReady ? 'Ready to switch' : 'Scheduled', color: s.isReady ? const Color(0xFF1B7F3B) : const Color(0xFF8A6D00)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Current provider', s.currentName),
          _row('Target provider', s.targetName),
          _row('Scheduled for', dateTimeLabel(s.scheduledFor)),
          _row('Affected families', '${s.families} (${s.accounts} account${s.accounts == 1 ? '' : 's'})'),
          _row('Still owed by them', formatMoneyMinor(s.outstandingMinor)),
          const SizedBox(height: 8),
          Text(
            s.isReady
                ? 'The date has come and nothing stands in the way. Nothing has changed yet: the switch happens only when you apply it.'
                : 'Nothing changes on this date by itself. When it comes, this switch becomes ready and waits for you.',
          ),
          for (final b in s.blockers) _bullet(b, const Color(0xFFB3261E)),
          for (final w in s.warnings) _bullet(w, const Color(0xFF8A6D00)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (s.isReady && widget.canManage)
                FilledButton(
                  key: const ValueKey('review-switch'),
                  onPressed: _busy ? null : _review,
                  child: const Text('Review and Apply Provider Switch'),
                ),
              if (!s.isReady) OutlinedButton(onPressed: _busy ? null : _review, child: const Text('Review')),
              if (widget.canManage) TextButton(onPressed: _busy ? null : _cancel, child: const Text('Cancel switch')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 150, child: Text(label, style: const TextStyle(color: Color(0xFF5F6B7A)))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );

  Widget _bullet(String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: TextStyle(color: color))),
          ],
        ),
      );
}

/// What applying the switch will do, in full, before the person confirms.
class _ReviewDialog extends StatelessWidget {
  const _ReviewDialog({required this.provider, required this.canApply});

  final ProviderSwitch provider;
  final bool canApply;

  @override
  Widget build(BuildContext context) {
    final s = provider;
    final ready = s.isReady && canApply;
    return AlertDialog(
      title: const Text('Review provider switch'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.currentName}  →  ${s.targetName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('${s.families} families have ${s.accounts} live account${s.accounts == 1 ? '' : 's'} with ${s.currentName}, and owe ${formatMoneyMinor(s.outstandingMinor)}.'),
            const SizedBox(height: 8),
            Text('What happens to those accounts: ${switchPolicyWords(s.switchPolicy)}'),
            const SizedBox(height: 8),
            const Text(
              'From then on, new family accounts are made with the new provider. Batches waiting for approval for the old provider go back to '
              'their maker. Nothing is deleted: the old accounts and their payments stay on record, and the old provider stays connected while any of '
              'its accounts is still in use.',
            ),
            if (s.openBatches > 0) ...[
              const SizedBox(height: 8),
              Text('${s.openBatches} collection batch${s.openBatches == 1 ? ' is' : 'es are'} still open for ${s.currentName}.'),
            ],
            for (final b in s.blockers)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text(b, style: const TextStyle(color: Color(0xFFB3261E)))),
            for (final w in s.warnings)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text(w, style: const TextStyle(color: Color(0xFF8A6D00)))),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Not now')),
        if (ready) FilledButton(key: const ValueKey('apply-switch'), onPressed: () => Navigator.of(context).pop(true), child: const Text('Apply provider switch')),
      ],
    );
  }
}
