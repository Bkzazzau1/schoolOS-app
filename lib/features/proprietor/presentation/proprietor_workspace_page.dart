import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../sync_center/presentation/sync_center_page.dart';
import 'proprietor_overview_page.dart';

class ProprietorWorkspacePage extends StatefulWidget {
  const ProprietorWorkspacePage({
    super.key,
    required this.membership,
    required this.localDatabase,
    required this.schoolSession,
  });

  final SchoolMembership membership;
  final LocalDatabase localDatabase;
  final SchoolSessionController schoolSession;

  @override
  State<ProprietorWorkspacePage> createState() => _ProprietorWorkspacePageState();
}

class _ProprietorWorkspacePageState extends State<ProprietorWorkspacePage> {
  int _pendingSyncCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshPendingCount();
  }

  void _refreshPendingCount() {
    final count = widget.localDatabase.pendingCount(
      tenantId: widget.membership.schoolId,
    );
    if (!mounted) return;
    setState(() => _pendingSyncCount = count);
  }

  Future<void> _openSyncCenter() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SyncCenterPage(
          localDatabase: widget.localDatabase,
          membership: widget.membership,
        ),
      ),
    );
    _refreshPendingCount();
  }

  Future<void> _switchSchool(SchoolMembership membership) async {
    if (membership.id == widget.membership.id) return;

    await widget.schoolSession.selectSchool(membership);
    if (!mounted) return;

    final page = membership.role == SchoolRole.proprietor
        ? ProprietorWorkspacePage(
            membership: membership,
            localDatabase: widget.localDatabase,
            schoolSession: widget.schoolSession,
          )
        : DashboardPage(
            membership: membership,
            localDatabase: widget.localDatabase,
            schoolSession: widget.schoolSession,
          );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (context) => page),
    );
  }

  void _handleModuleRequest(String moduleKey) {
    final title = switch (moduleKey) {
      'finance' => 'Owner Finance',
      'enrollment' => 'Enrollment & Admissions',
      'staff' => 'Staff & HR',
      'reports' => 'Executive Reports',
      'campuses' => 'Campus Comparison',
      'ai' => 'Proprietor AI',
      'structure' => 'Structure & Leadership',
      'appearance' => 'School Appearance',
      _ => 'Proprietor module',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$title will be ported as the next dedicated proprietor feature.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final phone = constraints.maxWidth < 700;

        if (phone) {
          return Scaffold(
            appBar: AppBar(
              title: _SchoolTitle(membership: widget.membership),
              actions: [
                if (widget.schoolSession.canSwitchSchool)
                  _SchoolSwitcherButton(
                    activeMembership: widget.membership,
                    memberships: widget.schoolSession.memberships,
                    onSelected: _switchSchool,
                  ),
                IconButton(
                  tooltip: _pendingSyncCount == 0
                      ? 'Sync Center'
                      : 'Sync Center · $_pendingSyncCount pending',
                  onPressed: _openSyncCenter,
                  icon: Badge(
                    isLabelVisible: _pendingSyncCount > 0,
                    label: Text('$_pendingSyncCount'),
                    child: Icon(
                      _pendingSyncCount == 0
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_upload_outlined,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
            body: ProprietorOverviewPage(
              schoolName: widget.membership.schoolName,
              onModuleRequested: _handleModuleRequest,
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: Container(
                  width: constraints.maxWidth >= 1180 ? 248 : 88,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: _OwnerBrand(
                          extended: constraints.maxWidth >= 1180,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _OwnerNavigationTile(
                        extended: constraints.maxWidth >= 1180,
                        icon: Icons.dashboard_rounded,
                        label: 'Executive Overview',
                        selected: true,
                        onTap: () {},
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: constraints.maxWidth >= 1180
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'OWNER WORKSPACE',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.membership.schoolName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'Whole-school authority',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              )
                            : const Icon(Icons.admin_panel_settings_outlined),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: _SchoolTitle(
                                membership: widget.membership,
                              ),
                            ),
                            if (widget.schoolSession.canSwitchSchool) ...[
                              _SchoolSwitcherButton(
                                activeMembership: widget.membership,
                                memberships: widget.schoolSession.memberships,
                                onSelected: _switchSchool,
                              ),
                              const SizedBox(width: 8),
                            ],
                            OutlinedButton.icon(
                              onPressed: _openSyncCenter,
                              icon: Icon(
                                _pendingSyncCount == 0
                                    ? Icons.cloud_done_outlined
                                    : Icons.cloud_upload_outlined,
                                size: 18,
                              ),
                              label: Text(
                                _pendingSyncCount == 0
                                    ? 'Synced'
                                    : '$_pendingSyncCount pending',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ProprietorOverviewPage(
                          schoolName: widget.membership.schoolName,
                          onModuleRequested: _handleModuleRequest,
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

class _OwnerBrand extends StatelessWidget {
  const _OwnerBrand({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mark = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.school_rounded, color: theme.colorScheme.onPrimary),
    );

    if (!extended) return mark;

    return Row(
      children: [
        mark,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SchoolOS',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Owner Command Center',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OwnerNavigationTile extends StatelessWidget {
  const _OwnerNavigationTile({
    required this.extended,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final bool extended;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: extended ? 14 : 10,
              vertical: 12,
            ),
            child: Row(
              mainAxisAlignment: extended
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(icon),
                if (extended) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ],
            ),
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
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Text(membership.schoolName.characters.first.toUpperCase()),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                membership.schoolName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text('Proprietor', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _SchoolSwitcherButton extends StatelessWidget {
  const _SchoolSwitcherButton({
    required this.activeMembership,
    required this.memberships,
    required this.onSelected,
  });

  final SchoolMembership activeMembership;
  final List<SchoolMembership> memberships;
  final ValueChanged<SchoolMembership> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SchoolMembership>(
      tooltip: 'Switch school',
      onSelected: onSelected,
      icon: const Icon(Icons.swap_horiz_rounded),
      itemBuilder: (context) => [
        for (final membership in memberships)
          PopupMenuItem<SchoolMembership>(
            value: membership,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: membership.id == activeMembership.id
                      ? const Icon(Icons.check_rounded, size: 18)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(membership.schoolName),
                      Text(
                        membership.roleLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
