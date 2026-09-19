import 'package:flutter/material.dart';

import '../data/administrator_dashboard_demo_data.dart';
import '../domain/administrator_dashboard_models.dart';

class AdministratorDashboardPage extends StatelessWidget {
  const AdministratorDashboardPage({
    super.key,
    required this.schoolName,
    required this.onActionRequested,
  });

  final String schoolName;
  final ValueChanged<String> onActionRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        final contentPadding = compact ? 16.0 : 28.0;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            contentPadding,
            22,
            contentPadding,
            40,
          ),
          children: [
            _Header(
              schoolName: schoolName,
              compact: compact,
              onSearchRecords: () => onActionRequested('students'),
              onRegisterStudent: () => onActionRequested('registration'),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final kpi in administratorKpis)
                  SizedBox(
                    width: compact ? 165 : 205,
                    child: _KpiCard(kpi: kpi),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            if (compact) ...[
              const _WorkQueueCard(),
              const SizedBox(height: 14),
              const _TodayCard(),
            ] else
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _WorkQueueCard()),
                  SizedBox(width: 16),
                  Expanded(child: _TodayCard()),
                ],
              ),
            const SizedBox(height: 18),
            Text(
              'Quick actions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final action in administratorQuickActions)
                  SizedBox(
                    width: compact ? double.infinity : 285,
                    child: _QuickActionCard(
                      action: action,
                      onTap: () => onActionRequested(action.key),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.admin_panel_settings_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Administrator authority: ',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            TextSpan(text: administratorAuthorityBoundary),
                          ],
                        ),
                      ),
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

class _Header extends StatelessWidget {
  const _Header({
    required this.schoolName,
    required this.compact,
    required this.onSearchRecords,
    required this.onRegisterStudent,
  });

  final String schoolName;
  final bool compact;
  final VoidCallback onSearchRecords;
  final VoidCallback onRegisterStudent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SCHOOL ADMINISTRATION · KADUNA CAMPUS',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Administrator Dashboard',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Manage student registration, school records, family accounts, staff files and operational workflows for $schoolName.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: onSearchRecords,
          icon: const Icon(Icons.search_rounded),
          label: const Text('Search records'),
        ),
        FilledButton.icon(
          onPressed: onRegisterStudent,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Register student'),
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [title, const SizedBox(height: 16), actions],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        const SizedBox(width: 20),
        actions,
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi});

  final AdministratorKpi kpi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kpi.label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 7),
            Text(
              kpi.value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              kpi.detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkQueueCard extends StatelessWidget {
  const _WorkQueueCard();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Administration Work Queue',
      subtitle: 'Operational records that need action today.',
      children: [
        for (final item in administratorWorkQueue)
          _ListItem(
            title: item.title,
            detail: item.detail,
            trailing: item.area,
          ),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Today at the Admin Desk',
      subtitle: 'Current prototype activity.',
      children: [
        for (final activity in administratorTodayActivities)
          _ListItem(title: activity.title, detail: activity.detail),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 14),
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index != children.length - 1) const Divider(height: 22),
            ],
          ],
        ),
      ),
    );
  }
}

class _ListItem extends StatelessWidget {
  const _ListItem({
    required this.title,
    required this.detail,
    this.trailing,
  });

  final String title;
  final String detail;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.chevron_right_rounded, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Chip(label: Text(trailing!)),
        ],
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action, required this.onTap});

  final AdministratorQuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.arrow_forward_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(action.description),
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
