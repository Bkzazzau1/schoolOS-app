import 'package:flutter/material.dart';

import '../data/parent_children_demo_data.dart';
import '../domain/parent_children_models.dart';

class ParentChildProfilePage extends StatelessWidget {
  const ParentChildProfilePage({
    super.key,
    required this.child,
    required this.schoolName,
    required this.academicPeriod,
    required this.onNavigate,
  });

  final ParentLinkedChild child;
  final String schoolName;
  final String academicPeriod;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(child.name),
        actions: [
          IconButton(
            tooltip: 'Message school',
            onPressed: () => _openWorkspaceDestination(context, 'messages'),
            icon: const Icon(Icons.mail_outline_rounded),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 900 ? 28.0 : 16.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 36),
            children: [
              _ProfileHeader(
                child: child,
                schoolName: schoolName,
                onMessage: () => _openWorkspaceDestination(context, 'messages'),
              ),
              const SizedBox(height: 16),
              _ProfileHero(child: child),
              const SizedBox(height: 16),
              _ResponsivePair(
                left: _LearningCard(child: child),
                right: _FinanceCard(
                  child: child,
                  academicPeriod: academicPeriod,
                  onOpenFinance: () => _openWorkspaceDestination(context, 'finance'),
                ),
              ),
              const SizedBox(height: 16),
              _ResponsivePair(
                left: _TimelineCard(child: child),
                right: _SchoolLifeCard(
                  child: child,
                  onNavigate: (key) => _openWorkspaceDestination(context, key),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openWorkspaceDestination(BuildContext context, String key) {
    Navigator.of(context).pop();
    onNavigate(key);
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.child,
    required this.schoolName,
    required this.onMessage,
  });

  final ParentLinkedChild child;
  final String schoolName;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MY CHILDREN · ${child.section.toUpperCase()}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              child.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              '${child.className} · ${child.admissionNumber} · $schoolName',
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
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('All children'),
            ),
            FilledButton.icon(
              onPressed: onMessage,
              icon: const Icon(Icons.mail_outline_rounded, size: 18),
              label: const Text('Message school'),
            ),
          ],
        );

        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [details, const SizedBox(height: 14), actions],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: details),
            const SizedBox(width: 20),
            actions,
          ],
        );
      },
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.child});

  final ParentLinkedChild child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final identity = Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: Text(
                    child.initials,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text('${child.section} · ${child.className}'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatusChip(
                            label: child.active ? 'Active' : 'Inactive',
                            icon: child.active
                                ? Icons.check_circle_outline_rounded
                                : Icons.pause_circle_outline_rounded,
                          ),
                          _StatusChip(
                            label: child.house,
                            icon: Icons.shield_outlined,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );

            final attendance = Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TODAY',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    child.presentToday ? 'Present' : 'Not marked present',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text('Attendance ${child.attendanceLabel}'),
                ],
              ),
            );

            if (constraints.maxWidth < 700) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [identity, const SizedBox(height: 16), attendance],
              );
            }

            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 190),
                  child: attendance,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LearningCard extends StatelessWidget {
  const _LearningCard({required this.child});

  final ParentLinkedChild child;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Learning & attendance',
      subtitle: 'Age-appropriate school progress visible to the family.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoGrid(
            items: [
              ('Class teacher', child.classTeacher),
              ('Attendance', child.attendanceLabel),
              (child.learningMetricLabel, child.learningLabel),
              ('Transport', child.transport),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (var i = 0; i < child.subjects.length; i++) ...[
                  ListTile(
                    dense: true,
                    title: Text(child.subjects[i].subject),
                    trailing: Text(
                      child.subjects[i].progress,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (i != child.subjects.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Callout(
            icon: Icons.info_outline_rounded,
            message: child.familyLearningContext,
          ),
        ],
      ),
    );
  }
}

class _FinanceCard extends StatelessWidget {
  const _FinanceCard({
    required this.child,
    required this.academicPeriod,
    required this.onOpenFinance,
  });

  final ParentLinkedChild child;
  final String academicPeriod;
  final VoidCallback onOpenFinance;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Family finance summary',
      subtitle: 'Current child account summary; detailed controls stay in Family Finance.',
      trailing: TextButton(
        onPressed: onOpenFinance,
        child: const Text('Open finance →'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoGrid(
            items: [
              ('Current balance', _naira(child.currentBalance)),
              ('Term', academicPeriod),
              ('Payment account', child.paymentAccount),
              ('Payment plan', child.paymentPlan),
            ],
          ),
          const SizedBox(height: 14),
          const _Callout(
            icon: Icons.lock_outline_rounded,
            message: parentChildFinanceBoundary,
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.child});

  final ParentLinkedChild child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SectionCard(
      title: 'Recent school timeline',
      subtitle: 'Family-visible updates only.',
      child: Column(
        children: [
          for (var i = 0; i < child.timeline.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 58,
                    child: Text(
                      child.timeline[i].dateLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (i != child.timeline.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: scheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: i == child.timeline.length - 1 ? 0 : 18,
                      ),
                      child: Text(child.timeline[i].description),
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

class _SchoolLifeCard extends StatelessWidget {
  const _SchoolLifeCard({
    required this.child,
    required this.onNavigate,
  });

  final ParentLinkedChild child;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'School life & services',
      subtitle: 'Participation and operational services for this child.',
      child: Column(
        children: [
          _DestinationRow(
            icon: Icons.celebration_outlined,
            title: 'Activities & clubs',
            detail: child.activities,
            onTap: () => onNavigate('school-life'),
          ),
          const Divider(height: 1),
          _DestinationRow(
            icon: Icons.directions_bus_outlined,
            title: 'Transport',
            detail: '${child.transport} · Guardian-safe route summary',
            onTap: () => onNavigate('school-life'),
          ),
          const Divider(height: 1),
          _DestinationRow(
            icon: Icons.description_outlined,
            title: 'Documents & consent',
            detail: 'Reports, consent forms and approved family documents',
            onTap: () => onNavigate('documents'),
          ),
          const Divider(height: 1),
          _DestinationRow(
            icon: Icons.auto_awesome_rounded,
            title: 'Parent AI',
            detail: 'Ask questions about this child using family-visible context',
            onTap: () => onNavigate('ai'),
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
        if (constraints.maxWidth < 820) {
          return Column(
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 16),
            child,
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
        final twoColumns = constraints.maxWidth >= 440;
        final itemWidth = twoColumns
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
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

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(detail),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
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
