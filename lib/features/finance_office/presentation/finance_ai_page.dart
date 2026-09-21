import 'package:flutter/material.dart';

import '../../../core/sync/sync_scope.dart';
import '../data/finance_facts.dart';
import '../data/finance_ledger_repository.dart';

/// Finance questions answered from the ledger, on this device. It says so when nothing is recorded, and it never contacts
/// families or changes records.
class FinanceAiPage extends StatefulWidget {
  const FinanceAiPage({super.key, required this.ledger});

  final FinanceLedgerRepository ledger;

  @override
  State<FinanceAiPage> createState() => _FinanceAiPageState();
}

class _FinanceAiPageState extends State<FinanceAiPage> with SyncRefresh<FinanceAiPage> {
  final _controller = TextEditingController();
  FinanceAiService? _service;
  FinanceAnswer? _answer;
  String? _last;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onSynced() => _load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final service = FinanceAiService(await loadFinanceFacts(widget.ledger));
      if (!mounted) return;
      setState(() {
        _service = service;
        _answer = service.answer(_last ?? financeAiPrompts.first);
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  void _ask(String question) {
    final q = question.trim();
    final service = _service;
    if (q.isEmpty || service == null) return;
    setState(() {
      _last = q;
      _answer = service.answer(q);
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final answer = _answer;
    if (answer == null) {
      return Center(child: _error == null ? const CircularProgressIndicator() : Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('FINANCE OFFICE · FINANCE AI', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
        const SizedBox(height: 6),
        Text('Finance AI', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('Answers come from the ledger on this device. Nothing is guessed, and nothing is sent to families from here.'),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in financeAiPrompts) ActionChip(label: Text(p), onPressed: () => _ask(p)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('finance-ai-input'),
                controller: _controller,
                onSubmitted: _ask,
                decoration: const InputDecoration(labelText: 'Ask about the school fees'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: () => _ask(_controller.text), child: const Text('Ask')),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(answer.question, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Text(answer.answer, key: const ValueKey('finance-ai-answer'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                const Text('Evidence', style: TextStyle(fontWeight: FontWeight.w800)),
                for (final e in answer.evidence) Padding(padding: const EdgeInsets.only(top: 4), child: Text('- $e')),
                const SizedBox(height: 12),
                Text(answer.boundary, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
