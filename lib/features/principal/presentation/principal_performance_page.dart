import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../data/principal_performance_demo_data.dart';
import '../domain/principal_performance_models.dart';

class PrincipalPerformancePage extends StatefulWidget {
  const PrincipalPerformancePage({
    super.key,
    required this.membership,
    required this.onNavigate,
  });

  final SchoolMembership membership;
  final ValueChanged<String> onNavigate;

  @override
  State<PrincipalPerformancePage> createState() => _PrincipalPerformancePageState();
}

class _PrincipalPerformancePageState extends State<PrincipalPerformancePage> {
  String _period = principalPerformancePeriods.first;
  String _comparison = principalPerformanceComparisons.first;

  @override
  Widget build(BuildContext context) {
    if (widget.membership.role != SchoolRole.principal) {
      return const Center(child: Text('School Performance is restricted to the active Principal membership.'));
    }

    final snapshot = principalPerformanceSnapshot;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(onNavigate: widget.onNavigate),
        const SizedBox(height: 16),
        _Controls(
          period: _period,
          comparison: _comparison,
          onPeriodChanged: (value) => setState(() => _period = value),
          onComparisonChanged: (value) => setState(() => _comparison = value),
        ),
        const SizedBox(height: 16),
        _Hero(snapshot: snapshot),
        const SizedBox(height: 16),
        _Metrics(snapshot: snapshot, onNavigate: widget.onNavigate),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final trend = _Trend(snapshot: snapshot);
            final health = _ClassHealth(snapshot: snapshot, onNavigate: widget.onNavigate);
            return constraints.maxWidth >= 980
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: trend), const SizedBox(width: 16), Expanded(child: health)])
                : Column(children: [trend, const SizedBox(height: 16), health]);
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final priorities = _Priorities(snapshot: snapshot, onNavigate: widget.onNavigate);
            final ai = _AiSummary(onNavigate: widget.onNavigate);
            return constraints.maxWidth >= 980
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: priorities), const SizedBox(width: 16), Expanded(child: ai)])
                : Column(children: [priorities, const SizedBox(height: 16), ai]);
          },
        ),
        const SizedBox(height: 16),
        _Reporting(
          period: _period,
          comparison: _comparison,
          snapshot: snapshot,
          onNavigate: widget.onNavigate,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onNavigate});
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 16,
        runSpacing: 12,
        children: [
          const SizedBox(
            width: 680,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PRINCIPAL · SCHOOL PERFORMANCE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              SizedBox(height: 4),
              Text('School Performance', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28)),
              SizedBox(height: 4),
              Text('Executive academic and operational scorecard across the current school term.'),
            ]),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(onPressed: () => onNavigate('dashboard'), child: const Text('Dashboard')),
            OutlinedButton(onPressed: () => onNavigate('ai'), child: const Text('Principal AI')),
            OutlinedButton(onPressed: () => onNavigate('results'), child: const Text('Results & Reports')),
          ]),
        ],
      );
}

class _Controls extends StatelessWidget {
  const _Controls({required this.period, required this.comparison, required this.onPeriodChanged, required this.onComparisonChanged});
  final String period;
  final String comparison;
  final ValueChanged<String> onPeriodChanged;
  final ValueChanged<String> onComparisonChanged;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 24, runSpacing: 14, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _Selector(label: 'Reporting period', value: period, values: principalPerformancePeriods, onChanged: onPeriodChanged),
            _Selector(label: 'Compare with', value: comparison, values: principalPerformanceComparisons, onChanged: onComparisonChanged),
            SizedBox(width: 280, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(period, style: const TextStyle(fontWeight: FontWeight.w900)), const Text('Prototype term analytics · current campus', style: TextStyle(fontSize: 12))])),
          ]),
        ),
      );
}

class _Selector extends StatelessWidget {
  const _Selector({required this.label, required this.value, required this.values, required this.onChanged});
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 230,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          DropdownButton<String>(
            value: value,
            isExpanded: true,
            items: [for (final item in values) DropdownMenuItem(value: item, child: Text(item))],
            onChanged: (next) { if (next != null) onChanged(next); },
          ),
        ]),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.snapshot});
  final PrincipalPerformanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: 330, child: Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Overall school health'),
          Text('${snapshot.overallHealth}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 42)),
          const Text('Good · improving', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Most monitored indicators are moving positively, but targeted intervention is still required in a small number of classes and operational areas.'),
        ])))),
        _SummaryCard('Improving indicators', '${snapshot.improvingIndicators} / ${snapshot.metrics.length}', 'Compared with previous term'),
        _SummaryCard('Below target', '${snapshot.belowTargetIndicators}', 'Indicators not yet at school target'),
        _SummaryCard('Priority issues', '${snapshot.priorities.length}', 'Requires principal follow-up'),
      ]);
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(this.label, this.value, this.note);
  final String label, value, note;
  @override
  Widget build(BuildContext context) => SizedBox(width: 205, child: Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28)), Text(note, style: Theme.of(context).textTheme.bodySmall)]))));
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.snapshot, required this.onNavigate});
  final PrincipalPerformanceSnapshot snapshot;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Core performance indicators', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const Text('Current term versus previous term and school target.'),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [for (final metric in snapshot.metrics) _MetricCard(metric: metric, onTap: () => onNavigate(metric.routeKey))]),
          ]),
        ),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric, required this.onTap});
  final PrincipalPerformanceMetric metric;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 245,
        child: Card(
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(metric.label, style: const TextStyle(fontWeight: FontWeight.w800))), Text('${metric.delta >= 0 ? '+' : ''}${metric.delta}${metric.suffix}', style: TextStyle(fontWeight: FontWeight.w900, color: metric.delta >= 0 ? Colors.green : Theme.of(context).colorScheme.error))]),
                const SizedBox(height: 6),
                Text('${metric.current}${metric.suffix}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26)),
                Text('Previous ${metric.previous}${metric.suffix} · Target ${metric.target}${metric.suffix}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: metric.targetProgress),
              ]),
            ),
          ),
        ),
      );
}

class _Trend extends StatelessWidget {
  const _Trend({required this.snapshot});
  final PrincipalPerformanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Term trend', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const Text('How the school has moved across recent terms.'),
            const SizedBox(height: 10),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('Term')), DataColumn(label: Text('Academics')), DataColumn(label: Text('Attendance')), DataColumn(label: Text('Teachers')), DataColumn(label: Text('Operations'))], rows: [for (final row in snapshot.termTrend) DataRow(cells: [DataCell(Text(row.term)), DataCell(Text('${row.academics}%')), DataCell(Text('${row.attendance}%')), DataCell(Text('${row.teacher}%')), DataCell(Text('${row.operations}%'))])])),
          ]),
        ),
      );
}

class _ClassHealth extends StatelessWidget {
  const _ClassHealth({required this.snapshot, required this.onNavigate});
  final PrincipalPerformanceSnapshot snapshot;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Class health ranking', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)), Text('Combined academic, attendance and delivery indicators.')])), TextButton(onPressed: () => onNavigate('academics'), child: const Text('Open academics'))]),
            const SizedBox(height: 8),
            for (final row in snapshot.classHealth) ListTile(contentPadding: EdgeInsets.zero, title: Text(row.className, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(row.status), trailing: SizedBox(width: 92, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text('${row.score}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), const SizedBox(width: 10), Text('${row.trend >= 0 ? '+' : ''}${row.trend}', style: TextStyle(fontWeight: FontWeight.w900, color: row.trend >= 0 ? Colors.green : Theme.of(context).colorScheme.error))]))),
          ]),
        ),
      );
}

class _Priorities extends StatelessWidget {
  const _Priorities({required this.snapshot, required this.onNavigate});
  final PrincipalPerformanceSnapshot snapshot;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Principal priorities', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const Text('Areas requiring human review or intervention.'),
            const SizedBox(height: 10),
            for (final item in snapshot.priorities) ListTile(contentPadding: EdgeInsets.zero, leading: Chip(label: Text(item.severity)), title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${item.area}\n${item.detail}'), isThreeLine: true, trailing: TextButton(onPressed: () => onNavigate(item.routeKey), child: const Text('Review'))),
          ]),
        ),
      );
}

class _AiSummary extends StatelessWidget {
  const _AiSummary({required this.onNavigate});
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('PRINCIPAL AI SUMMARY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            const SizedBox(height: 4),
            const Text('What the scorecard means', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 8),
            const Text(principalPerformanceAiSummary),
            const SizedBox(height: 12),
            const _Evidence('Strongest improvement', 'Lesson-plan compliance +5 pts'),
            const _Evidence('Most urgent weakness', 'JSS 2B combined health'),
            const _Evidence('Management posture', 'Targeted support'),
            const SizedBox(height: 10),
            TextButton(onPressed: () => onNavigate('ai'), child: const Text('Ask Principal AI about this scorecard')),
          ]),
        ),
      );
}

class _Evidence extends StatelessWidget {
  const _Evidence(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))]));
}

class _Reporting extends StatelessWidget {
  const _Reporting({required this.period, required this.comparison, required this.snapshot, required this.onNavigate});
  final String period;
  final String comparison;
  final PrincipalPerformanceSnapshot snapshot;
  final ValueChanged<String> onNavigate;

  Future<void> _preview(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Print-ready School Performance scorecard'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(period, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            Text('Comparison: $comparison'),
            const SizedBox(height: 12),
            Text('Overall school health: ${snapshot.overallHealth}', style: const TextStyle(fontWeight: FontWeight.w900)),
            Text('Improving indicators: ${snapshot.improvingIndicators}/${snapshot.metrics.length}'),
            Text('Below target: ${snapshot.belowTargetIndicators}'),
            Text('Priority issues: ${snapshot.priorities.length}'),
            const Divider(),
            for (final metric in snapshot.metrics) Text('${metric.label}: ${metric.current}${metric.suffix} · Previous ${metric.previous}${metric.suffix} · Target ${metric.target}${metric.suffix}'),
          ])),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const SizedBox(width: 520, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Management reporting', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)), Text('Use these views for principal review meetings and later proprietor-level reporting.')])),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(onPressed: () => onNavigate('results'), child: const Text('Academic reports')),
              OutlinedButton(onPressed: () => onNavigate('attendance'), child: const Text('Attendance report')),
              OutlinedButton(onPressed: () => onNavigate('teachers'), child: const Text('Teacher overview')),
              FilledButton.icon(onPressed: () => _preview(context), icon: const Icon(Icons.print_outlined), label: const Text('Print scorecard')),
            ]),
          ]),
        ),
      );
}
