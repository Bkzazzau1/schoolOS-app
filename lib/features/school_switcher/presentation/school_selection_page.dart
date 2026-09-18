import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';

class SchoolSelectionPage extends StatelessWidget {
  const SchoolSelectionPage({
    super.key,
    required this.memberships,
    required this.onSelected,
  });

  final List<SchoolMembership> memberships;
  final ValueChanged<SchoolMembership> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a school'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Your schools',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your account can belong to more than one school. Each membership keeps its own role, permissions and offline data.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              for (final membership in memberships) ...[
                Card(
                  elevation: 0,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    leading: CircleAvatar(
                      child: Text(
                        membership.schoolName.characters.first.toUpperCase(),
                      ),
                    ),
                    title: Text(
                      membership.schoolName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(membership.roleLabel),
                    trailing: const Icon(Icons.arrow_forward_rounded),
                    onTap: () => onSelected(membership),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
