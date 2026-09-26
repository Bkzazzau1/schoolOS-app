import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../familyfees/data/family_fees_api.dart';
import '../../smartcollect/data/smart_collect_api.dart';
import '../../smartcollect/presentation/accounts_tab.dart';
import '../../smartcollect/presentation/batches_tab.dart';
import '../../smartcollect/presentation/collection_batch_screen.dart';
import '../../smartcollect/presentation/policy_tab.dart';
import '../data/bank_connect_api.dart';
import 'bank_widgets.dart';
import 'collections_overview_tab.dart';
import 'payments_tab.dart';
import 'providers_tab.dart';
import 'review_tab.dart';

/// Smart Money Collection: the school's own collection provider (Paystack or Monnify), the collection accounts families pay
/// into, the policy for them, the batches that make them (prepared by one person and approved by another), and the payments that
/// arrive and are matched to families. For the owner and the Finance Office.
///
/// It needs the school's server. Without one it says so and shows nothing: no provider, account or payment is made up.
class CollectionsHubPage extends StatefulWidget {
  const CollectionsHubPage({super.key, required this.membership, this.onChanged, this.saveExport = saveExportToDocuments});

  final SchoolMembership membership;

  /// Called after anything changes, so a dashboard behind this screen can refresh.
  final VoidCallback? onChanged;

  /// Where a batch export is saved (a test replaces it).
  final SaveExport saveExport;

  @override
  State<CollectionsHubPage> createState() => _CollectionsHubPageState();
}

class _CollectionsHubPageState extends State<CollectionsHubPage> with SingleTickerProviderStateMixin {
  static const _tabs = ['Overview', 'Providers', 'Collection', 'Accounts', 'Policy', 'Payments', 'Review'];
  static const _providers = 1;
  static const _batches = 2;
  static const _accounts = 3;
  static const _policy = 4;
  static const _payments = 5;
  static const _review = 6;

  late final TabController _controller = TabController(length: _tabs.length, vsync: this);
  String? _paymentsConnection;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _viewPayments(String connectionId) {
    setState(() => _paymentsConnection = connectionId);
    _controller.animateTo(_payments);
  }

  Future<void> _openBatch(SmartCollectApi api, String id) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => CollectionBatchScreen(api: api, membership: widget.membership, batchId: id, saveExport: widget.saveExport)),
    );
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final api = BankConnectScope.maybeOf(context);
    if (api == null) return const NoServerNotice();
    final smart = SmartCollectScope.maybeOf(context);
    final familyApi = FamilyFeesScope.maybeOf(context);
    final m = widget.membership;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Smart Money Collection', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'The school\'s own collection provider makes each family an account to pay into. The money goes to the school through the '
                  'provider; SchoolOS never receives or holds it. Payments are matched to families, and anything unclear waits for a person.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        TabBar(controller: _controller, isScrollable: true, tabAlignment: TabAlignment.start, tabs: [for (final t in _tabs) Tab(text: t)]),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: [
              CollectionsOverviewTab(
                api: api,
                membership: m,
                onReview: () => _controller.animateTo(_review),
                onConnect: () => _controller.animateTo(_providers),
                onChanged: widget.onChanged,
                smartApi: smart,
                onOpenBatches: () => _controller.animateTo(_batches),
                onOpenPolicy: () => _controller.animateTo(_policy),
                onOpenAccounts: () => _controller.animateTo(_accounts),
                onOpenBatch: smart == null ? null : (id) => _openBatch(smart, id),
              ),
              ProvidersTab(api: api, smartApi: smart, membership: m, onViewPayments: _viewPayments, onChanged: widget.onChanged),
              if (smart == null) const _NeedsServer('Collection batches') else BatchesTab(api: smart, membership: m, onChanged: widget.onChanged, saveExport: widget.saveExport),
              if (smart == null || familyApi == null)
                const _NeedsServer('The payment accounts families pay into')
              else
                AccountsTab(api: smart, familyApi: familyApi, membership: m, onChanged: widget.onChanged),
              if (smart == null) const _NeedsServer('The collection policy') else PolicyTab(api: smart, familyApi: familyApi, membership: m, onChanged: widget.onChanged),
              PaymentsTab(
                key: ValueKey(_paymentsConnection),
                api: api,
                membership: m,
                connectionId: _paymentsConnection,
                connectionName: _paymentsConnection == null ? null : 'One provider',
                onClearConnection: () => setState(() => _paymentsConnection = null),
                onChanged: widget.onChanged,
              ),
              ReviewTab(api: api, membership: m, onChanged: widget.onChanged),
            ],
          ),
        ),
      ],
    );
  }
}

/// Where there is no school server these things cannot exist, so none are shown or made up.
class _NeedsServer extends StatelessWidget {
  const _NeedsServer(this.what);

  final String what;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('$what come from your school\'s server, which this app is not connected to.', textAlign: TextAlign.center),
        ),
      );
}
