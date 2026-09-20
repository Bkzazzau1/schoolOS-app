import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/teacher_ai_demo_data.dart';
import '../data/teacher_ai_repository.dart';
import '../domain/teacher_ai_models.dart';

class TeacherAiPage extends StatefulWidget {
  const TeacherAiPage({
    super.key,
    required this.repository,
    required this.onNavigate,
  });

  final TeacherAiRepository repository;
  final ValueChanged<String> onNavigate;

  @override
  State<TeacherAiPage> createState() => _TeacherAiPageState();
}

class _TeacherAiPageState extends State<TeacherAiPage> {
  final _composer = TextEditingController();
  late Future<TeacherAiSnapshot> _future;
  TeacherAiContext _context = TeacherAiContext.jss2bMathematics;
  String _response = teacherAiInitialResponse;
  List<TeacherAiPromptHistoryItem> _history = teacherAiInitialHistory;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load().then((snapshot) {
      _history = snapshot.history;
      return snapshot;
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _ask([String? suggestedPrompt]) async {
    final prompt = (suggestedPrompt ?? _composer.text).trim();
    final result = await widget.repository.ask(context: _context, prompt: prompt);
    if (!mounted) return;
    setState(() {
      _response = result.response;
      if (result.success && result.historyItem != null) {
        _history = [result.historyItem!, ..._history]
            .take(6)
            .toList(growable: false);
        _composer.clear();
      }
      _notice = result.success
          ? 'AI suggestion generated for review. Nothing was saved, sent or submitted automatically.'
          : result.response;
    });
  }

  Future<void> _copyResponse() async {
    await Clipboard.setData(ClipboardData(text: _response));
    if (!mounted) return;
    setState(() => _notice = 'AI response copied. Review it before reuse.');
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TeacherAiSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _ErrorState(
              onRetry: () => setState(() => _future = widget.repository.load()),
            );
          }
          final permissions = snapshot.data!.permissions;
          return LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context),
                  const SizedBox(height: 16),
                  if (_notice != null) ...[
                    _NoticeCard(
                      text: _notice!,
                      onClose: () => setState(() => _notice = null),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (constraints.maxWidth >= 980)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _chatCard(context, permissions)),
                        const SizedBox(width: 14),
                        Expanded(child: _historyCard(context)),
                      ],
                    )
                  else ...[
                    _chatCard(context, permissions),
                    const SizedBox(height: 14),
                    _historyCard(context),
                  ],
                  const SizedBox(height: 16),
                  _tools(context, constraints.maxWidth),
                  const SizedBox(height: 16),
                  _suggestedActions(context),
                  const SizedBox(height: 16),
                  _governance(context),
                ],
              ),
            ),
          );
        },
      );

  Widget _header(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 650,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TEACHER AI',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your teaching copilot',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'AI assistance grounded only in classes and school records you are permitted to access.',
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => widget.onNavigate('dashboard'),
            child: const Text('Dashboard'),
          ),
          OutlinedButton(
            onPressed: () => widget.onNavigate('classes'),
            child: const Text('My classes'),
          ),
        ],
      );

  Widget _chatCard(
    BuildContext context,
    TeacherAiPermissions permissions,
  ) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ask Teacher AI',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                        ),
                        SizedBox(height: 3),
                        Text('Plan, explain, analyze and draft—without bypassing teacher review.'),
                      ],
                    ),
                  ),
                  const Chip(label: Text('School context on')),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TeacherAiContext>(
                value: _context,
                decoration: const InputDecoration(
                  labelText: 'Working context',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final item in TeacherAiContext.values)
                    DropdownMenuItem(value: item, child: Text(item.label)),
                ],
                onChanged: permissions.canUseAssignedClassContext
                    ? (value) {
                        if (value != null) setState(() => _context = value);
                      }
                    : null,
              ),
              const SizedBox(height: 10),
              _BoundaryPanel(
                title: 'Permission boundary',
                body:
                    'Teacher AI cannot retrieve unrelated classes, school finance, staff-confidential data or another school’s records.',
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI RESPONSE',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_response),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _copyResponse,
                          child: const Text('Copy'),
                        ),
                        OutlinedButton(
                          onPressed: () => widget.onNavigate('lesson-plans'),
                          child: const Text('Turn into lesson plan'),
                        ),
                        OutlinedButton(
                          onPressed: () => widget.onNavigate('assignments'),
                          child: const Text('Create assignment'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final prompt in teacherAiPromptSuggestions)
                    ActionChip(
                      label: Text(prompt),
                      onPressed: () => _ask(prompt),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _composer,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText:
                      'Ask about lesson planning, class performance, student support, teaching ideas...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: permissions.canDraftTeachingContent ? () => _ask() : null,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Ask Teacher AI'),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _historyCard(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recent AI activity',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              ),
              const SizedBox(height: 3),
              const Text('Your recent prompts in this workspace.'),
              const SizedBox(height: 14),
              if (_history.isEmpty)
                const Text('No recent Teacher AI prompts.')
              else
                for (var i = 0; i < _history.length; i++) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _history[i].prompt,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${_history[i].context.label} · ${i == 0 ? 'Just now' : '${i + 1} hours ago'}',
                    ),
                  ),
                  if (i != _history.length - 1) const Divider(height: 1),
                ],
              const SizedBox(height: 12),
              const _BoundaryPanel(
                title: 'Human review is required',
                body:
                    'AI-generated lesson plans, marks, messages, student interventions and school records must be reviewed before consequential actions are taken.',
              ),
            ],
          ),
        ),
      );

  Widget _tools(BuildContext context, double width) {
    final cardWidth = width >= 1000 ? (width - 42) / 4 : width >= 620 ? (width - 14) / 2 : width;
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final tool in teacherAiTools)
          SizedBox(
            width: cardWidth,
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Chip(label: Text('AI TOOL')),
                    const SizedBox(height: 8),
                    Text(
                      tool.title,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                    const SizedBox(height: 6),
                    Text(tool.description),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => widget.onNavigate(tool.destination),
                      child: const Text('Open tool →'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _suggestedActions(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Today’s suggested actions',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              ),
              const SizedBox(height: 3),
              const Text('Suggestions generated from fictional demo data and teacher-authorized context.'),
              const SizedBox(height: 12),
              for (final action in teacherAiSuggestedActions) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    action.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(action.description),
                  trailing: TextButton(
                    onPressed: () => widget.onNavigate(action.destination),
                    child: Text(action.actionLabel),
                  ),
                ),
                if (action != teacherAiSuggestedActions.last) const Divider(height: 1),
              ],
            ],
          ),
        ),
      );

  Widget _governance(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Teacher AI governance',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 6),
              const Text(teacherAiGovernanceBoundary),
              const SizedBox(height: 10),
              Text(
                'AI output is a proposal, not a school record.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
}

class _BoundaryPanel extends StatelessWidget {
  const _BoundaryPanel({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(body),
          ],
        ),
      );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.text, required this.onClose});

  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          title: Text(text),
          trailing: IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Teacher AI could not load.'),
              const SizedBox(height: 10),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
