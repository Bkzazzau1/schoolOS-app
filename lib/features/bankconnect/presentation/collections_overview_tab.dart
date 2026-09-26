import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../data/bank_connect_api.dart';
import '../domain/bank_labels.dart';
import '../domain/collections_summary.dart';
import 'bank_widgets.dart';
import 'payment_detail_sheet.dart';

/// How much has really come in. Every figure is the server's own: the app adds nothing, and where the
/// server cannot know a number (what is still owed) it says so instead of showing one.
class CollectionsOverviewTab extends StatefulWidget {
  const CollectionsOverviewTab({
    super.key,
    required this.api,
    required this.membership,
    required this.onReview,
    required this.onConnect,
    this.onChanged,
  });

  final BankConnectApi api;
  final SchoolMembership membership;
  final VoidCallback onReview;
  final VoidCallback onConnect;
  final VoidCallback? onChanged;

  @override
  State<CollectionsOverviewTab> createState() => _CollectionsOverviewTabState();
}

class _CollectionsOverviewTabState extends State<CollectionsOverviewTab> {
  static const _periods = {'today': 'Today', 'week': 'This week', 'term': 'This term', 'all': 'All time'};

  CollectionsSummary? _summary;
  String? _error;
  bool _loading = true;
  String _period = 'term';
  bool _includeTest = false;

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
      final summary = await widget.api.summary(widget.membership, period: _period, includeSandbox: _includeTest);
      if (mounted) setState(() => _summary = summary);
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    if (s == null) {
      return _error != null ? ErrorRetry(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const Padding(padding: EdgeInsets.only(bottom: 8), child: LinearProgressIndicator()),
          if (!s.available) _noAccount(s) else ..._figures(s),
          if (s.sandboxHidden > 0 || s.sandboxIncluded)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Include test data'),
              subtitle: Text(
                s.sandboxIncluded
                    ? 'Test payments are counted below. They are not the school\'s money.'
                    : '${s.sandboxHidden} test payment${s.sandboxHidden == 1 ? ' is' : 's are'} left out of every figure.',
              ),
              value: _includeTest,
              onChanged: (value) {
                setState(() => _includeTest = value);
                _load();
              },
            ),
          _honestyNotes(s),
        ],
      ),
    );
  }

  Widget _noAccount(CollectionsSummary s) => BankSection(
        title: 'No bank account is connected yet',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Once the school\'s own account is connected, the payments it receives appear here and are matched to students. '
              'Until then there are no figures to show, and none are invented.',
            ),
            if (s.accounts.needAttention > 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${s.accounts.needAttention} account(s) need attention.')),
            const SizedBox(height: 12),
            FilledButton(onPressed: widget.onConnect, child: const Text('Go to bank accounts')),
          ],
        ),
      );

  List<Widget> _figures(CollectionsSummary s) => [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _kpi('Today', s.today),
            _kpi('This week', s.thisWeek),
            if (s.thisTerm != null) _kpi('This term', s.thisTerm!),
          ],
        ),
        const SizedBox(height: 16),
        BankSection(
          title: 'Reconciliation',
          trailing: s.reconciliation.pendingReviewCount > 0
              ? TextButton(onPressed: widget.onReview, child: Text('${s.reconciliation.pendingReviewCount} to review'))
              : null,
          child: _reconciliation(s.reconciliation),
        ),
        BankSection(
          title: 'Collected',
          trailing: Wrap(
            spacing: 6,
            children: [
              for (final e in _periods.entries)
                ChoiceChip(
                  label: Text(e.key == 'term' && s.thisTerm == null ? 'All time' : e.value),
                  selected: s.periodKey == e.key || (e.key == 'term' && s.thisTerm == null && s.periodKey == 'all'),
                  onSelected: (_) {
                    setState(() => _period = e.key);
                    _load();
                  },
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${s.periodLabel}: ${formatMoneyMinor(s.selected.amountMinor)} from ${s.selected.count} payment${s.selected.count == 1 ? '' : 's'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text('By what the account collects for', style: TextStyle(color: Color(0xFF5F6B7A))),
              if (s.byPurpose.isEmpty) const Text('Nothing in this period.'),
              for (final p in s.byPurpose) _line(purposeLabel(p.purpose), p.amountMinor, p.count),
              const SizedBox(height: 12),
              const Text('By bank account', style: TextStyle(color: Color(0xFF5F6B7A))),
              for (final b in s.byBank) _line('${b.label.isNotEmpty ? b.label : b.bankName} ${b.accountMask}', b.amountMinor, b.count),
            ],
          ),
        ),
        if (s.recent.isNotEmpty)
          BankSection(
            title: 'Latest payments',
            child: Column(
              children: [
                for (final r in s.recent)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${formatMoneyMinor(r.amountMinor, currency: r.currency)} · ${r.senderName.isEmpty ? 'Unnamed sender' : r.senderName}'),
                    subtitle: Text('${whenLabel(r.transactionDate)} · ${r.bankName}'),
                    trailing: PaymentStatusChip(r.status),
                    onTap: () async {
                      final changed = await showPaymentDetail(context, api: widget.api, membership: widget.membership, paymentId: r.id);
                      if (changed && mounted) {
                        await _load();
                        widget.onChanged?.call();
                      }
                    },
                  ),
              ],
            ),
          ),
      ];

  Widget _kpi(String label, AmountTotal total) => SizedBox(
        width: 200,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Color(0xFF5F6B7A))),
                const SizedBox(height: 4),
                Text(formatMoneyMinor(total.amountMinor), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                Text('${total.count} payment${total.count == 1 ? '' : 's'}', style: const TextStyle(color: Color(0xFF5F6B7A))),
              ],
            ),
          ),
        ),
      );

  Widget _line(String label, int amountMinor, int count) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text('${formatMoneyMinor(amountMinor)}  ($count)'),
          ],
        ),
      );

  Widget _reconciliation(ReconciliationTotals r) {
    final share = r.totalMinor == 0 ? 0.0 : r.reconciledMinor / r.totalMinor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: share, minHeight: 10)),
        const SizedBox(height: 8),
        Text('${formatMoneyMinor(r.reconciledMinor)} matched to students or accounted for'),
        Text('${formatMoneyMinor(r.unreconciledMinor)} still waiting for a person'),
      ],
    );
  }

  Widget _honestyNotes(CollectionsSummary s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!s.outstandingFeesAvailable)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'What is still owed is not shown yet. SchoolOS does not hold the school\'s fee records on the server, so it can '
                'say what has come in but not what is outstanding.',
                style: TextStyle(color: Color(0xFF5F6B7A)),
              ),
            ),
          if (s.otherCurrencyTransactions > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${s.otherCurrencyTransactions} payment(s) in another currency are not included in these naira totals.',
                style: const TextStyle(color: Color(0xFF5F6B7A)),
              ),
            ),
          if (s.accounts.needAttention > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${s.accounts.needAttention} account(s) need attention, so these figures may be behind.',
                style: const TextStyle(color: Color(0xFFB3261E)),
              ),
            ),
        ],
      );
}
