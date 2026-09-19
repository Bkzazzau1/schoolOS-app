import 'package:flutter/material.dart';

import '../data/administrator_lifecycle_repository.dart';
import '../domain/administrator_lifecycle_models.dart';

class AdministratorLifecyclePage extends StatefulWidget {
  const AdministratorLifecyclePage({
    super.key,
    required this.schoolName,
    required this.repository,
  });

  final String schoolName;
  final AdministratorLifecycleRepository repository;

  @override
  State<AdministratorLifecyclePage> createState() =>
      _AdministratorLifecyclePageState();
}

class _AdministratorLifecyclePageState
    extends State<AdministratorLifecyclePage> {
  bool _loading = true;
  String? _error;
  List<AdministratorLifecycleRecord> _records = const [];
  AdministratorLifecyclePermissions? _permissions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _records = snapshot.records;
        _permissions = snapshot.permissions;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  void _openRecord(AdministratorLifecycleRecord record) {
    if (!(_permissions?.canOpenOperationalReview ?? false)) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${record.studentName} · ${record.id}'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(label: 'Workflow', value: record.workflow),
                _DetailRow(label: 'Change', value: record.change),
                _DetailRow(label: 'Status', value: record.status.label),
                if (record.isPromotion) ...[
                  const SizedBox(height: 12),
                  const _BoundaryBox(
                    text:
                        'Promotion is an academic decision. Administration can process an approved promotion, but cannot create or override the academic decision from this lifecycle desk.',
                  ),
                ],
                const SizedBox(height: 12),
                const _BoundaryBox(text: administratorLifecycleAuthorityBoundary),
                const SizedBox(height: 8),
                const _BoundaryBox(text: administratorLifecycleHistoryBoundary),
                const SizedBox(height: 8),
                const _BoundaryBox(text: administratorLifecycleOpenBoundary),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        return ListView(
          padding: EdgeInsets.all(wide ? 28 : 16),
          children: [
            _Header(schoolName: widget.schoolName),
            const SizedBox(height: 18),
            if (wide)
              _WideRegister(
                records: _records,
                canOpen: _permissions?.canOpenOperationalReview ?? false,
                onOpen: _openRecord,
              )
            else
              _CompactRegister(
                records: _records,
                canOpen: _permissions?.canOpenOperationalReview ?? false,
                onOpen: _openRecord,
              ),
            const SizedBox(height: 16),
            const Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(18),
                child: _BoundaryBox(text: administratorLifecycleAuthorityBoundary),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(18),
                child: _BoundaryBox(text: administratorLifecycleHistoryBoundary),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.schoolName});
  final String schoolName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ADMINISTRATION · STUDENT LIFECYCLE',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 5),
        Text(
          'Transfers, Promotion & Status',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Process approved student status changes while preserving historical class and enrollment records. · $schoolName',
        ),
      ],
    );
  }
}

class _WideRegister extends StatelessWidget {
  const _WideRegister({
    required this.records,
    required this.canOpen,
    required this.onOpen,
  });

  final List<AdministratorLifecycleRecord> records;
  final bool canOpen;
  final ValueChanged<AdministratorLifecycleRecord> onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const _LifecycleRow(
              header: true,
              values: ['ID', 'Student', 'Workflow', 'Change', 'Status'],
            ),
            for (final record in records)
              _LifecycleDataRow(
                record: record,
                canOpen: canOpen,
                onOpen: () => onOpen(record),
              ),
          ],
        ),
      ),
    );
  }
}

class _LifecycleRow extends StatelessWidget {
  const _LifecycleRow({required this.header, required this.values});

  final bool header;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final style = header
        ? const TextStyle(fontWeight: FontWeight.w900)
        : const TextStyle();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          for (final value in values)
            Expanded(child: Text(value, style: style)),
          const SizedBox(width: 80),
        ],
      ),
    );
  }
}

class _LifecycleDataRow extends StatelessWidget {
  const _LifecycleDataRow({
    required this.record,
    required this.canOpen,
    required this.onOpen,
  });

  final AdministratorLifecycleRecord record;
  final bool canOpen;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(record.id, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          Expanded(child: Text(record.studentName)),
          Expanded(child: Text(record.workflow)),
          Expanded(child: Text(record.change)),
          Expanded(
            child: Text(
              record.status.label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(
            width: 80,
            child: TextButton(
              onPressed: canOpen ? onOpen : null,
              child: const Text('Open'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactRegister extends StatelessWidget {
  const _CompactRegister({
    required this.records,
    required this.canOpen,
    required this.onOpen,
  });

  final List<AdministratorLifecycleRecord> records;
  final bool canOpen;
  final ValueChanged<AdministratorLifecycleRecord> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final record in records)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.studentName,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(record.id),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(record.workflow),
                  const SizedBox(height: 3),
                  Text(record.change),
                  const SizedBox(height: 6),
                  Text(
                    record.status.label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: canOpen ? () => onOpen(record) : null,
                      child: const Text('Open'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label)),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _BoundaryBox extends StatelessWidget {
  const _BoundaryBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
    );
  }
}
