import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../bankconnect/data/bank_connect_api.dart';
import '../../bankconnect/domain/bank_labels.dart' show formatMoneyMinor;
import '../../bankconnect/domain/collections_summary.dart';
import '../../bankconnect/presentation/bank_widgets.dart' show describeBankError;

/// What Smart Money Collection has really taken in this term, read straight from the same summary the
/// Collections screen itself shows - every figure is the server's own, never recomputed here.
///
/// Deliberately a separate card, not merged into the Kpi row above: that row is the manual Finance
/// Office ledger, a different record kept by hand, and nothing here proves the two do not already
/// overlap. Adding the two together would risk counting a payment twice. This card is a view onto the
/// existing collection summary, not a step toward joining the two ledgers - that accounting work is
/// still outstanding (see docs/BACKEND_INTEGRATION.md).
class SmartCollectionSummaryCard extends StatefulWidget {
  const SmartCollectionSummaryCard({super.key, required this.membership, required this.onOpenCollections});

  final SchoolMembership membership;
  final VoidCallback onOpenCollections;

  @override
  State<SmartCollectionSummaryCard> createState() => _SmartCollectionSummaryCardState();
}

class _SmartCollectionSummaryCardState extends State<SmartCollectionSummaryCard> {
  BankConnectApi? _api;
  Future<CollectionsSummary>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final api = BankConnectScope.maybeOf(context);
    if (api != _api || (_future == null && api != null)) {
      _api = api;
      _future = api?.summary(widget.membership, period: 'term');
    }
  }

  void _retry() {
    final api = _api;
    setState(() => _future = api?.summary(widget.membership, period: 'term'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Smart Money Collection', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(
                        'Verified bank transfers this term. Separate from the manual ledger above - the two are never added together here.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: widget.onOpenCollections, child: const Text('Open Collections')),
              ],
            ),
            const SizedBox(height: 14),
            _body(context),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_api == null) {
      return const Text('Smart Money Collection is not connected on this device.');
    }
    return FutureBuilder<CollectionsSummary>(
      future: _future,
      builder: (context, state) {
        if (state.connectionState != ConnectionState.done) return const LinearProgressIndicator();
        if (state.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(describeBankError(state.error!)),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: _retry, child: const Text('Try again')),
            ],
          );
        }
        final s = state.data!;
        if (!s.available) {
          return const Text('No collection provider is connected yet. Connect one from the Collections screen to see real figures here.');
        }
        final scheme = Theme.of(context).colorScheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _metric(context, 'Today', formatMoneyMinor(s.today.amountMinor), '${s.today.count} payments'),
                _metric(context, 'This week', formatMoneyMinor(s.thisWeek.amountMinor), '${s.thisWeek.count} payments'),
                if (s.thisTerm != null) _metric(context, s.periodLabel.isEmpty ? 'This term' : s.periodLabel, formatMoneyMinor(s.thisTerm!.amountMinor), '${s.thisTerm!.count} payments'),
              ],
            ),
            if (s.reconciliation.pendingReviewCount > 0) ...[
              const SizedBox(height: 10),
              Text(
                '${s.reconciliation.pendingReviewCount} payment(s) waiting for someone to decide where they go.',
                style: TextStyle(color: scheme.error, fontWeight: FontWeight.w700),
              ),
            ],
            if (s.providers.connections.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Connections', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              for (final c in s.providers.connections) _connectionHealthRow(c),
            ],
          ],
        );
      },
    );
  }

  Widget _connectionHealthRow(ConnectionHealth connection) {
    final scheme = Theme.of(context).colorScheme;
    final color = connection.needsAttention ? scheme.error : (connection.status == 'connected' ? const Color(0xFF1B7F3B) : scheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 5), child: Icon(Icons.circle, size: 9, color: color)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(connection.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (connection.isActiveProvider) ...[
                      const SizedBox(width: 6),
                      Text('· Active', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ],
                ),
                Text(
                  connection.webhookConfirmed
                      ? 'Webhook confirmed ${_date(connection.webhookConfirmedAt)}'
                      : 'Webhook not yet confirmed - waiting for a real event',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                if (connection.lastVerifiedAt != null)
                  Text('Last verified ${_date(connection.lastVerifiedAt)}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                if (connection.needsAttention)
                  Text('Needs attention${connection.lastErrorCode.isEmpty ? '' : ' · ${connection.lastErrorCode}'}', style: TextStyle(fontSize: 12, color: scheme.error, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _date(DateTime? value) => value == null ? '' : value.toIso8601String().split('T').first;

  Widget _metric(BuildContext context, String label, String value, String note) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          Text(note, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
