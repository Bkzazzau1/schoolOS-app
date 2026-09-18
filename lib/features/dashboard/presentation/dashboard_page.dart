import 'package:flutter/material.dart';

import '../../../shared/layout/app_breakpoints.dart';
import '../../../shared/models/school_membership.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.membership,
  });

  final SchoolMembership membership;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  static const _destinations = <_AppDestination>[
    _AppDestination('Dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded),
    _AppDestination('Students', Icons.groups_outlined, Icons.groups_rounded),
    _AppDestination('Attendance', Icons.fact_check_outlined, Icons.fact_check_rounded),
    _AppDestination('Academics', Icons.menu_book_outlined, Icons.menu_book_rounded),
    _AppDestination('Messages', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final phone = AppBreakpoints.isPhone(constraints.maxWidth);

        if (phone) {
          return Scaffold(
            appBar: AppBar(
              title: _SchoolTitle(membership: widget.membership),
              actions: const [
                _SyncStatusButton(),
                SizedBox(width: 8),
              ],
            ),
            body: _Workspace(
              destination: _destinations[_selectedIndex],
              membership: widget.membership,
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              destinations: [
                for (final item in _destinations)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: item.label,
                  ),
              ],
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  extended: constraints.maxWidth >= 1180,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() => _selectedIndex = index);
                  },
                  leading: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    child: _SchoolMark(membership: widget.membership),
                  ),
                  destinations: [
                    for (final item in _destinations)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: Text(item.label),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 18, 28, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: _SchoolTitle(membership: widget.membership),
                            ),
                            const _SyncStatusButton(),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: _Workspace(
                          destination: _destinations[_selectedIndex],
                          membership: widget.membership,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Workspace extends StatelessWidget {
  const _Workspace({
    required this.destination,
    required this.membership,
  });

  final _AppDestination destination;
  final SchoolMembership membership;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          destination.label,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${membership.roleLabel} workspace · ${membership.schoolName}',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: const [
            _SummaryCard(
              label: 'Offline status',
              value: 'Ready',
              icon: Icons.cloud_done_outlined,
            ),
            _SummaryCard(
              label: 'Pending sync',
              value: '0',
              icon: Icons.sync_rounded,
            ),
            _SummaryCard(
              label: 'Edge AI',
              value: 'Foundation',
              icon: Icons.auto_awesome_outlined,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Foundation workspace',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This shell is ready for role-based modules. The next implementation step is authentication/session handling, local persistence, and the first offline attendance workflow.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 220,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 18),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchoolTitle extends StatelessWidget {
  const _SchoolTitle({required this.membership});

  final SchoolMembership membership;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SchoolMark(membership: membership),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                membership.schoolName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                membership.roleLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SchoolMark extends StatelessWidget {
  const _SchoolMark({required this.membership});

  final SchoolMembership membership;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CircleAvatar(
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      child: Text(membership.schoolName.characters.first.toUpperCase()),
    );
  }
}

class _SyncStatusButton extends StatelessWidget {
  const _SyncStatusButton();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'No changes waiting to sync',
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.cloud_done_outlined, size: 18),
        label: const Text('Synced'),
      ),
    );
  }
}

class _AppDestination {
  const _AppDestination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
