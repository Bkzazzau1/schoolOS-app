import 'package:flutter/material.dart';

import '../domain/bank_labels.dart';
import '../domain/payment_models.dart';
import 'bank_widgets.dart';

/// One payment in a list: how much, from whom, what the sender wrote, and what SchoolOS has done with it.
class PaymentTile extends StatelessWidget {
  const PaymentTile({super.key, required this.payment, required this.onTap});

  final BankPayment payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final students = p.activeAllocations.map((a) => a.studentName).toSet().join(', ');
    final incoming = p.isCredit;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${incoming ? '' : '- '}${formatMoneyMinor(p.amountMinor, currency: p.currency)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: incoming ? null : const Color(0xFF5F6B7A)),
              ),
            ),
            PaymentStatusChip(p.status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.senderTitle),
            if (p.narration.isNotEmpty) Text(p.narration, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (students.isNotEmpty) Text('For $students', style: const TextStyle(fontWeight: FontWeight.w600)),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${whenLabel(p.transactionDate)} · ${providerDisplayName(p.provider)}${p.receivingAccountRef.isEmpty ? '' : ' · ${p.receivingAccountRef}'}', style: const TextStyle(color: Color(0xFF5F6B7A), fontSize: 12)),
                if (p.isSandbox) const SandboxTag(),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

typedef PaymentLoader = Future<PaymentPage> Function(int offset);

/// A page-at-a-time list of payments. Give it a [loader] and it does the loading, "load more" and the
/// error and empty states. Changing [reloadKey] starts again from the top.
class PaymentListView extends StatefulWidget {
  const PaymentListView({
    super.key,
    required this.loader,
    required this.onOpen,
    required this.emptyText,
    this.reloadKey,
    this.header,
    this.onLoaded,
  });

  final PaymentLoader loader;
  final void Function(BankPayment payment) onOpen;
  final String emptyText;
  final Object? reloadKey;
  final Widget? header;
  final void Function(PaymentPage firstPage)? onLoaded;

  @override
  State<PaymentListView> createState() => PaymentListViewState();
}

class PaymentListViewState extends State<PaymentListView> {
  final _items = <BankPayment>[];
  int _total = 0;
  bool _more = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(PaymentListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadKey != widget.reloadKey) reload();
  }

  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.loader(0);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.payments);
        _total = page.total;
        _more = page.hasMore;
      });
      widget.onLoaded?.call(page);
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loading = true);
    try {
      final page = await widget.loader(_items.length);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.payments);
        _more = page.hasMore;
      });
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _items.isEmpty) return ErrorRetry(message: _error!, onRetry: reload);
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.header != null) widget.header!,
          if (_loading && _items.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
          if (!_loading && _items.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(widget.emptyText, textAlign: TextAlign.center))),
          for (final p in _items) PaymentTile(payment: p, onTap: () => widget.onOpen(p)),
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: _more
                    ? OutlinedButton(onPressed: _loading ? null : _loadMore, child: Text('Load more (${_items.length} of $_total)'))
                    : Text('$_total payment${_total == 1 ? '' : 's'}', style: const TextStyle(color: Color(0xFF5F6B7A))),
              ),
            ),
        ],
      ),
    );
  }
}
