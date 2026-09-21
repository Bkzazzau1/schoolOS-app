import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/sync/sync_scope.dart';
import '../../proprietor/data/owner_reports.dart' show ReportDoc;
import '../data/finance_facts.dart';
import '../data/finance_ledger_repository.dart';

/// Finance reports built from the ledger. A report with no records behind it says so. "Save report pack" writes them all as
/// one text file on this device.
class FinanceReportsPage extends StatefulWidget {
  const FinanceReportsPage({super.key, required this.ledger, required this.schoolName});

  final FinanceLedgerRepository ledger;
  final String schoolName;

  @override
  State<FinanceReportsPage> createState() => _FinanceReportsPageState();
}

class _FinanceReportsPageState extends State<FinanceReportsPage> with SyncRefresh<FinanceReportsPage> {
  List<ReportDoc>? _docs;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onSynced() => _load();

  Future<void> _load() async {
    try {
      final facts = await loadFinanceFacts(widget.ledger);
      if (!mounted) return;
      setState(() {
        _docs = buildFinanceReports(facts);
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _savePack(List<ReportDoc> docs) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final dir = await getApplicationDocumentsDirectory();
      final safe = widget.schoolName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '').toLowerCase();
      final day = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final file = File(p.join(dir.path, '${safe}_finance_report_pack_$day.txt'));
      await file.writeAsString(renderFinancePack(schoolName: widget.schoolName, docs: docs, date: now), flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Finance report pack saved on this device: ${file.path}')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save the pack: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _open(ReportDoc doc) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              shrinkWrap: true,
              children: [
                Text(doc.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(doc.coverage),
                const SizedBox(height: 12),
                if (!doc.available) Text('Not available yet: ${doc.unavailableReason}'),
                for (final s in doc.sections) ...[
                  const SizedBox(height: 10),
                  Text(s.heading, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  for (final line in s.lines) Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(line)),
                ],
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final docs = _docs;
    if (docs == null) {
      return Center(child: _error == null ? const CircularProgressIndicator() : Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('FINANCE OFFICE · REPORTS', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
        const SizedBox(height: 6),
        Text('Reports', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('${docs.where((d) => d.available).length} reports built from the ledger. Reports with no records behind them say so.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('reports-save'),
          onPressed: _saving ? null : () => _savePack(docs),
          icon: const Icon(Icons.inventory_2_outlined, size: 18),
          label: Text(_saving ? 'Saving…' : 'Save report pack'),
        ),
        const SizedBox(height: 16),
        for (final d in docs)
          Card(
            key: ValueKey('report-${d.title}'),
            elevation: 0,
            child: ListTile(
              title: Text(d.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(d.available ? d.coverage : 'Not available yet · ${d.unavailableReason}'),
              trailing: TextButton(onPressed: () => _open(d), child: const Text('Open')),
            ),
          ),
      ],
    );
  }
}
