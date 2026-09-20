import 'package:flutter/material.dart';

import '../data/teacher_messages_demo_data.dart';
import '../data/teacher_messages_repository.dart';
import '../domain/teacher_messages_models.dart';

class TeacherMessagesPage extends StatefulWidget {
  const TeacherMessagesPage({
    super.key,
    required this.repository,
    required this.onNavigate,
    required this.onMutationQueued,
  });

  final TeacherMessagesRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback onMutationQueued;

  @override
  State<TeacherMessagesPage> createState() => _TeacherMessagesPageState();
}

class _TeacherMessagesPageState extends State<TeacherMessagesPage> {
  late Future<TeacherMessagesSnapshot> _future;
  final _searchController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedThreadId = 'thread-1';
  String? _notice;
  bool _noticeSuccess = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final result = await widget.repository.queueMessage(
      threadId: _selectedThreadId,
      body: _messageController.text,
    );
    if (!mounted) return;
    setState(() {
      _notice = result.message;
      _noticeSuccess = result.success;
      if (result.success) {
        _messageController.clear();
        _future = widget.repository.load();
      }
    });
    if (result.success) widget.onMutationQueued();
  }

  void _aiDraft() {
    _messageController.text = teacherMessageAiDraft;
    _messageController.selection = TextSelection.collapsed(
      offset: _messageController.text.length,
    );
    setState(() {
      _notice = 'Teacher AI draft inserted for your review. Nothing has been sent.';
      _noticeSuccess = true;
    });
  }

  void _showNotice(String message, {bool success = true}) {
    setState(() {
      _notice = message;
      _noticeSuccess = success;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TeacherMessagesSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Messages could not be loaded.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => setState(() => _future = widget.repository.load()),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }
          final data = snapshot.data!;
          final filtered = data.threads
              .where((thread) => thread.matches(_searchController.text))
              .toList(growable: false);
          final selected = data.threads.firstWhere(
            (thread) => thread.id == _selectedThreadId,
            orElse: () => data.threads.first,
          );
          final messages = data.messagesForThread(selected.id);
          return LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context),
                  const SizedBox(height: 16),
                  _kpis(),
                  if (_notice != null) ...[
                    const SizedBox(height: 14),
                    _noticeBanner(),
                  ],
                  const SizedBox(height: 16),
                  if (constraints.maxWidth >= 900)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 350,
                          child: _threadPanel(filtered, selected),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: _chatPanel(selected, messages, data.permissions)),
                      ],
                    )
                  else ...[
                    _threadPanel(filtered, selected),
                    const SizedBox(height: 16),
                    _chatPanel(selected, messages, data.permissions),
                  ],
                  const SizedBox(height: 16),
                  _rules(context),
                ],
              ),
            ),
          );
        },
      );

  Widget _header(BuildContext context) => Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TEACHER PORTAL · CONTROLLED COMMUNICATION',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text('Messages', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Communicate with authorized guardians, staff and school leadership without exposing private contact details.'),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(onPressed: () => widget.onNavigate('students'), child: const Text('Students')),
              OutlinedButton(onPressed: () => widget.onNavigate('classes'), child: const Text('My Classes')),
              FilledButton.icon(
                onPressed: () => _showNotice('New-message composer ready. Choose an approved recipient group below.'),
                icon: const Icon(Icons.add_comment_outlined, size: 18),
                label: const Text('New message'),
              ),
            ],
          ),
        ],
      );

  Widget _kpis() => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final item in teacherMessageKpis)
            SizedBox(
              width: 210,
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.label),
                      const SizedBox(height: 4),
                      Text(item.value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                      Text(item.hint, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );

  Widget _noticeBanner() => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(_noticeSuccess ? Icons.check_circle_outline : Icons.info_outline),
              const SizedBox(width: 10),
              Expanded(child: Text(_notice!)),
              IconButton(onPressed: () => setState(() => _notice = null), icon: const Icon(Icons.close)),
            ],
          ),
        ),
      );

  Widget _threadPanel(
    List<TeacherMessageThread> filtered,
    TeacherMessageThread selected,
  ) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Conversations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const Text('Your permitted school communication channels.'),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search conversations...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No approved conversation matches this search.'),
                )
              else
                for (final thread in filtered) ...[
                  _threadTile(thread, selected.id == thread.id),
                  const SizedBox(height: 6),
                ],
            ],
          ),
        ),
      );

  Widget _threadTile(TeacherMessageThread thread, bool active) => Material(
        color: active ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() {
            _selectedThreadId = thread.id;
            _notice = null;
          }),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(child: Text(_initials(thread.name))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(thread.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text(teacherMessageChannelTypeLabel(thread.type), style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 3),
                      Text(thread.preview, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(thread.timeLabel, style: const TextStyle(fontSize: 11)),
                    if (thread.unread > 0) ...[
                      const SizedBox(height: 5),
                      Badge(label: Text('${thread.unread}')),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _chatPanel(
    TeacherMessageThread selected,
    List<TeacherMessage> messages,
    TeacherMessagePermissions permissions,
  ) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(selected.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      Text('${teacherMessageChannelTypeLabel(selected.type)} · Authorized SchoolOS channel'),
                    ],
                  ),
                  OutlinedButton(
                    onPressed: () => _showNotice('Conversation details opened. Personal phone numbers and emails remain hidden.'),
                    child: const Text('Channel details'),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (messages.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: Text('No cached messages in this approved channel yet.')),
                )
              else
                for (final message in messages) ...[
                  Align(
                    alignment: message.isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Card(
                        elevation: 0,
                        color: message.isOutgoing
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerLow,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(message.body),
                              if (message.attachmentName != null) ...[
                                const SizedBox(height: 6),
                                Text('Attachment: ${message.attachmentName}', style: const TextStyle(fontSize: 12)),
                              ],
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(message.timeLabel, style: const TextStyle(fontSize: 11)),
                                  if (message.isOutgoing) ...[
                                    const SizedBox(width: 8),
                                    Text(teacherMessageDeliveryLabel(message.deliveryState), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              const Divider(height: 24),
              TextField(
                controller: _messageController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Write a professional school message...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showNotice('Attachment picker would use tenant-scoped Wasabi storage in production. No file has been attached yet.'),
                    icon: const Icon(Icons.attach_file, size: 18),
                    label: const Text('Attach'),
                  ),
                  OutlinedButton.icon(
                    onPressed: permissions.canUseAiDraft ? _aiDraft : null,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('AI draft'),
                  ),
                  FilledButton.icon(
                    onPressed: permissions.canQueueMessages ? _send : null,
                    icon: const Icon(Icons.send_outlined, size: 18),
                    label: const Text('Send'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(teacherMessageDeliveryBoundary, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );

  Widget _rules(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 430,
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Communication rules', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const Text(teacherMessagePrivacyBoundary),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 430,
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Teacher AI assistance', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const Text(teacherMessageAiBoundary),
                    const SizedBox(height: 8),
                    TextButton(onPressed: () => widget.onNavigate('ai'), child: const Text('Open Teacher AI')),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

  String _initials(String value) {
    final words = value.split(' ').where((word) => word.isNotEmpty).toList();
    return words.take(2).map((word) => word[0]).join().toUpperCase();
  }
}
