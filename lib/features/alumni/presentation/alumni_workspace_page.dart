import 'package:flutter/material.dart';

import '../../../core/appearance/school_appearance_controller.dart';
import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_scope.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../community/data/community_repository.dart';
import '../../community/presentation/community_page.dart';
import '../data/alumni_directory_repository.dart';
import '../data/alumni_events_repository.dart';
import '../data/alumni_give_back_repository.dart';
import '../data/alumni_opportunities_repository.dart';
import '../data/alumni_profile_repository.dart';
import '../data/alumni_server_api.dart';
import 'alumni_directory_page.dart';
import 'alumni_events_page.dart';
import 'alumni_give_back_page.dart';
import 'alumni_opportunities_page.dart';
import 'alumni_profile_page.dart';

class AlumniNavItem {
  const AlumniNavItem(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

const alumniNavigation = <AlumniNavItem>[
  AlumniNavItem('dashboard', 'Home', Icons.home_outlined),
  AlumniNavItem('profile', 'My Alumni Profile', Icons.badge_outlined),
  AlumniNavItem('directory', 'Alumni Directory', Icons.groups_outlined),
  AlumniNavItem('community', 'Community', Icons.forum_outlined),
  AlumniNavItem('events', 'Events & Reunions', Icons.event_outlined),
  AlumniNavItem('mentorship', 'Mentorship', Icons.handshake_outlined),
  AlumniNavItem('opportunities', 'Jobs & Opportunities', Icons.work_outline),
  AlumniNavItem('give-back', 'Give Back', Icons.volunteer_activism_outlined),
];

class AlumniWorkspacePage extends StatefulWidget {
  const AlumniWorkspacePage({
    super.key,
    required this.membership,
    required this.localDatabase,
    required this.schoolSession,
    required this.schoolAppearance,
  });

  final SchoolMembership membership;
  final LocalDatabase localDatabase;
  final SchoolSessionController schoolSession;
  final SchoolAppearanceController schoolAppearance;

  @override
  State<AlumniWorkspacePage> createState() => _AlumniWorkspacePageState();
}

class _AlumniWorkspacePageState extends State<AlumniWorkspacePage>
    with AccessAware<AlumniWorkspacePage> {
  String _activeKey = 'dashboard';

  List<AlumniNavItem> get _navigation =>
      visibleScreens('alumni', alumniNavigation, (item) => item.key);

  AlumniNavItem get _activeItem => _navigation.firstWhere(
        (item) => item.key == _activeKey,
        orElse: () => _navigation.first,
      );

  @override
  Widget build(BuildContext context) {
    final navigation = _navigation;
    if (!navigation.any((item) => item.key == _activeKey)) {
      _activeKey = navigation.first.key;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Scaffold(
          appBar: AppBar(
            title: Text('${widget.membership.schoolName} · Alumni'),
          ),
          drawer: wide
              ? null
              : Drawer(
                  child: _navigationList(navigation, closeDrawer: true),
                ),
          body: Row(
            children: [
              if (wide)
                SizedBox(
                  width: 260,
                  child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: _navigationList(navigation),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _content(_activeItem),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _navigationList(
    List<AlumniNavItem> navigation, {
    bool closeDrawer = false,
  }) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALUMNI',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.membership.schoolName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
          for (final item in navigation)
            ListTile(
              leading: Icon(item.icon),
              title: Text(item.label),
              selected: item.key == _activeKey,
              onTap: () {
                setState(() => _activeKey = item.key);
                if (closeDrawer) Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }

  Widget _content(AlumniNavItem item) {
    return switch (item.key) {
      'dashboard' => _dashboard(),
      'profile' => AlumniProfilePage(
          repository: AlumniProfileRepository(
            localDatabase: widget.localDatabase,
            membership: widget.membership,
            remote: AlumniServerScope.maybeOf(context),
          ),
        ),
      'directory' => AlumniDirectoryPage(
          repository: AlumniDirectoryRepository(
            membership: widget.membership,
            remote: AlumniServerScope.maybeOf(context),
          ),
        ),
      'community' => CommunityPage(
          schoolName: widget.membership.schoolName,
          repository: CommunityRepository(
            localDatabase: widget.localDatabase,
            schoolSession: widget.schoolSession,
          ),
          onBack: () => setState(() => _activeKey = 'dashboard'),
          onCommunityChanged: () {},
        ),
      'events' => AlumniEventsPage(
          repository: AlumniEventsRepository(
            membership: widget.membership,
            remote: AlumniServerScope.maybeOf(context),
          ),
        ),
      'mentorship' => _foundationCard(
          title: 'Mentorship',
          description:
              'Alumni mentorship is not available yet.',
          icon: Icons.handshake_outlined,
        ),
      'opportunities' => AlumniOpportunitiesPage(
          repository: AlumniOpportunitiesRepository(
            membership: widget.membership,
            remote: AlumniServerScope.maybeOf(context),
          ),
          membershipId: widget.membership.id,
        ),
      'give-back' => AlumniGiveBackPage(
          repository: AlumniGiveBackRepository(
            membership: widget.membership,
            remote: AlumniServerScope.maybeOf(context),
          ),
        ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _dashboard() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to Alumni',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'A dedicated SchoolOS space for verified former students to stay connected with their school and alumni community.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _IdentityCard(
              label: 'School',
              value: widget.membership.schoolName,
              icon: Icons.school_outlined,
            ),
            _IdentityCard(
              label: 'Role',
              value: widget.membership.roleLabel,
              icon: Icons.workspace_premium_outlined,
            ),
            _IdentityCard(
              label: 'Membership',
              value: widget.membership.id,
              icon: Icons.fingerprint_rounded,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your alumni account',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Becoming an alumnus does not overwrite the former student record. Alumni is a separate school membership, so graduation history remains historical while the person can also hold another role such as Parent, Staff or Teacher.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _foundationCard({
    required String title,
    required String description,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 34, color: theme.colorScheme.primary),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 14),
            const Chip(
              avatar: Icon(Icons.lock_outline_rounded, size: 17),
              label: Text('Not available yet'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
