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

  String _className = 'JSS 2A';
  String _week = 'Week 6';
  String _topic = 'Linear Equations';
  String _query = '';
  String _editorStatus = 'Draft';
  String? _notice;
  bool _busy = false;
  bool _initializedDraft = false;

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
    super.dispose();
  }

  TeacherLessonPlan _editorPlan(TeacherLessonPlan base) => base.copyWith(
        className: _className,
        week: _week,
        topic: _topic,
        objectives: _objectives.text,
        starter: _starter.text,
        activities: _activities.text,
        assessment: _assessment.text,
        resources: _resources.text,
      );

  void _initializeFromDraft(TeacherLessonPlan plan) {
    if (_initializedDraft) return;
    _initializedDraft = true;
    _className = plan.className;
    _week = teacherLessonPlanWeeks.contains(plan.week) ? plan.week : 'Week 6';
    _topic = teacherLessonPlanTopics.contains(plan.topic) ? plan.topic : 'Linear Equations';
    _objectives.text = plan.objectives;
    _starter.text = plan.starter;
    _activities.text = plan.activities;
    _assessment.text = plan.assessment;
    _resources.text = plan.resources;
    _editorStatus = teacherLessonPlanStatusLabel(plan.status);
  }

  void _generateAiDraft() {
    _objectives.text = teacherLessonPlanAiObjectives;
    _starter.text = teacherLessonPlanAiStarter;
    _activities.text = teacherLessonPlanAiActivities;
    _assessment.text = teacherLessonPlanAiAssessment;
    _resources.text = teacherLessonPlanAiResources;
    setState(() {
      _editorStatus = 'AI draft ready';
      _notice = 'AI generated a draft only. Review and edit it before saving or submitting.';
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
      _editorStatus = result.success ? 'Draft saved · sync pending' : _editorStatus;
      if (result.success) _future = widget.repository.load();
    });
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
      _editorStatus = result.success ? 'Submitted for approval · sync pending' : _editorStatus;
      if (result.success) _future = widget.repository.load();
    });
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
              onPressed: () => setState(() => _future = widget.repository.load()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry lesson plans'),
            ),
          );
        }

        final data = snapshot.requireData;
        final draft = data.plans.firstWhere(
          (plan) => plan.id == 'LP-206',
          orElse: () => data.plans.first,
        );
        _initializeFromDraft(draft);
        final filtered = data.plans.where((plan) => plan.matches(_query)).toList();
        final editable = draft.teacherEditable;

        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 820;
            return SingleChildScrollView(
              padding: EdgeInsets.all(compact ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(onNavigate: widget.onNavigate),
                  if (_notice != null) ...[
                    const SizedBox(height: 12),
                    _Notice(message: _notice!),
                  ],
                  const SizedBox(height: 16),
                  const _TermStats(),
                  const SizedBox(height: 16),
                  if (compact)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Editor(
                          className: _className,
                          week: _week,
                          topic: _topic,
                          editorStatus: _editorStatus,
                          editable: editable,
                          busy: _busy,
                          objectives: _objectives,
                          starter: _starter,
                          activities: _activities,
                          assessment: _assessment,
                          resources: _resources,
                          onClassChanged: (value) => setState(() => _className = value),
                          onWeekChanged: (value) => setState(() => _week = value),
                          onTopicChanged: (value) => setState(() => _topic = value),
                          onGenerateAi: editable ? _generateAiDraft : null,
                          onSave: editable ? () => _saveDraft(draft) : null,
                          onSubmit: editable ? () => _submit(draft) : null,
                          onNavigate: widget.onNavigate,
                        ),
                        const SizedBox(height: 16),
                        _PlanningGuide(onNavigate: widget.onNavigate),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: _Editor(
                            className: _className,
                            week: _week,
                            topic: _topic,
                            editorStatus: _editorStatus,
                            editable: editable,
                            busy: _busy,
                            objectives: _objectives,
                            starter: _starter,
                            activities: _activities,
                            assessment: _assessment,
                            resources: _resources,
                            onClassChanged: (value) => setState(() => _className = value),
                            onWeekChanged: (value) => setState(() => _week = value),
                            onTopicChanged: (value) => setState(() => _topic = value),
                            onGenerateAi: editable ? _generateAiDraft : null,
                            onSave: editable ? () => _saveDraft(draft) : null,
                            onSubmit: editable ? () => _submit(draft) : null,
                            onNavigate: widget.onNavigate,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(flex: 3, child: _PlanningGuide(onNavigate: widget.onNavigate)),
                      ],
                    ),
                  const SizedBox(height: 16),
                  _History(
                    plans: filtered,
                    controller: _queryController,
                    onChanged: (value) => setState(() => _query = value),
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
  const _Header({required this.onNavigate});
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 690),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TEACHER PORTAL · LESSON PLANS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                Text('Lesson Plans', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                const Text('Create, improve, submit and track lesson plans for your assigned classes.'),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(onPressed: () => onNavigate('dashboard'), child: const Text('Dashboard')),
              TextButton(onPressed: () => onNavigate('syllabus'), child: const Text('Open syllabus')),
              TextButton(onPressed: () => onNavigate('weekly-progress'), child: const Text('Weekly parent update')),
              TextButton(onPressed: () => onNavigate('messages'), child: const Text('Send / share work')),
            ],
          ),
        ],
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
  const _TermStats();

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final item in teacherLessonPlanTermKpis)
            SizedBox(
              width: 200,
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.$1),
                      const SizedBox(height: 4),
                      Text(item.$2, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      Text(item.$3),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
}

class _Editor extends StatelessWidget {
  const _Editor({
    required this.className,
    required this.week,
    required this.topic,
    required this.editorStatus,
    required this.editable,
    required this.busy,
    required this.objectives,
    required this.starter,
    required this.activities,
    required this.assessment,
    required this.resources,
    required this.onClassChanged,
    required this.onWeekChanged,
    required this.onTopicChanged,
    required this.onGenerateAi,
    required this.onSave,
    required this.onSubmit,
    required this.onNavigate,
  });

  final String className;
  final String week;
  final String topic;
  final String editorStatus;
  final bool editable;
  final bool busy;
  final TextEditingController objectives;
  final TextEditingController starter;
  final TextEditingController activities;
  final TextEditingController assessment;
  final TextEditingController resources;
  final ValueChanged<String> onClassChanged;
  final ValueChanged<String> onWeekChanged;
  final ValueChanged<String> onTopicChanged;
  final VoidCallback? onGenerateAi;
  final VoidCallback? onSave;
  final VoidCallback? onSubmit;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                      Text('Create lesson plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      Text('Build from the approved syllabus topic, then edit before submission.'),
                    ],
                  ),
                  Chip(label: Text(editorStatus)),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SelectField(label: 'Class', value: className, values: teacherLessonPlanClasses, enabled: editable, onChanged: onClassChanged),
                  _SelectField(label: 'Week', value: week, values: teacherLessonPlanWeeks, enabled: editable, onChanged: onWeekChanged),
                  _SelectField(label: 'Syllabus topic', value: topic, values: teacherLessonPlanTopics, enabled: editable, onChanged: onTopicChanged),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Teacher AI', style: TextStyle(fontWeight: FontWeight.w900)),
                            Text('Generate a structured first draft from $className, $week and the selected syllabus topic. You remain responsible for reviewing and editing it.'),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: onGenerateAi,
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('Generate AI draft'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _TextArea(label: 'Learning objectives', controller: objectives, enabled: editable, hint: 'What should learners be able to do by the end of this lesson?'),
              _TextArea(label: 'Starter / prior knowledge', controller: starter, enabled: editable, hint: 'Opening activity and prior-knowledge check'),
              _TextArea(label: 'Teaching and learner activities', controller: activities, enabled: editable, hint: 'Explain the lesson flow, modelling, guided practice and learner activity', lines: 5),
              _TextArea(label: 'Assessment / evidence of learning', controller: assessment, enabled: editable, hint: 'How will you know whether learners understood?'),
              _TextArea(label: 'Resources', controller: resources, enabled: editable, hint: 'Books, worksheets, equipment, links or files'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(onPressed: () => onNavigate('messages'), child: const Text('Share with principal / colleague')),
                  OutlinedButton(onPressed: () => onNavigate('weekly-progress'), child: const Text('Prepare weekly update')),
                  OutlinedButton(onPressed: busy ? null : onSave, child: const Text('Save draft')),
                  FilledButton(onPressed: busy ? null : onSubmit, child: Text(busy ? 'Working…' : 'Submit for approval')),
                ],
              ),
              if (!editable) ...[
                const SizedBox(height: 10),
                const Text('This plan is locked for teacher editing until reviewer action.'),
              ],
            ],
          ),
        ),
      );
}

class _SelectField extends StatelessWidget {
  const _SelectField({required this.label, required this.value, required this.values, required this.enabled, required this.onChanged});
  final String label;
  final String value;
  final List<String> values;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 210,
        child: DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: [for (final item in values) DropdownMenuItem(value: item, child: Text(item))],
          onChanged: enabled ? (next) { if (next != null) onChanged(next); } : null,
        ),
      );
}

class _TextArea extends StatelessWidget {
  const _TextArea({required this.label, required this.controller, required this.enabled, required this.hint, this.lines = 3});
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
          decoration: InputDecoration(labelText: label, hintText: hint, alignLabelWithHint: true),
        ),
      );
}

class _PlanningGuide extends StatelessWidget {
  const _PlanningGuide({required this.onNavigate});
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Planning guide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              for (final item in teacherLessonPlanGuide) ...[
                Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(item.$2),
                const SizedBox(height: 14),
              ],
              TextButton.icon(
                onPressed: () => onNavigate('syllabus'),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Check curriculum position'),
              ),
            ],
          ),
        ),
      );
}

class _History extends StatelessWidget {
  const _History({required this.plans, required this.controller, required this.onChanged});
  final List<TeacherLessonPlan> plans;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

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
                      Text('My lesson plans', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      Text('Recent plans and approval status'),
                    ],
                  ),
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: controller,
                      onChanged: onChanged,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search plans...', isDense: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (plans.isEmpty)
                const Padding(padding: EdgeInsets.all(16), child: Text('No lesson plans match this search.'))
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 760) {
                      return Column(
                        children: [
                          for (final plan in plans)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('${plan.id} · ${plan.className}', style: const TextStyle(fontWeight: FontWeight.w900)),
                              subtitle: Text('${plan.week} · ${plan.topic}\n${plan.updatedLabel}'),
                              isThreeLine: true,
                              trailing: Chip(label: Text(teacherLessonPlanStatusLabel(plan.status))),
                            ),
                        ],
                      );
                    }
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Plan')),
                          DataColumn(label: Text('Class')),
                          DataColumn(label: Text('Week')),
                          DataColumn(label: Text('Topic')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Updated')),
                        ],
                        rows: [
                          for (final plan in plans)
                            DataRow(cells: [
                              DataCell(Text(plan.id, style: const TextStyle(fontWeight: FontWeight.w900))),
                              DataCell(Text(plan.className)),
                              DataCell(Text(plan.week)),
                              DataCell(Text(plan.topic)),
                              DataCell(Chip(label: Text(teacherLessonPlanStatusLabel(plan.status)))),
                              DataCell(Text(plan.updatedLabel)),
                            ]),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      );
}

class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard();

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Lesson-plan authority & offline boundary', style: TextStyle(fontWeight: FontWeight.w900)),
              SizedBox(height: 6),
              Text(teacherLessonPlanAuthorityBoundary),
              SizedBox(height: 6),
              Text(teacherLessonPlanOfflineBoundary),
            ],
          ),
        ),
      );
}
