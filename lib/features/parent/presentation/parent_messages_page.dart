import 'package:flutter/material.dart';

import '../data/parent_messages_demo_data.dart';
import '../data/parent_messages_repository.dart';
import '../domain/parent_messages_models.dart';

class ParentMessagesPage extends StatefulWidget {
  const ParentMessagesPage({
    super.key,
    required this.repository,
    required this.onQueueChanged,
    required this.onNavigate,
  });

  final ParentMessagesRepository repository;
  final VoidCallback onQueueChanged;
  final ValueChanged<String> onNavigate;

  @override
  State<ParentMessagesPage> createState() => _ParentMessagesPageState();
}

class _ParentMessagesPageState extends State<ParentMessagesPage> {
  late Future<ParentMessagesSnapshot> _snapshot;
  final _composer = TextEditingController();
  String? _selectedThreadId;
  bool _queueing = false;

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
  }

  Future<void> _queueReply(ParentMessageThread thread) async {
    final body = _composer.text.trim();
    if (body.isEmpty || _queueing) return;

    setState(() => _queueing = true);
    try {
      await widget.repository.queueReply(threadId: thread.id, body: body);
      if (!mounted) return;
      _composer.clear();
      widget.onQueueChanged();
      setState(() {
        _snapshot = widget.repository.load();
        _queueing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Message queued on this device. It is not sent until synchronization is acknowledged.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _queueing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message could not be queued: $error')),
      );
    }
  }

  Future<void> _chooseApprovedConversation(
    ParentMessagesSnapshot snapshot,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New message',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose an approved school conversation.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              for (final thread
                  in snapshot.threads.where((item) => item.approvedParticipant))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.school_outlined),
                  ),
                  title: Text(
                    thread.participantName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${thread.participantRole} · ${thread.childLabel}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pop(thread.id),
                ),
            ],
          ),
        ),
      ),
    );

    if (selected != null && mounted) _selectThread(selected);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ParentMessagesSnapshot>(
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

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 1000 ? 28.0 : 16.0;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 36),
                children: [
                  _Header(
                    unreadCount: data.unreadCount,
                    onDashboard: () => widget.onNavigate('dashboard'),
                    onNewMessage: () => _chooseApprovedConversation(data),
                  ),
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
                  const SizedBox(height: 14),
                  const _BoundaryCard(),
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
  const _Header({
    required this.unreadCount,
    required this.onDashboard,
    required this.onNewMessage,
  });

  final int unreadCount;
  final VoidCallback onDashboard;
  final VoidCallback onNewMessage;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FAMILY ACCOUNT · COMMUNICATION',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: .9,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Messages',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              'Contact teachers and approved school offices about your linked children through school-managed family communication.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                '$unreadCount unread conversation${unreadCount == 1 ? '' : 's'}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ],
        );

        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onDashboard,
              icon: const Icon(Icons.home_outlined),
              label: const Text('Dashboard'),
            ),
            FilledButton.icon(
              onPressed: onNewMessage,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('New message'),
            ),
          ],
        );

        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 14), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            actions,
          ],
        );
      },
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.threads,
    required this.selectedId,
    required this.onSelected,
  });

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
            const Text(
              'Conversations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              'School-managed family communication.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final thread in threads) ...[
              _ConversationTile(
                thread: thread,
                selected: thread.id == selectedId,
                onTap: () => onSelected(thread.id),
              ),
              if (thread != threads.last) const SizedBox(height: 7),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactConversationPicker extends StatelessWidget {
  const _CompactConversationPicker({
    required this.threads,
    required this.selectedId,
    required this.onSelected,
  });

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
                color: selected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    child: Text(_initials(thread.participantName)),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          thread.participantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          thread.childLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (thread.unread)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
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
  const _ConversationTile({
    required this.thread,
    required this.selected,
    required this.onTap,
  });

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
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(child: Text(_initials(thread.participantName))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.participantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(thread.timeLabel, style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                  Text(
                    thread.participantRole,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    thread.childLabel,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    thread.preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (thread.unread) ...[
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageThreadCard extends StatelessWidget {
  const _MessageThreadCard({
    required this.thread,
    required this.composer,
    required this.queueing,
    required this.onQueue,
  });

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
                CircleAvatar(
                  radius: 22,
                  child: Text(_initials(thread.participantName)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        thread.participantName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text('${thread.participantRole} · ${thread.childLabel}'),
                    ],
                  ),
                ),
                const Chip(
                  avatar: Icon(Icons.verified_user_outlined, size: 16),
                  label: Text('Approved'),
                  visualDensity: VisualDensity.compact,
                ),
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
              decoration: const InputDecoration(
                hintText: 'Write a message to the school...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Only authorized participants can access this conversation.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: queueing ? null : onQueue,
                  icon: queueing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(queueing ? 'Queueing...' : 'Queue message'),
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
    final guardian = message.isGuardianMessage;
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: guardian ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: guardian ? scheme.primaryContainer : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.authorLabel,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(message.body, style: const TextStyle(height: 1.4)),
              const SizedBox(height: 7),
              Wrap(
                spacing: 7,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(message.timeLabel, style: const TextStyle(fontSize: 10)),
                  if (guardian) _MessageStateChip(state: message.state),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageStateChip extends StatelessWidget {
  const _MessageStateChip({required this.state});

  final ParentMessageState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            state == ParentMessageState.queued
                ? Icons.schedule_rounded
                : state == ParentMessageState.read
                    ? Icons.done_all_rounded
                    : Icons.check_rounded,
            size: 12,
          ),
          const SizedBox(width: 3),
          Text(
            state.label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard();

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
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Family communication boundary',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(parentMessagesPrivacyBoundary),
            const SizedBox(height: 8),
            Text(
              parentMessagesDeliveryBoundary,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
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
            const Text(
              'Family messages could not be opened.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
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
            const Text(
              'No approved school conversations are available yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onDashboard,
              icon: const Icon(Icons.home_outlined),
              label: const Text('Back to dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
