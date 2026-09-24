import 'package:flutter/material.dart';

import '../../teacher/domain/teacher_assessment_models.dart';
import '../data/administrator_assessment_release_repository.dart';

class AdministratorAssessmentReleasePage extends StatefulWidget {
  const AdministratorAssessmentReleasePage({
    super.key,
    required this.repository,
    this.onChanged,
  });

  final AdministratorAssessmentReleaseRepository repository;
  final VoidCallback? onChanged;

  @override
  State<AdministratorAssessmentReleasePage> createState() => _AdministratorAssessmentReleasePageState();
}

class _AdministratorAssessmentReleasePageState extends State<AdministratorAssessmentReleasePage> {
  late Future<AdministratorAssessmentReleaseSnapshot> _future;
  String? _notice;
  bool _noticeSuccess = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  void _reload() => setState(() => _future = widget.repository.load());

  Future<void> _run(Future<AdministratorAssessmentReleaseActionResult> Function() action) async {
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

  Future<void> _returnWithComment(TeacherAssessment assessment) async {
    final controller = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return for correction'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason'),
          maxLines: 2,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Return'),
          ),
        ],
      ),
    );
    if (comment == null || comment.isEmpty) return;
    await _run(() => widget.repository.returnForCorrection(assessment, comment: comment));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdministratorAssessmentReleaseSnapshot>(
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
                const Text('Could not load assessments awaiting release.'),
                const SizedBox(height: 10),
                FilledButton(onPressed: _reload, child: const Text('Retry')),
              ],
            ),
          );
        }
        final data = snapshot.requireData;
        if (!data.permissions.canManage) {
          return const Center(child: Text('Assessment release requires Proprietor or Administrator authority.'));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assessment Release', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text(
                'Lock scores once a Teacher submits them for review, then release to make them visible to Students and their linked Parents. This never edits a score.',
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
              _section(
                title: 'Submitted · awaiting lock',
                items: data.awaitingLock,
                emptyText: 'No submitted assessments are waiting.',
                actionLabel: 'Lock',
                onAction: (a) => _run(() => widget.repository.lock(a)),
                onReturn: _returnWithComment,
              ),
              const SizedBox(height: 18),
              _section(
                title: 'Locked · awaiting release',
                items: data.awaitingRelease,
                emptyText: 'No locked assessments are waiting.',
                actionLabel: 'Release',
                onAction: (a) => _run(() => widget.repository.release(a)),
                onReturn: _returnWithComment,
              ),
              const SizedBox(height: 18),
              _section(
                title: 'Recently released',
                items: data.released.take(10).toList(),
                emptyText: 'Nothing has been released yet.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _section({
    required String title,
    required List<TeacherAssessment> items,
    required String emptyText,
    String? actionLabel,
    ValueChanged<TeacherAssessment>? onAction,
    ValueChanged<TeacherAssessment>? onReturn,
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
                  title: Text('${item.title} · ${item.className}${item.subject.isEmpty ? '' : ' · ${item.subject}'}'),
                  subtitle: Text(
                    '${teacherAssessmentTypeLabel(item.type)} · Max ${item.maximumScore} · ${item.entered}/${item.totalStudents} scored'
                    '${item.currentTeacher.isEmpty ? '' : ' · ${item.currentTeacher}'}',
                  ),
                  trailing: actionLabel == null
                      ? null
                      : Wrap(
                          spacing: 8,
                          children: [
                            TextButton(onPressed: () => onReturn?.call(item), child: const Text('Return')),
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
