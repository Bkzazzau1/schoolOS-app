import 'package:flutter/material.dart';

import '../../bankconnect/domain/bank_labels.dart';
import '../../bankconnect/presentation/bank_widgets.dart';
import '../domain/collection_models.dart';
import 'collection_words.dart';

/// One family in a collection batch: what it owes, why it is or is not eligible, whether it is selected, and what a maker can do about it.
/// The buttons offered depend on what is true of the family; the server checks every change again.
class BatchItemTile extends StatelessWidget {
  const BatchItemTile({
    super.key,
    required this.item,
    required this.editable,
    required this.canOverride,
    required this.onSelect,
    required this.onOverride,
    required this.onClearOverride,
    required this.onChooseBalances,
    required this.onAddIdentity,
    this.retryMode = false,
    this.retryTicked = false,
    this.onRetryTick,
  });

  final BatchItem item;

  /// The batch can still be changed (a draft, or one that was rejected) and this person prepares batches.
  final bool editable;
  final bool canOverride;
  final void Function(bool selected) onSelect;
  final VoidCallback onOverride;
  final VoidCallback onClearOverride;
  final VoidCallback onChooseBalances;
  final VoidCallback onAddIdentity;

  /// Choosing failed families to retry, instead of choosing families for the batch.
  final bool retryMode;
  final bool retryTicked;
  final void Function(bool ticked)? onRetryTick;

  @override
  Widget build(BuildContext context) {
    final i = item;
    final locked = i.isGenerated;
    return Card(
      key: ValueKey('item-${i.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (retryMode && i.hasFailed)
              Checkbox(key: ValueKey('retry-${i.id}'), value: retryTicked, onChanged: (v) => onRetryTick?.call(v == true))
            else if (editable && !locked)
              Checkbox(
                key: ValueKey('select-${i.id}'),
                value: i.selected,
                onChanged: i.canBeSelected ? (v) => onSelect(v == true) : null,
              )
            else
              Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(i.selected ? Icons.check_box : Icons.check_box_outline_blank, color: const Color(0xFF5F6B7A)),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(i.familyName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                      EligibilityChip(i.eligibilityStatus),
                    ],
                  ),
                  Text(i.familyCode, style: const TextStyle(color: Color(0xFF5F6B7A), fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 16,
                    runSpacing: 2,
                    children: [
                      _figure('Previous balance', i.previousArrearsMinor),
                      _figure('Due this period', i.currentDueMinor),
                      _figure('Collection target', i.proposedCollectionMinor, bold: true),
                    ],
                  ),
                  if (i.eligibilityNote.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(i.eligibilityNote, style: const TextStyle(color: Color(0xFF5F6B7A)))),
                  if (i.eligibilityOverride)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Included by an override${i.overrideBy == null ? '' : ' (${i.overrideBy!.name})'}: ${i.overrideReason}. What the family owes is unchanged.',
                        style: const TextStyle(color: Color(0xFF8A6D00)),
                      ),
                    ),
                  if (i.manualApprovalNeeded && i.selected)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        i.manualApprovedBy == null ? 'The approver must approve this family.' : 'Approved by ${i.manualApprovedBy!.name}.',
                        style: const TextStyle(color: Color(0xFF8A6D00)),
                      ),
                    ),
                  if (i.arrearsPolicy == 'custom_selection' && i.arrearsBreakdown.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${i.customArrearsReceivableIds.length} of ${i.arrearsBreakdown.length} earlier balances carried.'),
                    ),
                  if (i.generationStatus != 'skipped' && i.generationStatus != 'pending' && (i.isGenerated || i.hasFailed || i.generationStatus == 'retrying' || i.generationStatus == 'generating'))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          StatusChip(label: generationStatusLabel(i.generationStatus), color: generationStatusColor(i.generationStatus)),
                          if (i.hasFailed && i.errorMessage.isNotEmpty) Expanded(child: Padding(padding: const EdgeInsets.only(left: 8), child: Text(i.errorMessage, style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12)))),
                        ],
                      ),
                    ),
                  if (editable && !locked) _actions(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _figure(String label, int minor, {bool bold = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF5F6B7A), fontSize: 11)),
          Text(formatMoneyMinor(minor), style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ],
      );

  Widget _actions() {
    final i = item;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          if (i.needsOverride && !i.eligibilityOverride && canOverride)
            OutlinedButton(key: ValueKey('override-${i.id}'), onPressed: onOverride, child: const Text('Override eligibility')),
          if (i.eligibilityOverride) TextButton(key: ValueKey('clear-override-${i.id}'), onPressed: onClearOverride, child: const Text('Remove override')),
          if (i.arrearsPolicy == 'custom_selection' && i.arrearsBreakdown.isNotEmpty)
            OutlinedButton(key: ValueKey('balances-${i.id}'), onPressed: onChooseBalances, child: const Text('Choose balances')),
          if (i.eligibilityStatus == 'missing_details' && i.missingDetails.any((m) => m.contains('BVN')))
            OutlinedButton(key: ValueKey('identity-${i.id}'), onPressed: onAddIdentity, child: const Text('Add BVN or NIN')),
        ],
      ),
    );
  }
}
