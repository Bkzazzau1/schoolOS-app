import 'package:flutter/material.dart';

import '../data/teacher_lesson_plan_demo_data.dart';
import '../data/teacher_lesson_plan_repository.dart';
import '../domain/teacher_lesson_plan_models.dart';

class TeacherLessonPlansPage extends StatefulWidget {
  const TeacherLessonPlansPage({
    super.key,
    required this.repository,
    required this.onNavigate,
    required this.onMutationQueued,
  });

  final TeacherLessonPlanRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback onMutationQueued;

  @override
  State<TeacherLessonPlansPage> createState() => _TeacherLessonPlansPageState();
}

class _TeacherLessonPlansPageState extends State<TeacherLessonPlansPage> {
  late Future<TeacherLessonPlanSnapshot> _future;
  final _queryController = TextEditingController();
  final _objectives = TextEditingController();
  final _starter = TextEditingController();
  final _activities = TextEditingController();
  final _assessment = TextEditingController();
  final _resources = TextEditingController();
  final _reflection = TextEditingController();
  final _homework = TextEditingController();

  String? _selectedId;
  String _selectedTopicId = '';
  String _selectedTopicTitle = '';
  String _query = '';
  String? _notice;
  bool _busy = false;
  bool _topicCompleted = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _objectives.dispose();
    _starter.dispose();
    _activities.dispose();
    _assessment.dispose();
    _resources.dispose();
    _reflection.dispose();
    _homework.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _future = widget.repository.load());

  void _selectPlan(
    TeacherLessonPlan plan,
    TeacherLessonPlanSnapshot snapshot,
  ) {
    final delivery = snapshot.deliveryFor(plan.id);
    setState(() {
      _selectedId = plan.id;
      _selectedTopicId = plan.topicId;
      _selectedTopicTitle = plan.topic;
      _objectives.text = plan.objectives;
      _starter.text = plan.starter;
      _activities.text = plan.activities;
      _assessment.text = plan.assessment;
      _resources.text = plan.resources;
      _reflection.text = delivery?.reflection ?? '';
      _homework.text = delivery?.homework ?? '';
      _topicCompleted = delivery?.topicCompleted ?? false;
      _notice = null;
    });
  }

  List<TeacherLessonPlanTopicOption> _topicOptionsFor(
    TeacherLessonPlanSnapshot snapshot,
    TeacherLessonPlan plan,
  ) {
    final byId = <String, TeacherLessonPlanTopicOption>{};
    for (final occurrence in snapshot.occurrenceOptions) {
      if (occurrence.classSubjectId != plan.classSubjectId ||
          occurrence.termId != plan.termId) {
        continue;
      }
      for (final topic in occurrence.topics) {
        byId[topic.id] = topic;
      }
    }
    if (plan.topicId.isNotEmpty) {
      byId.putIfAbsent(
        plan.topicId,
        () => TeacherLessonPlanTopicOption(
          id: plan.topicId,
          title: plan.topic,
          sequence: 0,
        ),
      );
    }
    final values = byId.values.toList()
      ..sort((a, b) {
        final bySequence = a.sequence.compareTo(b.sequence);
        return bySequence != 0 ? bySequence : a.title.compareTo(b.title);
      });
    return values;
  }

  TeacherLessonPlan _editorPlan(TeacherLessonPlan base) => base.copyWith(
        topicId: _selectedTopicId.isEmpty ? base.topicId : _selectedTopicId,
        topic: _selectedTopicTitle.isEmpty ? base.topic : _selectedTopicTitle,
        objectives: _objectives.text,
        starter: _starter.text,
        activities: _activities.text,
        assessment: _assessment.text,
        resources: _resources.text,
      );

  void _generateAiDraft() {
    _objectives.text = teacherLessonPlanAiObjectives;
    _starter.text = teacherLessonPlanAiStarter;
    _activities.text = teacherLessonPlanAiActivities;
    _assessment.text = teacherLessonPlanAiAssessment;
    _resources.text = teacherLessonPlanAiResources;
    setState(() {
      _notice =
          'AI generated a draft only. Review and edit it before saving or submitting.';
    });
  }

  Future<void> _saveDraft(TeacherLessonPlan base) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await widget.repository.saveDraft(plan: _editorPlan(base));
    if (!mounted) return;
    if (result.success) widget.onMutationQueued();
    setState(() {
      _busy = false;
      _notice = result.message;
    });
    if (result.success) _reload();
  }

  Future<void> _submit(TeacherLessonPlan base) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await widget.repository.submit(plan: _editorPlan(base));
    if (!mounted) return;
    if (result.success) widget.onMutationQueued();
    setState(() {
      _busy = false;
      _notice = result.message;
    });
    if (result.success) _reload();
  }

  Future<void> _saveDelivery(
    TeacherLessonPlan plan, {
    required bool deliver,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = deliver
        ? await widget.repository.recordDelivered(
            plan: plan,
            reflection: _reflection.text,
            homework: _homework.text,
            topicCompleted: _topicCompleted,
          )
        : await widget.repository.saveDeliveryDraft(
            plan: plan,
            reflection: _reflection.text,
            homework: _homework.text,
            topicCompleted: _topicCompleted,
          );
    if (!mounted) return;
    if (result.success) widget.onMutationQueued();
    setState(() {
      _busy = false;
      _notice = result.message;
    });
    if (result.success) _reload();
  }

  Future<void> _createPlan(TeacherLessonPlanSnapshot snapshot) async {
    if (!snapshot.canonical) {
      setState(() {
        _notice =
            'Standalone demo keeps seeded lesson-plan examples. Canonical plans require a real timetable occurrence.';
      });
      return;
    }
    final planned = {
      for (final plan in snapshot.plans)
        '${plan.timetableEntryId}|${plan.lessonDate}',
    };
    final available = snapshot.occurrenceOptions
        .where((item) => !planned.contains(item.id))
        .toList(growable: false);
    if (available.isEmpty) {
      setState(() {
        _notice =
            'Every occurrence in the current planning horizon already has a plan, or no authorized occurrence with curriculum topics is available.';
      });
      return;
    }

    final draft = await showDialog<_NewPlanDraft>(
      context: context,
      builder: (context) => _NewPlanDialog(occurrences: available),
    );
    if (draft == null) return;
    final result = await widget.repository.createPlan(
      occurrence: draft.occurrence,
      topic: draft.topic,
    );
    if (!mounted) return;
    setState(() {
      _notice = result.message;
      if (result.success && result.plan != null) {
        _selectedId = result.plan!.id;
        _selectedTopicId = result.plan!.topicId;
        _selectedTopicTitle = result.plan!.topic;
      }
    });
    if (result.success) {
      widget.onMutationQueued();
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeacherLessonPlanSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry lesson plans'),
            ),
          );
        }

        final data = snapshot.requireData;
        if (data.plans.isEmpty) {
          return _EmptyState(
            canonical: data.canonical,
            canCreate: data.occurrenceOptions.isNotEmpty,
            onCreate: () => _createPlan(data),
            onNavigate: widget.onNavigate,
          );
        }

        if (_selectedId == null ||
            !data.plans.any((plan) => plan.id == _selectedId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && data.plans.isNotEmpty) {
              _selectPlan(data.plans.first, data);
            }
          });
          return const Center(child: CircularProgressIndicator());
        }

        final plan = data.plans.firstWhere((item) => item.id == _selectedId);
        final delivery = data.deliveryFor(plan.id);
        final filtered = data.plans.where((item) => item.matches(_query)).toList();
        final topicOptions = _topicOptionsFor(data, plan);
        if (_selectedTopicId.isEmpty) {
          _selectedTopicId = plan.topicId;
          _selectedTopicTitle = plan.topic;
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            return SingleChildScrollView(
              padding: EdgeInsets.all(compact ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    canonical: data.canonical,
                    onNavigate: widget.onNavigate,
                  ),
                  if (_notice != null) ...[
                    const SizedBox(height: 12),
                    _Notice(message: _notice!),
                  ],
                  const SizedBox(height: 16),
                  _TermStats(plans: data.plans, deliveries: data.deliveries),
                  const SizedBox(height: 16),
                  _OccurrenceCard(plan: plan),
                  const SizedBox(height: 16),
                  _PlanEditor(
                    plan: plan,
                    topicOptions: topicOptions,
                    selectedTopicId: _selectedTopicId,
                    busy: _busy,
                    objectives: _objectives,
                    starter: _starter,
                    activities: _activities,
                    assessment: _assessment,
                    resources: _resources,
                    onTopicChanged: (id) {
                      final topic = topicOptions.firstWhere((item) => item.id == id);
                      setState(() {
                        _selectedTopicId = topic.id;
                        _selectedTopicTitle = topic.title;
                      });
                    },
                    onGenerateAi: plan.teacherEditable ? _generateAiDraft : null,
                    onSave: plan.teacherEditable ? () => _saveDraft(plan) : null,
                    onSubmit: plan.teacherEditable ? () => _submit(plan) : null,
                  ),
                  if (plan.reviewComment.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _ReviewCard(plan: plan),
                  ],
                  const SizedBox(height: 16),
                  _DeliveryPanel(
                    plan: plan,
                    delivery: delivery,
                    reflection: _reflection,
                    homework: _homework,
                    topicCompleted: _topicCompleted,
                    busy: _busy,
                    onTopicCompleted: (value) =>
                        setState(() => _topicCompleted = value),
                    onSaveDraft: () => _saveDelivery(plan, deliver: false),
                    onDeliver: () => _saveDelivery(plan, deliver: true),
                  ),
                  const SizedBox(height: 16),
                  _History(
                    plans: filtered,
                    selectedId: _selectedId,
                    controller: _queryController,
                    onChanged: (value) => setState(() => _query = value),
                    onSelect: (selected) => _selectPlan(selected, data),
                    onCreate: () => _createPlan(data),
                  ),
                  const SizedBox(height: 16),
                  const _BoundaryCard(),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.canonical, required this.onNavigate});

  final bool canonical;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TEACHER PORTAL · LESSON DELIVERY',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                ),
                Text(
                  'Lesson Plans & Delivery',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  canonical
                      ? 'Plan authorized occurrences in the rolling 21-day timetable horizon, submit for review, then record what was actually delivered.'
                      : 'Standalone demo lesson-plan workspace.',
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => onNavigate('timetable'),
                child: const Text('Timetable'),
              ),
              OutlinedButton(
                onPressed: () => onNavigate('syllabus'),
                child: const Text('Syllabus'),
              ),
              OutlinedButton(
                onPressed: () => onNavigate('attendance'),
                child: const Text('Attendance'),
              ),
            ],
          ),
        ],
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.canonical,
    required this.canCreate,
    required this.onCreate,
    required this.onNavigate,
  });

  final bool canonical;
  final bool canCreate;
  final VoidCallback onCreate;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.menu_book_outlined, size: 48),
                const SizedBox(height: 12),
                Text(
                  canonical
                      ? (canCreate
                          ? 'No lesson plans yet. Create one from an authorized occurrence in the current 21-day planning horizon.'
                          : 'No authorized occurrence with an approved curriculum topic is available in the current planning horizon.')
                      : 'No lesson-plan demo records are available.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: canCreate ? onCreate : null,
                      icon: const Icon(Icons.add),
                      label: const Text('New occurrence plan'),
                    ),
                    OutlinedButton(
                      onPressed: () => onNavigate('timetable'),
                      child: const Text('Open timetable'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
}

class _TermStats extends StatelessWidget {
  const _TermStats({required this.plans, required this.deliveries});

  final List<TeacherLessonPlan> plans;
  final List<TeacherLessonDelivery> deliveries;

  @override
  Widget build(BuildContext context) {
    final approved = plans
        .where((item) => item.status == TeacherLessonPlanStatus.approved)
        .length;
    final pending = plans
        .where((item) =>
            item.status == TeacherLessonPlanStatus.submitted ||
            item.status == TeacherLessonPlanStatus.queuedSubmission)
        .length;
    final delivered = deliveries
        .where((item) => item.state == TeacherLessonDeliveryState.delivered)
        .length;
    final completedTopics = deliveries
        .where((item) =>
            item.state == TeacherLessonDeliveryState.delivered &&
            item.topicCompleted)
        .length;
    final values = [
      ('Plans', '${plans.length}', 'visible occurrences'),
      ('Approved', '$approved', 'server reviewed'),
      ('Pending', '$pending', 'queued or under review'),
      ('Delivered', '$delivered', '$completedTopics topic completion signal(s)'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final item in values)
          SizedBox(
            width: 210,
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$1),
                    const SizedBox(height: 4),
                    Text(
                      item.$2,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(item.$3),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _OccurrenceCard extends StatelessWidget {
  const _OccurrenceCard({required this.plan});

  final TeacherLessonPlan plan;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Canonical lesson occurrence',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Chip(label: Text(teacherLessonPlanStatusLabel(plan.status))),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 22,
                runSpacing: 10,
                children: [
                  _Meta('Date', plan.lessonDate.isEmpty ? plan.week : plan.lessonDate),
                  _Meta('Class', plan.className),
                  _Meta('Subject', plan.subject.isEmpty ? '—' : plan.subject),
                  _Meta('Time', plan.time.isEmpty ? '—' : plan.time),
                  _Meta('Room', plan.room.isEmpty ? '—' : plan.room),
                  _Meta('Curriculum topic', plan.topic),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Occurrence, class, subject and date are fixed. The approved curriculum topic may be corrected while the plan is Draft or Returned; submission locks it for review.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
}

class _Meta extends StatelessWidget {
  const _Meta(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _PlanEditor extends StatelessWidget {
  const _PlanEditor({
    required this.plan,
    required this.topicOptions,
    required this.selectedTopicId,
    required this.busy,
    required this.objectives,
    required this.starter,
    required this.activities,
    required this.assessment,
    required this.resources,
    required this.onTopicChanged,
    required this.onGenerateAi,
    required this.onSave,
    required this.onSubmit,
  });

  final TeacherLessonPlan plan;
  final List<TeacherLessonPlanTopicOption> topicOptions;
  final String selectedTopicId;
  final bool busy;
  final TextEditingController objectives;
  final TextEditingController starter;
  final TextEditingController activities;
  final TextEditingController assessment;
  final TextEditingController resources;
  final ValueChanged<String> onTopicChanged;
  final VoidCallback? onGenerateAi;
  final VoidCallback? onSave;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final editable = plan.teacherEditable;
    final ids = {for (final item in topicOptions) item.id};
    final topicValue = ids.contains(selectedTopicId)
        ? selectedTopicId
        : (ids.contains(plan.topicId) ? plan.topicId : null);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lesson preparation',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    Text('Prepare evidence for this fixed timetable occurrence.'),
                  ],
                ),
                FilledButton.tonalIcon(
                  onPressed: onGenerateAi,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('AI draft'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (topicOptions.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: topicValue,
                decoration: const InputDecoration(
                  labelText: 'Approved curriculum topic',
                  helperText:
                      'Editable only while the plan is Draft or Returned for changes.',
                ),
                items: [
                  for (final topic in topicOptions)
                    DropdownMenuItem(
                      value: topic.id,
                      child: Text(
                        topic.sequence > 0
                            ? '${topic.sequence}. ${topic.title}'
                            : topic.title,
                      ),
                    ),
                ],
                onChanged: editable
                    ? (value) {
                        if (value != null) onTopicChanged(value);
                      }
                    : null,
              ),
              const SizedBox(height: 14),
            ],
            _TextArea(
              label: 'Learning objectives',
              controller: objectives,
              enabled: editable,
              hint: 'What should learners be able to do by the end?',
            ),
            _TextArea(
              label: 'Starter / prior knowledge',
              controller: starter,
              enabled: editable,
              hint: 'Opening activity and prior-knowledge check',
            ),
            _TextArea(
              label: 'Teaching and learner activities',
              controller: activities,
              enabled: editable,
              hint: 'Lesson flow, modelling, guided practice and learner activity',
              lines: 5,
            ),
            _TextArea(
              label: 'Assessment / evidence of learning',
              controller: assessment,
              enabled: editable,
              hint: 'How will you check whether learning happened?',
            ),
            _TextArea(
              label: 'Resources',
              controller: resources,
              enabled: editable,
              hint: 'Books, worksheets, equipment, links or files',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : onSave,
                  child: const Text('Save draft'),
                ),
                FilledButton(
                  onPressed: busy ? null : onSubmit,
                  child: Text(busy ? 'Working…' : 'Submit for review'),
                ),
              ],
            ),
            if (!editable) ...[
              const SizedBox(height: 10),
              Text(
                plan.status == TeacherLessonPlanStatus.queuedSubmission
                    ? 'Submission is queued and locked locally until the server responds.'
                    : 'This plan is locked for Teacher editing unless a reviewer returns it for changes.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.plan});
  final TeacherLessonPlan plan;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Principal review',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(plan.reviewComment),
              if (plan.reviewedAt != null) Text('Reviewed: ${plan.reviewedAt}'),
            ],
          ),
        ),
      );
}

class _DeliveryPanel extends StatelessWidget {
  const _DeliveryPanel({
    required this.plan,
    required this.delivery,
    required this.reflection,
    required this.homework,
    required this.topicCompleted,
    required this.busy,
    required this.onTopicCompleted,
    required this.onSaveDraft,
    required this.onDeliver,
  });

  final TeacherLessonPlan plan;
  final TeacherLessonDelivery? delivery;
  final TextEditingController reflection;
  final TextEditingController homework;
  final bool topicCompleted;
  final bool busy;
  final ValueChanged<bool> onTopicCompleted;
  final VoidCallback onSaveDraft;
  final VoidCallback onDeliver;

  @override
  Widget build(BuildContext context) {
    final state = delivery?.state ?? TeacherLessonDeliveryState.draft;
    final approved = plan.status == TeacherLessonPlanStatus.approved;
    final locked = state != TeacherLessonDeliveryState.draft;
    final lessonDate = DateTime.tryParse(plan.lessonDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reached = lessonDate == null || !lessonDate.isAfter(today);
    final enabled =
        approved && reached && !locked && plan.currentTeacherAuthorized;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Actual lesson delivery',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      Text('Record what happened after the scheduled occurrence.'),
                    ],
                  ),
                ),
                Chip(label: Text(teacherLessonDeliveryStateLabel(state))),
              ],
            ),
            const SizedBox(height: 12),
            if (!approved)
              const Text(
                'Delivery opens only after the server confirms Principal approval of this lesson plan.',
              )
            else if (!plan.currentTeacherAuthorized)
              const Text(
                'You can view this historical plan, but the occurrence is no longer assigned to your Teacher membership.',
              )
            else if (!reached)
              const Text(
                'This occurrence is still in the future. Delivery evidence cannot be recorded yet.',
              ),
            const SizedBox(height: 10),
            _TextArea(
              label: 'Teacher reflection',
              controller: reflection,
              enabled: enabled,
              hint:
                  'What worked, what learners struggled with, and what should change next?',
              lines: 4,
            ),
            _TextArea(
              label: 'Homework / follow-up',
              controller: homework,
              enabled: enabled,
              hint: 'Optional learner follow-up after this occurrence',
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: topicCompleted,
              onChanged: enabled ? (value) => onTopicCompleted(value ?? false) : null,
              title: const Text('Curriculum topic completed by this delivered lesson'),
              subtitle: const Text(
                'This evidence can move canonical syllabus coverage to Completed only after server acknowledgement.',
              ),
            ),
            if (delivery != null && delivery!.attendanceState != null) ...[
              const Divider(),
              Text(
                'Attendance evidence: ${delivery!.attendanceState} · '
                '${delivery!.attendancePresent}/${delivery!.attendanceTotal} present · '
                '${delivery!.attendanceAbsent} absent · ${delivery!.attendanceLate} late',
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy || !enabled ? null : onSaveDraft,
                  child: const Text('Save delivery draft'),
                ),
                FilledButton(
                  onPressed: busy || !enabled ? null : onDeliver,
                  child: const Text('Record delivered lesson'),
                ),
              ],
            ),
            if (state == TeacherLessonDeliveryState.queued) ...[
              const SizedBox(height: 8),
              const Text(
                'Delivery is queued, not canonical. Syllabus coverage remains unchanged until the server accepts it.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TextArea extends StatelessWidget {
  const _TextArea({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.hint,
    this.lines = 3,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final String hint;
  final int lines;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          enabled: enabled,
          minLines: lines,
          maxLines: lines,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            alignLabelWithHint: true,
          ),
        ),
      );
}

class _History extends StatelessWidget {
  const _History({
    required this.plans,
    required this.selectedId,
    required this.controller,
    required this.onChanged,
    required this.onSelect,
    required this.onCreate,
  });

  final List<TeacherLessonPlan> plans;
  final String? selectedId;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<TeacherLessonPlan> onSelect;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Occurrence lesson plans',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      Text('Each canonical plan stays attached to one scheduled occurrence.'),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      SizedBox(
                        width: 280,
                        child: TextField(
                          controller: controller,
                          onChanged: onChanged,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search_rounded),
                            hintText: 'Search plans...',
                            isDense: true,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: onCreate,
                        icon: const Icon(Icons.add),
                        label: const Text('New occurrence plan'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (plans.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No lesson plans match this search.'),
                )
              else
                for (final plan in plans)
                  ListTile(
                    selected: plan.id == selectedId,
                    onTap: () => onSelect(plan),
                    title: Text(
                      '${plan.className} · ${plan.subject.isEmpty ? plan.topic : plan.subject}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '${plan.lessonDate.isEmpty ? plan.week : plan.lessonDate} · '
                      '${plan.time.isEmpty ? plan.topic : '${plan.time} · ${plan.topic}'}\n'
                      '${plan.updatedLabel}',
                    ),
                    isThreeLine: true,
                    trailing: Chip(
                      label: Text(teacherLessonPlanStatusLabel(plan.status)),
                    ),
                  ),
            ],
          ),
        ),
      );
}

class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard();

  @override
  Widget build(BuildContext context) => const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lesson-delivery authority boundary',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 6),
              Text(
                'The timetable occurrence defines where and when the plan belongs. A Teacher may choose or correct only an approved curriculum topic while the plan remains editable. Submission does not equal Principal approval. A queued delivery does not equal a delivered lesson, and syllabus completion is generated only from server-accepted delivery evidence.',
              ),
              SizedBox(height: 6),
              Text(
                'AI may draft objectives, activities and assessment ideas, but it cannot approve a lesson plan, claim a lesson happened, or mark a curriculum topic complete.',
              ),
            ],
          ),
        ),
      );
}

class _NewPlanDraft {
  const _NewPlanDraft({required this.occurrence, required this.topic});

  final TeacherLessonPlanOccurrenceOption occurrence;
  final TeacherLessonPlanTopicOption topic;
}

class _NewPlanDialog extends StatefulWidget {
  const _NewPlanDialog({required this.occurrences});

  final List<TeacherLessonPlanOccurrenceOption> occurrences;

  @override
  State<_NewPlanDialog> createState() => _NewPlanDialogState();
}

class _NewPlanDialogState extends State<_NewPlanDialog> {
  late TeacherLessonPlanOccurrenceOption _occurrence = widget.occurrences.first;
  late TeacherLessonPlanTopicOption _topic = _occurrence.topics.first;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('New occurrence lesson plan'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _occurrence.id,
                decoration: const InputDecoration(labelText: 'Scheduled occurrence'),
                items: [
                  for (final item in widget.occurrences)
                    DropdownMenuItem(value: item.id, child: Text(item.label)),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  final next = widget.occurrences
                      .firstWhere((item) => item.id == value);
                  setState(() {
                    _occurrence = next;
                    _topic = next.topics.first;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(_occurrence.id),
                isExpanded: true,
                initialValue: _topic.id,
                decoration: const InputDecoration(
                  labelText: 'Approved curriculum topic',
                ),
                items: [
                  for (final item in _occurrence.topics)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text('${item.sequence}. ${item.title}'),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _topic = _occurrence.topics
                        .firstWhere((item) => item.id == value);
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              _NewPlanDraft(occurrence: _occurrence, topic: _topic),
            ),
            child: const Text('Create plan'),
          ),
        ],
      );
}
