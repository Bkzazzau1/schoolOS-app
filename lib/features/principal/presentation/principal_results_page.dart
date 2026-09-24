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
        Text(
          'Secondary classes from the student register. School average: '
          '${snapshot.schoolAverage == null ? 'not recorded yet' : '${snapshot.schoolAverage}%'}.',
        ),
        const SizedBox(height: 16),
        Text(
          'Released assessments: ${snapshot.reportsReady} · Classes with released results: ${snapshot.releasedClasses}',
        ),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'This is recorded and released assessment evidence per class, not an official term report card. A report card also needs a term grade roll-up, position, conduct and Principal/Administrator sign-off, which is a separate, not-yet-built feature. Nothing here is fabricated or inferred beyond a released assessment\'s own recorded scores.',
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
                row.complete == 0
                    ? '${row.students} registered students · No released assessment yet'
                    : '${row.students} registered students · ${row.complete} released assessment${row.complete == 1 ? '' : 's'} · '
                        'average ${row.average}% · pass rate ${row.passRate}%',
              ),
            ),
          ),
      ],
    );
  }
}
