import 'package:flutter/material.dart';

import '../data/proprietor_ai_brief_exporter.dart';
import '../../../core/sync/sync_scope.dart';
import '../data/owner_reports.dart';
import '../data/proprietor_ai_service.dart';
import '../data/proprietor_ai_text.dart';
import '../domain/proprietor_ai_models.dart';

class ProprietorAiPage extends StatefulWidget {
  const ProprietorAiPage({
    super.key,
    required this.schoolName,
    required this.onActionRequested,
    required this.repository,
  });

  final String schoolName;
  final ValueChanged<String> onActionRequested;
  final OwnerReportsRepository repository;

  @override
  State<ProprietorAiPage> createState() => _ProprietorAiPageState();
}

class _ProprietorAiPageState extends State<ProprietorAiPage> with SyncRefresh<ProprietorAiPage> {
  final _controller = TextEditingController();
  final ProprietorAiBriefExporter _exporter = const ProprietorAiBriefExporter();

  ProprietorAiService? _service;
  ProprietorAiResponse? _response;
  String? _lastQuestion;
  bool _failed = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onSynced() => _load();

  Future<void> _load() async {
    try {
      final facts = await widget.repository.load();
      if (!mounted) return;
      final service = ProprietorAiService(facts);
      setState(() {
        _service = service;
        _response = _lastQuestion == null ? service.defaultBriefQuestion() : service.answer(_lastQuestion!);
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _ask(String question) {
    final value = question.trim();
    final service = _service;
    if (value.isEmpty || service == null) return;
    setState(() {
      _lastQuestion = value;
      _response = service.answer(value);
      _controller.clear();
    });
  }

  Future<void> _createBrief() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final service = _service;
      if (service == null) return;
      final path = await _exporter.export(schoolName: widget.schoolName, sections: service.briefSections());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Executive AI brief saved offline to $path'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create executive brief: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final response = _response;
    if (response == null) {
      return Center(
        child: _failed
            ? const Padding(padding: EdgeInsets.all(24), child: Text('The assistant could not read the school records.'))
            : const CircularProgressIndicator(),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 780;
        final contentWidth = constraints.maxWidth >= 1460 ? 1280.0 : 1160.0;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            compact ? 18 : 28,
            24,
            compact ? 18 : 28,
            48,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      schoolName: widget.schoolName,
                      compact: compact,
                      exporting: _exporting,
                      onOverview: () => widget.onActionRequested('overview'),
                      onCreateBrief: _createBrief,
                    ),
                    const SizedBox(height: 18),
                    _AssistantHero(onPrompt: _ask),
                    const SizedBox(height: 18),
                    _TwoColumn(
                      compact: compact,
                      left: _AiCard(
                        title: 'Ask Your School',
                        subtitle:
                            'Answers come from the records on this device. Nothing is guessed.',
                        child: _Conversation(
                          response: response,
                          controller: _controller,
                          onAsk: _ask,
                        ),
                      ),
                      right: _AiCard(
                        title: 'Suggested questions',
                        subtitle: 'Management questions suited to proprietor scope.',
                        child: _SuggestedQuestions(onSelected: _ask),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _TwoColumn(
                      compact: compact,
                      left: const _AiCard(
                        title: 'AI context boundary',
                        subtitle: 'Hard production principle.',
                        child: _BoundaryCallout(
                          text: proprietorAiContextBoundary,
                          warning: false,
                        ),
                      ),
                      right: const _AiCard(
                        title: 'Decision boundary',
                        subtitle: 'AI advises; authorized humans decide.',
                        child: _BoundaryCallout(
                          text: proprietorAiDecisionBoundary,
                          warning: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Answers from your school records on this device · ${widget.schoolName}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
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

class _Header extends StatelessWidget {
  const _Header({
    required this.schoolName,
    required this.compact,
    required this.exporting,
    required this.onOverview,
    required this.onCreateBrief,
  });

  final String schoolName;
  final bool compact;
  final bool exporting;
  final VoidCallback onOverview;
  final VoidCallback onCreateBrief;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROPRIETOR · SCHOOL AI',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Proprietor AI',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ask whole-school management questions about $schoolName using owner-authorized context while preserving campus, section and sensitive-data boundaries.',
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: onOverview,
          child: const Text('Executive Overview'),
        ),
        FilledButton.icon(
          onPressed: exporting ? null : onCreateBrief,
          icon: exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome_rounded, size: 18),
          label: Text(exporting ? 'Creating…' : 'New executive brief'),
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [title, const SizedBox(height: 18), actions],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: title),
        const SizedBox(width: 24),
        Flexible(child: Align(alignment: Alignment.topRight, child: actions)),
      ],
    );
  }
}

class _AssistantHero extends StatelessWidget {
  const _AssistantHero({required this.onPrompt});

  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            child: const Text('AI', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Owner Intelligence Assistant',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'Answers from what has been recorded: what is waiting on you, staffing, scholarships, discounts, payroll and leadership. Areas with no data say so. Answers separate evidence from interpretation and keep decisions with you.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final prompt in proprietorAiPrompts.take(3))
                      ActionChip(
                        avatar: const Icon(Icons.arrow_outward_rounded, size: 16),
                        label: Text(prompt.question),
                        onPressed: () => onPrompt(prompt.question),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Conversation extends StatelessWidget {
  const _Conversation({
    required this.response,
    required this.controller,
    required this.onAsk,
  });

  final ProprietorAiResponse response;
  final TextEditingController controller;
  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MessageBubble(
          label: 'YOU',
          text: response.question,
          icon: Icons.person_outline_rounded,
          emphasized: false,
        ),
        const SizedBox(height: 10),
        _MessageBubble(
          label: 'SCHOOLOS AI · ${response.isOffline ? 'OFFLINE' : 'CONNECTED'}',
          text: response.answer,
          icon: Icons.auto_awesome_rounded,
          emphasized: true,
        ),
        const SizedBox(height: 14),
        Text('Evidence used', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        for (final evidence in response.evidence)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(evidence)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'Interpretation: ${response.interpretation}',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.send,
          onSubmitted: onAsk,
          decoration: InputDecoration(
            hintText: 'Ask a whole-school question…',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: 'Ask AI',
              icon: const Icon(Icons.send_rounded),
              onPressed: () => onAsk(controller.text),
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.label,
    required this.text,
    required this.icon,
    required this.emphasized,
  });

  final String label;
  final String text;
  final IconData icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: emphasized
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.42)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(text, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedQuestions extends StatelessWidget {
  const _SuggestedQuestions({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < proprietorAiPrompts.length; i++) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.question_answer_outlined),
            title: Text(
              proprietorAiPrompts[i].question,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${proprietorAiPrompts[i].category} · aggregate, role-authorized school context',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => onSelected(proprietorAiPrompts[i].question),
          ),
          if (i != proprietorAiPrompts.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }
}

class _BoundaryCallout extends StatelessWidget {
  const _BoundaryCallout({required this.text, required this.warning});

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = warning
        ? theme.colorScheme.errorContainer.withValues(alpha: 0.48)
        : theme.colorScheme.primaryContainer.withValues(alpha: 0.38);
    final foreground = warning
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onPrimaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.gavel_outlined : Icons.shield_outlined,
            color: foreground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: foreground,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiCard extends StatelessWidget {
  const _AiCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({
    required this.compact,
    required this.left,
    required this.right,
  });

  final bool compact;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: [left, const SizedBox(height: 14), right],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }
}
