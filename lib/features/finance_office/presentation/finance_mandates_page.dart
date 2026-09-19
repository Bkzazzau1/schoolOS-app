import 'package:flutter/material.dart';

import '../data/finance_mandates_demo_data.dart';
import '../domain/finance_mandates_models.dart';

class FinanceMandatesPage extends StatefulWidget {
  const FinanceMandatesPage({super.key});

  @override
  State<FinanceMandatesPage> createState() => _FinanceMandatesPageState();
}

class _FinanceMandatesPageState extends State<FinanceMandatesPage> {
  String _selectedId = financeMandates.first.id;
  String? _notice;

  FinanceMandate get _current => financeMandates.firstWhere(
        (item) => item.id == _selectedId,
        orElse: () => financeMandates.first,
      );

  void _select(FinanceMandate mandate) {
    setState(() {
      _selectedId = mandate.id;
      _notice = null;
    });
  }

  void _providerPrototype(String action) {
    final mandate = _current;
    setState(() {
      _notice = switch (action) {
        'Retry collection' =>
          'Retry is still a provider prototype. No debit was attempted and ${mandate.latestAttempt.label} remains unchanged.',
        'Reschedule' =>
          'Reschedule is still a provider prototype. ${mandate.nextAttempt} remains the authoritative next attempt until the provider acknowledges a change.',
        'Pause mandate' =>
          'Pause is still a provider prototype. The mandate status remains ${mandate.status.label} until provider acknowledgement.',
        'Contact guardian' =>
          'Guardian contact workflow opened locally. This does not change consent or mandate status.',
        _ => '$action is still a website prototype action.',
      };
    });
  }

  void _headerPrototype(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action is still a website prototype action.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(onPrototype: _headerPrototype),
        const SizedBox(height: 18),
        const _KpiWrap(),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 900;
            final register = _MandateRegister(
              selectedId: _selectedId,
              onSelected: _select,
            );
            final detail = _MandateDetail(
              mandate: current,
              notice: _notice,
              onAction: _providerPrototype,
            );
            if (narrow) {
              return Column(
                children: [register, const SizedBox(height: 18), detail],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: register),
                const SizedBox(width: 18),
                Expanded(child: detail),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        const _WorkflowCard(),
        const SizedBox(height: 14),
        const _ControlBoundary(),
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
              'REVENUE ASSURANCE · CONSENT-BASED COLLECTION',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Payment Mandates',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Track parent-authorized recurring bank or salary-linked school-fee deductions.',
            ),
          ],
        );
        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton(
              onPressed: () => onPrototype('Export mandates'),
              child: const Text('Export mandates'),
            ),
            FilledButton.icon(
              onPressed: () => onPrototype('Create mandate'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create mandate'),
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
          children: [
            Expanded(child: title),
            const SizedBox(width: 18),
            actions,
          ],
        );
      },
    );
  }
}

class _KpiWrap extends StatelessWidget {
  const _KpiWrap();

  @override
  Widget build(BuildContext context) {
    const cards = <Widget>[
      _Kpi('Active mandates', '$financeMandateActiveCount', 'School-wide prototype'),
      _Kpi('Expected next 30 days', financeMandateExpectedNext30Days, 'Scheduled collections'),
      _Kpi('Successful this month', '$financeMandateSuccessfulThisMonth', 'Completed attempts'),
      _Kpi('Failed attempts', '$financeMandateFailedAttempts', 'Need action'),
      _Kpi('Pending consent', '$financeMandatePendingConsent', 'Not yet active'),
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
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(hint, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _MandateRegister extends StatelessWidget {
  const _MandateRegister({
    required this.selectedId,
    required this.onSelected,
  });

  final String selectedId;
  final ValueChanged<FinanceMandate> onSelected;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Mandate register',
      subtitle: 'Parent consent, deduction schedule and latest attempt.',
      child: Column(
        children: [
          for (final mandate in financeMandates)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: mandate.id == selectedId
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSelected(mandate),
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
                                  Text(
                                    mandate.guardian,
                                    style: const TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                  Text(mandate.children),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            _StatusChip(status: mandate.status),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 14,
                          runSpacing: 4,
                          children: [
                            Text(
                              financeMandateMoney(mandate.amount),
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            Text(mandate.day),
                            Text('Latest: ${mandate.latestAttempt.label}'),
                          ],
                        ),
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
}

class _MandateDetail extends StatelessWidget {
  const _MandateDetail({
    required this.mandate,
    required this.notice,
    required this.onAction,
  });

  final FinanceMandate mandate;
  final String? notice;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: mandate.guardian,
      subtitle: '${mandate.id} · ${mandate.children}',
      trailing: _StatusChip(status: mandate.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final facts = <(String, String)>[
                ('Authorized amount', financeMandateMoney(mandate.amount)),
                ('Schedule', mandate.day),
                ('Next attempt', mandate.nextAttempt),
                ('Latest result', mandate.latestAttempt.label),
              ];
              final itemWidth = constraints.maxWidth >= 540
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final fact in facts)
                    SizedBox(
                      width: itemWidth,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fact.$1, style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 4),
                            Text(fact.$2, style: const TextStyle(fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _InfoLine('Collection method', mandate.method),
          _InfoLine('Provider rail', mandate.provider),
          const _InfoLine('Consent record', 'Parent authorization captured · prototype'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                onPressed: () => onAction('Retry collection'),
                child: const Text('Retry collection'),
              ),
              OutlinedButton(
                onPressed: () => onAction('Reschedule'),
                child: const Text('Reschedule'),
              ),
              OutlinedButton(
                onPressed: () => onAction('Pause mandate'),
                child: const Text('Pause mandate'),
              ),
              TextButton(
                onPressed: () => onAction('Contact guardian'),
                child: const Text('Contact guardian'),
              ),
            ],
          ),
          if (notice != null) ...[
            const SizedBox(height: 10),
            _Notice(text: notice!),
          ],
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _WorkflowCard extends StatelessWidget {
  const _WorkflowCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Mandate workflow',
      subtitle: 'The UI keeps authorization, collection and school-fee posting separate but connected.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final vertical = constraints.maxWidth < 820;
          final steps = <Widget>[
            for (var i = 0; i < financeMandateWorkflow.length; i++)
              _WorkflowStep(index: i + 1, step: financeMandateWorkflow[i]),
          ];
          if (vertical) {
            return Column(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  steps[i],
                  if (i < steps.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Icon(Icons.arrow_downward_rounded),
                    ),
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                Expanded(child: steps[i]),
                if (i < steps.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(top: 28),
                    child: Icon(Icons.arrow_forward_rounded),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep({required this.index, required this.step});

  final int index;
  final FinanceMandateWorkflowStep step;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 14, child: Text('$index')),
          const SizedBox(height: 8),
          Text(step.title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(step.detail, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ControlBoundary extends StatelessWidget {
  const _ControlBoundary();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('MANDATE CONTROL BOUNDARY', style: TextStyle(fontWeight: FontWeight.w900)),
            SizedBox(height: 8),
            Text(financeMandateConsentBoundary),
            SizedBox(height: 6),
            Text(financeMandateProviderBoundary),
            SizedBox(height: 6),
            Text(financeMandatePostingBoundary),
            SizedBox(height: 6),
            Text(financeMandateReceiptBoundary),
          ],
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
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
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final FinanceMandateStatus status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status.label),
      avatar: Icon(
        status == FinanceMandateStatus.active
            ? Icons.check_circle_outline_rounded
            : Icons.hourglass_top_rounded,
        size: 16,
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
    );
  }
}
