import 'package:flutter/material.dart';

import '../../administrator/domain/report_card_models.dart';
import '../data/teacher_class_teacher_repository.dart';

class TeacherClassTeacherPage extends StatefulWidget {
  const TeacherClassTeacherPage({
    super.key,
    required this.repository,
    this.onMutationQueued,
  });

  final TeacherClassTeacherRepository repository;
  final VoidCallback? onMutationQueued;

  @override
  State<TeacherClassTeacherPage> createState() => _TeacherClassTeacherPageState();
}

class _TeacherClassTeacherPageState extends State<TeacherClassTeacherPage> {
  late Future<TeacherClassTeacherSnapshot> _future;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  void _reload() => setState(() => _future = widget.repository.load());

  Future<void> _comment(ReportCard card) async {
    final controller = TextEditingController(text: card.classTeacherComment);
    final comment = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Comment for ${card.studentName}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Class-teacher comment'),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (comment == null) return;
    final result = await widget.repository.comment(card, comment);
    if (!mounted) return;
    setState(() => _notice = result.message);
    if (result.success) {
      widget.onMutationQueued?.call();
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeacherClassTeacherSnapshot>(
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
                const Text('Could not load class-teacher data.'),
                const SizedBox(height: 10),
                FilledButton(onPressed: _reload, child: const Text('Retry')),
              ],
            ),
          );
        }
        final data = snapshot.requireData;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Class Teacher', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Your own remark on a report card - separate from subject scores and Principal review.'),
              const SizedBox(height: 16),
              if (_notice != null) ...[
                Text(_notice!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 12),
              ],
              if (data.myClasses.isEmpty)
                const Card(
                  elevation: 0,
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('You are not currently assigned as a class teacher for any class.'),
                  ),
                )
              else ...[
                Text('Class teacher for: ${data.myClasses.map((c) => c.className).join(', ')}'),
                const SizedBox(height: 12),
                if (data.reportCards.isEmpty)
                  const Card(
                    elevation: 0,
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No compiled, not-yet-released report cards for your class yet.'),
                    ),
                  )
                else
                  for (final card in data.reportCards)
                    Card(
                      elevation: 0,
                      child: ListTile(
                        title: Text(card.studentName),
                        subtitle: Text(
                          card.classTeacherComment.isEmpty
                              ? '${reportCardStateLabel(card.state)} · No comment yet'
                              : '${reportCardStateLabel(card.state)} · "${card.classTeacherComment}"',
                        ),
                        trailing: TextButton(
                          onPressed: () => _comment(card),
                          child: Text(card.classTeacherComment.isEmpty ? 'Add comment' : 'Edit'),
                        ),
                      ),
                    ),
              ],
            ],
          ),
        );
      },
    );
  }
}
