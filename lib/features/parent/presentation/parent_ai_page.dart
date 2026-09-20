import 'package:flutter/material.dart';

import '../data/parent_ai_repository.dart';
import '../domain/parent_ai_models.dart';

class ParentAIPage extends StatefulWidget {
  const ParentAIPage({
    super.key,
    required this.repository,
    required this.onNavigate,
  });

  final ParentAIRepository repository;
  final ValueChanged<String> onNavigate;

  @override
  State<ParentAIPage> createState() => _ParentAIPageState();
}

class _ParentAIPageState extends State<ParentAIPage> {
  final _controller = TextEditingController();
  late Future<ParentAISnapshot> _snapshotFuture;
  ParentAISnapshot? _snapshot;
  ParentAIResponse? _response;
  bool _asking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _load();
  }

  Future<ParentAISnapshot> _load() async {
    final snapshot = await widget.repository.load();
    _snapshot = snapshot;
    _response = ParentAIResponse(
      question: snapshot.defaultPrompt,
      answer: snapshot.defaultAnswer,
      isGroundedInCachedFamilyContext: true,
    );
    return snapshot;
  }

  Future<void> _ask(String question) async {
    final value = question.trim();
    if (value.isEmpty || _asking) return;

    setState(() {
      _asking = true;
      _error = null;
    });

    try {
      final response = await widget.repository.answer(value);
      if (!mounted) return;
      setState(() {
        _response = response;
        _asking = false;
      });
      _controller.clear();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _asking = false;
        _error = error.toString();
      });
    }
  }

  void _newSummary() {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    setState(() {
      _controller.clear();
      _error = null;
      _response = ParentAIResponse(
        question: snapshot.defaultPrompt,
        answer: snapshot.defaultAnswer,
        isGroundedInCachedFamilyContext: true,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ParentAISnapshot>(
      future: _snapshotFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _Failure(
            onRetry: () => setState(() => _snapshotFuture = _load()),
          );
        }

        final data = snapshot.data!;
        final response = _response ??
            ParentAIResponse(
              question: data.defaultPrompt,
              answer: data.defaultAnswer,
              isGroundedInCachedFamilyContext: true,
            );

        return LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 1100 ? 28.0 : 16.0;
            return ListView(
              padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 36),
              children: [
                _Header(
                  onDashboard: () => widget.onNavigate('dashboard'),
                  onNewSummary: _newSummary,
                ),
                const SizedBox(height: 16),
                _AIHero(snapshot: data),
                const SizedBox(height: 16),
                _ResponsivePair(
                  left: _ChatCard(
                    response: response,
                    controller: _controller,
                    asking: _asking,
                    error: _error,
                    onAsk: () => _ask(_controller.text),
                  ),
                  right: _SuggestionsCard(
                    suggestions: data.suggestions,
                    onSelected: (value) => _ask(value),
                  ),
                ),
                const SizedBox(height: 16),
                _ResponsivePair(
                  left: _BoundaryCard(
                    icon: Icons.lock_outline_rounded,
                    title: 'Privacy boundary',
                    subtitle: 'Family context is filtered before AI sees it.',
                    body: data.privacyBoundary,
                  ),
                  right: _BoundaryCard(
                    icon: Icons.rule_outlined,
                    title: 'Decision boundary',
                    subtitle: 'AI supports communication; it does not judge families.',
                    body: data.decisionBoundary,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onDashboard, required this.onNewSummary});

  final VoidCallback onDashboard;
  final VoidCallback onNewSummary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FAMILY ACCOUNT · PARENT AI',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Parent AI',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ask questions about your linked children and family account using only guardian-visible SchoolOS context.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onDashboard,
              icon: const Icon(Icons.home_outlined),
              label: const Text('Dashboard'),
            ),
            FilledButton.icon(
              onPressed: onNewSummary,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('New summary'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AIHero extends StatelessWidget {
  const _AIHero({required this.snapshot});

  final ParentAISnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            child: const Text('AI', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(snapshot.assistantName,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 5),
                Text(snapshot.description),
                const SizedBox(height: 8),
                const Text(
                  'Uses cached, family-visible evidence only · Advisory · No automatic actions',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
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
        if (constraints.maxWidth < 900) {
          return Column(
            children: [left, const SizedBox(height: 16), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: left),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: right),
          ],
        );
      },
    );
  }
}

class _ChatCard extends StatelessWidget {
  const _ChatCard({
    required this.response,
    required this.controller,
    required this.asking,
    required this.error,
    required this.onAsk,
  });

  final ParentAIResponse response;
  final TextEditingController controller;
  final bool asking;
  final String? error;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Ask Your School',
      subtitle: 'Answers are limited to guardian-visible cached SchoolOS context.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Bubble(
            label: 'YOU',
            body: response.question,
            guardian: true,
          ),
          const SizedBox(height: 10),
          _Bubble(
            label: 'SCHOOLOS AI',
            body: response.answer,
            guardian: false,
            footer: response.isGroundedInCachedFamilyContext
                ? 'Grounded in cached family-visible records'
                : 'Insufficient cached evidence — no guess made',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            maxLength: 1000,
            enabled: !asking,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onAsk(),
            decoration: const InputDecoration(
              labelText: 'Ask about your children, fees, messages or school life',
              border: OutlineInputBorder(),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: asking ? null : onAsk,
              icon: asking
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(asking ? 'Checking context…' : 'Ask AI'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.label,
    required this.body,
    required this.guardian,
    this.footer,
  });

  final String label;
  final String body;
  final bool guardian;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: guardian ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: guardian ? scheme.primaryContainer : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .7)),
            const SizedBox(height: 5),
            Text(body),
            if (footer != null) ...[
              const SizedBox(height: 8),
              Text(
                footer!,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionsCard extends StatelessWidget {
  const _SuggestionsCard({required this.suggestions, required this.onSelected});

  final List<ParentAISuggestion> suggestions;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Suggested questions',
      subtitle: 'Useful family-level prompts.',
      child: Column(
        children: [
          for (final item in suggestions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.help_outline_rounded),
              title: Text(item.prompt, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Uses linked-child and family-visible records only.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onSelected(item.prompt),
            ),
        ],
      ),
    );
  }
}

class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String body;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      subtitle: subtitle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(child: Text(body)),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.subtitle, required this.child});

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(subtitle,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 10),
            const Text('Parent AI context could not be loaded.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
