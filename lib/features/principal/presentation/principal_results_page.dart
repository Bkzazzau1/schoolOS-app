import 'package:flutter/material.dart';
import '../../administrator/domain/report_card_models.dart' show reportCardEventLabel;
import '../data/principal_results_repository.dart';
import '../domain/principal_results_models.dart';

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
  String? _notice;
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

  Future<void> _approve(PrincipalStudentResult student) => _review(student, PrincipalReportReviewAction.approve, '');

  Future<void> _returnWithComment(PrincipalStudentResult student) async {
    final controller = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Return ${student.name}\'s report card'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Comment'),
          maxLines: 2,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Return')),
        ],
      ),
    );
    if (comment == null || comment.isEmpty) return;
    await _review(student, PrincipalReportReviewAction.returnWithComment, comment);
  }

  Future<void> _review(PrincipalStudentResult student, PrincipalReportReviewAction action, String comment) async {
    final result = await widget.repository.reviewReport(studentId: student.id, action: action, comment: comment);
    if (!mounted) return;
    setState(() => _notice = result.message);
    if (result.success) {
      widget.onMutationQueued?.call();
      _load();
    }
  }

  void _showHistory(PrincipalStudentResult student) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${student.name} · history'),
        content: SizedBox(
          width: 420,
          child: student.events.isEmpty
              ? const Text('No history recorded yet.')
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final event in student.events)
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
    final awaitingReview = snapshot.students
        .where((s) => s.reportStatus == PrincipalResultReleaseState.awaitingApproval)
        .toList();
    final decided = snapshot.students
        .where((s) => s.reportStatus != PrincipalResultReleaseState.awaitingApproval)
        .toList();

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
          'Report cards awaiting review: ${snapshot.pendingApproval} · Released: ${snapshot.reportsReady}',
        ),
        if (_notice != null) ...[
          const SizedBox(height: 8),
          Text(_notice!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        ],
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Report cards are compiled by the Administrator from released assessment evidence and submitted attendance registers. Approving here is a review decision, not publication - release to families remains a separate Administrator/Proprietor action.',
            ),
          ),
        ),
        OutlinedButton(
          onPressed: () => widget.onNavigate('academics'),
          child: const Text('View recorded assessment evidence'),
        ),
        const SizedBox(height: 16),
        if (awaitingReview.isNotEmpty) ...[
          Text('Awaiting your review', style: Theme.of(context).textTheme.titleMedium),
          for (final student in awaitingReview)
            Card(
              child: ListTile(
                title: Text('${student.name} · ${student.className}'),
                subtitle: Text(
                  student.average == 0 ? 'No released assessment evidence yet' : 'Average ${student.average}%'
                      '${student.position.isEmpty ? '' : ' · Position ${student.position}'}',
                ),
                trailing: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(tooltip: 'History', icon: const Icon(Icons.history_rounded, size: 20), onPressed: () => _showHistory(student)),
                    TextButton(onPressed: () => _returnWithComment(student), child: const Text('Return')),
                    FilledButton(onPressed: () => _approve(student), child: const Text('Approve')),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
        if (decided.isNotEmpty) ...[
          Text('Reviewed / released', style: Theme.of(context).textTheme.titleMedium),
          for (final student in decided)
            Card(
              child: ListTile(
                title: Text('${student.name} · ${student.className}'),
                subtitle: Text(
                  'Average ${student.average}%${student.position.isEmpty ? '' : ' · Position ${student.position}'}',
                ),
                trailing: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(tooltip: 'History', icon: const Icon(Icons.history_rounded, size: 20), onPressed: () => _showHistory(student)),
                    Chip(label: Text(student.reportStatus.label)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
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
