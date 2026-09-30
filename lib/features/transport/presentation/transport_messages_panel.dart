import 'package:flutter/material.dart';

import '../../driver/domain/driver_messages_models.dart';
import '../data/transport_messages_repository.dart';
import '../domain/transport_messages_models.dart';

/// Transport Control's own side of the real channel with each real, currently assigned Driver -
/// the other end of what `DriverMessagesPage` shows a Driver. A separate panel from Driver
/// Assignments/Route Management above it: those set policy, this is a private conversation per
/// real Driver.
class TransportMessagesPanel extends StatefulWidget {
  const TransportMessagesPanel({super.key, required this.repository, this.onChanged});

  final TransportMessagesRepository repository;
  final VoidCallback? onChanged;

  @override
  State<TransportMessagesPanel> createState() => _TransportMessagesPanelState();
}

class _TransportMessagesPanelState extends State<TransportMessagesPanel> {
  late Future<TransportMessagesSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  void _reload() {
    setState(() => _future = widget.repository.load());
  }

  Future<void> _openThread(TransportMessagesSnapshot snapshot, DriverMessageThread thread) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _ConversationDialog(thread: thread, canReply: snapshot.canReply),
    );
    if (result == null || result.trim().isEmpty) return;

    try {
      await widget.repository.queueReply(threadId: thread.id, body: result);
      if (!mounted) return;
      widget.onChanged?.call();
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply saved locally and queued. Queued does not mean sent or delivered.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_message(error))));
    }
  }

  String _message(Object error) {
    if (error is StateError) return error.message;
    if (error is ArgumentError) return '${error.message}';
    return '$error';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TransportMessagesSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Card(
            child: Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator())),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Driver messages', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('${snapshot.error ?? 'Driver messages could not be loaded.'}'),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Driver messages', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    ),
                    IconButton(tooltip: 'Reload', onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'One real conversation with each real, currently assigned Driver.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 14),
                if (data.threads.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: Text('No Driver is currently assigned to a route yet.')),
                  )
                else
                  for (final thread in data.threads) ...[
                    _ThreadTile(thread: thread, onTap: () => _openThread(data, thread)),
                    if (thread != data.threads.last) const Divider(height: 18),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.thread, required this.onTap});

  final DriverMessageThread thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(child: Icon(Icons.local_shipping_outlined)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(thread.participantName, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(thread.participantRole, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 3),
                  Text(
                    thread.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _ConversationDialog extends StatefulWidget {
  const _ConversationDialog({required this.thread, required this.canReply});

  final DriverMessageThread thread;
  final bool canReply;

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
          Text(widget.thread.participantRole, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      content: SizedBox(
        width: 620,
        height: dialogHeight,
        child: Column(
          children: [
            Expanded(
              child: widget.thread.messages.isEmpty
                  ? const Center(child: Text('No messages yet.'))
                  : ListView.separated(
                      itemCount: widget.thread.messages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final message = widget.thread.messages[index];
                        final mine = !message.isDriverMessage;
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: mine
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : Theme.of(context).colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(message.authorLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 4),
                                  Text(message.body),
                                  const SizedBox(height: 5),
                                  Text('${message.timeLabel} · ${message.state.label}', style: Theme.of(context).textTheme.bodySmall),
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
              enabled: widget.canReply,
              minLines: 2,
              maxLines: 4,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: 'Reply',
                hintText: widget.canReply ? 'Keep the message factual and transport-related.' : 'Only Transport Control may reply.',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        FilledButton.icon(
          onPressed: !widget.canReply
              ? null
              : () {
                  final text = _controller.text.trim();
                  if (text.isEmpty) return;
                  Navigator.of(context).pop(text);
                },
          icon: const Icon(Icons.send_outlined),
          label: const Text('Queue reply'),
        ),
      ],
    );
  }
}
