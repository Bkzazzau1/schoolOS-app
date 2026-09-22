import 'package:flutter/material.dart';
import '../data/principal_results_repository.dart';

class PrincipalResultsPage extends StatefulWidget {
  const PrincipalResultsPage({
    super.key,
    required this.repository,
    required this.onNavigate,
    this.onMutationQueued,
  });
  final PrincipalResultsRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback? onMutationQueued;
  @override
  State<PrincipalResultsPage> createState() => _PrincipalResultsPageState();
}

class _PrincipalResultsPageState extends State<PrincipalResultsPage> {
  PrincipalResultsSnapshot? _snapshot;
  String? _error;
  String _query = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.repository.load();
      if (mounted) {
        setState(() {
          _snapshot = snapshot;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load results.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: TextButton(onPressed: _load, child: Text('$_error Retry')),
      );
    }
    final snapshot = _snapshot;
    if (snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!snapshot.permissions.canViewSecondaryResults) {
      return const Center(
        child: Text('Secondary results require Principal access.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Results & Reports',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Text(
          'Secondary classes from the student register. Official term results: Not recorded yet.',
        ),
        const SizedBox(height: 16),
        const Text('Reports ready: 0 · Released reports: 0'),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No official report cards have been prepared. Teacher assessments do not yet include the subject, term grading and report approval records needed to produce a report card. Scores, rankings, conduct, comments and release states are not inferred.',
            ),
          ),
        ),
        OutlinedButton(
          onPressed: () => widget.onNavigate('academics'),
          child: const Text('View recorded assessment evidence'),
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Search class'),
          onChanged: (value) =>
              setState(() => _query = value.trim().toLowerCase()),
        ),
        if (snapshot.classes.isEmpty)
          const Text('No Secondary classes in the student register.'),
        for (final row in snapshot.classes.where(
          (c) => c.className.toLowerCase().contains(_query),
        ))
          Card(
            child: ListTile(
              title: Text(row.className),
              subtitle: Text(
                '${row.students} registered students · Results not recorded yet',
              ),
            ),
          ),
      ],
    );
  }
}
