import 'package:flutter/material.dart';

import '../data/proprietor_school_life_data.dart';

class ProprietorSchoolLifePage extends StatelessWidget {
  const ProprietorSchoolLifePage({
    super.key,
    required this.schoolName,
    required this.onDashboard,
    required this.onCapabilityRequested,
  });

  final String schoolName;
  final VoidCallback onDashboard;
  final ValueChanged<ProprietorSchoolLifeCapability> onCapabilityRequested;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final maxWidth = constraints.maxWidth >= 1460 ? 1320.0 : 1180.0;

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
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      schoolName: schoolName,
                      compact: compact,
                      onDashboard: onDashboard,
                    ),
                    const SizedBox(height: 18),
                    const _ScopeBanner(),
                    const SizedBox(height: 18),
                    _Stats(compact: compact),
                    const SizedBox(height: 18),
                    _CapabilitySection(
                      compact: compact,
                      onCapabilityRequested: onCapabilityRequested,
                    ),
                    const SizedBox(height: 18),
                    _Principles(compact: compact),
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
    required this.onDashboard,
  });

  final String schoolName;
  final bool compact;
  final VoidCallback onDashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SCHOOL-WIDE FOUNDATION · ${schoolName.toUpperCase()}',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'School Life',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Everything that connects the school community beyond marks, attendance and fees.',
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          text,
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onDashboard,
            icon: const Icon(Icons.dashboard_outlined),
            label: const Text('Owner dashboard'),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: text),
        const SizedBox(width: 24),
        OutlinedButton.icon(
          onPressed: onDashboard,
          icon: const Icon(Icons.dashboard_outlined),
          label: const Text('Owner dashboard'),
        ),
      ],
    );
  }
}

class _ScopeBanner extends StatelessWidget {
  const _ScopeBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PROPRIETOR',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  proprietorSchoolLifeScope,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(proprietorSchoolLifeNote),
              ],
            ),
          ),
          Chip(
            avatar: const Icon(Icons.verified_user_outlined, size: 18),
            label: const Text('Role-aware access'),
            backgroundColor: theme.colorScheme.surface,
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final items = const [
      _StatData('Active role', 'Proprietor', 'Owner workspace context'),
      _StatData('Scope', 'Whole school', 'Does not bypass sensitivity rules'),
      _StatData('Shared modules', '16', 'One School Life layer'),
      _StatData('Cross-section override', 'Off', 'Use scoped memberships and permissions'),
      _StatData('Backend enforcement', 'Pending API', 'UI is not the security boundary'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = compact ? 1 : (constraints.maxWidth >= 1050 ? 5 : 3);
        final rows = <Widget>[];
        for (var start = 0; start < items.length; start += columns) {
          final end = (start + columns).clamp(0, items.length);
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = start; i < end; i++) ...[
                  Expanded(child: _StatCard(data: items[i])),
                  if (i != end - 1) const SizedBox(width: 10),
                ],
                for (var i = end; i < start + columns; i++) ...[
                  const Expanded(child: SizedBox()),
                  if (i != start + columns - 1) const SizedBox(width: 10),
                ],
              ],
            ),
          );
          if (end != items.length) rows.add(const SizedBox(height: 10));
        }
        return Column(children: rows);
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 7),
          Text(
            data.value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(data.note, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _CapabilitySection extends StatelessWidget {
  const _CapabilitySection({
    required this.compact,
    required this.onCapabilityRequested,
  });

  final bool compact;
  final ValueChanged<ProprietorSchoolLifeCapability> onCapabilityRequested;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Role permissions',
      subtitle:
          'What the Proprietor can do when each shared School Life module is connected to production authorization.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = compact ? 1 : (constraints.maxWidth >= 1050 ? 2 : 1);
          if (columns == 1) {
            return Column(
              children: [
                for (final capability in proprietorSchoolLifeCapabilities) ...[
                  _CapabilityCard(
                    capability: capability,
                    onTap: () => onCapabilityRequested(capability),
                  ),
                  if (capability != proprietorSchoolLifeCapabilities.last)
                    const SizedBox(height: 10),
                ],
              ],
            );
          }

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final capability in proprietorSchoolLifeCapabilities)
                SizedBox(
                  width: (constraints.maxWidth - 12) / 2,
                  child: _CapabilityCard(
                    capability: capability,
                    onTap: () => onCapabilityRequested(capability),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.capability, required this.onTap});

  final ProprietorSchoolLifeCapability capability;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconFor(capability.key),
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                capability.tag.toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                capability.module,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            capability.level,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      capability.detail,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      capability.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Shared School Life module',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 17,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Principles extends StatelessWidget {
  const _Principles({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cards = const [
      _PrincipleCard(
        kicker: 'ACCESS PRINCIPLE',
        title: 'One module, different authority',
        body: proprietorSchoolLifeAccessPrinciple,
        icon: Icons.account_tree_outlined,
      ),
      _PrincipleCard(
        kicker: 'PRODUCTION RULE',
        title: 'UI permissions are not security',
        body: proprietorSchoolLifeProductionRule,
        icon: Icons.security_outlined,
      ),
      _PrincipleCard(
        kicker: 'ACADEMIC BOUNDARY',
        title: 'School Life stays separate from grades',
        body:
            'House points, participation, awards and service records can support school culture without changing academic marks or creating permanent student ranking.',
        icon: Icons.school_outlined,
      ),
    ];

    if (compact) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i != cards.length - 1) const SizedBox(height: 10),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i != cards.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _PrincipleCard extends StatelessWidget {
  const _PrincipleCard({
    required this.kicker,
    required this.title,
    required this.body,
    required this.icon,
  });

  final String kicker;
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            kicker,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _StatData {
  const _StatData(this.label, this.value, this.note);

  final String label;
  final String value;
  final String note;
}

IconData _iconFor(String key) {
  return switch (key) {
    'community' => Icons.forum_outlined,
    'noticeboard' => Icons.campaign_outlined,
    'activities' => Icons.sports_basketball_outlined,
    'events' => Icons.calendar_month_outlined,
    'houses' => Icons.groups_outlined,
    'gallery' => Icons.photo_library_outlined,
    'excursions' => Icons.directions_bus_filled_outlined,
    'transport' => Icons.route_outlined,
    'meals' => Icons.restaurant_outlined,
    'boarding' => Icons.bed_outlined,
    'assembly' => Icons.record_voice_over_outlined,
    'visitors' => Icons.badge_outlined,
    'lost-found' => Icons.inventory_2_outlined,
    'service' => Icons.volunteer_activism_outlined,
    'awards' => Icons.emoji_events_outlined,
    'teaching-models' => Icons.model_training_outlined,
    _ => Icons.widgets_outlined,
  };
}
