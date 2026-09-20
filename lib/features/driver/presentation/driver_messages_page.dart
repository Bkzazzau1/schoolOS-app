import 'package:flutter/material.dart';

import '../data/driver_messages_demo_data.dart';
import '../data/driver_messages_repository.dart';
import '../domain/driver_messages_models.dart';

class DriverMessagesPage extends StatefulWidget {
  const DriverMessagesPage({
    super.key,
    required this.repository,
    this.onMessagesChanged,
  });

  final DriverMessagesRepository repository;
  final VoidCallback? onMessagesChanged;

  @override
  State<DriverMessagesPage> createState() => _DriverMessagesPageState();
}

class _DriverMessagesPageState extends State<DriverMessagesPage> {
  late Future<DriverMessagesSnapshot> _future;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  void _reload() {
    setState(() => _future = widget.repository.load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DriverMessagesSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _FailureState(
            message: '${snapshot.error ?? 'Driver messages could not be loaded.'}',
            onRetry: _reload,
          );
        }
        return _buildPage(snapshot.data!);
      },
    );
  }

  Widget _buildPage(DriverMessagesSnapshot snapshot) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          final padding = wide ? 28.0 : 16.0;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(padding, 20, padding, 40),
            children: [
              _Header(snapshot: snapshot),
              const SizedBox(height: 16),
              _Summary(snapshot: snapshot),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.forum_outlined),
                    label: Text('Messages'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.notifications_active_outlined),
                    label: Text('Alerts'),
                  ),
                ],
                selected: {_tabIndex},
                onSelectionChanged: (value) {
                  setState(() => _tabIndex = value.first);
                },
              ),
              const SizedBox(height: 18),
              if (_tabIndex == 0)
                _messages(snapshot, wide)
              else
                _alerts(snapshot, wide),
              const SizedBox(height: 18),
              const _BoundaryCard(),
            ],
          );
        },
      ),
    );
  }

  Widget _messages(DriverMessagesSnapshot snapshot, bool wide) {
    if (snapshot.threads.isEmpty) {
      return const _EmptyCard(
        icon: Icons.forum_outlined,
        title: 'No operational conversations',
        body: 'Approved transport communication channels will appear here.',
      );
    }

    if (wide) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final thread in snapshot.threads)
            SizedBox(
              width: 420,
              child: _ThreadCard(
                thread: thread,
                onOpen: () => _openThread(snapshot, thread),
              ),
            ),
        ],
      );
    }

    return Column(
      children: [
        for (final thread in snapshot.threads) ...[
          _ThreadCard(
            thread: thread,
            onOpen: () => _openThread(snapshot, thread),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _alerts(DriverMessagesSnapshot snapshot, bool wide) {
    if (snapshot.alerts.isEmpty) {
      return const _EmptyCard(
        icon: Icons.notifications_none_rounded,
        title: 'No operational alerts',
        body: 'School transport alerts will appear here.',
      );
    }

    return Column(
      children: [
        for (final alert in snapshot.alerts) ...[
          _AlertCard(
            alert: alert,
            onRead: alert.read ? null : () => _markAlertRead(alert.id),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Future<void> _openThread(
    DriverMessagesSnapshot snapshot,
    DriverMessageThread thread,
  ) async {
    try {
      await widget.repository.markThreadSeen(thread.id);
      widget.onMessagesChanged?.call();
    } catch (_) {
      // Opening the locally cached conversation remains possible even if a
      // read receipt cannot be queued. Sending still uses repository checks.
    }
    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => _ConversationDialog(thread: thread),
    );
    if (result == null || result.trim().isEmpty) {
      _reload();
      return;
    }

    try {
      await widget.repository.queueReply(threadId: thread.id, body: result);
      if (!mounted) return;
      widget.onMessagesChanged?.call();
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Message saved locally and queued. Queued does not mean sent or delivered.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(error))),
      );
      _reload();
    }
  }

  Future<void> _markAlertRead(String alertId) async {
    try {
      await widget.repository.markAlertRead(alertId);
      if (!mounted) return;
      widget.onMessagesChanged?.call();
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(error))),
      );
    }
  }

  String _message(Object error) {
    if (error is StateError) return error.message;
    if (error is ArgumentError) return '${error.message}';
    return '$error';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.snapshot});

  final DriverMessagesSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DRIVER PORTAL · OPERATIONS COMMUNICATION',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Messages & Alerts',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${snapshot.routeId} · ${snapshot.vehicle}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.snapshot});

  final DriverMessagesSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Approved channels', '${snapshot.threads.length}', Icons.verified_user_outlined),
      ('Unread messages', '${snapshot.unreadThreads}', Icons.mark_chat_unread_outlined),
      ('Unread alerts', '${snapshot.unreadAlerts}', Icons.notifications_outlined),
      ('Urgent alerts', '${snapshot.urgentUnreadAlerts}', Icons.priority_high_rounded),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(metric.$3, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                metric.$2,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              Text(metric.$1),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({required this.thread, required this.onOpen});

  final DriverMessageThread thread;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    child: Icon(
                      thread.participantRole.toLowerCase().contains('vehicle')
                          ? Icons.build_outlined
                          : Icons.support_agent_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          thread.participantName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(thread.participantRole),
                      ],
                    ),
                  ),
                  if (thread.unread)
                    const Badge(label: Text('New')),
                ],
              ),
              const SizedBox(height: 12),
              Text(thread.preview, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  _Meta(icon: Icons.lock_outline, text: thread.channelLabel),
                  _Meta(icon: Icons.schedule_outlined, text: thread.timeLabel),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onRead});

  final DriverOperationalAlert alert;
  final VoidCallback? onRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  alert.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Chip(label: Text(alert.priority.label)),
                if (!alert.read) const Chip(label: Text('Unread')),
              ],
            ),
            const SizedBox(height: 8),
            Text(alert.body),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Meta(icon: Icons.route_outlined, text: alert.scopeLabel),
                _Meta(icon: Icons.schedule_outlined, text: alert.timeLabel),
                if (onRead != null)
                  TextButton.icon(
                    onPressed: onRead,
                    icon: const Icon(Icons.done_all_rounded),
                    label: const Text('Mark read'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationDialog extends StatefulWidget {
  const _ConversationDialog({required this.thread});

  final DriverMessageThread thread;

  @override
  State<_ConversationDialog> createState() => _ConversationDialogState();
}

class _ConversationDialogState extends State<_ConversationDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final dialogHeight = screenHeight < 700 ? screenHeight * .62 : 520.0;
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.thread.participantName),
          Text(
            widget.thread.channelLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        height: dialogHeight,
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: widget.thread.messages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final message = widget.thread.messages[index];
                  final outgoing = message.isDriverMessage;
                  return Align(
                    alignment: outgoing
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Container(
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
                            Text(message.body),
                            const SizedBox(height: 5),
                            Text(
                              '${message.timeLabel} · ${message.state.label}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Operational message',
                hintText: 'Keep the message factual and transport-related.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) return;
            Navigator.of(context).pop(text);
          },
          icon: const Icon(Icons.send_outlined),
          label: const Text('Queue message'),
        ),
      ],
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
            Text(
              'Communication boundaries',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(driverMessagingBoundary),
            const SizedBox(height: 6),
            const Text(driverDeliveryBoundary),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 5),
        Flexible(child: Text(text)),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
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
