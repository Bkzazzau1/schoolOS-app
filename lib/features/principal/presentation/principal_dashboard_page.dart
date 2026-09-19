import 'package:flutter/material.dart';

import '../data/principal_dashboard_demo_data.dart';
import '../domain/principal_dashboard_models.dart';

class PrincipalDashboardPage extends StatefulWidget {
  const PrincipalDashboardPage({
    super.key,
    required this.schoolName,
    required this.onActionRequested,
  });

  final String schoolName;
  final ValueChanged<String> onActionRequested;

  @override
  State<PrincipalDashboardPage> createState() => _PrincipalDashboardPageState();
}

class _PrincipalDashboardPageState extends State<PrincipalDashboardPage> {
  final _queryController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teachers = principalTeachers.where((item) => item.matches(_query)).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(schoolName: widget.schoolName, queryController: _queryController, onQueryChanged: (value) => setState(() => _query = value)),
              const SizedBox(height: 16),
              _Hero(onAction: widget.onActionRequested),
              const SizedBox(height: 16),
              _AiBrief(onAction: widget.onActionRequested),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [for (final item in principalKpis) SizedBox(width: compact ? double.infinity : 210, child: _KpiCard(item: item))],
              ),
              const SizedBox(height: 16),
              _responsivePair(
                compact,
                _Panel(title: 'Approval queue', subtitle: 'Secondary teacher work awaiting principal action', actionLabel: 'Open', onAction: () => widget.onActionRequested('approvals'), child: _ApprovalList(items: principalApprovals)),
                _Panel(title: 'Today’s alerts', subtitle: 'Secondary issues that may need leadership action', actionLabel: 'Open', onAction: () => widget.onActionRequested('ai'), child: _AlertList(items: principalAlerts)),
              ),
              const SizedBox(height: 16),
              _responsivePair(
                compact,
                _Panel(title: 'Teacher oversight', subtitle: 'Support-oriented Secondary teaching indicators', actionLabel: 'Open', onAction: () => widget.onActionRequested('teachers'), child: _TeacherList(items: teachers)),
                _Panel(title: 'Class performance', subtitle: 'Secondary academic and attendance health', actionLabel: 'Open', onAction: () => widget.onActionRequested('academics'), child: const _ClassList(items: principalClasses)),
              ),
              const SizedBox(height: 16),
              _responsivePair(
                compact,
                _Panel(title: 'Section activity', subtitle: 'Recent Secondary academic and operational events', actionLabel: 'Open', onAction: () => widget.onActionRequested('communication'), child: const _ActivityList()),
                _Panel(title: 'Quick leadership actions', subtitle: 'Common Secondary principal workflows', child: _QuickActions(onAction: widget.onActionRequested)),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(principalScopeBoundary, style: Theme.of(context).textTheme.bodyMedium),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _responsivePair(bool compact, Widget first, Widget second) {
    if (compact) return Column(children: [first, const SizedBox(height: 16), second]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: first), const SizedBox(width: 16), Expanded(child: second)]);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.schoolName, required this.queryController, required this.onQueryChanged});
  final String schoolName;
  final TextEditingController queryController;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('PRINCIPAL · SECONDARY SCHOOL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Dashboard', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          Text('$schoolName · Secondary School'),
        ]),
        SizedBox(
          width: 360,
          child: TextField(
            controller: queryController,
            onChanged: onQueryChanged,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search Secondary teachers, classes, issues...', isDense: true),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onAction});
  final ValueChanged<String> onAction;
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SECONDARY SCHOOL DAY OVERVIEW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Good afternoon, Principal.', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Your authority is scoped to the Secondary School section. There are 4 items awaiting your approval, 2 Secondary classes needing academic attention, 3 teacher follow-ups, and subject assignments requiring review.'),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 8, children: [
            FilledButton(onPressed: () => onAction('assignments'), child: const Text('Assign teachers')),
            FilledButton.tonal(onPressed: () => onAction('approvals'), child: const Text('Review approvals')),
            OutlinedButton(onPressed: () => onAction('ai'), child: const Text('Ask Principal AI')),
          ]),
        ]),
      ),
    );
  }
}

class _AiBrief extends StatelessWidget {
  const _AiBrief({required this.onAction});
  final ValueChanged<String> onAction;
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CircleAvatar(child: Text('AI')),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Principal AI Brief · Secondary only', style: TextStyle(fontWeight: FontWeight.w900)),
            const Text('Updated this morning'),
            const SizedBox(height: 8),
            const Text(principalAiBrief),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              TextButton(onPressed: () => onAction('ai'), child: const Text('Open intelligence')),
              TextButton(onPressed: () => onAction('assignments'), child: const Text('Review teaching assignments')),
            ]),
          ])),
        ]),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item});
  final PrincipalKpi item;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.label), const SizedBox(height: 6), Text(item.value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)), Text(item.hint)])));
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.subtitle, required this.child, this.actionLabel, this.onAction});
  final String title;
  final String subtitle;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), Text(subtitle)])), if (onAction != null) TextButton(onPressed: onAction, child: Text('${actionLabel ?? 'Open'} →'))]), const SizedBox(height: 10), child])));
}

class _ApprovalList extends StatelessWidget {
  const _ApprovalList({required this.items});
  final List<PrincipalApprovalItem> items;
  @override
  Widget build(BuildContext context) => Column(children: [for (final item in items) ListTile(contentPadding: EdgeInsets.zero, leading: Chip(label: Text(item.priority)), title: Text('${item.type} · ${item.title}', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${item.teacher} · ${item.age} ago'))]);
}

class _AlertList extends StatelessWidget {
  const _AlertList({required this.items});
  final List<PrincipalAlert> items;
  @override
  Widget build(BuildContext context) => Column(children: [for (final item in items) ListTile(contentPadding: EdgeInsets.zero, leading: Icon(item.warning ? Icons.warning_amber_rounded : Icons.info_outline_rounded), title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(item.detail))]);
}

class _TeacherList extends StatelessWidget {
  const _TeacherList({required this.items});
  final List<PrincipalTeacherIndicator> items;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('No Secondary teachers match this search.'));
    return Column(children: [for (final item in items) ListTile(contentPadding: EdgeInsets.zero, title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${item.subject} · Compliance ${item.compliance}% · Syllabus ${item.syllabus}%'), trailing: Chip(label: Text(item.status)))]);
  }
}

class _ClassList extends StatelessWidget {
  const _ClassList({required this.items});
  final List<PrincipalClassIndicator> items;
  @override
  Widget build(BuildContext context) => Column(children: [for (final item in items) ListTile(contentPadding: EdgeInsets.zero, title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('Average ${item.average}% · Attendance ${item.attendance}% · Syllabus ${item.syllabus}%'), trailing: Chip(label: Text(item.status)))]);
}

class _ActivityList extends StatelessWidget {
  const _ActivityList();
  @override
  Widget build(BuildContext context) => Column(children: [for (var i = 0; i < principalActivity.length; i++) ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 11))), title: Text(principalActivity[i]), trailing: Text(i == 0 ? '12 min' : '${(i + 1) * 18} min'))]);
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onAction});
  final ValueChanged<String> onAction;
  @override
  Widget build(BuildContext context) {
    const actions = <(String, String)>[
      ('Assign teachers to subjects', 'assignments'),
      ('Approve teacher work', 'approvals'),
      ('Review teachers', 'teachers'),
      ('Student interventions', 'students'),
      ('Review reports', 'results'),
      ('Open incidents', 'incidents'),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: [for (final action in actions) OutlinedButton(onPressed: () => onAction(action.$2), child: Text(action.$1)), OutlinedButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scholarship / discount requests are routed to the shared finance concession workflow; Principal may request but cannot inherit Proprietor approval authority.'))), child: const Text('Request scholarship / discount'))]);
  }
}
