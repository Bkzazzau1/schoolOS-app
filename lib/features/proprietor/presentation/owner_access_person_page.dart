import 'package:flutter/material.dart';

import '../data/owner_access_controller.dart';
import '../domain/owner_access_models.dart';
import 'owner_access_dialogs.dart';
import 'owner_access_extra_roles.dart';

/// One person's access: every screen, grouped, with what they have and why.
///
/// Turning a screen on gives it to them (or restores their role's default);
/// turning it off takes it away (or removes what the owner gave them). Landing
/// screens and the access screen itself cannot be changed.
class OwnerAccessPersonPage extends StatelessWidget {
  const OwnerAccessPersonPage({super.key, required this.controller, required this.membershipId});

  final OwnerAccessController controller;
  final String membershipId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final person = controller.person(membershipId);
        final catalog = controller.catalog;
        if (person == null || catalog == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('This person is no longer in the school.')));
        }
        return Scaffold(
          appBar: AppBar(title: Text(person.displayName)),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  '${roleLabel(person.role)} · ${person.email}\n'
                  'Screens marked "role default" come from their role. Anything you give or take away here is only for them.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (controller.supportsExtraRoles) ExtraRolesSection(controller: controller, person: person),
              for (final group in catalog.groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(group.area, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                ),
                for (final activity in group.activities)
                  _ActivityRow(controller: controller, person: person, activity: activity),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.controller, required this.person, required this.activity});

  final OwnerAccessController controller;
  final PersonAccess person;
  final AccessActivity activity;

  bool get _roleHasIt => activity.rolesInThisSchool.contains(person.role);

  @override
  Widget build(BuildContext context) {
    final has = person.activities.contains(activity.key);
    final override = person.overrideFor(activity.key);
    final locked = activity.essential || !activity.grantable;

    return ListTile(
      key: ValueKey('activity-${activity.key}'),
      title: Text(activity.label),
      subtitle: Text(_status(has, override)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (override != null && !locked)
            TextButton(onPressed: () => _restore(context), child: const Text('Reset')),
          if (has && !locked)
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (value) => _move(context),
              itemBuilder: (_) => const [PopupMenuItem(value: 'move', child: Text('Move to someone else...'))],
            ),
          if (locked)
            Tooltip(
              message: activity.essential ? 'Their landing screen: it cannot be taken away' : 'Only the owner has this',
              child: const Icon(Icons.lock_outline_rounded, size: 20),
            )
          else
            Switch(value: has, onChanged: (on) => on ? _turnOn(context) : _turnOff(context)),
        ],
      ),
    );
  }

  String _status(bool has, AccessOverride? override) {
    if (override != null) {
      if (override.isBlock) {
        if (override.state == OverrideState.waitingForSync) {
          return 'Being taken away · after their next sync, and by ${formatDate(override.takesEffectBy ?? override.setAt)}';
        }
        return 'Taken away by you${_until(override)}';
      }
      return 'Given by you${_until(override)}';
    }
    if (has) return 'Has it · role default';
    return _roleHasIt ? 'Not available' : 'Not in their role';
  }

  String _until(AccessOverride o) => o.expiresAt == null ? '' : ' · until ${formatDate(o.expiresAt!)}';

  Future<void> _turnOn(BuildContext context) async {
    final override = person.overrideFor(activity.key);
    // Taking back a block first restores their role's default; that may already be enough.
    if (override != null && override.isBlock) {
      final problem = await controller.change((repo, owner) => repo.clearOverride(owner, person.membershipId, activity.key));
      if (!context.mounted) return;
      if (problem != null) return showMessage(context, problem);
      if (_roleHasIt) return;
    }
    final choice = await askGrant(context, activity: activity, personName: person.displayName);
    if (choice == null || !context.mounted) return;
    final problem = await controller.change(
      (repo, owner) => repo.setOverride(
        owner, person.membershipId, activity.key,
        block: false, expiresAt: choice.expiresAt, note: choice.note,
      ),
    );
    if (context.mounted && problem != null) showMessage(context, problem);
  }

  Future<void> _turnOff(BuildContext context) async {
    final override = person.overrideFor(activity.key);
    if (override != null && !override.isBlock) {
      // What you gave them comes back; if their role also has it, they keep it through the role.
      final problem = await controller.change((repo, owner) => repo.clearOverride(owner, person.membershipId, activity.key));
      if (!context.mounted) return;
      if (problem != null) return showMessage(context, problem);
      if (!_roleHasIt) return;
    }
    if (!context.mounted) return;
    final choice = await askBlock(context, activity: activity, personName: person.displayName);
    if (choice == null || !context.mounted) return;
    final problem = await controller.change(
      (repo, owner) => repo.setOverride(
        owner, person.membershipId, activity.key,
        block: true, immediately: choice.immediately, expiresAt: choice.expiresAt, note: choice.note,
      ),
    );
    if (context.mounted && problem != null) showMessage(context, problem);
  }

  Future<void> _restore(BuildContext context) async {
    final problem = await controller.change((repo, owner) => repo.clearOverride(owner, person.membershipId, activity.key));
    if (context.mounted && problem != null) showMessage(context, problem);
  }

  Future<void> _move(BuildContext context) async {
    final candidates = [
      for (final p in controller.people)
        if (p.membershipId != person.membershipId && !p.activities.contains(activity.key)) p,
    ];
    final choice = await askReassign(context, activity: activity, from: person, candidates: candidates);
    if (choice == null || !context.mounted) return;
    final problem = await controller.change(
      (repo, owner) => repo.reassign(
        owner,
        activity: activity.key,
        fromMembershipId: person.membershipId,
        toMembershipId: choice.toMembershipId,
        immediately: choice.immediately,
        note: choice.note,
      ),
    );
    if (context.mounted) showMessage(context, problem ?? '${activity.label} moved.');
  }
}
