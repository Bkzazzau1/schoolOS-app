import 'package:flutter/material.dart';

import '../data/finance_ai_demo_data.dart';
import '../domain/finance_ai_models.dart';

class FinanceAiPage extends StatefulWidget {
  const FinanceAiPage({super.key});

  @override
  State<FinanceAiPage> createState() => _FinanceAiPageState();
}

class _FinanceAiPageState extends State<FinanceAiPage> {
  final TextEditingController _controller = TextEditingController();
  late FinanceAiResponse _response;

  @override
  void initState() {
    super.initState();
    _response = financeAiAnswerFor(financeAiPrompts.first);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _ask([String? suggested]) {
    final question = (suggested ?? _controller.text).trim();
    if (question.isEmpty) return;
    setState(() {
      _response = financeAiAnswerFor(question);
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _Header(),
        const SizedBox(height: 16),
        const _IntroCard(),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 980) {
              return Column(
                children: [
                  _ConversationCard(
                    controller: _controller,
                    response: _response,
                    onAsk: _ask,
                  ),
                  const SizedBox(height: 16),
                  _SuggestedQuestions(onSelected: _ask),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _ConversationCard(
                    controller: _controller,
                    response: _response,
                    onAsk: _ask,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _SuggestedQuestions(onSelected: _ask)),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const _GuardrailGrid(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 780),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FINANCE OFFICE · AI',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Finance AI',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ask operational finance questions using authorized billing, transaction, reconciliation and reporting context.',
          ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Finance Intelligence Assistant',
      subtitle:
          'Explain collection movement, reconciliation exceptions, balances, payment plans, expenses and reports.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Finance AI should show evidence, separate observation from interpretation and never make hidden credit decisions about families.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.controller,
    required this.response,
    required this.onAsk,
  });

  final TextEditingController controller;
  final FinanceAiResponse response;
  final void Function([String? suggested]) onAsk;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Ask Finance',
      subtitle: 'Prototype conversation using grounded mock finance data.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Message(label: 'YOU', text: response.question),
          const SizedBox(height: 12),
          _Message(
            label: 'SCHOOLOS FINANCE AI',
            text: response.answer,
            accent: true,
          ),
          const SizedBox(height: 14),
          Text('Evidence used', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (final item in response.evidence)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(response.boundary),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final input = TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onAsk(),
                decoration: const InputDecoration(
                  hintText: 'Ask a finance question...',
                  border: OutlineInputBorder(),
                ),
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    input,
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () => onAsk(),
                      icon: const Icon(Icons.arrow_upward_rounded),
                      label: const Text('Ask AI'),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: input),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => onAsk(),
                    icon: const Icon(Icons.arrow_upward_rounded),
                    label: const Text('Ask AI'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.label, required this.text, this.accent = false});

  final String label;
  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .45)
            : Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(text),
        ],
      ),
    );
  }
}

class _SuggestedQuestions extends StatelessWidget {
  const _SuggestedQuestions({required this.onSelected});

  final void Function([String? suggested]) onSelected;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Suggested questions',
      subtitle: 'Uses finance-authorized aggregate context.',
      child: Column(
        children: [
          for (var i = 0; i < financeAiPrompts.length; i++) ...[
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelected(financeAiPrompts[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text('${i + 1}'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(financeAiPrompts[i], style: const TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text('Uses finance-authorized aggregate context.', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i != financeAiPrompts.length - 1) const Divider(height: 10),
          ],
        ],
      ),
    );
  }
}

class _GuardrailGrid extends StatelessWidget {
  const _GuardrailGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final children = <Widget>[
          const _BoundaryCard(
            icon: Icons.gavel_outlined,
            title: 'Human action remains required',
            text: financeAiActionBoundary,
          ),
          const _BoundaryCard(
            icon: Icons.family_restroom_outlined,
            title: 'No hidden family scoring',
            text: financeAiFairnessBoundary,
          ),
          const _BoundaryCard(
            icon: Icons.lock_outline_rounded,
            title: 'Finance-authorized context only',
            text: financeAiDataBoundary,
          ),
          const _BoundaryCard(
            icon: Icons.fact_check_outlined,
            title: 'Evidence before interpretation',
            text: financeAiEvidenceBoundary,
          ),
        ];
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final child in children)
              SizedBox(width: (constraints.maxWidth - 12) / 2, child: child),
          ],
        );
      },
    );
  }
}

class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: title,
      subtitle: 'Finance AI governance',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
