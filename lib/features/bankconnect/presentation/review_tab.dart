import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../data/bank_connect_api.dart';
import '../domain/bank_labels.dart';
import '../domain/payment_models.dart';
import 'payment_detail_sheet.dart';
import 'payment_list.dart';

/// Money received that SchoolOS could not settle on its own, oldest first. Nothing is matched here
/// silently: a payment is either matched with clear evidence, or it waits for a person.
class ReviewTab extends StatefulWidget {
  const ReviewTab({super.key, required this.api, required this.membership, this.onChanged});

  final BankConnectApi api;
  final SchoolMembership membership;
  final VoidCallback? onChanged;

  @override
  State<ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<ReviewTab> {
  String? _status;
  int _reload = 0;
  Map<String, int> _counts = const {};

  Future<PaymentPage> _load(int offset) => widget.api.reviewQueue(widget.membership, status: _status, offset: offset);

  Future<void> _open(BankPayment payment) async {
    final changed = await showPaymentDetail(context, api: widget.api, membership: widget.membership, paymentId: payment.id);
    if (changed && mounted) {
      setState(() => _reload++);
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _counts.values.fold(0, (a, b) => a + b);
    return PaymentListView(
      loader: _load,
      onOpen: _open,
      reloadKey: (_status, _reload),
      // The server's counts describe the whole queue, whichever filter is on.
      onLoaded: (page) => setState(() => _counts = page.counts),
      emptyText: _status == null
          ? 'Nothing is waiting for review. Payments SchoolOS cannot match with confidence appear here.'
          : 'Nothing with that status.',
      header: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Oldest first. Each payment shows what SchoolOS saw and why it could not be sure.'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(label: Text('All ($total)'), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
                for (final entry in _counts.entries)
                  ChoiceChip(
                    label: Text('${paymentStatusLabel(entry.key)} (${entry.value})'),
                    selected: _status == entry.key,
                    onSelected: (_) => setState(() => _status = entry.key),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
