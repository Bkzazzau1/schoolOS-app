import 'package:flutter/material.dart';

import '../data/principal_communication_demo_data.dart';
import '../data/principal_communication_repository.dart';
import '../domain/principal_communication_models.dart';

class PrincipalCommunicationPage extends StatefulWidget {
  const PrincipalCommunicationPage({
    super.key,
    required this.repository,
    required this.onNavigate,
    this.onMutationQueued,
  });

  final PrincipalCommunicationRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback? onMutationQueued;

  @override
  State<PrincipalCommunicationPage> createState() =>
      _PrincipalCommunicationPageState();
}

class _PrincipalCommunicationPageState
    extends State<PrincipalCommunicationPage> {
  final _replyController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  PrincipalCommunicationSnapshot? _snapshot;
  String? _error;
  String _activeThreadId = '';
  String _query = '';
  PrincipalCommunicationAudience _audience =
      PrincipalCommunicationAudience.staff;
  PrincipalCommunicationChannel _channel = PrincipalCommunicationChannel.portal;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
        if (!snapshot.threads.any((thread) => thread.id == _activeThreadId) &&
            snapshot.threads.isNotEmpty) {
          _activeThreadId = snapshot.threads.first.id;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  List<PrincipalCommunicationThread> _filteredThreads(
    PrincipalCommunicationSnapshot snapshot,
  ) {
    final query = _query.trim().toLowerCase();
    return snapshot.threads
        .where((thread) {
          final haystack = '${thread.title} ${thread.person} ${thread.context}'
              .toLowerCase();
          return query.isEmpty || haystack.contains(query);
        })
        .toList(growable: false);
  }

  PrincipalCommunicationThread _activeThread(
    PrincipalCommunicationSnapshot snapshot,
  ) => snapshot.threads.firstWhere(
    (thread) => thread.id == _activeThreadId,
    orElse: () => snapshot.threads.first,
  );

  Future<void> _sendReply() async {
    if (_saving) return;
    setState(() => _saving = true);
    final result = await widget.repository.queueReply(
      threadId: _activeThreadId,
      message: _replyController.text,
    );
    if (!mounted) return;
    if (result.success) {
      _replyController.clear();
      await _load();
      widget.onMutationQueued?.call();
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _sendAnnouncement() async {
    if (_saving) return;
    setState(() => _saving = true);
    final result = await widget.repository.queueAnnouncement(
      audience: _audience,
      channel: _channel,
      subject: _subjectController.text,
      message: _messageController.text,
    );
    if (!mounted) return;
    if (result.success) {
      _subjectController.clear();
      _messageController.clear();
      await _load();
      widget.onMutationQueued?.call();
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  void _useAttendanceTemplate() {
    setState(() {
      _audience = PrincipalCommunicationAudience.guardians;
      _channel = PrincipalCommunicationChannel.sms;
    });
    _subjectController.text = principalAttendanceTemplateSubject;
    _messageController.text = principalAttendanceTemplateMessage;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 10),
              const Text(
                'Could not load Communication Hub.',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final activeThread = snapshot.threads.isEmpty
        ? null
        : _activeThread(snapshot);
    final filteredThreads = _filteredThreads(snapshot);
    final queuedReplies = snapshot.outgoing
        .where(
          (item) =>
              item.kind == PrincipalOutgoingKind.reply &&
              item.threadId == activeThread?.id,
        )
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(onNavigate: widget.onNavigate),
        const SizedBox(height: 16),
        _Kpis(snapshot: snapshot),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final inbox = _InboxCard(
              threads: filteredThreads,
              activeThreadId: activeThread?.id ?? '',
              onQueryChanged: (value) => setState(() => _query = value),
              onSelected: (id) {
                _replyController.clear();
                setState(() => _activeThreadId = id);
              },
            );
            final thread = activeThread == null
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No verified conversations recorded for this Principal.',
                      ),
                    ),
                  )
                : _ThreadCard(
                    thread: activeThread,
                    queuedReplies: queuedReplies,
                    controller: _replyController,
                    saving: _saving,
                    canSend: snapshot.permissions.canQueueMessages,
                    onQuickReply: () =>
                        _replyController.text = principalQuickReply,
                    onSend: _sendReply,
                  );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: inbox),
                      const SizedBox(width: 16),
                      Expanded(flex: 5, child: thread),
                    ],
                  )
                : Column(children: [inbox, const SizedBox(height: 16), thread]);
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final compose = _ComposeCard(
              audience: _audience,
              channel: _channel,
              subjectController: _subjectController,
              messageController: _messageController,
              saving: _saving,
              queuedCount: snapshot.queuedCount,
              canSend: snapshot.permissions.canQueueMessages,
              onAudienceChanged: (value) => setState(() => _audience = value),
              onChannelChanged: (value) => setState(() => _channel = value),
              onTemplate: _useAttendanceTemplate,
              onSend: _sendAnnouncement,
            );
            final followUps = _FollowUpsCard(
              items: snapshot.followUps,
              onNavigate: widget.onNavigate,
            );
            if (constraints.maxWidth >= 980) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: compose),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: followUps),
                ],
              );
            }
            return Column(
              children: [compose, const SizedBox(height: 16), followUps],
            );
          },
        ),
        const SizedBox(height: 16),
        _AnnouncementsCard(
          items: snapshot.announcements,
          onNavigate: widget.onNavigate,
        ),
        const SizedBox(height: 12),
        const _Boundary(text: principalCommunicationPrivacyBoundary),
        const SizedBox(height: 8),
        const _Boundary(text: principalCommunicationOfflineBoundary),
        const SizedBox(height: 8),
        const _Boundary(text: principalCommunicationScopeBoundary),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onNavigate});
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    runSpacing: 12,
    spacing: 16,
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PRINCIPAL · COMMUNICATION',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
            SizedBox(height: 4),
            Text(
              'Communication Hub',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28),
            ),
            SizedBox(height: 4),
            Text(
              'Coordinate staff messages, guardian follow-ups, announcements and urgent school notices.',
            ),
          ],
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed: () => onNavigate('dashboard'),
            child: const Text('Dashboard'),
          ),
          OutlinedButton(
            onPressed: () => onNavigate('students'),
            child: const Text('Students'),
          ),
          OutlinedButton(
            onPressed: () => onNavigate('teachers'),
            child: const Text('Teachers'),
          ),
          OutlinedButton(
            onPressed: () => onNavigate('incidents'),
            child: const Text('Incidents'),
          ),
        ],
      ),
    ],
  );
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.snapshot});
  final PrincipalCommunicationSnapshot snapshot;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      _Kpi(
        label: 'Unread',
        value: '${snapshot.unreadCount}',
        note: 'Conversations requiring attention',
      ),
      _Kpi(
        label: 'Announcements',
        value: '${snapshot.announcements.length}',
        note: 'Your saved announcements',
      ),
      const _Kpi(
        label: 'Delivery rate',
        value: 'Not recorded',
        note: 'No verified recipient totals',
      ),
      _Kpi(
        label: 'Follow-ups due',
        value: '${snapshot.dueTodayCount}',
        note: 'Needs action today',
      ),
      const _Kpi(
        label: 'Guardian responses',
        value: 'Not recorded',
        note: 'No response tracking feed',
      ),
    ],
  );
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.note});
  final String label;
  final String value;
  final String note;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26),
            ),
            Text(note, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class _InboxCard extends StatelessWidget {
  const _InboxCard({
    required this.threads,
    required this.activeThreadId,
    required this.onQueryChanged,
    required this.onSelected,
  });

  final List<PrincipalCommunicationThread> threads;
  final String activeThreadId;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inbox',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const Text('Staff and authorized guardian conversations.'),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search conversations...',
              border: OutlineInputBorder(),
            ),
            onChanged: onQueryChanged,
          ),
          const SizedBox(height: 10),
          if (threads.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('No conversations match this search.')),
            )
          else
            for (final thread in threads) ...[
              Material(
                color: thread.id == activeThreadId
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelected(thread.id),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PriorityChip(priority: thread.priority),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      thread.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  if (thread.unread)
                                    const Icon(Icons.circle, size: 9),
                                ],
                              ),
                              Text(
                                thread.person,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                thread.context,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                thread.preview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          thread.time,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    ),
  );
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({
    required this.thread,
    required this.queuedReplies,
    required this.controller,
    required this.saving,
    required this.canSend,
    required this.onQuickReply,
    required this.onSend,
  });

  final PrincipalCommunicationThread thread;
  final List<PrincipalOutgoingCommunication> queuedReplies;
  final TextEditingController controller;
  final bool saving;
  final bool canSend;
  final VoidCallback onQuickReply;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      thread.context,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      thread.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 21,
                      ),
                    ),
                    Text(thread.person),
                  ],
                ),
              ),
              _PriorityChip(priority: thread.priority),
            ],
          ),
          const SizedBox(height: 14),
          _MessageBubble(
            label: 'School · 9:54 AM',
            message:
                'We are following up regarding the recent school matter. We would like to coordinate the next step with you.',
            outgoing: true,
          ),
          const SizedBox(height: 8),
          _MessageBubble(
            label: '${thread.person} · ${thread.time}',
            message: thread.preview,
            outgoing: false,
          ),
          for (final item in queuedReplies) ...[
            const SizedBox(height: 8),
            _MessageBubble(
              label: 'Principal · queued offline',
              message: item.message,
              outgoing: true,
              queued: true,
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Reply',
              hintText: 'Write a professional school reply...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(
                onPressed: saving ? null : onQuickReply,
                child: const Text('Use quick reply'),
              ),
              FilledButton.icon(
                onPressed: saving || !canSend ? null : onSend,
                icon: const Icon(Icons.send_rounded),
                label: Text(saving ? 'Queuing...' : 'Send reply'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            principalCommunicationPrivacyBoundary,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.label,
    required this.message,
    required this.outgoing,
    this.queued = false,
  });
  final String label;
  final String message;
  final bool outgoing;
  final bool queued;

  @override
  Widget build(BuildContext context) => Align(
    alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: outgoing
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              if (queued) ...[
                const SizedBox(width: 6),
                const Icon(Icons.cloud_upload_outlined, size: 14),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(message),
        ],
      ),
    ),
  );
}

class _ComposeCard extends StatelessWidget {
  const _ComposeCard({
    required this.audience,
    required this.channel,
    required this.subjectController,
    required this.messageController,
    required this.saving,
    required this.queuedCount,
    required this.canSend,
    required this.onAudienceChanged,
    required this.onChannelChanged,
    required this.onTemplate,
    required this.onSend,
  });

  final PrincipalCommunicationAudience audience;
  final PrincipalCommunicationChannel channel;
  final TextEditingController subjectController;
  final TextEditingController messageController;
  final bool saving;
  final int queuedCount;
  final bool canSend;
  final ValueChanged<PrincipalCommunicationAudience> onAudienceChanged;
  final ValueChanged<PrincipalCommunicationChannel> onChannelChanged;
  final VoidCallback onTemplate;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compose announcement',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Send a controlled message to an approved school audience.',
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: saving ? null : onTemplate,
                child: const Text('Attendance template'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<PrincipalCommunicationAudience>(
                  initialValue: audience,
                  decoration: const InputDecoration(
                    labelText: 'Audience',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final item in principalCommunicationAudiences)
                      DropdownMenuItem(
                        value: item,
                        child: Text('Secondary ${item.label.toLowerCase()}'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) onAudienceChanged(value);
                  },
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<PrincipalCommunicationChannel>(
                  initialValue: channel,
                  decoration: const InputDecoration(
                    labelText: 'Channel',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final item in principalCommunicationChannels)
                      DropdownMenuItem(value: item, child: Text(item.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) onChannelChanged(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: subjectController,
            decoration: const InputDecoration(
              labelText: 'Subject',
              hintText: 'Announcement subject',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: messageController,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Message',
              hintText: 'Write school announcement or notice...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 10,
            spacing: 12,
            children: [
              Text(
                'Audience: ${audience.label} · Channel: ${channel.label} · $queuedCount queued locally',
              ),
              FilledButton.icon(
                onPressed: saving || !canSend ? null : onSend,
                icon: const Icon(Icons.campaign_outlined),
                label: Text(saving ? 'Queuing...' : 'Queue announcement'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Whole School remains constrained by the Principal\'s authorized Secondary scope in the native client.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _FollowUpsCard extends StatelessWidget {
  const _FollowUpsCard({required this.items, required this.onNavigate});
  final List<PrincipalCommunicationFollowUp> items;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Follow-ups',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const Text(
            'Communication tasks created from attendance, academics or staff oversight.',
          ),
          const SizedBox(height: 10),
          for (final item in items) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(item.context),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(label: Text(item.action)),
                      Text(
                        item.status,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextButton(
                        onPressed: () => onNavigate(item.targetKey),
                        child: const Text('Open'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    ),
  );
}

class _AnnouncementsCard extends StatelessWidget {
  const _AnnouncementsCard({required this.items, required this.onNavigate});
  final List<PrincipalRecentAnnouncement> items;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent announcements',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text('Saved offline announcements; delivery and reading require confirmation.'),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => onNavigate('ai'),
                child: const Text('Ask Principal AI to draft'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 780) {
                return Column(
                  children: [
                    for (final item in items) _AnnouncementCard(item: item),
                  ],
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Announcement')),
                    DataColumn(label: Text('Audience')),
                    DataColumn(label: Text('Channel')),
                    DataColumn(label: Text('State')),
                    DataColumn(label: Text('Delivered')),
                    DataColumn(label: Text('Read')),
                  ],
                  rows: [
                    for (final item in items)
                      DataRow(
                        cells: [
                          DataCell(
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          DataCell(Text(item.audience)),
                          DataCell(Text(item.channel)),
                          DataCell(Text(item.sent)),
                          DataCell(Text(item.delivered)),
                          DataCell(Text(item.read)),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.item});
  final PrincipalRecentAnnouncement item;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
        Text('${item.audience} · ${item.channel} · ${item.sent}'),
        Text('Delivered ${item.delivered} · Read ${item.read}'),
      ],
    ),
  );
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});
  final PrincipalCommunicationPriority priority;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(priority.label),
    avatar: Icon(
      priority == PrincipalCommunicationPriority.urgent
          ? Icons.priority_high_rounded
          : priority == PrincipalCommunicationPriority.important
          ? Icons.flag_outlined
          : Icons.circle_outlined,
      size: 16,
    ),
  );
}

class _Boundary extends StatelessWidget {
  const _Boundary({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text),
  );
}
