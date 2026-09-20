import 'package:flutter/material.dart';

import '../data/parent_children_demo_data.dart';
import '../data/parent_children_repository.dart';
import '../domain/parent_children_models.dart';
import 'parent_child_profile_page.dart';

class ParentChildrenPage extends StatefulWidget {
  const ParentChildrenPage({
    super.key,
    required this.repository,
    required this.schoolName,
    required this.onNavigate,
  });

  final ParentChildrenRepository repository;
  final String schoolName;
  final ValueChanged<String> onNavigate;

  @override
  State<ParentChildrenPage> createState() => _ParentChildrenPageState();
}

class _ParentChildrenPageState extends State<ParentChildrenPage> {
  late Future<ParentChildrenSnapshot> _snapshot;

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
    return FutureBuilder<ParentChildrenSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _LoadFailure(onRetry: _reload);
        }

        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 900 ? 28.0 : 16.0;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 36),
                children: [
                  _Header(
                    onDashboard: () => widget.onNavigate('dashboard'),
                    onContactSchool: () => widget.onNavigate('messages'),
                  ),
                  const SizedBox(height: 18),
                  if (data.children.isEmpty)
                    const _EmptyChildrenCard()
                  else
                    _ChildrenGrid(
                      children: data.children,
                      onOpenProfile: (child) => _openProfile(data, child),
                      onFinance: () => widget.onNavigate('finance'),
                      onMessageSchool: () => widget.onNavigate('messages'),
                    ),
                  const SizedBox(height: 16),
                  const _PrivacyBoundary(),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openProfile(
    ParentChildrenSnapshot snapshot,
    ParentLinkedChild child,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ParentChildProfilePage(
          child: child,
          schoolName: widget.schoolName,
          academicPeriod: snapshot.academicPeriod,
          onNavigate: widget.onNavigate,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onDashboard,
    required this.onContactSchool,
  });

  final VoidCallback onDashboard;
  final VoidCallback onContactSchool;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FAMILY ACCOUNT · LINKED CHILDREN',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              'My Children',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              'Academic, attendance, finance and school-life summaries for children linked to this guardian account.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );

        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onDashboard,
              icon: const Icon(Icons.home_outlined, size: 18),
              label: const Text('Dashboard'),
            ),
            FilledButton.icon(
              onPressed: onContactSchool,
              icon: const Icon(Icons.mail_outline_rounded, size: 18),
              label: const Text('Contact school'),
            ),
          ],
        );

        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [text, const SizedBox(height: 14), actions],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: text),
            const SizedBox(width: 20),
            actions,
          ],
        );
      },
    );
  }
}

class _ChildrenGrid extends StatelessWidget {
  const _ChildrenGrid({
    required this.children,
    required this.onOpenProfile,
    required this.onFinance,
    required this.onMessageSchool,
  });

  final List<ParentLinkedChild> children;
  final ValueChanged<ParentLinkedChild> onOpenProfile;
  final VoidCallback onFinance;
  final VoidCallback onMessageSchool;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 900;
        final gap = 16.0;
        final cardWidth = twoColumns
            ? (constraints.maxWidth - gap) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(
                width: cardWidth,
                child: _ChildCard(
                  child: child,
                  onOpenProfile: () => onOpenProfile(child),
                  onFinance: onFinance,
                  onMessageSchool: onMessageSchool,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({
    required this.child,
    required this.onOpenProfile,
    required this.onFinance,
    required this.onMessageSchool,
  });

  final ParentLinkedChild child;
  final VoidCallback onOpenProfile;
  final VoidCallback onFinance;
  final VoidCallback onMessageSchool;

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: Text(
                    child.initials,
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${child.className} · ${child.section} · ${child.id}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                    child.active
                        ? Icons.check_circle_outline_rounded
                        : Icons.pause_circle_outline_rounded,
                    size: 16,
                  ),
                  label: Text(child.active ? 'Active' : 'Inactive'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoGrid(
              items: [
                ('Class teacher', child.classTeacher),
                ('Attendance', child.attendanceLabel),
                (child.learningMetricLabel, child.learningLabel),
                ('House', child.house),
                ('Current balance', _naira(child.currentBalance)),
                ('Today', child.presentToday ? 'Present' : 'Not marked present'),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onOpenProfile,
                  icon: const Icon(Icons.person_outline_rounded, size: 18),
                  label: const Text('Open full profile'),
                ),
                OutlinedButton.icon(
                  onPressed: onFinance,
                  icon: const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                  ),
                  label: const Text('Finance'),
                ),
                OutlinedButton.icon(
                  onPressed: onMessageSchool,
                  icon: const Icon(Icons.mail_outline_rounded, size: 18),
                  label: const Text('Message school'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 3 : 2;
        final gap = 10.0;
        final itemWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$1,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$2,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
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

class _PrivacyBoundary extends StatelessWidget {
  const _PrivacyBoundary();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.privacy_tip_outlined, color: scheme.primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                parentChildrenPrivacyBoundary,
                style: TextStyle(height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChildrenCard extends StatelessWidget {
  const _EmptyChildrenCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.family_restroom_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'No linked children',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'No student relationship is currently linked to this guardian membership.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
                    'Unable to open linked children',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'The locally available family record could not be loaded.',
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

String _naira(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return '₦$buffer';
}
