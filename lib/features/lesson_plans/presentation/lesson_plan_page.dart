import 'package:flutter/material.dart';

import '../../../shared/layout/app_breakpoints.dart';
import '../../../shared/models/school_membership.dart';
import '../data/lesson_plan_generation_service.dart';
import '../data/lesson_plan_repository.dart';
import '../domain/lesson_plan_models.dart';

class LessonPlanPage extends StatefulWidget {
  const LessonPlanPage({
    super.key,
    required this.membership,
    required this.generationService,
    required this.repository,
    required this.onQueuedForSync,
  });

  final SchoolMembership membership;
  final LessonPlanGenerationService generationService;
  final LessonPlanRepository repository;
  final VoidCallback onQueuedForSync;

  @override
  State<LessonPlanPage> createState() => _LessonPlanPageState();
}

class _LessonPlanPageState extends State<LessonPlanPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController(text: 'Basic Science');
  final _topicController = TextEditingController(text: 'Photosynthesis');
  final _objectivesController = TextEditingController();
  final _resourcesController = TextEditingController(text: 'Whiteboard, textbook');

  String _className = 'JSS 2';
  String _term = 'First Term';
  int _week = 5;
  int _durationMinutes = 40;
  bool _tryEdgeAi = true;
  bool _tryCloud = false;
  bool _generating = false;
  bool _saving = false;
  LessonPlanGenerationResult? _result;
  LessonPlanRequest? _lastRequest;
  String? _saveMessage;

  @override
  void dispose() {
    _subjectController.dispose();
    _topicController.dispose();
    _objectivesController.dispose();
    _resourcesController.dispose();
    super.dispose();
  }

  LessonPlanRequest _buildRequest() {
    return LessonPlanRequest(
      schoolId: widget.membership.schoolId,
      className: _className,
      subject: _subjectController.text.trim(),
      topic: _topicController.text.trim(),
      durationMinutes: _durationMinutes,
      term: _term,
      week: _week,
      learningObjectives: _lines(_objectivesController.text),
      availableResources: _commaSeparated(_resourcesController.text),
    );
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate() || _generating) return;

    final request = _buildRequest();
    setState(() {
      _generating = true;
      _saveMessage = null;
    });

    try {
      final result = await widget.generationService.generate(
        request,
        tryEdgeAi: _tryEdgeAi,
        tryCloud: _tryCloud,
      );
      if (!mounted) return;
      setState(() {
        _lastRequest = request;
        _result = result;
      });
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _save({required bool queueForSync}) async {
    final result = _result;
    final request = _lastRequest;
    if (result == null || request == null || _saving) return;

    setState(() => _saving = true);
    try {
      await widget.repository.saveDraft(
        request: request,
        draft: result.draft,
        queueForSync: queueForSync,
      );
      if (queueForSync) widget.onQueuedForSync();
      if (!mounted) return;
      setState(() {
        _saveMessage = queueForSync
            ? 'Saved on this device and queued for SchoolOS Cloud sync.'
            : 'Saved securely on this device. No internet required.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final phone = AppBreakpoints.isPhone(constraints.maxWidth);
        final form = _BuildForm(
          formKey: _formKey,
          subjectController: _subjectController,
          topicController: _topicController,
          objectivesController: _objectivesController,
          resourcesController: _resourcesController,
          className: _className,
          term: _term,
          week: _week,
          durationMinutes: _durationMinutes,
          tryEdgeAi: _tryEdgeAi,
          tryCloud: _tryCloud,
          generating: _generating,
          onClassChanged: (value) => setState(() => _className = value),
          onTermChanged: (value) => setState(() => _term = value),
          onWeekChanged: (value) => setState(() => _week = value),
          onDurationChanged: (value) => setState(() => _durationMinutes = value),
          onEdgeChanged: (value) => setState(() => _tryEdgeAi = value),
          onCloudChanged: (value) => setState(() => _tryCloud = value),
          onGenerate: _generate,
        );

        final output = _LessonPlanOutput(
          result: _result,
          saving: _saving,
          saveMessage: _saveMessage,
          onSaveLocal: () => _save(queueForSync: false),
          onSaveAndSync: () => _save(queueForSync: true),
        );

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Lesson Plan Assistant',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.membership.schoolName} · ${widget.membership.roleLabel}',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            const _OfflinePromiseCard(),
            const SizedBox(height: 20),
            if (phone) ...[
              form,
              const SizedBox(height: 20),
              output,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 390, child: form),
                  const SizedBox(width: 20),
                  Expanded(child: output),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _OfflinePromiseCard extends StatelessWidget {
  const _OfflinePromiseCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.offline_bolt_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'A usable lesson-plan draft is always generated locally. Edge AI and cloud AI only improve it; they never block the teacher when internet or a model is unavailable.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildForm extends StatelessWidget {
  const _BuildForm({
    required this.formKey,
    required this.subjectController,
    required this.topicController,
    required this.objectivesController,
    required this.resourcesController,
    required this.className,
    required this.term,
    required this.week,
    required this.durationMinutes,
    required this.tryEdgeAi,
    required this.tryCloud,
    required this.generating,
    required this.onClassChanged,
    required this.onTermChanged,
    required this.onWeekChanged,
    required this.onDurationChanged,
    required this.onEdgeChanged,
    required this.onCloudChanged,
    required this.onGenerate,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController subjectController;
  final TextEditingController topicController;
  final TextEditingController objectivesController;
  final TextEditingController resourcesController;
  final String className;
  final String term;
  final int week;
  final int durationMinutes;
  final bool tryEdgeAi;
  final bool tryCloud;
  final bool generating;
  final ValueChanged<String> onClassChanged;
  final ValueChanged<String> onTermChanged;
  final ValueChanged<int> onWeekChanged;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<bool> onEdgeChanged;
  final ValueChanged<bool> onCloudChanged;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Lesson context',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: className,
                decoration: const InputDecoration(labelText: 'Class'),
                items: const [
                  DropdownMenuItem(value: 'JSS 1', child: Text('JSS 1')),
                  DropdownMenuItem(value: 'JSS 2', child: Text('JSS 2')),
                  DropdownMenuItem(value: 'JSS 3', child: Text('JSS 3')),
                  DropdownMenuItem(value: 'SS 1', child: Text('SS 1')),
                  DropdownMenuItem(value: 'SS 2', child: Text('SS 2')),
                  DropdownMenuItem(value: 'SS 3', child: Text('SS 3')),
                ],
                onChanged: (value) {
                  if (value != null) onClassChanged(value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: subjectController,
                decoration: const InputDecoration(labelText: 'Subject'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: topicController,
                decoration: const InputDecoration(labelText: 'Topic'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: term,
                      decoration: const InputDecoration(labelText: 'Term'),
                      items: const [
                        DropdownMenuItem(
                          value: 'First Term',
                          child: Text('First Term'),
                        ),
                        DropdownMenuItem(
                          value: 'Second Term',
                          child: Text('Second Term'),
                        ),
                        DropdownMenuItem(
                          value: 'Third Term',
                          child: Text('Third Term'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) onTermChanged(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: week,
                      decoration: const InputDecoration(labelText: 'Week'),
                      items: [
                        for (var value = 1; value <= 14; value++)
                          DropdownMenuItem(
                            value: value,
                            child: Text('$value'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) onWeekChanged(value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: durationMinutes,
                decoration: const InputDecoration(labelText: 'Duration'),
                items: const [
                  DropdownMenuItem(value: 30, child: Text('30 minutes')),
                  DropdownMenuItem(value: 40, child: Text('40 minutes')),
                  DropdownMenuItem(value: 45, child: Text('45 minutes')),
                  DropdownMenuItem(value: 60, child: Text('60 minutes')),
                  DropdownMenuItem(value: 80, child: Text('80 minutes')),
                ],
                onChanged: (value) {
                  if (value != null) onDurationChanged(value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: objectivesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Learning objectives (optional)',
                  hintText: 'One objective per line',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: resourcesController,
                decoration: const InputDecoration(
                  labelText: 'Available resources',
                  hintText: 'Whiteboard, projector, textbook',
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Try Edge AI'),
                subtitle: const Text('Use a downloaded local model when available.'),
                value: tryEdgeAi,
                onChanged: onEdgeChanged,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Try Cloud enhancement'),
                subtitle: const Text('Use cloud AI only when explicitly enabled.'),
                value: tryCloud,
                onChanged: onCloudChanged,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: generating ? null : onGenerate,
                icon: generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Text(generating ? 'Generating…' : 'Generate lesson plan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonPlanOutput extends StatelessWidget {
  const _LessonPlanOutput({
    required this.result,
    required this.saving,
    required this.saveMessage,
    required this.onSaveLocal,
    required this.onSaveAndSync,
  });

  final LessonPlanGenerationResult? result;
  final bool saving;
  final String? saveMessage;
  final VoidCallback onSaveLocal;
  final VoidCallback onSaveAndSync;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    if (result == null) {
      return const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.description_outlined, size: 42),
              SizedBox(height: 12),
              Text(
                'Enter the lesson context and generate a draft. The first version works entirely offline.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final draft = result.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(_modeLabel(draft.mode))),
                    if (result.usedEdgeAi)
                      const Chip(label: Text('Edge AI used')),
                    if (result.usedCloud)
                      const Chip(label: Text('Cloud enhanced')),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  draft.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (result.fallbackMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    result.fallbackMessage!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _PlanSection(title: 'Learning objectives', items: draft.objectives),
        _PlanSection(title: 'Prior knowledge', body: draft.priorKnowledge),
        _PlanSection(title: 'Teaching materials', items: draft.materials),
        _PlanSection(title: 'Introduction', items: draft.introduction),
        _PlanSection(title: 'Teacher activities', items: draft.teacherActivities),
        _PlanSection(title: 'Student activities', items: draft.studentActivities),
        _PlanSection(title: 'Assessment', items: draft.assessment),
        _PlanSection(title: 'Homework', body: draft.homework),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: saving ? null : onSaveLocal,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save on device'),
            ),
            FilledButton.icon(
              onPressed: saving ? null : onSaveAndSync,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Save & sync'),
            ),
          ],
        ),
        if (saveMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            saveMessage!,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _PlanSection extends StatelessWidget {
  const _PlanSection({
    required this.title,
    this.items = const [],
    this.body,
  });

  final String title;
  final List<String> items;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            if (body != null) Text(body!),
            for (var index = 0; index < items.length; index++)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text('${index + 1}. ${items[index]}'),
              ),
          ],
        ),
      ),
    );
  }
}

String? _required(String? value) {
  if (value == null || value.trim().isEmpty) return 'Required';
  return null;
}

List<String> _lines(String value) {
  return value
      .split('\n')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<String> _commaSeparated(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _modeLabel(LessonPlanGenerationMode mode) {
  return switch (mode) {
    LessonPlanGenerationMode.offlineTemplate => 'Offline draft',
    LessonPlanGenerationMode.edgeAi => 'Edge AI draft',
    LessonPlanGenerationMode.cloudEnhanced => 'Cloud enhanced',
  };
}
