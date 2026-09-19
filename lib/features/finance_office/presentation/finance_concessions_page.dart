import 'package:flutter/material.dart';

import '../data/finance_concessions_demo_data.dart';
import '../data/finance_concessions_repository.dart';
import '../domain/finance_concessions_models.dart';

class FinanceConcessionsPage extends StatefulWidget {
  const FinanceConcessionsPage({
    super.key,
    required this.repository,
    required this.onMutationQueued,
  });

  final FinanceConcessionsRepository repository;
  final VoidCallback onMutationQueued;

  @override
  State<FinanceConcessionsPage> createState() => _FinanceConcessionsPageState();
}

class _FinanceConcessionsPageState extends State<FinanceConcessionsPage> {
  final _formKey = GlobalKey<FormState>();
  final _student = TextEditingController();
  final _className = TextEditingController();
  final _grossFee = TextEditingController();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final _requestedBy = TextEditingController(text: 'Mr. Ahmad Bello');

  String _filter = 'All';
  FinanceConcessionType _type = FinanceConcessionType.scholarship;
  bool _showForm = false;
  String? _notice;
  late Future<FinanceConcessionsSnapshot> _future;

  static const _filters = <String>[
    'All',
    'Scholarship',
    'Discount',
    'Pending Approval',
    'Approved',
    'Declined',
  ];

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  @override
  void dispose() {
    _student.dispose();
    _className.dispose();
    _grossFee.dispose();
    _amount.dispose();
    _reason.dispose();
    _requestedBy.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _future = widget.repository.load());

  List<FinanceConcessionRequest> _visible(List<FinanceConcessionRequest> items) {
    if (_filter == 'All') return items;
    return items.where((item) {
      return financeConcessionTypeLabel(item.type) == _filter ||
          financeConcessionStatusLabel(item.status) == _filter;
    }).toList(growable: false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final result = await widget.repository.submit(
      student: _student.text,
      className: _className.text,
      type: _type,
      grossFee: int.tryParse(_grossFee.text) ?? -1,
      amount: int.tryParse(_amount.text) ?? -1,
      reason: _reason.text,
      requestedBy: _requestedBy.text,
    );
    if (!mounted) return;
    setState(() {
      _notice = result.message;
      if (result.success) {
        _student.clear();
        _className.clear();
        _grossFee.clear();
        _amount.clear();
        _reason.clear();
        _type = FinanceConcessionType.scholarship;
        _showForm = false;
      }
    });
    if (result.success) {
      widget.onMutationQueued();
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FinanceConcessionsSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 42),
                  const SizedBox(height: 12),
                  const Text('Could not load concession records.'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final visible = _visible(data.requests);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _Header(
              filter: _filter,
              filters: _filters,
              onFilterChanged: (value) => setState(() => _filter = value),
              canSubmit: data.canSubmit,
              onToggleForm: () => setState(() {
                _showForm = !_showForm;
                _notice = null;
              }),
            ),
            const SizedBox(height: 16),
            _Kpis(snapshot: data),
            const SizedBox(height: 14),
            const _InfoNotice(),
            if (_notice != null) ...[
              const SizedBox(height: 10),
              _Notice(text: _notice!),
            ],
            if (_showForm) ...[
              const SizedBox(height: 14),
              _RequestForm(
                formKey: _formKey,
                student: _student,
                className: _className,
                grossFee: _grossFee,
                amount: _amount,
                reason: _reason,
                requestedBy: _requestedBy,
                type: _type,
                onTypeChanged: (value) => setState(() => _type = value),
                onCancel: () => setState(() => _showForm = false),
                onSubmit: _submit,
              ),
            ],
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 920;
                final ledger = _Ledger(items: visible);
                const types = _ConcessionTypesCard();
                return narrow
                    ? Column(children: [ledger, const SizedBox(height: 14), types])
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: ledger),
                          const SizedBox(width: 14),
                          const Expanded(child: types),
                        ],
                      );
              },
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 760;
                const funding = _FundingSourceCard();
                const control = _ControlPrincipleCard();
                return narrow
                    ? const Column(children: [funding, SizedBox(height: 14), control])
                    : const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Expanded(child: funding), SizedBox(width: 14), Expanded(child: control)],
                      );
              },
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.filter,
    required this.filters,
    required this.onFilterChanged,
    required this.canSubmit,
    required this.onToggleForm,
  });

  final String filter;
  final List<String> filters;
  final ValueChanged<String> onFilterChanged;
  final bool canSubmit;
  final VoidCallback onToggleForm;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FINANCE OFFICE · CONCESSIONS', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('Scholarships & Discounts', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Track every concession request separately so proprietors never confuse supported students with unpaid debt.'),
            ],
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<String>(
                initialValue: filter,
                decoration: const InputDecoration(labelText: 'Filter'),
                items: [for (final item in filters) DropdownMenuItem(value: item, child: Text(item))],
                onChanged: (value) { if (value != null) onFilterChanged(value); },
              ),
            ),
            FilledButton.icon(
              onPressed: canSubmit ? onToggleForm : null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New concession request'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.snapshot});
  final FinanceConcessionsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Gross fee represented', financeMoney(snapshot.approvedGrossTotal), 'Approved concession population'),
      ('Scholarships & discounts', financeMoney(snapshot.approvedConcessionTotal), 'Approved concessions only'),
      ('Net parent obligation', financeMoney(snapshot.netParentObligation), 'After approved concessions'),
      ('Students supported', '${snapshot.studentsSupported}', 'Approved records'),
      ('Pending proprietor review', '${snapshot.pendingCount}', 'Awaiting approval'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final item in items)
          SizedBox(
            width: 210,
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.$1, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 5),
                  Text(item.$2, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(item.$3, style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoNotice extends StatelessWidget {
  const _InfoNotice();
  @override
  Widget build(BuildContext context) => const _Notice(
        text: 'Only the Proprietor can approve a scholarship or discount. Finance Office, Administrator, Head Master, Principal and Director accounts may submit a request — it stays Pending Approval until the Proprietor decides.',
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text),
      );
}

class _RequestForm extends StatelessWidget {
  const _RequestForm({
    required this.formKey,
    required this.student,
    required this.className,
    required this.grossFee,
    required this.amount,
    required this.reason,
    required this.requestedBy,
    required this.type,
    required this.onTypeChanged,
    required this.onCancel,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController student;
  final TextEditingController className;
  final TextEditingController grossFee;
  final TextEditingController amount;
  final TextEditingController reason;
  final TextEditingController requestedBy;
  final FinanceConcessionType type;
  final ValueChanged<FinanceConcessionType> onTypeChanged;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('New concession request', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text("This goes to the Proprietor's approval queue. It will not reduce any fee until approved."),
            const SizedBox(height: 14),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _Field(width: 250, child: TextFormField(controller: student, decoration: const InputDecoration(labelText: 'Student name'), validator: _required)),
              _Field(width: 200, child: TextFormField(controller: className, decoration: const InputDecoration(labelText: 'Class'), validator: _required)),
              _Field(width: 190, child: DropdownButtonFormField<FinanceConcessionType>(initialValue: type, decoration: const InputDecoration(labelText: 'Type'), items: const [DropdownMenuItem(value: FinanceConcessionType.scholarship, child: Text('Scholarship')), DropdownMenuItem(value: FinanceConcessionType.discount, child: Text('Discount'))], onChanged: (value) { if (value != null) onTypeChanged(value); })),
              _Field(width: 210, child: TextFormField(controller: grossFee, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Gross term fee (₦)'), validator: _nonNegative)),
              _Field(width: 220, child: TextFormField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Concession amount (₦)'), validator: _nonNegative)),
              _Field(width: 260, child: TextFormField(controller: reason, decoration: const InputDecoration(labelText: 'Reason / sponsor'))),
              _Field(width: 230, child: TextFormField(controller: requestedBy, decoration: const InputDecoration(labelText: 'Requested by (name)'), validator: _required)),
              const _Field(width: 210, child: InputDecorator(decoration: InputDecoration(labelText: 'Requesting as'), child: Text('Finance Office'))),
            ]),
            const SizedBox(height: 14),
            Wrap(spacing: 10, children: [OutlinedButton(onPressed: onCancel, child: const Text('Cancel')), FilledButton(onPressed: onSubmit, child: const Text('Send to Proprietor for approval'))]),
          ]),
        ),
      ),
    );
  }

  static String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;
  static String? _nonNegative(String? value) {
    final parsed = int.tryParse(value ?? '');
    return parsed == null || parsed < 0 ? 'Enter a valid amount' : null;
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.width, required this.child});
  final double width;
  final Widget child;
  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: child);
}

class _Ledger extends StatelessWidget {
  const _Ledger({required this.items});
  final List<FinanceConcessionRequest> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Concession ledger', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Every request shows the original fee and the amount the family owes once a decision is made.'),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Text('No concession requests match this filter.'))
          else
            ...items.map((item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.student, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${item.className} · ${financeConcessionTypeLabel(item.type)} · ${item.requestedByRole}\nGross ${financeMoney(item.grossFee)} · Concession ${financeMoney(item.amount)}'),
                  isThreeLine: true,
                  trailing: Chip(label: Text(financeConcessionStatusLabel(item.status))),
                )),
        ]),
      ),
    );
  }
}

class _ConcessionTypesCard extends StatelessWidget {
  const _ConcessionTypesCard();
  @override
  Widget build(BuildContext context) => const _SimpleCard(
        title: 'Concession types',
        subtitle: 'Keep financial support explicit and reportable.',
        lines: [
          ('Scholarships', 'Founder, academic, community, sports or external sponsor awards. · Tracked as support, not debt.'),
          ('Discounts', 'Sibling, staff-child and policy-based reductions. · Reduces billable amount before collection.'),
          ('Approval authority', 'Finance Office, Administrator, Head Master, Principal and Directors can request. · Only the Proprietor can approve.'),
          ('Audit trail', "Every decision records who approved it and when. · Visible on the Proprietor's approval queue"),
        ],
      );
}

class _FundingSourceCard extends StatelessWidget {
  const _FundingSourceCard();
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Funding source', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const Text('Who absorbs the concession.'),
            const SizedBox(height: 14),
            for (final row in financeConcessionFundingRows) ...[
              Row(children: [Expanded(child: Text(row.label)), Text(row.value, style: const TextStyle(fontWeight: FontWeight.w800))]),
              const SizedBox(height: 5),
              LinearProgressIndicator(value: row.percent / 100),
              const SizedBox(height: 12),
            ],
          ]),
        ),
      );
}

class _ControlPrincipleCard extends StatelessWidget {
  const _ControlPrincipleCard();
  @override
  Widget build(BuildContext context) => const _SimpleCard(
        title: 'Control principle',
        subtitle: 'The collection engine uses the net obligation.',
        lines: [('Net obligation', financeConcessionControlPrinciple)],
      );
}

class _SimpleCard extends StatelessWidget {
  const _SimpleCard({required this.title, required this.subtitle, required this.lines});
  final String title;
  final String subtitle;
  final List<(String, String)> lines;
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            Text(subtitle),
            const SizedBox(height: 12),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(line.$1, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(line.$2)]),
              ),
          ]),
        ),
      );
}
