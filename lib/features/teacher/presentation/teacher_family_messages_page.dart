import 'package:flutter/material.dart';

import '../../parent/domain/parent_messages_models.dart';
import '../data/teacher_family_messages_repository.dart';
import '../domain/teacher_family_messages_models.dart';

/// A real reply screen for one real family conversation at a time, scoped to the classes this
/// Teacher membership is really assigned to. Separate from Teacher Messages' own class-wide
/// broadcast channels — this is a private, per-family thread.
class TeacherFamilyMessagesPage extends StatefulWidget {
  const TeacherFamilyMessagesPage({
    super.key,
    required this.repository,
    required this.onNavigate,
    required this.onMutationQueued,
  });

  final TeacherFamilyMessagesRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback onMutationQueued;

  @override
  State<TeacherFamilyMessagesPage> createState() => _TeacherFamilyMessagesPageState();
}

class _TeacherFamilyMessagesPageState extends State<TeacherFamilyMessagesPage> {
  late Future<TeacherFamilyMessagesSnapshot> _snapshot;
  final _composer = TextEditingController();
  String? _selectedThreadId;
  bool _queueing = false;
  bool _autoSelectHandled = false;
  final _markingSeen = <String>{};

  @override
  void initState() {
    super.initState();
    _snapshot = widget.repository.load();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _snapshot = widget.repository.load());
  }

  void _selectThread(String threadId) {
    if (_selectedThreadId == threadId) return;
    setState(() {
      _selectedThreadId = threadId;
      _composer.clear();
    });
    _markSeen(threadId);
  }

  void _markSeen(String threadId) {
    if (!_markingSeen.add(threadId)) return;
    widget.repository.markThreadSeen(threadId).then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {
      // Opening the conversation remains possible even if a read receipt cannot be queued.
    });
  }

  Future<void> _queueReply(ParentMessageThread thread) async {
    final body = _composer.text.trim();
    if (body.isEmpty || _queueing) return;

    setState(() => _queueing = true);
    try {
      await widget.repository.queueReply(threadId: thread.id, body: body);
      if (!mounted) return;
      _composer.clear();
      widget.onMutationQueued();
      setState(() {
        _snapshot = widget.repository.load();
        _queueing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply queued on this device. It is not sent until synchronization is acknowledged.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _queueing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reply could not be queued: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeacherFamilyMessagesSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _LoadFailure(onRetry: _reload);
        }

        final data = snapshot.data!;
        if (data.threads.isEmpty) {
          return _EmptyState(onDashboard: () => widget.onNavigate('dashboard'));
        }

        final selected = data.threadById(_selectedThreadId ?? '') ?? data.threads.first;
        _selectedThreadId ??= selected.id;
        if (!_autoSelectHandled) {
          _autoSelectHandled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _markSeen(selected.id));
        }

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 1000 ? 28.0 : 16.0;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 36),
                children: [
                  _Header(count: data.threads.length, onDashboard: () => widget.onNavigate('dashboard')),
                  const SizedBox(height: 16),
                  if (constraints.maxWidth >= 900)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 340,
                          child: _ConversationList(
                            threads: data.threads,
                            selectedId: selected.id,
                            onSelected: _selectThread,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _MessageThreadCard(
                            thread: selected,
                            composer: _composer,
                            queueing: _queueing,
                            onQueue: () => _queueReply(selected),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _CompactConversationPicker(
                      threads: data.threads,
                      selectedId: selected.id,
                      onSelected: _selectThread,
                    ),
                    const SizedBox(height: 12),
                    _MessageThreadCard(
                      thread: selected,
                      composer: _composer,
                      queueing: _queueing,
                      onQueue: () => _queueReply(selected),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count, required this.onDashboard});

  final int count;
  final VoidCallback onDashboard;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TEACHER · FAMILY COMMUNICATION',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: .9,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text('Family Messages', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(
              'Reply to the real guardians of the students in your real assigned classes, one family at a time.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text('$count famil${count == 1 ? 'y' : 'ies'}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        );

        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 14), OutlinedButton.icon(onPressed: onDashboard, icon: const Icon(Icons.home_outlined), label: const Text('Dashboard'))],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            OutlinedButton.icon(onPressed: onDashboard, icon: const Icon(Icons.home_outlined), label: const Text('Dashboard')),
          ],
        );
      },
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({required this.threads, required this.selectedId, required this.onSelected});

  final List<ParentMessageThread> threads;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Families', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text('Your real assigned classes.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            for (final thread in threads) ...[
              _ConversationTile(thread: thread, selected: thread.id == selectedId, onTap: () => onSelected(thread.id)),
              if (thread != threads.last) const SizedBox(height: 7),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactConversationPicker extends StatelessWidget {
  const _CompactConversationPicker({required this.threads, required this.selectedId, required this.onSelected});

  final List<ParentMessageThread> threads;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: threads.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final thread = threads[index];
          final selected = thread.id == selectedId;
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelected(thread.id),
            child: Container(
              width: 218,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: selected ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  CircleAvatar(radius: 18, child: Text(_initials(thread.childLabel))),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(thread.childLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                        Text(thread.participantName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.thread, required this.selected, required this.onTap});

  final ParentMessageThread thread;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(child: Text(_initials(thread.childLabel))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(thread.childLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900))),
                      Text(thread.timeLabel, style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                  Text(thread.participantRole, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(thread.participantName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    thread.preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageThreadCard extends StatelessWidget {
  const _MessageThreadCard({required this.thread, required this.composer, required this.queueing, required this.onQueue});

  final ParentMessageThread thread;
  final TextEditingController composer;
  final bool queueing;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 22, child: Text(_initials(thread.childLabel))),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(thread.childLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      Text('${thread.participantRole} · ${thread.participantName}'),
                    ],
                  ),
                ),
                const Chip(avatar: Icon(Icons.verified_user_outlined, size: 16), label: Text('Real family'), visualDensity: VisualDensity.compact),
              ],
            ),
            const Divider(height: 28),
            for (final message in thread.messages) ...[
              _MessageBubble(message: message),
              const SizedBox(height: 9),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: composer,
              enabled: !queueing,
              minLines: 3,
              maxLines: 6,
              maxLength: 4000,
              decoration: const InputDecoration(hintText: 'Write a reply to this family...', border: OutlineInputBorder(), alignLabelWithHint: true),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Only the guardian, you and school leadership can access this conversation.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: queueing ? null : onQueue,
                  icon: queueing
                      ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_outlined),
                  label: Text(queueing ? 'Queueing...' : 'Queue reply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ParentMessageItem message;

  @override
  Widget build(BuildContext context) {
    final mine = message.authorLabel == 'You';
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: mine ? scheme.primaryContainer : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.authorLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(message.body, style: const TextStyle(height: 1.4)),
              const SizedBox(height: 7),
              Text(message.timeLabel, style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_unread_outlined, size: 42),
            const SizedBox(height: 10),
            const Text('Family messages could not be opened.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onDashboard});

  final VoidCallback onDashboard;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mail_outline_rounded, size: 44),
            const SizedBox(height: 10),
            const Text('No assigned classes yet, so there are no families to message.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: onDashboard, icon: const Icon(Icons.home_outlined), label: const Text('Back to dashboard')),
          ],
        ),
      ),
    );
  }
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList(growable: false);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
