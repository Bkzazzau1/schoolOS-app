import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../data/bank_connect_api.dart';
import '../domain/bank_labels.dart';
import '../domain/payment_models.dart';
import 'payment_detail_sheet.dart';
import 'payment_list.dart';

/// Every payment the school's connected accounts have received, newest first.
class PaymentsTab extends StatefulWidget {
  const PaymentsTab({
    super.key,
    required this.api,
    required this.membership,
    this.connectionId,
    this.connectionName,
    this.onClearConnection,
    this.onChanged,
  });

  final BankConnectApi api;
  final SchoolMembership membership;

  /// Show only this account's payments.
  final String? connectionId;
  final String? connectionName;
  final VoidCallback? onClearConnection;
  final VoidCallback? onChanged;

  @override
  State<PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<PaymentsTab> {
  final _search = TextEditingController();
  String? _status;
  String _term = '';
  int _reload = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<PaymentPage> _load(int offset) => widget.api.payments(
        widget.membership,
        connectionId: widget.connectionId,
        status: _status,
        query: _term,
        offset: offset,
      );

  Future<void> _open(BankPayment payment) async {
    final changed = await showPaymentDetail(context, api: widget.api, membership: widget.membership, paymentId: payment.id);
    if (changed && mounted) {
      setState(() => _reload++);
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) => PaymentListView(
        loader: _load,
        onOpen: _open,
        reloadKey: (_status, _term, widget.connectionId, _reload),
        emptyText: _status != null || _term.isNotEmpty || widget.connectionId != null
            ? 'No payments match.'
            : 'No payments yet. When a connected account receives money it appears here.',
        header: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) => setState(() => _term = value.trim()),
                decoration: InputDecoration(
                  labelText: 'Search sender, narration or reference',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _term.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _search.clear();
                            setState(() => _term = '');
                          },
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<String?>(
                    value: _status,
                    hint: const Text('Any status'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Any status')),
                      for (final e in paymentStatusLabels.entries) DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (value) => setState(() => _status = value),
                  ),
                  if (widget.connectionId != null)
                    InputChip(
                      label: Text(widget.connectionName ?? 'One account'),
                      onDeleted: widget.onClearConnection,
                    ),
                ],
              ),
            ],
          ),
        ),
      );
}
