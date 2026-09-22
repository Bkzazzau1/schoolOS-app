import 'package:flutter/material.dart';

import '../../../core/sync/sync_scope.dart';
import '../data/owner_access_controller.dart';
import '../domain/owner_access_models.dart';
import 'owner_access_dialogs.dart';
import 'owner_access_history_tabs.dart';
import 'owner_access_person_page.dart';
import 'owner_access_roles_tab.dart';

/// Access & Activities: the owner decides who sees which screen.
///
/// Four tabs: **People** (one person at a time: give, take away, move a screen),
/// **Roles** (what everyone in a role gets by default), **Waiting** (blocks that
/// have not taken effect yet) and **History** (who changed what).
class OwnerAccessPage extends StatefulWidget {
  const OwnerAccessPage({super.key, required this.controller});

  final OwnerAccessController controller;

  @override
  State<OwnerAccessPage> createState() => _OwnerAccessPageState();
}

class _OwnerAccessPageState extends State<OwnerAccessPage> with SyncRefresh<OwnerAccessPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  void onSynced() => widget.controller.load();

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.loaded) {
          return _FirstLoad(controller: controller);
        }
        return DefaultTabController(
          length: 4,
          child: Column(
            children: [
              if (controller.loadError != null)
                MaterialBanner(
                  content: Text(controller.loadError!),
                  actions: [TextButton(onPressed: controller.load, child: const Text('Try again'))],
                ),
              if (controller.supportsExtraRoles)
                Container(
                  key: const ValueKey('demo-access-note'),
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: const Text(
                    'Demo school: your decisions apply on this device at once. Sign in as the person to see what they now get.',
                  ),
                ),
              const TabBar(
                tabs: [
                  Tab(text: 'People'),
                  Tab(text: 'Roles'),
                  Tab(text: 'Waiting'),
                  Tab(text: 'History'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _PeopleTab(controller: controller),
                    OwnerAccessRolesTab(controller: controller),
                    OwnerAccessWaitingTab(controller: controller),
                    OwnerAccessHistoryTab(controller: controller),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FirstLoad extends StatelessWidget {
  const _FirstLoad({required this.controller});

  final OwnerAccessController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.loading || controller.loadError == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40),
            const SizedBox(height: 12),
            Text(controller.loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: controller.load, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _PeopleTab extends StatefulWidget {
  const _PeopleTab({required this.controller});

  final OwnerAccessController controller;

  @override
  State<_PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<_PeopleTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final needle = _query.trim().toLowerCase();
    final people = [
      for (final p in controller.people)
        if (needle.isEmpty ||
            p.displayName.toLowerCase().contains(needle) ||
            p.email.toLowerCase().contains(needle) ||
            roleLabel(p.role).toLowerCase().contains(needle))
          p,
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'Search by name, email or role',
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.load,
            child: people.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No one matches.')))],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: people.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) => _PersonTile(
                      person: people[index],
                      onOpen: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => OwnerAccessPersonPage(controller: controller, membershipId: people[index].membershipId),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person, required this.onOpen});

  final PersonAccess person;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final grants = person.overrides.where((o) => !o.isBlock && o.state != OverrideState.expired).length;
    final blocks = person.overrides.where((o) => o.isBlock && o.state != OverrideState.expired).length;
    final waiting = person.overrides.any((o) => o.state == OverrideState.waitingForSync);
    return ListTile(
      onTap: onOpen,
      leading: CircleAvatar(child: Text(person.displayName.characters.first.toUpperCase())),
      title: Text(person.displayName),
      subtitle: Text(
        [
          '${roleLabel(person.role)} · ${person.activities.length} screens',
          if (grants > 0) '$grants given',
          if (blocks > 0) '$blocks taken away',
        ].join(' · '),
      ),
      trailing: waiting
          ? Tooltip(message: 'A change is waiting for their next sync', child: const Icon(Icons.hourglass_top_rounded, size: 20))
          : const Icon(Icons.chevron_right_rounded),
    );
  }
}

/// Shows a refusal or a failure in words the owner can act on.
void reportProblem(BuildContext context, String? problem) {
  if (problem != null) showMessage(context, problem);
}
