import 'package:flutter/material.dart';

import '../data/owner_access_controller.dart';
import '../domain/owner_access_models.dart';
import 'owner_access_dialogs.dart';

/// A person's roles: the main one, and any extra roles the owner has given them.
///
/// Someone with an extra role signs in and can switch between their roles (a teacher who is also a
/// parent). Shown only where the owner can do this (the demo, for now).
class ExtraRolesSection extends StatelessWidget {
  const ExtraRolesSection({super.key, required this.controller, required this.person});

  final OwnerAccessController controller;
  final PersonAccess person;

  static const _givable = ['administrator', 'principal', 'teacher', 'accountant', 'parent', 'driver', 'staff'];

  @override
  Widget build(BuildContext context) {
    final options = [for (final r in _givable) if (r != person.role && !person.extraRoles.contains(r)) r];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Roles', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(label: Text('${roleLabel(person.role)} (main)')),
              for (final role in person.extraRoles)
                InputChip(
                  key: ValueKey('extra-role-$role'),
                  label: Text(roleLabel(role)),
                  onDeleted: () => _remove(context, role),
                ),
              if (options.isNotEmpty)
                ActionChip(
                  key: const ValueKey('add-role'),
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add a role'),
                  onPressed: () => _add(context, options),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, List<String> options) async {
    final role = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Give ${person.displayName} another role'),
        children: [
          for (final r in options) SimpleDialogOption(onPressed: () => Navigator.pop(context, r), child: Text(roleLabel(r))),
        ],
      ),
    );
    if (role == null || !context.mounted) return;
    final problem = await controller.change((repo, owner) => repo.addRole(owner, person.membershipId, role));
    if (context.mounted) showMessage(context, problem ?? '${person.displayName} can now switch to ${roleLabel(role)}.');
  }

  Future<void> _remove(BuildContext context, String role) async {
    final ok = await confirm(
      context,
      title: 'Take away ${roleLabel(role)}?',
      message: '${person.displayName} will no longer be able to switch to the ${roleLabel(role).toLowerCase()} role.',
      action: 'Take away',
    );
    if (!ok || !context.mounted) return;
    final problem = await controller.change((repo, owner) => repo.removeRole(owner, person.membershipId, role));
    if (context.mounted && problem != null) showMessage(context, problem);
  }
}
