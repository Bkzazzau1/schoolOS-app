import 'package:flutter/material.dart';

import '../data/owner_access_controller.dart';
import '../domain/owner_access_models.dart';
import 'owner_access_dialogs.dart';

/// What everyone in a role gets by default in this school.
class OwnerAccessRolesTab extends StatelessWidget {
  const OwnerAccessRolesTab({super.key, required this.controller});

  final OwnerAccessController controller;

  @override
  Widget build(BuildContext context) {
    final roles = controller.roles;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: roles.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final role = roles[index];
        final people = controller.people.where((p) => p.role == role.role).length;
        return ListTile(
          key: ValueKey('role-${role.role}'),
          onTap: role.editable
              ? () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => OwnerAccessRolePage(controller: controller, role: role.role)),
                  )
              : null,
          title: Text(roleLabel(role.role)),
          subtitle: Text('${role.activities.length} screens · $people ${people == 1 ? 'person' : 'people'}'),
          trailing: role.customized
              ? const Chip(label: Text('Changed'), visualDensity: VisualDensity.compact)
              : const Icon(Icons.chevron_right_rounded),
        );
      },
    );
  }
}

/// Edits one role's screens. Landing screens stay on. Saving tells everyone in the role.
class OwnerAccessRolePage extends StatefulWidget {
  const OwnerAccessRolePage({super.key, required this.controller, required this.role});

  final OwnerAccessController controller;
  final String role;

  @override
  State<OwnerAccessRolePage> createState() => _OwnerAccessRolePageState();
}

class _OwnerAccessRolePageState extends State<OwnerAccessRolePage> {
  late Set<String> _chosen;
  bool _saving = false;

  RoleAccess get _role => widget.controller.role(widget.role)!;

  @override
  void initState() {
    super.initState();
    _chosen = {..._role.activities};
  }

  bool get _changed {
    final saved = _role.activities;
    return _chosen.length != saved.length || !_chosen.containsAll(saved);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final people = widget.controller.people.where((p) => p.role == widget.role).length;
    final agreed = await confirm(
      context,
      title: 'Save changes for ${roleLabel(widget.role)}?',
      message: 'This changes what all $people ${people == 1 ? 'person' : 'people'} in this role can see, '
          'except where you set something for one person. They will be told.',
      action: 'Save',
    );
    if (!agreed || !mounted) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    final problem = await widget.controller.change((repo, owner) => repo.setRole(owner, widget.role, _chosen));
    if (!mounted) return;
    setState(() => _saving = false);
    if (problem != null) return showMessage(context, problem);
    Navigator.of(context).pop();
    showMessage(context, '${roleLabel(widget.role)} updated.');
  }

  Future<void> _reset() async {
    final agreed = await confirm(
      context,
      title: 'Go back to the built-in screens?',
      message: 'Everything you changed for ${roleLabel(widget.role)} is undone.',
      action: 'Go back',
    );
    if (!agreed || !mounted) return;
    setState(() => _saving = true);
    final problem = await widget.controller.change((repo, owner) => repo.resetRole(owner, widget.role));
    if (!mounted) return;
    setState(() => _saving = false);
    if (problem != null) return showMessage(context, problem);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = widget.controller.catalog!;
    return Scaffold(
      appBar: AppBar(
        title: Text(roleLabel(widget.role)),
        actions: [
          if (_role.customized) TextButton(onPressed: _saving ? null : _reset, child: const Text('Reset')),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          for (final group in catalog.groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(group.area, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ),
            for (final activity in group.activities)
              CheckboxListTile(
                key: ValueKey('role-activity-${activity.key}'),
                value: _chosen.contains(activity.key),
                onChanged: (activity.essential || !activity.grantable || _saving)
                    ? null
                    : (on) => setState(() => on == true ? _chosen.add(activity.key) : _chosen.remove(activity.key)),
                title: Text(activity.label),
                subtitle: activity.essential
                    ? const Text('Landing screen: always on')
                    : activity.sensitive
                        ? const Text('Shows money or personal information')
                        : null,
              ),
          ],
        ],
      ),
      floatingActionButton: _changed
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Save changes'),
            )
          : null,
    );
  }
}
