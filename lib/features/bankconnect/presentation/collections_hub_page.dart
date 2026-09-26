import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../data/bank_connect_api.dart';
import 'bank_accounts_tab.dart';
import 'bank_widgets.dart';
import 'collections_overview_tab.dart';
import 'payments_tab.dart';
import 'review_tab.dart';

/// Smart Money Collection: the school's own bank accounts, the payments they receive, and the
/// matching of those payments to students. For the owner and the Finance Office.
///
/// It needs the school's server. Without one it says so and shows nothing: no accounts and no
/// payments are made up.
class CollectionsHubPage extends StatefulWidget {
  const CollectionsHubPage({super.key, required this.membership, this.onChanged});

  final SchoolMembership membership;

  /// Called after anything changes, so a dashboard behind this screen can refresh.
  final VoidCallback? onChanged;

  @override
  State<CollectionsHubPage> createState() => _CollectionsHubPageState();
}

class _CollectionsHubPageState extends State<CollectionsHubPage> with SingleTickerProviderStateMixin {
  static const _tabs = ['Overview', 'Bank accounts', 'Payments', 'Review'];

  late final TabController _controller = TabController(length: _tabs.length, vsync: this);
  String? _paymentsConnection;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _viewPayments(String connectionId) {
    setState(() => _paymentsConnection = connectionId);
    _controller.animateTo(2);
  }

  @override
  Widget build(BuildContext context) {
    final api = BankConnectScope.maybeOf(context);
    if (api == null) return const NoServerNotice();
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
                  'The school\'s own bank accounts, connected securely. Payments they receive are matched to students; '
                  'anything unclear waits for a person.',
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
                onReview: () => _controller.animateTo(3),
                onConnect: () => _controller.animateTo(1),
                onChanged: widget.onChanged,
              ),
              BankAccountsTab(api: api, membership: m, onViewPayments: _viewPayments, onChanged: widget.onChanged),
              PaymentsTab(
                key: ValueKey(_paymentsConnection),
                api: api,
                membership: m,
                connectionId: _paymentsConnection,
                connectionName: _paymentsConnection == null ? null : 'One account',
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
