import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../data/mandates_api.dart';
import 'debit_batches_tab.dart';
import 'mandate_providers_tab.dart';
import 'mandate_transactions_tab.dart';
import 'mandate_widgets.dart';
import 'mandates_overview_tab.dart';
import 'mandates_tab.dart';

/// Mandates & Direct Debit: the school's own Remita and Lendsqr connections, payers' mandates, the batches that debit them (prepared by one
/// person and approved by another) and the debits the providers report. For the owner and the Finance Office.
///
/// It is a payment path of its own, apart from Smart Money Collection (Paystack and Monnify). It needs the school's server: without one it says
/// so and shows nothing - no provider, mandate or debit is made up, and no debit is ever queued on a phone as though it had happened.
class MandatesHubPage extends StatefulWidget {
  const MandatesHubPage({super.key, required this.membership, this.onChanged});

  final SchoolMembership membership;

  /// Called after anything changes, so a dashboard behind this screen can refresh.
  final VoidCallback? onChanged;

  @override
  State<MandatesHubPage> createState() => _MandatesHubPageState();
}

class _MandatesHubPageState extends State<MandatesHubPage> with SingleTickerProviderStateMixin {
  static const _tabs = ['Overview', 'Providers', 'Mandates', 'Debit Batches', 'Transactions'];

  late final TabController _controller = TabController(length: _tabs.length, vsync: this);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = MandatesScope.maybeOf(context);
    if (api == null) return const MandatesNoServerNotice();
    final m = widget.membership;
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mandates & Direct Debit', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Remita and Lendsqr. A payer authorises a mandate; an approved debit is executed by the provider and settled into the fee ledger.'),
              ],
            ),
          ),
        ),
        TabBar(controller: _controller, isScrollable: true, tabs: [for (final t in _tabs) Tab(text: t)]),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: [
              MandatesOverviewTab(api: api, membership: m, onOpenTab: _controller.animateTo),
              MandateProvidersTab(api: api, membership: m, onChanged: widget.onChanged),
              MandatesTab(api: api, membership: m, onChanged: widget.onChanged),
              DebitBatchesTab(api: api, membership: m, onChanged: widget.onChanged),
              MandateTransactionsTab(api: api, membership: m, canCheck: true),
            ],
          ),
        ),
      ],
    );
  }
}
