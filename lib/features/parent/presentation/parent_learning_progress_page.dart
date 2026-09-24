import 'package:flutter/material.dart';

import '../data/parent_learning_progress_demo_data.dart';
import '../data/parent_learning_progress_repository.dart';
import '../domain/parent_learning_progress_models.dart';

class ParentLearningProgressPage extends StatefulWidget {
  const ParentLearningProgressPage({
    super.key,
    required this.repository,
    required this.onNavigate,
  });

  final ParentLearningProgressRepository repository;
  final ValueChanged<String> onNavigate;

  @override
  State<ParentLearningProgressPage> createState() =>
      _ParentLearningProgressPageState();
}

class _ParentLearningProgressPageState
    extends State<ParentLearningProgressPage> {
  late Future<ParentLearningProgressSnapshot> _snapshot;
  String? _selectedChildId;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.repository.load();
  }

  void _reload() {
    setState(() => _snapshot = widget.repository.load());
  }

  void _selectChild(String childId) {
    if (_selectedChildId == childId) return;
    setState(() => _selectedChildId = childId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ParentLearningProgressSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _LoadFailure(onRetry: _reload);
        }

        final data = snapshot.data!;
        if (data.children.isEmpty) {
          return _EmptyState(onBack: () => widget.onNavigate('children'));
        }

        final selected = data.childById(_selectedChildId ?? '') ?? data.children.first;
        _selectedChildId ??= selected.id;

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 1000 ? 28.0 : 16.0;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 36),
                children: [
                  _Header(onBack: () => widget.onNavigate('children')),
                  const SizedBox(height: 18),
                  _KpiGrid(child: selected),
                  if (selected.reportCard != null) ...[
                    const SizedBox(height: 16),
                    _ReportCardCard(child: selected),
                  ],
                  const SizedBox(height: 16),
                  _ResponsivePair(
                    left: _ChildrenSelector(
                      children: data.children,
                      selectedChildId: selected.id,
                      onSelected: _selectChild,
                    ),
                    right: _HistoryCard(child: selected),
                  ),
                  const SizedBox(height: 16),
                  _SubjectEvidenceCard(child: selected),
                  const SizedBox(height: 16),
                  _ResponsivePair(
                    left: _TopicLearningCard(child: selected),
                    right: _EvidenceMixCard(child: selected),
                  ),
                  const SizedBox(height: 16),
                  _ResponsivePair(
                    left: _LearningInsightCard(child: selected),
                    right: _LearningTimelineCard(child: selected),
                  ),
                  const SizedBox(height: 16),
                  const _GuardianBoundaryCard(),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FAMILY PORTAL · LEARNING PROGRESS',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              'Learning Progress',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              'See how your child is progressing across exams, classwork, assignments and attendance, with clear areas to practise next.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        );

        final back = OutlinedButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Back to My Children'),
        );

        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [text, const SizedBox(height: 14), back],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: text),
            const SizedBox(width: 20),
            back,
          ],
        );
      },
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.child});

  final ParentLearningChild child;

  @override
  Widget build(BuildContext context) {
    final strongest = child.strongestTopic;
    final priority = child.priorityTopic;
    final assignment = child.assignmentEvidence;

    final items = <_KpiData>[
      _KpiData(
        label: 'Current average',
        value: '${child.averagePercent}%',
        detail:
            '${child.improving ? 'Improving' : 'Needs review'} · ${child.trendLabel} trend',
        icon: Icons.analytics_outlined,
      ),
      _KpiData(
        label: 'Attendance',
        value: '${child.attendancePercent}%',
        detail: 'Context, not a cause by itself',
        icon: Icons.fact_check_outlined,
      ),
      _KpiData(
        label: 'Assignment completion',
        value: assignment?.value ?? '—',
        detail: assignment?.note ?? 'No current evidence',
        icon: Icons.assignment_turned_in_outlined,
      ),
      _KpiData(
        label: 'Strongest topic',
        value: strongest == null ? '—' : '${strongest.scorePercent}%',
        detail: strongest?.name ?? 'No topic evidence',
        icon: Icons.trending_up_rounded,
      ),
      _KpiData(
        label: 'Priority topic',
        value: priority == null ? '—' : '${priority.scorePercent}%',
        detail: priority?.name ?? 'No topic evidence',
        icon: Icons.track_changes_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 5
            : constraints.maxWidth >= 760
                ? 3
                : constraints.maxWidth >= 480
                    ? 2
                    : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(width: width, child: _KpiCard(data: item)),
          ],
        );
      },
    );
  }
}

class _KpiData {
  const _KpiData({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});

  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(data.icon, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              data.value,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              data.detail,
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
        if (constraints.maxWidth < 860) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 16), right],
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
      },
    );
  }
}

class _ChildrenSelector extends StatelessWidget {
  const _ChildrenSelector({
    required this.children,
    required this.selectedChildId,
    required this.onSelected,
  });

  final List<ParentLearningChild> children;
  final String selectedChildId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'My children',
      subtitle: 'Select a child to review the complete learning picture.',
      child: Column(
        children: [
          for (final child in children) ...[
            _ChildSelectorTile(
              child: child,
              selected: child.id == selectedChildId,
              onTap: () => onSelected(child.id),
            ),
            if (child != children.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ChildSelectorTile extends StatelessWidget {
  const _ChildSelectorTile({
    required this.child,
    required this.selected,
    required this.onTap,
  });

  final ParentLearningChild child;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: selected ? scheme.primary : scheme.surfaceContainerHighest,
                foregroundColor: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                child: Text(
                  _initials(child.name),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${child.className} · ${child.section}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Avg ${child.averagePercent}% · Attendance ${child.attendancePercent}%',
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    child.trendLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: child.improving ? scheme.primary : scheme.error,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _StatusChip(status: child.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ParentLearningStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final concern = status == ParentLearningStatus.watch ||
        status == ParentLearningStatus.needsSupport;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: concern ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: concern ? scheme.onErrorContainer : scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.child});

  final ParentLearningChild child;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Historical performance',
      subtitle: 'Seven-term learning trend.',
      child: SizedBox(
        height: 210,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final count = child.history.length;
            final gap = 8.0;
            final barWidth = count == 0
                ? constraints.maxWidth
                : (constraints.maxWidth - gap * (count - 1)) / count;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < count; index++) ...[
                  SizedBox(
                    width: barWidth,
                    child: _HistoryBar(
                      term: 'T${index + 1}',
                      value: child.history[index],
                    ),
                  ),
                  if (index < count - 1) SizedBox(width: gap),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HistoryBar extends StatelessWidget {
  const _HistoryBar({required this.term, required this.value});

  final String term;
  final int value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('$value%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: (value.clamp(20, 100)) / 100,
              widthFactor: .72,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(term, style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _SubjectEvidenceCard extends StatelessWidget {
  const _SubjectEvidenceCard({required this.child});

  final ParentLearningChild child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SectionCard(
      title: 'Subject evidence',
      subtitle:
          'Exams are only one part of the picture; classwork and assignments are shown beside them.',
      child: child.subjects.isEmpty
          ? const _NoEvidence()
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 720),
                child: Column(
                  children: [
                    const _SubjectRow(
                      subject: 'Subject',
                      exam: 'Exam',
                      classwork: 'Classwork',
                      assignment: 'Assignment',
                      trend: 'Trend',
                      header: true,
                    ),
                    Divider(color: scheme.outlineVariant),
                    for (final subject in child.subjects)
                      _SubjectRow(
                        subject: subject.subject,
                        exam: '${subject.examPercent}%',
                        classwork: '${subject.classworkPercent}%',
                        assignment: '${subject.assignmentPercent}%',
                        trend: subject.trendLabel,
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.subject,
    required this.exam,
    required this.classwork,
    required this.assignment,
    required this.trend,
    this.header = false,
  });

  final String subject;
  final String exam;
  final String classwork;
  final String assignment;
  final String trend;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: 12,
      fontWeight: header ? FontWeight.w900 : FontWeight.w600,
      color: header ? Theme.of(context).colorScheme.onSurfaceVariant : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          SizedBox(width: 220, child: Text(subject, style: textStyle)),
          SizedBox(width: 105, child: Text(exam, style: textStyle)),
          SizedBox(width: 115, child: Text(classwork, style: textStyle)),
          SizedBox(width: 125, child: Text(assignment, style: textStyle)),
          SizedBox(
            width: 100,
            child: Text(
              trend,
              style: textStyle.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicLearningCard extends StatelessWidget {
  const _TopicLearningCard({required this.child});

  final ParentLearningChild child;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Topic-level learning map',
      subtitle:
          'Pinpoint what needs reinforcement instead of labelling the whole subject as weak.',
      child: child.topics.isEmpty
          ? const _NoEvidence()
          : Column(
              children: [
                for (final topic in child.topics) ...[
                  _TopicTile(topic: topic),
                  if (topic != child.topics.last) const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.topic});

  final ParentLearningTopic topic;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(topic.name, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              Text('${topic.scorePercent}% evidence', style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: topic.scorePercent / 100,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 8),
          Text(topic.note, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ReportCardCard extends StatelessWidget {
  const _ReportCardCard({required this.child});

  final ParentLearningChild child;

  @override
  Widget build(BuildContext context) {
    final card = child.reportCard!;
    return _SectionCard(
      title: 'Term report card',
      subtitle: '${card.term} · Released',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${card.overallAverage?.round() ?? '—'}%${card.overallGrade.isEmpty ? '' : ' · ${card.overallGrade}'}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26),
          ),
          if (card.classPosition != null) Text('Position ${card.classPosition} of ${card.classSize}'),
          const SizedBox(height: 8),
          for (final line in card.subjects)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(line.subject)),
                  Text(
                    line.percent == null ? 'Not recorded' : '${line.percent!.round()}% · ${line.grade}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          if (card.classTeacherComment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Class teacher: ${card.classTeacherComment}'),
          ],
          if (card.principalComment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Principal: ${card.principalComment}'),
          ],
        ],
      ),
    );
  }
}

class _EvidenceMixCard extends StatelessWidget {
  const _EvidenceMixCard({required this.child});

  final ParentLearningChild child;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Evidence mix',
      subtitle: 'Current learning signals used in this prototype view.',
      child: child.evidence.isEmpty
          ? const _NoEvidence()
          : LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 500 ? 2 : 1;
                const gap = 10.0;
                final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final item in child.evidence)
                      SizedBox(width: width, child: _EvidenceTile(item: item)),
                  ],
                );
              },
            ),
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.item});

  final ParentLearningEvidenceItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 5),
          Text(item.value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(item.note, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _LearningInsightCard extends StatelessWidget {
  const _LearningInsightCard({required this.child});

  final ParentLearningChild child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: scheme.onPrimaryContainer),
                const SizedBox(width: 9),
                Text(
                  'Learning insight',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              child.insight,
              style: TextStyle(color: scheme.onPrimaryContainer, height: 1.45),
            ),
            if (child.actions.isNotEmpty) ...[
              const SizedBox(height: 14),
              for (final action in child.actions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.arrow_right_rounded,
                        size: 20,
                        color: scheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          action,
                          style: TextStyle(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LearningTimelineCard extends StatelessWidget {
  const _LearningTimelineCard({required this.child});

  final ParentLearningChild child;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Recent learning timeline',
      subtitle: 'Interventions, assessments and review points.',
      child: child.timeline.isEmpty
          ? const _NoEvidence()
          : Column(
              children: [
                for (final event in child.timeline) ...[
                  _TimelineTile(event: event),
                  if (event != child.timeline.last) const Divider(height: 22),
                ],
              ],
            ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event});

  final ParentLearningTimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(event.detail, style: TextStyle(height: 1.4, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 5),
              Text(
                event.dateLabel,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: scheme.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _GuardianBoundaryCard extends StatelessWidget {
  const _GuardianBoundaryCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              parentLearningProgressBoundary,
              style: TextStyle(height: 1.45, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoEvidence extends StatelessWidget {
  const _NoEvidence();

  @override
  Widget build(BuildContext context) {
    return Text(
      'No current family-visible learning evidence.',
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.trending_up_rounded, size: 42),
                  const SizedBox(height: 12),
                  const Text(
                    'No learning progress available',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'There are no linked children with family-visible learning evidence in this account.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: onBack,
                    icon: const Icon(Icons.family_restroom_outlined),
                    label: const Text('My Children'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 42),
                  const SizedBox(height: 12),
                  const Text(
                    'Unable to open learning progress',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'The locally available family learning record could not be loaded.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
}
