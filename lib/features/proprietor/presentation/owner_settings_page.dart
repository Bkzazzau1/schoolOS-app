import 'package:flutter/material.dart';

/// A hub for administrative setup screens, as opposed to day-to-day operational ones. Jobs &
/// Delegation is the first screen here; more settings-type screens belong alongside it rather than
/// in the main sidebar.
class OwnerSettingsPage extends StatelessWidget {
  const OwnerSettingsPage({super.key, required this.onOpenJobs});

  final VoidCallback onOpenJobs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Settings', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Administrative setup for the school, separate from day-to-day operations.'),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.assignment_ind_outlined),
              title: const Text('Jobs & Delegation'),
              subtitle: const Text('Assign responsibilities and duties to any person, including someone who has not registered.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onOpenJobs,
            ),
          ),
        ],
      ),
    );
  }
}
