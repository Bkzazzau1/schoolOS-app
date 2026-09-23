import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/parent_finance_demo_data.dart';
import '../data/parent_finance_repository.dart';
import '../domain/parent_finance_models.dart';

// The real choices a guardian can actually pick for a payment mandate. A fresh family's real mandate
// preference honestly reads "Not recorded yet" for collectionMethod (no real one has ever been
// configured) — that value is correct for a read-only display, but it is not a selectable option here,
// so initializing the picker to it would crash. The dropdown always falls back to a real option instead.
const _mandateDebitDays = ['5th', '10th', '15th', '20th', '25th', '28th'];
const _mandateCollectionMethods = [
  'Bank direct debit · prototype',
  'Salary-linked collection · prototype',
];

class ParentFinancePage extends StatefulWidget {
  const ParentFinancePage({
    super.key,
    required this.repository,
    required this.onQueueChanged,
  });

  final ParentFinanceRepository repository;
  final VoidCallback onQueueChanged;

  @override
  State<ParentFinancePage> createState() => _ParentFinancePageState();
}

class _ParentFinancePageState extends State<ParentFinancePage> {
  late Future<ParentFinanceViewData> _future;
  ParentFinanceViewData? _current;
  bool _controlsInitialized = false;
  bool _autoPay = true;
  String _debitDay = '25th';
  String _mandateAmount = '30000';
  String _collectionMethod = 'Bank direct debit · prototype';
  final Map<String, bool> _selectedAccounts = <String, bool>{};
  final Map<String, String> _payAmounts = <String, String>{};
  bool _savingMandate = false;
  bool _queueingPayment = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ParentFinanceViewData> _load() async {
    final data = await widget.repository.load();
    _current = data;
    if (!_controlsInitialized) {
      _autoPay = data.snapshot.mandate.enabled;
      _debitDay = _mandateDebitDays.contains(data.snapshot.mandate.debitDay)
          ? data.snapshot.mandate.debitDay
          : _mandateDebitDays.first;
      _mandateAmount = data.snapshot.mandate.monthlyAmount.toString();
      _collectionMethod = _mandateCollectionMethods.contains(data.snapshot.mandate.collectionMethod)
          ? data.snapshot.mandate.collectionMethod
          : _mandateCollectionMethods.first;
      for (final child in data.snapshot.children) {
        _selectedAccounts[child.accountNumber] = true;
        _payAmounts[child.accountNumber] = child.balance.toString();
      }
      _controlsInitialized = true;
    }
    return data;
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  Future<void> _queueCombinedPayment() async {
    final data = _current;
    if (data == null || _queueingPayment) return;

    final allocations = <ParentCombinedPaymentAllocation>[];
    for (final child in data.snapshot.children) {
      if (_selectedAccounts[child.accountNumber] != true) continue;
      final amount = int.tryParse(_payAmounts[child.accountNumber] ?? '') ?? 0;
      allocations.add(
        ParentCombinedPaymentAllocation(
          childId: child.id,
          childName: child.name,
          accountNumber: child.accountNumber,
          amount: amount,
        ),
      );
    }

    setState(() {
      _queueingPayment = true;
      _notice = null;
    });
    try {
      final request = await widget.repository.queueCombinedPayment(
        allocations: allocations,
      );
      widget.onQueueChanged();
      if (!mounted) return;
      setState(() {
        _notice =
            '${request.id} queued for ${_money(request.total)}. Balances and receipts remain unchanged until server and payment-provider confirmation.';
      });
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() => _notice = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _queueingPayment = false);
    }
  }

  Future<void> _saveMandate() async {
    if (_savingMandate) return;
    final amount = int.tryParse(_mandateAmount.trim());
    if (amount == null || amount < 0) {
      setState(() => _notice = 'Enter a valid monthly mandate amount.');
      return;
    }

    setState(() {
      _savingMandate = true;
      _notice = null;
    });
    try {
      await widget.repository.saveMandatePreference(
        ParentPaymentMandatePreference(
          enabled: _autoPay,
          monthlyAmount: amount,
          debitDay: _debitDay,
          collectionMethod: _collectionMethod,
        ),
      );
      widget.onQueueChanged();
      if (!mounted) return;
      setState(() {
        _notice =
            'Payment mandate preference saved locally and queued for synchronization. This does not create a real debit instruction.';
      });
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() => _notice = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _savingMandate = false);
    }
  }

  void _openReminders(ParentFinanceSnapshot snapshot) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ParentFeeRemindersPage(snapshot: snapshot),
      ),
    );
  }

  void _openReceipts(ParentFinanceSnapshot snapshot) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ParentFinanceReceiptsPage(snapshot: snapshot),
      ),
    );
  }

  void _openPurchases(ParentFinanceSnapshot snapshot) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ParentPurchasesPage(snapshot: snapshot),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ParentFinanceViewData>(
      future: _future,
      builder: (context, state) {
        if (state.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.hasError || !state.hasData) {
          return _FinanceLoadFailure(onRetry: _refresh);
        }

        final data = state.data!;
        final snapshot = data.snapshot;
        final selectedChildren = snapshot.children
            .where((child) => _selectedAccounts[child.accountNumber] == true)
            .toList(growable: false);
        final combinedTotal = selectedChildren.fold<int>(
          0,
          (sum, child) =>
              sum + (int.tryParse(_payAmounts[child.accountNumber] ?? '') ?? 0),
        );

        return RefreshIndicator(
          onRefresh: _refresh,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 1000 ? 28.0 : 16.0;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 40),
                children: [
                  _FinanceHeader(
                    onReminders: () => _openReminders(snapshot),
                    onPurchases: () => _openPurchases(snapshot),
                    onReceipts: () => _openReceipts(snapshot),
                  ),
                  const SizedBox(height: 18),
                  _FinanceKpis(snapshot: snapshot),
                  if (_notice != null) ...[
                    const SizedBox(height: 14),
                    _Callout(text: _notice!),
                  ],
                  if (data.pendingCombinedRequests.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _QueuedPaymentsCard(requests: data.pendingCombinedRequests),
                  ],
                  const SizedBox(height: 14),
                  _CombinedPaymentCard(
                    children: snapshot.children,
                    selectedAccounts: _selectedAccounts,
                    payAmounts: _payAmounts,
                    combinedTotal: combinedTotal,
                    queueing: _queueingPayment,
                    onSelectionChanged: (account, selected) {
                      setState(() => _selectedAccounts[account] = selected);
                    },
                    onAmountChanged: (account, amount) {
                      setState(() => _payAmounts[account] = amount);
                    },
                    onQueue: selectedChildren.length >= 2 && combinedTotal > 0
                        ? _queueCombinedPayment
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _ResponsivePair(
                    left: _TermAccountsCard(
                      snapshot: snapshot,
                      onCopy: _copy,
                    ),
                    right: _MandateCard(
                      autoPay: _autoPay,
                      debitDay: _debitDay,
                      amount: _mandateAmount,
                      collectionMethod: _collectionMethod,
                      queued: data.mandateQueued,
                      saving: _savingMandate,
                      onAutoPayChanged: (value) =>
                          setState(() => _autoPay = value),
                      onDebitDayChanged: (value) =>
                          setState(() => _debitDay = value),
                      onAmountChanged: (value) =>
                          setState(() => _mandateAmount = value),
                      onCollectionMethodChanged: (value) =>
                          setState(() => _collectionMethod = value),
                      onSave: _saveMandate,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _UpcomingReminderCard(
                    reminders: snapshot.reminders,
                    onOpen: () => _openReminders(snapshot),
                  ),
                  const SizedBox(height: 14),
                  _PaymentHistoryCard(
                    ledger: snapshot.ledger,
                    onReceipts: () => _openReceipts(snapshot),
                  ),
                  const SizedBox(height: 14),
                  _ResponsivePair(
                    left: _PaymentRailsCard(
                      onPurchases: () => _openPurchases(snapshot),
                    ),
                    right: const _FinancePrincipleCard(),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _FinanceHeader extends StatelessWidget {
  const _FinanceHeader({
    required this.onReminders,
    required this.onPurchases,
    required this.onReceipts,
  });

  final VoidCallback onReminders;
  final VoidCallback onPurchases;
  final VoidCallback onReceipts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FAMILY ACCOUNT · SMART COLLECTIONS',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              'Finance & Payments',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              'Pay each child through a unique term account, make small deposits anytime, view balances and confirmed receipts.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onReminders,
              icon: const Icon(Icons.notifications_none_rounded, size: 18),
              label: const Text('Fee reminders'),
            ),
            OutlinedButton.icon(
              onPressed: onPurchases,
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text('Purchases & Orders'),
            ),
            FilledButton.tonalIcon(
              onPressed: onReceipts,
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: const Text('View receipts'),
            ),
          ],
        );
        if (constraints.maxWidth < 820) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [text, const SizedBox(height: 14), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: text),
            const SizedBox(width: 20),
            Flexible(child: actions),
          ],
        );
      },
    );
  }
}

class _FinanceKpis extends StatelessWidget {
  const _FinanceKpis({required this.snapshot});
  final ParentFinanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final items = <(String, String, String)>[
          ('Gross term fees', _money(snapshot.grossTotal), '${snapshot.children.length} linked children'),
          ('Discounts', _money(snapshot.discountTotal), 'Sibling discount'),
          ('Paid', _money(snapshot.paidTotal), 'Across all term accounts'),
          ('Outstanding', _money(snapshot.outstandingTotal), 'Net family obligation'),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _MetricCard(
                  label: item.$1,
                  value: item.$2,
                  note: item.$3,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(note, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _CombinedPaymentCard extends StatelessWidget {
  const _CombinedPaymentCard({
    required this.children,
    required this.selectedAccounts,
    required this.payAmounts,
    required this.combinedTotal,
    required this.queueing,
    required this.onSelectionChanged,
    required this.onAmountChanged,
    required this.onQueue,
  });

  final List<ParentFinanceChildAccount> children;
  final Map<String, bool> selectedAccounts;
  final Map<String, String> payAmounts;
  final int combinedTotal;
  final bool queueing;
  final void Function(String account, bool selected) onSelectionChanged;
  final void Function(String account, String amount) onAmountChanged;
  final VoidCallback? onQueue;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Pay for multiple children at once',
      subtitle:
          'Select two or more children and prepare one family payment request. Each child keeps a separate term-account allocation.',
      child: Column(
        children: [
          for (final child in children) ...[
            _CombinedPaymentRow(
              child: child,
              selected: selectedAccounts[child.accountNumber] == true,
              amount: payAmounts[child.accountNumber] ?? '',
              onSelected: (value) => onSelectionChanged(child.accountNumber, value),
              onAmountChanged: (value) => onAmountChanged(child.accountNumber, value),
            ),
            if (child != children.last) const Divider(height: 20),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Expanded(child: Text('Total for this combined payment')),
                Text(
                  _money(combinedTotal),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: queueing ? null : onQueue,
              icon: queueing
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.payments_outlined),
              label: Text(queueing ? 'Queuing…' : 'Prepare combined payment'),
            ),
          ),
          const SizedBox(height: 10),
          const _Callout(text: parentFinanceConfirmationBoundary),
        ],
      ),
    );
  }
}

class _CombinedPaymentRow extends StatelessWidget {
  const _CombinedPaymentRow({
    required this.child,
    required this.selected,
    required this.amount,
    required this.onSelected,
    required this.onAmountChanged,
  });

  final ParentFinanceChildAccount child;
  final bool selected;
  final String amount;
  final ValueChanged<bool> onSelected;
  final ValueChanged<String> onAmountChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final identity = CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: selected,
          onChanged: (value) => onSelected(value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(child.name, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text('${child.className} · Outstanding ${_money(child.balance)}'),
        );
        final field = TextFormField(
          initialValue: amount,
          enabled: selected,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: '₦',
            border: OutlineInputBorder(),
          ),
          onChanged: onAmountChanged,
        );
        if (constraints.maxWidth < 620) {
          return Column(children: [identity, field]);
        }
        return Row(
          children: [
            Expanded(child: identity),
            const SizedBox(width: 16),
            SizedBox(width: 210, child: field),
          ],
        );
      },
    );
  }
}

class _QueuedPaymentsCard extends StatelessWidget {
  const _QueuedPaymentsCard({required this.requests});
  final List<ParentCombinedPaymentRequest> requests;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Queued family payment requests',
      subtitle: 'Durable offline requests waiting for server/payment-provider processing.',
      child: Column(
        children: [
          for (final request in requests.take(4))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_upload_outlined),
              title: Text(request.id, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                '${request.allocations.map((item) => item.childName).join(' · ')}\n${_queuedTime(request.queuedAt)}',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_money(request.total), style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(request.status, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TermAccountsCard extends StatelessWidget {
  const _TermAccountsCard({required this.snapshot, required this.onCopy});
  final ParentFinanceSnapshot snapshot;
  final Future<void> Function(String value, String label) onCopy;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Student term accounts',
      subtitle: 'Each account is unique to the child and remains fixed for the active term.',
      child: Column(
        children: [
          for (final child in snapshot.children) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(child.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text('${child.className} · ${snapshot.academicPeriod}'),
                  const SizedBox(height: 10),
                  Text(child.bank, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          child.accountNumber,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy account',
                        onPressed: () => onCopy(child.accountNumber, 'Account number'),
                        icon: const Icon(Icons.copy_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: Text('Outstanding · ${_money(child.balance)}')),
                      Text(child.discountLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            if (child != snapshot.children.last) const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
          const _Callout(
            text:
                'You can deposit smaller amounts at any time. Large payments above the authorized collection limit require a special arrangement with the school Finance Office.',
          ),
        ],
      ),
    );
  }
}

class _MandateCard extends StatelessWidget {
  const _MandateCard({
    required this.autoPay,
    required this.debitDay,
    required this.amount,
    required this.collectionMethod,
    required this.queued,
    required this.saving,
    required this.onAutoPayChanged,
    required this.onDebitDayChanged,
    required this.onAmountChanged,
    required this.onCollectionMethodChanged,
    required this.onSave,
  });

  final bool autoPay;
  final String debitDay;
  final String amount;
  final String collectionMethod;
  final bool queued;
  final bool saving;
  final ValueChanged<bool> onAutoPayChanged;
  final ValueChanged<String> onDebitDayChanged;
  final ValueChanged<String> onAmountChanged;
  final ValueChanged<String> onCollectionMethodChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    const days = _mandateDebitDays;
    const methods = _mandateCollectionMethods;
    return _SectionCard(
      title: 'Automatic payment mandate',
      subtitle: 'Optional recurring collection preference connected to the school-fee ledger.',
      trailing: queued
          ? const Chip(
              avatar: Icon(Icons.schedule_send_outlined, size: 16),
              label: Text('Queued'),
            )
          : null,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: autoPay,
            onChanged: onAutoPayChanged,
            title: const Text('Automatic monthly charge'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Monthly amount',
              prefixText: '₦',
              border: OutlineInputBorder(),
            ),
            onChanged: onAmountChanged,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: debitDay,
            decoration: const InputDecoration(
              labelText: 'Preferred debit day',
              border: OutlineInputBorder(),
            ),
            items: [for (final day in days) DropdownMenuItem(value: day, child: Text(day))],
            onChanged: (value) {
              if (value != null) onDebitDayChanged(value);
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: collectionMethod,
            decoration: const InputDecoration(
              labelText: 'Collection method',
              border: OutlineInputBorder(),
            ),
            items: [for (final method in methods) DropdownMenuItem(value: method, child: Text(method))],
            onChanged: (value) {
              if (value != null) onCollectionMethodChanged(value);
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(saving ? 'Saving…' : 'Save payment mandate preference'),
            ),
          ),
          const SizedBox(height: 10),
          const _Callout(
            text:
                'This is a parent-authorized preference. Saving it locally or queuing it for sync does not create a real debit instruction.',
          ),
        ],
      ),
    );
  }
}

class _UpcomingReminderCard extends StatelessWidget {
  const _UpcomingReminderCard({required this.reminders, required this.onOpen});
  final List<ParentFeeReminder> reminders;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Upcoming fee reminder',
      subtitle: 'SchoolOS uses the current arrangement before deciding what reminder to show.',
      trailing: TextButton(onPressed: onOpen, child: const Text('Open reminder center')),
      child: Column(
        children: [
          for (final reminder in reminders)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available_outlined),
              title: Text(
                '${reminder.childName} · ${_money(reminder.nextAmount)} ${reminder.status.toLowerCase()}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('${reminder.method} · ${reminder.dateLabel}'),
            ),
        ],
      ),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  const _PaymentHistoryCard({required this.ledger, required this.onReceipts});
  final List<ParentFinanceLedgerEntry> ledger;
  final VoidCallback onReceipts;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Payment history',
      subtitle: 'Only provider/server-confirmed credits appear here and create receipts.',
      trailing: TextButton(onPressed: onReceipts, child: const Text('Open receipt center')),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Child')),
            DataColumn(label: Text('Reference')),
            DataColumn(label: Text('Channel')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Status')),
          ],
          rows: [
            for (final entry in ledger)
              DataRow(
                cells: [
                  DataCell(Text(entry.dateLabel)),
                  DataCell(Text(entry.childName)),
                  DataCell(SelectableText(entry.reference)),
                  DataCell(Text(entry.channel)),
                  DataCell(Text(_money(entry.amount), style: const TextStyle(fontWeight: FontWeight.w900))),
                  DataCell(Text(entry.status)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PaymentRailsCard extends StatelessWidget {
  const _PaymentRailsCard({required this.onPurchases});
  final VoidCallback onPurchases;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'School fees vs store purchases',
      subtitle: 'Two separate payment rails keep records clear.',
      child: Column(
        children: [
          const _ListFact(
            title: 'School fees',
            detail: 'Use the child’s static term account or a combined family payment request. These payments reduce term obligations only after confirmation.',
          ),
          const _ListFact(
            title: 'Books & uniforms',
            detail: 'Use the dynamic account assigned to that specific store order.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onPurchases,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Open Purchases & Orders'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinancePrincipleCard extends StatelessWidget {
  const _FinancePrincipleCard();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      title: 'Finance principle',
      subtitle: 'Payment history is a factual record—not a child score.',
      child: _Callout(text: parentFinancePrinciple),
    );
  }
}

class ParentFeeRemindersPage extends StatelessWidget {
  const ParentFeeRemindersPage({super.key, required this.snapshot});
  final ParentFinanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('School Fee Reminders')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const _SubpageIntro(
            kicker: 'FAMILY ACCOUNT · FEE REMINDERS',
            title: 'School Fee Reminders',
            description:
                'See upcoming school-fee commitments, scheduled deductions and reminder history for your linked children.',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final two = constraints.maxWidth >= 760;
              final width = two ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final reminder in snapshot.reminders)
                    SizedBox(width: width, child: _ReminderCard(reminder: reminder)),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Reminder history',
            subtitle: 'Messages about school-fee payments and confirmed balance changes.',
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Child')),
                  DataColumn(label: Text('Channel')),
                  DataColumn(label: Text('Message')),
                  DataColumn(label: Text('Status')),
                ],
                rows: [
                  for (final entry in snapshot.reminderHistory)
                    DataRow(cells: [
                      DataCell(Text(entry.dateLabel)),
                      DataCell(Text(entry.childName)),
                      DataCell(Text(entry.channel)),
                      DataCell(Text(entry.message)),
                      DataCell(Text(entry.status)),
                    ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const _ResponsivePair(
            left: _SectionCard(
              title: 'How reminders work',
              subtitle: 'SchoolOS uses the current finance arrangement before deciding what message to show.',
              child: Column(
                children: [
                  _ListFact(title: 'Active mandate', detail: 'Show the scheduled deduction rather than a duplicate “please pay” message.'),
                  _ListFact(title: 'Payment plan', detail: 'Show only the agreed instalment, not the full balance as immediately due.'),
                  _ListFact(title: 'Recent payment', detail: 'Reminder timing updates after a confirmed credit reduces the balance.'),
                ],
              ),
            ),
            right: _SectionCard(
              title: 'Need another arrangement?',
              subtitle: 'Contact Finance if the current payment plan needs review.',
              child: _Callout(
                text:
                    'A reminder is a finance communication only. It does not affect a child’s grades, classroom participation, teacher support or academic record.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.reminder});
  final ParentFeeReminder reminder;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: reminder.childName,
      subtitle: '${reminder.className} · 2026/2027 Term 1',
      trailing: Chip(label: Text(reminder.status)),
      child: Column(
        children: [
          _InfoGrid(items: [
            ('Outstanding', _money(reminder.balance)),
            ('Next expected payment', _money(reminder.nextAmount)),
            ('Date', reminder.dateLabel),
            ('Collection method', reminder.method),
          ]),
          const SizedBox(height: 10),
          _Callout(text: reminder.message),
        ],
      ),
    );
  }
}

class ParentFinanceReceiptsPage extends StatefulWidget {
  const ParentFinanceReceiptsPage({super.key, required this.snapshot});
  final ParentFinanceSnapshot snapshot;

  @override
  State<ParentFinanceReceiptsPage> createState() => _ParentFinanceReceiptsPageState();
}

class _ParentFinanceReceiptsPageState extends State<ParentFinanceReceiptsPage> {
  String? _selectedNumber;

  @override
  Widget build(BuildContext context) {
    final receipts = widget.snapshot.receipts;
    final selected = receipts.firstWhere(
      (item) => item.number == _selectedNumber,
      orElse: () => receipts.first,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Receipts'),
        actions: [
          IconButton(
            tooltip: 'Copy receipt details',
            onPressed: () => _copyReceipt(context, selected),
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const _SubpageIntro(
            kicker: 'FAMILY ACCOUNT · RECEIPTS',
            title: 'Payment Receipts',
            description: 'Confirmed school-fee payments for your linked children.',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final history = _SectionCard(
                title: 'Receipt history',
                subtitle: 'Select any confirmed payment.',
                child: Column(
                  children: [
                    for (final receipt in receipts)
                      ListTile(
                        selected: receipt.number == selected.number,
                        selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        title: Text('${receipt.student} · ${_money(receipt.amount)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${receipt.dateLabel} · ${receipt.method}\n${receipt.number}'),
                        onTap: () => setState(() => _selectedNumber = receipt.number),
                      ),
                  ],
                ),
              );
              final detail = _ReceiptDetail(receipt: selected, academicPeriod: widget.snapshot.academicPeriod);
              if (constraints.maxWidth < 820) {
                return Column(children: [history, const SizedBox(height: 14), detail]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 360, child: history),
                  const SizedBox(width: 14),
                  Expanded(child: detail),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _copyReceipt(BuildContext context, ParentFinanceReceipt receipt) async {
    final text = [
      'BrightGate Academy · Payment Receipt',
      'Receipt: ${receipt.number}',
      'Student: ${receipt.student}',
      'Admission: ${receipt.admissionNumber}',
      'Class: ${receipt.className}',
      'Amount: ${_money(receipt.amount)}',
      'Date: ${receipt.dateLabel}',
      'Method: ${receipt.method}',
      'Reference: ${receipt.reference}',
      'Previous balance: ${_money(receipt.previousBalance)}',
      'New balance: ${_money(receipt.newBalance)}',
      'Status: Confirmed',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt details copied')),
    );
  }
}

class _ReceiptDetail extends StatelessWidget {
  const _ReceiptDetail({required this.receipt, required this.academicPeriod});
  final ParentFinanceReceipt receipt;
  final String academicPeriod;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'BrightGate Academy',
      subtitle: 'Kaduna Campus · PAYMENT RECEIPT',
      trailing: const Chip(label: Text('Confirmed')),
      child: Column(
        children: [
          _InfoGrid(items: [
            ('Receipt No.', receipt.number),
            ('Student', receipt.student),
            ('Admission No.', receipt.admissionNumber),
            ('Class', receipt.className),
            ('Term', academicPeriod),
            ('Amount paid', _money(receipt.amount)),
            ('Payment method', receipt.method),
            ('Transaction ref', receipt.reference),
            ('Payment date', receipt.dateLabel),
            ('Previous balance', _money(receipt.previousBalance)),
            ('New balance', _money(receipt.newBalance)),
            ('Status', 'Confirmed'),
          ]),
          const SizedBox(height: 12),
          const _Callout(
            text:
                'This receipt exists only for a confirmed credit. A queued or pending payment request must never generate a confirmed receipt.',
          ),
        ],
      ),
    );
  }
}

class ParentPurchasesPage extends StatefulWidget {
  const ParentPurchasesPage({super.key, required this.snapshot});
  final ParentFinanceSnapshot snapshot;

  @override
  State<ParentPurchasesPage> createState() => _ParentPurchasesPageState();
}

class _ParentPurchasesPageState extends State<ParentPurchasesPage> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final orders = widget.snapshot.storeOrders;
    final current = orders.firstWhere(
      (item) => item.id == _selectedId,
      orElse: () => orders.first,
    );
    final paid = orders.where((item) => item.status != 'Awaiting payment').length;
    final awaiting = orders.where((item) => item.status == 'Awaiting payment').length;
    final readyOrPending = orders.where((item) => item.issueStatus != 'Not issued').length;

    return Scaffold(
      appBar: AppBar(title: const Text('Purchases & Orders')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const _SubpageIntro(
            kicker: 'FAMILY FINANCE · SCHOOL STORE',
            title: 'Purchases & Orders',
            description:
                'Books, uniforms and other school-store purchases are kept separate from school-fee payments.',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final items = <(String, String, String)>[
                ('Open orders', '${orders.length}', 'Current family orders'),
                ('Paid orders', '$paid', 'Separate from tuition'),
                ('Awaiting payment', '$awaiting', 'Dynamic account active'),
                ('Ready / pending issue', '$readyOrPending', 'Collection status tracked'),
              ];
              final columns = constraints.maxWidth >= 950 ? 4 : constraints.maxWidth >= 520 ? 2 : 1;
              const gap = 12.0;
              final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final item in items)
                    SizedBox(width: width, child: _MetricCard(label: item.$1, value: item.$2, note: item.$3)),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final orderList = _SectionCard(
                title: 'Orders',
                subtitle: 'Select an order to see payment and issue details.',
                child: Column(
                  children: [
                    for (final order in orders)
                      ListTile(
                        selected: order.id == current.id,
                        selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        title: Text('${order.childName} · ${order.id}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${order.items.join(' · ')}\n${_money(order.amount)} · ${order.status}'),
                        onTap: () => setState(() => _selectedId = order.id),
                      ),
                  ],
                ),
              );
              final detail = _StoreOrderDetail(order: current);
              if (constraints.maxWidth < 820) {
                return Column(children: [orderList, const SizedBox(height: 14), detail]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 390, child: orderList),
                  const SizedBox(width: 14),
                  Expanded(child: detail),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          const _SectionCard(
            title: 'Why this payment is separate',
            subtitle: 'The school-fee term account is never used for store purchases.',
            child: Column(
              children: [
                _ListFact(title: 'School fees', detail: 'Use the child’s static term account. Confirmed payments reduce tuition/term obligations only.'),
                _ListFact(title: 'Books & uniforms', detail: 'Each order receives a separate temporary account for the exact invoice amount.'),
                _ListFact(title: 'After payment', detail: 'The store order changes to paid only after confirmation; a store receipt becomes available and issue/collection status is tracked until completion.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreOrderDetail extends StatelessWidget {
  const _StoreOrderDetail({required this.order});
  final ParentStoreOrder order;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: order.id,
      subtitle: '${order.childName} · ${order.className}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Order payment account', style: TextStyle(fontWeight: FontWeight.w800)),
                Text(order.bank),
                const SizedBox(height: 8),
                SelectableText(order.accountNumber, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: 1)),
                Text('Exact amount · ${_money(order.amount)}'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: order.accountNumber));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Order payment account copied')),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy payment account'),
            ),
          ),
          const SizedBox(height: 10),
          _InfoGrid(items: [
            ('Payment status', order.status),
            ('Issue status', order.issueStatus),
            ('Account expiry', order.expiresLabel),
            ('Store receipt', order.receiptNumber),
          ]),
        ],
      ),
    );
  }
}

class _SubpageIntro extends StatelessWidget {
  const _SubpageIntro({
    required this.kicker,
    required this.title,
    required this.description,
  });

  final String kicker;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kicker,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
        ),
        const SizedBox(height: 5),
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(description, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 850) {
          return Column(children: [left, const SizedBox(height: 14), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 14),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 680 ? 3 : constraints.maxWidth >= 360 ? 2 : 1;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.$1, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w900)),
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

class _ListFact extends StatelessWidget {
  const _ListFact({required this.title, required this.detail});
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 19, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(detail),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(height: 1.4)),
    );
  }
}

class _FinanceLoadFailure extends StatelessWidget {
  const _FinanceLoadFailure({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 44),
            const SizedBox(height: 12),
            const Text('Unable to open family finance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('The locally available finance record could not be loaded.'),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

String _money(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    out.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) out.write(',');
  }
  return '${negative ? '-' : ''}₦$out';
}

String _queuedTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}
