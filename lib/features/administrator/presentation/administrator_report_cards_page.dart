import 'package:flutter/material.dart';

import '../data/administrator_academics_repository.dart';
import '../data/administrator_report_card_repository.dart';
import '../domain/administrator_academics_models.dart';
import '../domain/report_card_models.dart';

class AdministratorReportCardsPage extends StatefulWidget {
  const AdministratorReportCardsPage({
    super.key,
    required this.repository,
    required this.academics,
    this.onChanged,
  });

  final AdministratorReportCardRepository repository;
  final AdministratorAcademicsRepository academics;
  final VoidCallback? onChanged;

  @override
  State<AdministratorReportCardsPage> createState() => _AdministratorReportCardsPageState();
}

class _AdministratorReportCardsPageState extends State<AdministratorReportCardsPage> {
  late Future<(AdministratorReportCardSnapshot, AdministratorAcademicsSnapshot)> _future;
  String? _classId;
  String? _termId;
  String? _notice;
  bool _noticeSuccess = false;
  bool _compiling = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(AdministratorReportCardSnapshot, AdministratorAcademicsSnapshot)> _load() async {
    final cards = await widget.repository.load();
    final academics = await widget.academics.load();
    return (cards, academics);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _compile() async {
    if (_classId == null || _termId == null) return;
    setState(() => _compiling = true);
    final result = await widget.repository.compileClass(classId: _classId!, termId: _termId!);
    if (!mounted) return;
    setState(() {
      _compiling = false;
      _notice = result.message;
      _noticeSuccess = result.success;
    });
    if (result.success) {
      widget.onChanged?.call();
      _reload();
    }
  }

  Future<void> _run(Future<AdministratorReportCardActionResult> Function() action) async {
    final result = await action();
    if (!mounted) return;
    setState(() {
      _notice = result.message;
      _noticeSuccess = result.success;
    });
    if (result.success) {
      widget.onChanged?.call();
      _reload();
    }
  }

  void _showHistory(ReportCard card) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${card.studentName} · history'),
        content: SizedBox(
          width: 420,
          child: card.events.isEmpty
              ? const Text('No history recorded yet.')
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final event in card.events)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(reportCardEventLabel(event.action), style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text('${event.actor} · ${event.occurredAt}', style: Theme.of(context).textTheme.bodySmall),
                              if (event.comment.isNotEmpty) Text(event.comment),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(AdministratorReportCardSnapshot, AdministratorAcademicsSnapshot)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load report cards.'),
                const SizedBox(height: 10),
                FilledButton(onPressed: _reload, child: const Text('Retry')),
              ],
            ),
          );
        }
        final (cards, academics) = snapshot.requireData;
        if (!cards.permissions.canManage) {
          return const Center(child: Text('Report cards require Proprietor or Administrator authority.'));
        }
        _classId ??= academics.classes.isEmpty ? null : academics.classes.first.id;
        _termId ??= academics.terms.where((t) => t.status == 'active').map((t) => t.id).firstOrNull ??
            (academics.terms.isEmpty ? null : academics.terms.first.id);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Report Cards', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text(
                'Compile every roster student\'s term report from released assessment evidence, then submit and release. This never edits a score.',
              ),
              const SizedBox(height: 18),
              if (_notice != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _noticeSuccess
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_notice!),
                ),
                const SizedBox(height: 14),
              ],
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Compile a class', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 260,
                            child: DropdownButtonFormField<String>(
                              initialValue: _classId,
                              decoration: const InputDecoration(labelText: 'Class'),
                              items: [
                                for (final item in academics.classes)
                                  DropdownMenuItem(value: item.id, child: Text('${item.name} · ${item.section}')),
                              ],
                              onChanged: (v) => setState(() => _classId = v),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: DropdownButtonFormField<String>(
                              initialValue: _termId,
                              decoration: const InputDecoration(labelText: 'Term'),
                              items: [
                                for (final item in academics.terms)
                                  DropdownMenuItem(value: item.id, child: Text(item.name)),
                              ],
                              onChanged: (v) => setState(() => _termId = v),
                            ),
                          ),
                          FilledButton(
                            onPressed: _compiling ? null : _compile,
                            child: Text(_compiling ? 'Compiling…' : 'Compile'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _section(
                title: 'Submitted · awaiting Principal review',
                items: cards.awaitingReview,
                emptyText: 'No Secondary report cards are awaiting Principal review.',
              ),
              const SizedBox(height: 18),
              _section(
                title: 'Ready to release',
                items: cards.awaitingRelease,
                emptyText: 'No report cards are ready to release.',
                actionLabel: 'Release',
                onAction: (c) => _run(() => widget.repository.release(c)),
              ),
              const SizedBox(height: 18),
              _section(
                title: 'Recently released',
                items: cards.released.take(10).toList(),
                emptyText: 'Nothing has been released yet.',
              ),
              const SizedBox(height: 18),
              const Card(
                elevation: 0,
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reportCardReleaseBoundary),
                      SizedBox(height: 8),
                      Text(reportCardPrincipalReviewBoundary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _section({
    required String title,
    required List<ReportCard> items,
    required String emptyText,
    String? actionLabel,
    ValueChanged<ReportCard>? onAction,
  }) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Text(emptyText)
            else
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${item.studentName} · ${item.className}'),
                  subtitle: Text(
                    item.hasEvidence
                        ? 'Average ${item.overallAverage!.round()}% · ${item.overallGrade}'
                            '${item.classPosition == null ? '' : ' · Position ${item.classPosition}/${item.classSize}'}'
                        : 'No released assessment evidence yet',
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'History',
                        icon: const Icon(Icons.history_rounded, size: 20),
                        onPressed: () => _showHistory(item),
                      ),
                      if (actionLabel == null)
                        Chip(label: Text(reportCardStateLabel(item.state)))
                      else
                        FilledButton(onPressed: () => onAction?.call(item), child: Text(actionLabel)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
