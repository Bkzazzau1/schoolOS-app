import 'package:flutter/material.dart';

import '../data/finance_store_demo_data.dart';
import '../domain/finance_store_models.dart';

class FinanceStorePage extends StatefulWidget {
  const FinanceStorePage({super.key});

  @override
  State<FinanceStorePage> createState() => _FinanceStorePageState();
}

class _FinanceStorePageState extends State<FinanceStorePage> {
  late List<FinanceStoreOrder> _orders;
  late String _selectedId;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _orders = List<FinanceStoreOrder>.from(financeStoreOrders);
    _selectedId = _orders.first.id;
  }

  FinanceStoreOrder get _current => _orders.firstWhere(
        (order) => order.id == _selectedId,
        orElse: () => _orders.first,
      );

  void _select(FinanceStoreOrder order) {
    setState(() {
      _selectedId = order.id;
      _notice = null;
    });
  }

  void _confirmPayment() {
    setState(() {
      _notice =
          'Payment status was not changed. Authoritative bank/provider confirmation is required before this order can become Paid · ready.';
    });
  }

  void _issue() {
    final current = _current;
    if (current.status == FinanceStoreOrderStatus.awaitingPayment) {
      setState(() {
        _notice = 'Items cannot be marked fully issued while payment is still awaiting authoritative confirmation.';
      });
      return;
    }
    setState(() {
      _orders = [
        for (final order in _orders)
          if (order.id == current.id)
            order.copyWith(
              status: FinanceStoreOrderStatus.completed,
              issued: 'Fully issued',
            )
          else
            order,
      ];
      _notice = '${current.id} marked fully issued locally in this prototype.';
    });
  }

  void _prototype(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action is still a website prototype action.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totals = financeStoreTotals(_orders);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(onPrototype: _prototype),
        const SizedBox(height: 12),
        const _SampleDataBanner(
          text: 'This screen shows sample store orders, not real ones. Finance AI already treats the school store as not recorded yet; this screen is not yet connected to real orders or stock.',
        ),
        const SizedBox(height: 18),
        _Kpis(totals: totals),
        const SizedBox(height: 18),
        const _CollectionRails(),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 920;
            final orders = _OrderList(
              orders: _orders,
              selectedId: _selectedId,
              onSelected: _select,
            );
            final detail = _OrderDetail(
              order: _current,
              notice: _notice,
              onConfirmPayment: _confirmPayment,
              onIssue: _issue,
              onPrintReceipt: () => _prototype('Print store receipt'),
            );
            if (narrow) {
              return Column(children: [orders, const SizedBox(height: 18), detail]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: orders),
                const SizedBox(width: 18),
                Expanded(child: detail),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return const Column(
                children: [
                  _InventoryCard(),
                  SizedBox(height: 18),
                  _ExceptionsCard(),
                ],
              );
            }
            return const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _InventoryCard()),
                SizedBox(width: 18),
                Expanded(child: _ExceptionsCard()),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        const _BoundaryCard(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onPrototype});
  final ValueChanged<String> onPrototype;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FINANCE OFFICE · SCHOOL STORE & SUNDRY COLLECTIONS',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'School Store & Collections',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Separate tuition from books, uniforms and other school purchases using order-specific payment accounts.',
            ),
          ],
        );
        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => onPrototype('New order'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New order'),
            ),
            FilledButton(
              onPressed: () => onPrototype('Assign payment account'),
              child: const Text('Assign payment account'),
            ),
          ],
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 14), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [Expanded(child: title), const SizedBox(width: 18), actions],
        );
      },
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.totals});
  final FinanceStoreTotals totals;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _Kpi('Store sales', financeStoreMoney(totals.sales), 'Paid sample orders'),
      _Kpi('Open orders', '${totals.openOrders}', 'Awaiting payment or issue'),
      _Kpi('Paid not fully issued', '${totals.paidNotFullyIssued}', 'Owner-visible exception'),
      _Kpi('Awaiting payment', '${totals.awaitingPayment}', 'Dynamic account active'),
      _Kpi('Low-stock items', '${totals.lowStockItems}', 'Review replenishment'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth = width >= 1180
            ? (width - 48) / 5
            : width >= 720
                ? (width - 24) / 3
                : width;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final card in cards) SizedBox(width: itemWidth, child: card)],
        );
      },
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.hint);
  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(hint, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}

class _CollectionRails extends StatelessWidget {
  const _CollectionRails();

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Two separate collection rails', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final schoolFees = _Rail(title: financeStoreFeeRailTitle, text: financeStoreFeeRailRule);
                  final sundry = _Rail(title: financeStoreSundryRailTitle, text: financeStoreSundryRailRule);
                  if (constraints.maxWidth < 680) {
                    return Column(children: [schoolFees, const SizedBox(height: 10), sundry]);
                  }
                  return Row(children: [Expanded(child: schoolFees), const SizedBox(width: 10), Expanded(child: sundry)]);
                },
              ),
            ],
          ),
        ),
      );
}

class _Rail extends StatelessWidget {
  const _Rail({required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(text)],
        ),
      );
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders, required this.selectedId, required this.onSelected});
  final List<FinanceStoreOrder> orders;
  final String selectedId;
  final ValueChanged<FinanceStoreOrder> onSelected;

  @override
  Widget build(BuildContext context) => _CardShell(
        title: 'Orders & payment accounts',
        subtitle: 'Every order has its own expected amount, temporary account and issue status.',
        child: Column(
          children: [
            for (final order in orders)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: order.id == selectedId
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onSelected(order),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
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
                                    Text(order.student, style: const TextStyle(fontWeight: FontWeight.w900)),
                                    Text('${order.className} · ${order.id}'),
                                    Text(order.items, style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              _StatusChip(status: order.status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(financeStoreMoney(order.amount), style: const TextStyle(fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _OrderDetail extends StatelessWidget {
  const _OrderDetail({
    required this.order,
    required this.notice,
    required this.onConfirmPayment,
    required this.onIssue,
    required this.onPrintReceipt,
  });
  final FinanceStoreOrder order;
  final String? notice;
  final VoidCallback onConfirmPayment;
  final VoidCallback onIssue;
  final VoidCallback onPrintReceipt;

  @override
  Widget build(BuildContext context) => _CardShell(
        title: order.id,
        subtitle: '${order.student} · ${order.guardian}',
        trailing: _StatusChip(status: order.status),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DYNAMIC ORDER ACCOUNT'),
                  const SizedBox(height: 6),
                  SelectableText(order.account, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('Partner Bank Store Rail · expires ${order.expires}'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _DetailGrid(order: order),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton(onPressed: onConfirmPayment, child: const Text('Confirm payment')),
                OutlinedButton(onPressed: onIssue, child: const Text('Mark items issued')),
                TextButton(onPressed: onPrintReceipt, child: const Text('Print store receipt')),
              ],
            ),
            if (notice != null) ...[
              const SizedBox(height: 10),
              _Notice(text: notice!),
            ],
            const SizedBox(height: 10),
            Text(financeStorePaymentBoundary, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.order});
  final FinanceStoreOrder order;

  @override
  Widget build(BuildContext context) {
    final facts = <(String, String)>[
      ('Expected amount', financeStoreMoney(order.amount)),
      ('Maximum receivable', financeStoreMoney(order.amount)),
      ('Items', order.items),
      ('Issue status', order.issued),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 560 ? (constraints.maxWidth - 10) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final fact in facts)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fact.$1, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(fact.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard();

  @override
  Widget build(BuildContext context) => _CardShell(
        title: 'Inventory movement',
        subtitle: 'Monitor what was received, sold/issued and what remains available.',
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Item')),
              DataColumn(label: Text('Opening')),
              DataColumn(label: Text('Issued')),
              DataColumn(label: Text('Available')),
              DataColumn(label: Text('Price')),
            ],
            rows: [
              for (final item in financeStoreStock)
                DataRow(
                  cells: [
                    DataCell(Text(item.item, style: const TextStyle(fontWeight: FontWeight.w800))),
                    DataCell(Text('${item.opening}')),
                    DataCell(Text('${item.issued}')),
                    DataCell(Text('${item.available}')),
                    DataCell(Text(financeStoreMoney(item.price))),
                  ],
                ),
            ],
          ),
        ),
      );
}

class _ExceptionsCard extends StatelessWidget {
  const _ExceptionsCard();

  @override
  Widget build(BuildContext context) => _CardShell(
        title: 'Store control exceptions',
        subtitle: 'Money collection and physical issue must reconcile.',
        child: Column(
          children: [
            for (final item in financeStoreControlExceptions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(item.$2),
                trailing: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(item.$3, textAlign: TextAlign.end, style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
          ],
        ),
      );
}

class _SampleDataBanner extends StatelessWidget {
  const _SampleDataBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: .35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.science_outlined, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard();

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(financeStoreRailBoundary),
              const SizedBox(height: 8),
              const Text(financeStorePrototypeBoundary),
              if (!financeStoreStock.first.reconciles) ...[
                const SizedBox(height: 8),
                Text(
                  'Source-data review: School Shirt opening/issued/available values do not arithmetically reconcile in the website prototype.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final FinanceStoreOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = switch (status) {
      FinanceStoreOrderStatus.awaitingPayment => scheme.errorContainer,
      FinanceStoreOrderStatus.paidReady => scheme.secondaryContainer,
      FinanceStoreOrderStatus.partiallyIssued => scheme.tertiaryContainer,
      FinanceStoreOrderStatus.completed => scheme.primaryContainer,
    };
    return Chip(
      backgroundColor: background,
      label: Text(status.label, overflow: TextOverflow.ellipsis),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text),
      );
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.title, required this.subtitle, required this.child, this.trailing});
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(subtitle),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 10), Flexible(child: trailing!)],
                ],
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      );
}
