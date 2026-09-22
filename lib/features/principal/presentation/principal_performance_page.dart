import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../data/principal_performance_repository.dart';
import '../domain/principal_performance_models.dart';

class PrincipalPerformancePage extends StatefulWidget {
  const PrincipalPerformancePage({
    super.key,
    required this.membership,
    required this.repository,
    required this.onNavigate,
  });

  final SchoolMembership membership;
  final PrincipalPerformanceRepository repository;
  final ValueChanged<String> onNavigate;

  @override
  State<PrincipalPerformancePage> createState() => _PrincipalPerformancePageState();
}

class _PrincipalPerformancePageState extends State<PrincipalPerformancePage> {
  PrincipalPerformanceSnapshot? _snapshot;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.membership.role != SchoolRole.principal) {
      return const Center(child: Text('School Performance is restricted to the active Principal membership.'));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          const SizedBox(height: 12),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }
    final snapshot = _snapshot;
    if (snapshot == null) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(onNavigate: widget.onNavigate),
        const SizedBox(height: 16),
        _CurrentTermNotice(),
        const SizedBox(height: 16),
        _Hero(snapshot: snapshot),
        const SizedBox(height: 16),
        _Metrics(snapshot: snapshot, onNavigate: widget.onNavigate),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final health = _ClassHealth(snapshot: snapshot, onNavigate: widget.onNavigate);
            final priorities = _Priorities(snapshot: snapshot, onNavigate: widget.onNavigate);
            return constraints.maxWidth >= 980
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: health), const SizedBox(width: 16), Expanded(child: priorities)])
                : Column(children: [health, const SizedBox(height: 16), priorities]);
          },
        ),
        const SizedBox(height: 16),
        _AiSummary(onNavigate: widget.onNavigate),
        const SizedBox(height: 16),
        _Reporting(snapshot: snapshot),
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
              Text('A live scorecard rolled up from the real Academics, Attendance, Teachers and Incidents records.'),
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

class _CurrentTermNotice extends StatelessWidget {
  const _CurrentTermNotice();

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'This scorecard reflects the current term only. Nothing in the app stores a snapshot at the end of a term yet, so a previous-term or same-term-last-year comparison is not available.',
              ),
            ),
          ]),
        ),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.snapshot});
  final PrincipalPerformanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(
          width: 330,
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Overall school health'),
                Text(
                  snapshot.overallHealth == null ? 'Not recorded' : '${snapshot.overallHealth}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 42),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.overallHealth == null
                      ? 'No indicator has real evidence recorded yet.'
                      : 'Mean progress toward target across indicators with real evidence recorded so far.',
                ),
              ]),
            ),
          ),
        ),
        _SummaryCard('Indicators with evidence', '${snapshot.evaluatedIndicators} / ${snapshot.metrics.length}', 'Have at least one real record'),
        _SummaryCard('Below target', '${snapshot.belowTargetIndicators}', 'Of the indicators with evidence'),
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
            const Text('Current term against school target. Indicators with no real record yet show "Not recorded".'),
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
                Text(metric.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  metric.hasEvidence ? '${metric.current}${metric.suffix}' : 'Not recorded',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26),
                ),
                Text('Target ${metric.target}${metric.suffix}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: metric.targetProgress),
              ]),
            ),
          ),
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
            Row(children: [
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Class health', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                  Text('Real academic average and today\'s real attendance, per Secondary class.'),
                ]),
              ),
              TextButton(onPressed: () => onNavigate('academics'), child: const Text('Open academics')),
            ]),
            const SizedBox(height: 8),
            if (snapshot.classHealth.isEmpty) const Text('No Secondary classes match this school yet.'),
            for (final row in snapshot.classHealth)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(row.className, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(row.average == null ? 'No assessment evidence recorded yet' : 'Academic average'),
                trailing: SizedBox(
                  width: 140,
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(row.average == null ? '—' : '${row.average}%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(width: 10),
                    Text('${row.attendance}% att.', style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
              ),
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
            if (snapshot.priorities.isEmpty)
              const Text('Not available yet. Flagging a genuine leadership priority needs human judgement over a pattern; nothing in the app infers one automatically. Review Academics, Attendance and Incidents directly for the real underlying figures.'),
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
            const Text('Not available yet. A written summary needs enough recorded evidence across indicators to say something real; ask Principal AI directly once more indicators have real data.'),
            const SizedBox(height: 10),
            TextButton(onPressed: () => onNavigate('ai'), child: const Text('Ask Principal AI about this scorecard')),
          ]),
        ),
      );
}

class _Reporting extends StatelessWidget {
  const _Reporting({required this.snapshot});
  final PrincipalPerformanceSnapshot snapshot;

  Future<void> _preview(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Print-ready School Performance scorecard'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Current term', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 12),
              Text('Overall school health: ${snapshot.overallHealth ?? 'Not recorded'}', style: const TextStyle(fontWeight: FontWeight.w900)),
              Text('Indicators with evidence: ${snapshot.evaluatedIndicators}/${snapshot.metrics.length}'),
              Text('Below target: ${snapshot.belowTargetIndicators}'),
              Text('Priority issues: ${snapshot.priorities.length}'),
              const Divider(),
              for (final metric in snapshot.metrics)
                Text('${metric.label}: ${metric.hasEvidence ? '${metric.current}${metric.suffix}' : 'Not recorded'} · Target ${metric.target}${metric.suffix}'),
            ]),
          ),
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
            FilledButton.icon(onPressed: () => _preview(context), icon: const Icon(Icons.print_outlined), label: const Text('Print scorecard')),
          ]),
        ),
      );
}
