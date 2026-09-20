import 'package:flutter/material.dart';

import '../data/parent_school_life_demo_data.dart';
import '../data/parent_school_life_repository.dart';
import '../domain/parent_school_life_models.dart';

class ParentSchoolLifePage extends StatefulWidget {
  const ParentSchoolLifePage({
    super.key,
    required this.repository,
    required this.onNavigate,
  });

  final ParentSchoolLifeRepository repository;
  final ValueChanged<String> onNavigate;

  @override
  State<ParentSchoolLifePage> createState() => _ParentSchoolLifePageState();
}

class _ParentSchoolLifePageState extends State<ParentSchoolLifePage> {
  late Future<ParentSchoolLifeSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.repository.load();
  }

  void _reload() {
    setState(() => _snapshot = widget.repository.load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ParentSchoolLifeSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _SchoolLifeFailure(onRetry: _reload);
        }

        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 1000 ? 28.0 : 16.0;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 36),
                children: [
                  _SchoolLifeHeader(
                    onDashboard: () => widget.onNavigate('dashboard'),
                    onMessages: () => widget.onNavigate('messages'),
                  ),
                  const SizedBox(height: 18),
                  _ResponsivePair(
                    left: _ActivitiesCard(activities: data.activities),
                    right: _EventsCard(events: data.events),
                  ),
                  const SizedBox(height: 16),
                  _ResponsivePair(
                    left: _TransportCard(transport: data.transport),
                    right: _MealsCard(snapshot: data),
                  ),
                  const SizedBox(height: 16),
                  _RecognitionCard(items: data.recognition),
                  const SizedBox(height: 12),
                  const _BoundaryCard(
                    icon: Icons.auto_awesome_outlined,
                    title: 'School-life principle',
                    body: parentSchoolLifeRecognitionBoundary,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _SchoolLifeHeader extends StatelessWidget {
  const _SchoolLifeHeader({
    required this.onDashboard,
    required this.onMessages,
  });

  final VoidCallback onDashboard;
  final VoidCallback onMessages;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 14,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FAMILY ACCOUNT · SCHOOL LIFE',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'School Life',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Activities, events, transport, meals and family-visible participation for your linked children.',
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
              onPressed: onMessages,
              icon: const Icon(Icons.mail_outline_rounded),
              label: const Text('Ask school'),
            ),
          ],
        ),
      ],
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
            children: [
              left,
              const SizedBox(height: 16),
              right,
            ],
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

class _ActivitiesCard extends StatelessWidget {
  const _ActivitiesCard({required this.activities});

  final List<ParentSchoolLifeActivity> activities;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Activities & clubs',
      subtitle: 'Participation is separate from academic grades.',
      child: activities.isEmpty
          ? const _EmptyLine('No family-visible activities are available.')
          : Column(
              children: [
                for (final item in activities)
                  _ActivityRow(activity: item),
              ],
            ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final ParentSchoolLifeActivity activity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.groups_2_outlined, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.activity, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${activity.childName} · ${activity.schedule}'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(activity.status),
          ),
        ],
      ),
    );
  }
}

class _EventsCard extends StatelessWidget {
  const _EventsCard({required this.events});

  final List<ParentSchoolLifeEvent> events;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Upcoming events',
      subtitle: 'Family-relevant dates and notices.',
      child: events.isEmpty
          ? const _EmptyLine('No upcoming family-visible events.')
          : Column(
              children: [
                for (final event in events)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Text(
                        event.dateLabel.split(' ').first,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    title: Text(
                      event.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text('${event.dateLabel} · ${event.scope}'),
                  ),
              ],
            ),
    );
  }
}

class _TransportCard extends StatelessWidget {
  const _TransportCard({required this.transport});

  final List<ParentSchoolLifeTransport> transport;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Transport',
      subtitle: 'Guardian-safe transport summaries only.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in transport)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.directions_bus_outlined),
              title: Text(
                item.childName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${item.serviceCode} · ${item.status} · ${item.guardianSafeSummary}',
              ),
            ),
          const SizedBox(height: 8),
          const _BoundaryCard(
            icon: Icons.shield_outlined,
            title: 'Transport privacy',
            body: parentSchoolLifeTransportBoundary,
          ),
        ],
      ),
    );
  }
}

class _MealsCard extends StatelessWidget {
  const _MealsCard({required this.snapshot});

  final ParentSchoolLifeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Meals & routines',
      subtitle: 'General family-visible service information.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final meal in snapshot.mealPlans)
                _InfoTile(label: meal.childName, value: meal.planLabel),
              _InfoTile(label: 'Today', value: snapshot.todayMeal),
              _InfoTile(label: 'Service', value: snapshot.todayMealService),
            ],
          ),
          const SizedBox(height: 12),
          const _BoundaryCard(
            icon: Icons.health_and_safety_outlined,
            title: 'Minimum necessary health context',
            body: parentSchoolLifeMealsBoundary,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _RecognitionCard extends StatelessWidget {
  const _RecognitionCard({required this.items});

  final List<ParentSchoolLifeRecognition> items;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Awards & recognition',
      subtitle: 'Positive recognition without creating permanent child rankings.',
      child: items.isEmpty
          ? const _EmptyLine('No recognition items are available.')
          : Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in items)
                  Container(
                    constraints: const BoxConstraints(minWidth: 250, maxWidth: 390),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.workspace_premium_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.childName),
                              const SizedBox(height: 3),
                              Text(
                                item.title,
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 3),
                              Text(item.periodLabel),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
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
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(child: Text(message)),
    );
  }
}

class _SchoolLifeFailure extends StatelessWidget {
  const _SchoolLifeFailure({required this.onRetry});

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
            const SizedBox(height: 12),
            const Text(
              'School-life information could not be loaded.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
