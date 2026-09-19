import 'package:flutter/material.dart';

import '../data/noticeboard_demo_data.dart';
import '../data/noticeboard_repository.dart';
import '../domain/noticeboard_models.dart';

class NoticeboardPage extends StatefulWidget {
  const NoticeboardPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onBack,
    required this.onNoticeboardChanged,
  });

  final String schoolName;
  final NoticeboardRepository repository;
  final VoidCallback onBack;
  final VoidCallback onNoticeboardChanged;

  @override
  State<NoticeboardPage> createState() => _NoticeboardPageState();
}

class _NoticeboardPageState extends State<NoticeboardPage> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _searchController = TextEditingController();
  NoticeboardSnapshot? _snapshot;
  NoticeAudience _draftAudience = NoticeAudience.wholeSchool;
  NoticePriority _draftPriority = NoticePriority.normal;
  NoticeAudience? _audienceFilter;
  NoticePriority? _priorityFilter;
  bool _ack = false;
  bool _loading = true;
  bool _saving = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final snapshot = await widget.repository.load();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _loading = false;
    });
  }

  List<NoticeboardNotice> get _visible => filterNotices(
        notices: _snapshot?.notices ?? const [],
        query: _searchController.text,
        audience: _audienceFilter,
        priority: _priorityFilter,
      );

  Future<void> _publish() async {
    if (_saving) return;
    setState(() => _saving = true);
    final result = await widget.repository.publish(
      title: _titleController.text,
      body: _bodyController.text,
      audience: _draftAudience,
      priority: _draftPriority,
      acknowledgementRequired: _ack,
    );
    if (result.success) {
      _titleController.clear();
      _bodyController.clear();
      setState(() => _ack = false);
      widget.onNoticeboardChanged();
      await _load();
    }
    if (!mounted) return;
    setState(() {
      _message = result.message;
      _saving = false;
    });
  }

  Future<void> _togglePin(NoticeboardNotice notice) async {
    final result = await widget.repository.togglePin(notice.id);
    if (result.success) {
      widget.onNoticeboardChanged();
      await _load();
    }
    if (!mounted) return;
    setState(() => _message = result.message);
  }

  Future<void> _edit(NoticeboardNotice notice) async {
    final title = TextEditingController(text: notice.title);
    final body = TextEditingController(text: notice.body);
    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${notice.id}'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Notice title')),
              const SizedBox(height: 12),
              TextField(controller: body, minLines: 4, maxLines: 7, decoration: const InputDecoration(labelText: 'Official message')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop([title.text, body.text]), child: const Text('Save')),
        ],
      ),
    );
    title.dispose();
    body.dispose();
    if (values == null) return;
    final result = await widget.repository.edit(id: notice.id, title: values[0], body: values[1]);
    if (result.success) {
      widget.onNoticeboardChanged();
      await _load();
    }
    if (!mounted) return;
    setState(() => _message = result.message);
  }

  void _deliveryReport(NoticeboardNotice notice) {
    final percent = notice.totalRecipients == 0 ? 0 : (notice.readRate * 100).round();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${notice.id} delivery report'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notice.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text('${notice.readCount}/${notice.totalRecipients} recipients have read this notice ($percent%).'),
              const SizedBox(height: 8),
              Text('Audience: ${notice.audience.label}'),
              Text('Priority: ${notice.priority.label}'),
              Text('Acknowledgement required: ${notice.acknowledgementRequired ? 'Yes' : 'No'}'),
              const SizedBox(height: 12),
              const Text('Production delivery will reconcile in-app read state with configured SMS, WhatsApp or email channels.'),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final snapshot = _snapshot!;
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 760;
      final wide = constraints.maxWidth >= 1080;
      return ListView(
        padding: EdgeInsets.fromLTRB(compact ? 16 : 26, 22, compact ? 16 : 26, 48),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1380),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Header(schoolName: widget.schoolName, onBack: widget.onBack, compact: compact),
                const SizedBox(height: 16),
                const _ScopeCard(),
                const SizedBox(height: 16),
                _Stats(notices: snapshot.notices, compact: compact),
                const SizedBox(height: 16),
                if (wide)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 7, child: _mainPanel(snapshot)),
                    const SizedBox(width: 16),
                    const Expanded(flex: 3, child: _Sidebar()),
                  ])
                else ...[
                  _mainPanel(snapshot),
                  const SizedBox(height: 16),
                  const _Sidebar(),
                ],
              ]),
            ),
          ),
        ],
      );
    });
  }

  Widget _mainPanel(NoticeboardSnapshot snapshot) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Notices & announcements', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Official school messages with scope, urgency and delivery status.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          _composer(snapshot.permissions),
          const SizedBox(height: 18),
          _filters(),
          const SizedBox(height: 16),
          if (_visible.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No notices match these filters.')))
          else
            for (final notice in _visible) ...[
              _NoticeCard(
                notice: notice,
                permissions: snapshot.permissions,
                onPin: () => _togglePin(notice),
                onEdit: () => _edit(notice),
                onDelivery: () => _deliveryReport(notice),
              ),
              if (notice != _visible.last) const SizedBox(height: 12),
            ],
        ]),
      ),
    );
  }

  Widget _composer(NoticeboardPermissions permissions) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        TextField(controller: _titleController, enabled: permissions.canPublish, decoration: const InputDecoration(labelText: 'Official notice title')),
        const SizedBox(height: 12),
        TextField(controller: _bodyController, enabled: permissions.canPublish, minLines: 4, maxLines: 7, decoration: const InputDecoration(labelText: 'Write the official announcement')),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(width: 250, child: DropdownButtonFormField<NoticeAudience>(
            initialValue: _draftAudience,
            decoration: const InputDecoration(labelText: 'Audience'),
            items: permissions.allowedAudiences.map((a) => DropdownMenuItem(value: a, child: Text(a.label))).toList(),
            onChanged: permissions.canPublish ? (value) { if (value != null) setState(() => _draftAudience = value); } : null,
          )),
          SizedBox(width: 220, child: DropdownButtonFormField<NoticePriority>(
            initialValue: _draftPriority,
            decoration: const InputDecoration(labelText: 'Priority'),
            items: NoticePriority.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label))).toList(),
            onChanged: permissions.canPublish ? (value) { if (value != null) setState(() => _draftPriority = value); } : null,
          )),
        ]),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Require recipient acknowledgement'),
          subtitle: const Text('Use for critical notices that require explicit confirmation.'),
          value: _ack,
          onChanged: permissions.canPublish ? (value) => setState(() => _ack = value) : null,
        ),
        Row(children: [
          Expanded(child: Text(_message.isEmpty ? 'Official publishing is role- and scope-controlled.' : _message, style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(width: 12),
          FilledButton.icon(onPressed: permissions.canPublish && !_saving ? _publish : null, icon: const Icon(Icons.campaign_outlined), label: Text(_saving ? 'Saving…' : 'Publish notice')),
        ]),
      ]),
    );
  }

  Widget _filters() {
    return Wrap(spacing: 12, runSpacing: 12, children: [
      SizedBox(width: 300, child: TextField(controller: _searchController, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search notices'))),
      SizedBox(width: 220, child: DropdownButtonFormField<NoticeAudience?>(
        initialValue: _audienceFilter,
        decoration: const InputDecoration(labelText: 'Audience'),
        items: [const DropdownMenuItem<NoticeAudience?>(value: null, child: Text('All audiences')), ...NoticeAudience.values.map((a) => DropdownMenuItem<NoticeAudience?>(value: a, child: Text(a.label)))],
        onChanged: (value) => setState(() => _audienceFilter = value),
      )),
      SizedBox(width: 220, child: DropdownButtonFormField<NoticePriority?>(
        initialValue: _priorityFilter,
        decoration: const InputDecoration(labelText: 'Priority'),
        items: [const DropdownMenuItem<NoticePriority?>(value: null, child: Text('All priorities')), ...NoticePriority.values.map((p) => DropdownMenuItem<NoticePriority?>(value: p, child: Text(p.label)))],
        onChanged: (value) => setState(() => _priorityFilter = value),
      )),
    ]);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.schoolName, required this.onBack, required this.compact});
  final String schoolName;
  final VoidCallback onBack;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('SCHOOL LIFE · ${schoolName.toUpperCase()}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text('Official Noticeboard', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text('Authoritative school communication with audience, urgency and delivery controls.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
    if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 12), OutlinedButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back), label: const Text('School Life'))]);
    return Row(children: [Expanded(child: title), OutlinedButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back), label: const Text('School Life'))]);
  }
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .45), borderRadius: BorderRadius.circular(18)),
    child: const Text('Only authorized leadership roles can publish. Notices can be school-wide or scoped to a section, class, staff group or guardians, with urgency, expiry and acknowledgement controls.'),
  );
}

class _Stats extends StatelessWidget {
  const _Stats({required this.notices, required this.compact});
  final List<NoticeboardNotice> notices;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final stats = [
      ('Active notices','${notices.length}','Across current audiences'),
      ('Pinned','${notices.where((n) => n.pinned).length}','High-visibility notices'),
      ('Need acknowledgement','${notices.where((n) => n.acknowledgementRequired).length}','Critical read confirmation'),
      ('Average read rate','$noticeboardAverageReadRate%','Prototype audience delivery'),
      ('Scheduled','$noticeboardScheduledCount','Future publication queue'),
    ];
    return Wrap(spacing: 10, runSpacing: 10, children: [
      for (final stat in stats) SizedBox(
        width: compact ? double.infinity : 210,
        child: Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(stat.$1, style: Theme.of(context).textTheme.labelMedium), const SizedBox(height: 6), Text(stat.$2, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(stat.$3, style: Theme.of(context).textTheme.bodySmall)]))),
      ),
    ]);
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice, required this.permissions, required this.onPin, required this.onEdit, required this.onDelivery});
  final NoticeboardNotice notice;
  final NoticeboardPermissions permissions;
  final VoidCallback onPin;
  final VoidCallback onEdit;
  final VoidCallback onDelivery;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outlineVariant), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          Chip(label: Text(notice.audience.label)),
          Chip(label: Text(notice.role)),
          if (notice.pinned) const Chip(label: Text('PINNED')),
          if (notice.acknowledgementRequired) const Chip(label: Text('ACK REQUIRED')),
          Chip(label: Text(notice.priority.label), backgroundColor: notice.priority == NoticePriority.emergency ? theme.colorScheme.errorContainer : null),
        ]),
        const SizedBox(height: 8),
        Text(notice.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(notice.body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
        const SizedBox(height: 10),
        Wrap(spacing: 14, runSpacing: 6, children: [Text('Published ${notice.publishedLabel}', style: theme.textTheme.bodySmall), Text('Expires ${notice.expiresLabel}', style: theme.textTheme.bodySmall), Text('${notice.readCount}/${notice.totalRecipients} read', style: theme.textTheme.bodySmall)]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          OutlinedButton(onPressed: permissions.canPin ? onPin : null, child: Text(notice.pinned ? 'Unpin' : 'Pin')),
          OutlinedButton(onPressed: permissions.canEdit ? onEdit : null, child: const Text('Edit')),
          OutlinedButton(onPressed: permissions.canViewDeliveryReport ? onDelivery : null, child: const Text('Delivery report')),
        ]),
      ]),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();
  @override
  Widget build(BuildContext context) => Column(children: [
    _PolicyCard(title:'Publishing authority', subtitle:'Recommended school-wide policy.', items: noticeboardPublishingAuthority),
    const SizedBox(height: 12),
    _PolicyCard(title:'Delivery channels', subtitle:'Planned production behavior.', items: noticeboardDeliveryChannels),
    const SizedBox(height: 12),
    Card(elevation:0, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[const Text('Noticeboard ≠ Community feed', style: TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height:6), const Text(noticeboardBoundary)]))),
  ]);
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({required this.title, required this.subtitle, required this.items});
  final String title;
  final String subtitle;
  final List<(String, String)> items;
  @override
  Widget build(BuildContext context) => Card(elevation:0, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    const SizedBox(height:12),
    for (final item in items) ...[Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height:2), Text(item.$2, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height:10)],
  ])));
}
