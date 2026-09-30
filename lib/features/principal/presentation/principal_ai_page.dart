import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../data/principal_ai_demo_data.dart';
import '../domain/principal_ai_models.dart';

class PrincipalAIPage extends StatefulWidget {
  const PrincipalAIPage({super.key, required this.membership, required this.onNavigate});

  final SchoolMembership membership;
  final ValueChanged<String> onNavigate;

  @override
  State<PrincipalAIPage> createState() => _PrincipalAIPageState();
}

class _PrincipalAIPageState extends State<PrincipalAIPage> {
  final _questionController = TextEditingController();
  String _lastQuestion = principalAIDefaultQuestion;
  List<String> _history = const [
    'What needs my attention today?',
    'Why is JSS 2B declining?',
  ];

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  PrincipalAIInsight get _insight => resolvePrincipalAIInsight(_lastQuestion);
  bool get _authorized => widget.membership.role == SchoolRole.principal;

  void _ask([String? question]) {
    if (!_authorized) return;
    final next = (question ?? _questionController.text).trim();
    if (next.isEmpty) return;
    setState(() {
      _lastQuestion = next;
      _history = [next, ..._history.where((item) => item != next)].take(6).toList(growable: false);
      _questionController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_authorized) {
      return const Center(child: Text('Principal AI is available only inside an authorized Principal membership.'));
    }
    final insight = _insight;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(onNavigate: widget.onNavigate),

        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final chat = _ChatCard(
            questionController: _questionController,
            lastQuestion: _lastQuestion,
            insight: insight,
            onAsk: _ask,
            onNavigate: widget.onNavigate,
          );
          final side = _SideColumn(history: _history, onAsk: _ask, onNavigate: widget.onNavigate);
          return constraints.maxWidth >= 1000
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 7, child: chat), const SizedBox(width: 16), Expanded(flex: 4, child: side)])
              : Column(children: [chat, const SizedBox(height: 16), side]);
        }),

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
              Text('PRINCIPAL · AI INTELLIGENCE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              SizedBox(height: 4),
              Text('Principal AI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28)),
              SizedBox(height: 4),
              Text('Ask school-wide questions, understand the evidence, and move directly into the underlying workflow.'),
            ]),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(onPressed: () => onNavigate('dashboard'), child: const Text('Dashboard')),
            OutlinedButton(onPressed: () => onNavigate('academics'), child: const Text('Academics')),
            OutlinedButton(onPressed: () => onNavigate('students'), child: const Text('Students')),
            OutlinedButton(onPressed: () => onNavigate('teachers'), child: const Text('Teachers')),
          ]),
        ],
      );
}

class _ChatCard extends StatelessWidget {
  const _ChatCard({required this.questionController, required this.lastQuestion, required this.insight, required this.onAsk, required this.onNavigate});
  final TextEditingController questionController;
  final String lastQuestion;
  final PrincipalAIInsight insight;
  final void Function([String?]) onAsk;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Ask Your School', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 21)),
                Text('Ask in normal language. The answer should explain both the conclusion and the supporting school signals.'),
              ])),
              const Chip(label: Text('Principal scope')),
            ]),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [for (final item in principalAISuggestedQuestions) ActionChip(label: Text(item), onPressed: () => onAsk(item))]),
            const SizedBox(height: 14),
            TextField(
              controller: questionController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Example: Why is JSS 2B declining, and what should I review first?'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text('AI answers are not available yet.', style: Theme.of(context).textTheme.bodySmall)),
              FilledButton.icon(onPressed: () => onAsk(), icon: const Icon(Icons.auto_awesome_rounded), label: const Text('Ask Principal AI')),
            ]),
            const Divider(height: 28),
            const Text('QUESTION', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            Text(lastQuestion, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(insight.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
            const SizedBox(height: 6),
            Text(insight.answer),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('DATA SCOPE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)), Text(insight.scope, style: const TextStyle(fontWeight: FontWeight.w800))]),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [for (final action in insight.actions) OutlinedButton(onPressed: () => onNavigate(action.target), child: Text(action.label))]),
          ]),
        ),
      );
}

class _SideColumn extends StatelessWidget {
  const _SideColumn({required this.history, required this.onAsk, required this.onNavigate});
  final List<String> history;
  final void Function([String?]) onAsk;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Column(children: [
        Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Priority signals', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 8),
          const Text('Not available yet. Ranking a genuine priority needs human judgement over a pattern that nothing in the app infers automatically. Review Performance for the real school-wide figures directly.'),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => onNavigate('performance'), child: const Text('Open Performance')),
        ]))),
        const SizedBox(height: 12),
        Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Expanded(child: Text('Recent questions', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20))), Chip(label: Text('Sample'))]),
          const SizedBox(height: 6),
          for (final item in history) Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => onAsk(item), child: Text(item))),
        ]))),

      ]);
}
