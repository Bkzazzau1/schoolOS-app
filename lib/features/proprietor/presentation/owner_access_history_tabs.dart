import 'package:flutter/material.dart';

import '../data/owner_access_controller.dart';
import '../domain/owner_access_models.dart';
import 'owner_access_dialogs.dart';

/// Blocks the owner made that have not taken effect yet, because the person's app
/// is still sending their unsent work. Each takes effect after their next sync, and
/// no later than the date shown.
class OwnerAccessWaitingTab extends StatelessWidget {
  const OwnerAccessWaitingTab({super.key, required this.controller});

  final OwnerAccessController controller;

  @override
  Widget build(BuildContext context) {
    final waiting = controller.waiting;
    if (waiting.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Nothing is waiting. Every block you made is in force.', textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.separated(
      itemCount: waiting.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = waiting[index];
        final label = controller.catalog?.labelOf(item.block.activity) ?? item.block.activity;
        return ListTile(
          leading: const Icon(Icons.hourglass_top_rounded),
          title: Text('${item.person.displayName}: $label'),
          subtitle: Text(
            'Taken away after their next sync, and by ${formatDate(item.block.takesEffectBy ?? item.block.setAt)} at the latest.',
          ),
          trailing: TextButton(
            onPressed: () async {
              final problem = await controller.change(
                (repo, owner) => repo.clearOverride(owner, item.person.membershipId, item.block.activity),
              );
              if (context.mounted) showMessage(context, problem ?? 'Cancelled. ${item.person.displayName} keeps $label.');
            },
            child: const Text('Cancel'),
          ),
        );
      },
    );
  }
}

/// Who changed access, newest first.
class OwnerAccessHistoryTab extends StatelessWidget {
  const OwnerAccessHistoryTab({super.key, required this.controller});

  final OwnerAccessController controller;

  @override
  Widget build(BuildContext context) {
    final entries = controller.history;
    if (entries.isEmpty) {
      return const Center(child: Text('No changes yet.'));
    }
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return ListTile(
            title: Text(describeChange(entry, controller.catalog)),
            subtitle: Text('${formatDateTime(entry.at)}${entry.by == null ? '' : ' · by ${entry.by}'}'),
          );
        },
      ),
    );
  }
}

/// One line in plain words for an entry in the history.
String describeChange(AccessChangeEntry entry, AccessCatalogData? catalog) {
  final screen = entry.activity.isEmpty ? '' : (catalog?.labelOf(entry.activity) ?? entry.activity);
  final person = entry.forPerson ?? 'someone';
  final note = (entry.detail['note'] as String?)?.trim() ?? '';
  final withNote = note.isEmpty ? '' : ' ("$note")';
  return switch (entry.kind) {
    'person_grant' => 'Gave $person $screen$withNote',
    'person_block' => 'Took $screen from $person$withNote',
    'person_clear' => 'Put $person back on their role\'s setting for $screen',
    'reassign' => 'Moved $screen to $person$withNote',
    'role_set' => 'Changed the screens for ${roleLabel(entry.role)}'
        '${_list(entry.detail['added'], 'added')}${_list(entry.detail['removed'], 'removed')}',
    'role_reset' => 'Put ${roleLabel(entry.role)} back on the built-in screens',
    _ => 'Changed access',
  };
}

String _list(Object? keys, String verb) {
  final list = [for (final k in (keys as List? ?? const [])) '$k'];
  if (list.isEmpty) return '';
  return '. ${verb[0].toUpperCase()}${verb.substring(1)}: ${list.join(', ')}';
}
