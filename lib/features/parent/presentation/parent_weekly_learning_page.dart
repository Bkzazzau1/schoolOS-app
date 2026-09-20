import 'package:flutter/material.dart';

import '../data/parent_weekly_learning_demo_data.dart';
import '../data/parent_weekly_learning_repository.dart';
import '../domain/parent_weekly_learning_models.dart';

class ParentWeeklyLearningPage extends StatefulWidget {
  const ParentWeeklyLearningPage({
    super.key,
    required this.repository,
  });

  final ParentWeeklyLearningRepository repository;

  @override
  State<ParentWeeklyLearningPage> createState() =>
      _ParentWeeklyLearningPageState();
}

class _ParentWeeklyLearningPageState extends State<ParentWeeklyLearningPage> {
  late Future<ParentWeeklyLearningSnapshot> _snapshot;
  String? _selectedChildId;
  String? _selectedUpdateId;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.repository.load();
  }

  void _reload() {
    setState(() => _snapshot = widget.repository.load());
  }

  void _selectChild(String? childId) {
    if (childId == null || childId == _selectedChildId) return;
    setState(() {
      _selectedChildId = childId;
      _selectedUpdateId = null;
    });
  }

  void _selectUpdate(String updateId) {
    if (updateId == _selectedUpdateId) return;
    setState(() => _selectedUpdateId = updateId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ParentWeeklyLearningSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _LoadFailure(onRetry: _reload);
        }

        final data = snapshot.data!;
        final children = data.children;
        if (children.isEmpty) {
          return const _EmptyState();
        }

        final child = children.firstWhere(
          (item) => item.id == _selectedChildId,
          orElse: () => children.first,
        );
        final updates = data.updatesForChild(child.id);
        if (updates.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _Header(
                  children: children,
                  selectedChildId: child.id,
                  onChildChanged: _selectChild,
                ),
                const SizedBox(height: 18),
                const _NoPublishedUpdate(),
              ],
            ),
          );
        }

        final current = updates.firstWhere(
          (item) => item.id == _selectedUpdateId,
          orElse: () => updates.first,
        );

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 1000 ? 28.0 : 16.0;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 36),
                children: [
                  _Header(
                    children: children,
                    selectedChildId: child.id,
                    onChildChanged: _selectChild,
                  ),
                  const SizedBox(height: 18),
                  _WeeklyHero(update: current),
                  const SizedBox(height: 16),
                  _HistoryAndSubjects(
                    updates: updates,
                    current: current,
                    onSelectUpdate: _selectUpdate,
                  ),
                  const SizedBox(height: 16),
                  _BottomCards(update: current),
                  const SizedBox(height: 16),
                  const _LearningBoundaryCard(),
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
  const _Header({
    required this.children,
    required this.selectedChildId,
    required this.onChildChanged,
  });

  final List<ParentWeeklyLearningChild> children;
  final String selectedChildId;
  final ValueChanged<String?> onChildChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FAMILY PORTAL · WEEKLY LEARNING',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              'Weekly Learning Update',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              'See what your child learned this week, classroom evidence, what comes next and where a little extra practice may help.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );

        final selector = ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
          child: DropdownButtonFormField<String>(
            initialValue: selectedChildId,
            decoration: const InputDecoration(
              labelText: 'Child',
              prefixIcon: Icon(Icons.family_restroom_rounded),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final child in children)
                DropdownMenuItem(
                  value: child.id,
                  child: Text(child.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onChildChanged,
          ),
        );

        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [title, const SizedBox(height: 14), selector],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: title),
            const SizedBox(width: 20),
            selector,
          ],
        );
      },
    );
  }
}

class _WeeklyHero extends StatelessWidget {
  const _WeeklyHero({required this.update});

  final ParentWeeklyLearningUpdate update;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final main = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${update.weekLabel} · ${update.dateLabel}',
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                update.childName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '${update.className} · Class teacher: ${update.teacher}',
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
            ],
          );

          final status = Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_outlined, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Published',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                SizedBox(height: 3),
                Text(
                  'Parent-safe weekly summary',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          );

          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [main, const SizedBox(height: 14), status],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: main),
              const SizedBox(width: 20),
              status,
            ],
          );
        },
      ),
    );
  }
}

class _HistoryAndSubjects extends StatelessWidget {
  const _HistoryAndSubjects({
    required this.updates,
    required this.current,
    required this.onSelectUpdate,
  });

  final List<ParentWeeklyLearningUpdate> updates;
  final ParentWeeklyLearningUpdate current;
  final ValueChanged<String> onSelectUpdate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final history = _WeeklyHistory(
          updates: updates,
          currentId: current.id,
          onSelectUpdate: onSelectUpdate,
        );
        final subjects = _SubjectUpdates(update: current);

        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [history, const SizedBox(height: 16), subjects],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 270, child: history),
            const SizedBox(width: 16),
            Expanded(child: subjects),
          ],
        );
      },
    );
  }
}

class _WeeklyHistory extends StatelessWidget {
  const _WeeklyHistory({
    required this.updates,
    required this.currentId,
    required this.onSelectUpdate,
  });

  final List<ParentWeeklyLearningUpdate> updates;
  final String currentId;
  final ValueChanged<String> onSelectUpdate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Weekly history',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Look back at previous published updates.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            for (final update in updates) ...[
              Material(
                color: update.id == currentId
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelectUpdate(update.id),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                update.weekLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                update.dateLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                '${update.subjects.length} subject updates',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (update.id == currentId)
                          Icon(Icons.check_circle_rounded, color: scheme.primary),
                      ],
                    ),
                  ),
                ),
              ),
              if (update != updates.last) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubjectUpdates extends StatelessWidget {
  const _SubjectUpdates({required this.update});

  final ParentWeeklyLearningUpdate update;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'What happened this week',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Based on the teacher’s lesson plan and actual classroom delivery.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            for (final subject in update.subjects) ...[
              _SubjectCard(subject: subject),
              if (subject != update.subjects.last) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject});

  final ParentWeeklySubjectUpdate subject;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subject.subject,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Chip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(Icons.check_rounded, size: 15),
                label: Text('Completed'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _DetailLine(label: 'This week', value: subject.thisWeek),
          const SizedBox(height: 9),
          _DetailLine(
            label: 'Learning evidence',
            value: subject.learningEvidence,
          ),
          const SizedBox(height: 9),
          _DetailLine(label: 'Next', value: subject.nextTopic),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.tips_and_updates_outlined, size: 17, color: scheme.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  subject.practiceNote,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 126,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _BottomCards extends StatelessWidget {
  const _BottomCards({required this.update});

  final ParentWeeklyLearningUpdate update;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final note = _InfoCard(
          title: 'Teacher’s weekly note',
          subtitle: 'Short summary for the family.',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(update.teacherNote, style: const TextStyle(height: 1.45)),
          ),
        );

        const guidance = _InfoCard(
          title: 'How to use this update',
          subtitle:
              'Support learning without turning the weekly update into another report card.',
          child: Column(
            children: [
              _GuidanceItem(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Ask about the topic',
                detail:
                    'Let your child explain what was learned in their own words.',
              ),
              SizedBox(height: 11),
              _GuidanceItem(
                icon: Icons.edit_note_rounded,
                title: 'Use suggested practice',
                detail: 'Focus on the specific topic named by the teacher.',
              ),
              SizedBox(height: 11),
              _GuidanceItem(
                icon: Icons.calendar_today_outlined,
                title: 'Check next week',
                detail: 'You can see what the class plans to learn next.',
              ),
            ],
          ),
        );

        if (constraints.maxWidth < 820) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [note, const SizedBox(height: 16), guidance],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: note),
            const SizedBox(width: 16),
            const Expanded(child: guidance),
          ],
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _GuidanceItem extends StatelessWidget {
  const _GuidanceItem({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(
                detail,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LearningBoundaryCard extends StatelessWidget {
  const _LearningBoundaryCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.shield_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(parentWeeklyLearningBoundary, style: TextStyle(height: 1.45)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoPublishedUpdate extends StatelessWidget {
  const _NoPublishedUpdate();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'No published weekly update',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Teacher drafts and queued publications are not visible in the Family Portal. A weekly update appears here only after publication is confirmed.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No published weekly learning updates are available for this family account.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                    'Unable to open weekly learning',
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
