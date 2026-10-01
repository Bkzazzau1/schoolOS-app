import 'package:flutter/material.dart';

import '../data/alumni_directory_repository.dart';
import '../domain/alumni_directory_models.dart';

class AlumniDirectoryPage extends StatefulWidget {
  const AlumniDirectoryPage({super.key, required this.repository});

  final AlumniDirectoryRepository repository;

  @override
  State<AlumniDirectoryPage> createState() => _AlumniDirectoryPageState();
}

class _AlumniDirectoryPageState extends State<AlumniDirectoryPage> {
  List<AlumniDirectoryEntry>? _entries;
  bool _loading = true;
  String? _error;
  String _query = '';
  int? _graduationYear;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!widget.repository.hasServer) {
      setState(() {
        _loading = false;
        _entries = null;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  List<AlumniDirectoryEntry> get _filtered {
    final entries = _entries ?? const [];
    return entries
        .where((entry) => entry.matches(_query))
        .where((entry) => _graduationYear == null || entry.graduationYear == _graduationYear)
        .toList(growable: false);
  }

  List<int> get _graduationYearOptions {
    final years = <int>{
      for (final entry in _entries ?? const <AlumniDirectoryEntry>[])
        if (entry.graduationYear != null) entry.graduationYear!,
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    return years;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.repository.hasServer) {
      return const _BackendRequiredCard();
    }
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null) {
      return _DirectoryError(message: _error!, onRetry: _load);
    }

    final filtered = _filtered;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Alumni Directory',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        const Text('Every real, verified alumnus who has chosen to appear here.'),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 560;
            final search = TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search by name, profession or organisation...',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            );
            final filter = DropdownButtonFormField<int?>(
              initialValue: _graduationYear,
              decoration: const InputDecoration(labelText: 'Graduation year', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('All years')),
                for (final year in _graduationYearOptions)
                  DropdownMenuItem<int?>(value: year, child: Text('$year')),
              ],
              onChanged: (value) => setState(() => _graduationYear = value),
            );
            if (stacked) {
              return Column(children: [search, const SizedBox(height: 10), filter]);
            }
            return Row(
              children: [
                Expanded(flex: 2, child: search),
                const SizedBox(width: 10),
                Expanded(child: filter),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Text(
                (_entries ?? const []).isEmpty
                    ? 'No verified alumni have chosen to appear in the directory yet.'
                    : 'No alumnus matches this search.',
              ),
            ),
          )
        else
          for (final entry in filtered) ...[
            _EntryCard(entry: entry),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final AlumniDirectoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.name,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                ),
                if (entry.graduationYear != null) Chip(label: Text('Class of ${entry.graduationYear}')),
              ],
            ),
            if (entry.graduationSet.trim().isNotEmpty) Text(entry.graduationSet),
            const SizedBox(height: 8),
            Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                if (entry.profession.trim().isNotEmpty) _Fact('Profession', entry.profession),
                if (entry.organisation.trim().isNotEmpty) _Fact('Organisation', entry.organisation),
                if (entry.locationText.trim().isNotEmpty) _Fact('Location', entry.locationText),
              ],
            ),
            if (entry.bio.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(entry.bio),
            ],
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _BackendRequiredCard extends StatelessWidget {
  const _BackendRequiredCard();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Text('Connect to your school to browse the alumni directory.'),
            ),
          ),
        ),
      );
}

class _DirectoryError extends StatelessWidget {
  const _DirectoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
