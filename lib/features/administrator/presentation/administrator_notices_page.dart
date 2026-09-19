import 'package:flutter/material.dart';

import '../data/administrator_notices_demo_data.dart';
import '../data/administrator_notices_repository.dart';
import '../domain/administrator_notices_models.dart';

class AdministratorNoticesPage extends StatefulWidget {
  const AdministratorNoticesPage({
    super.key,
    required this.schoolName,
    required this.repository,
    this.onNoticesChanged,
  });

  final String schoolName;
  final AdministratorNoticesRepository repository;
  final VoidCallback? onNoticesChanged;

  @override
  State<AdministratorNoticesPage> createState() =>
      _AdministratorNoticesPageState();
}

class _AdministratorNoticesPageState extends State<AdministratorNoticesPage> {
  final _messageController = TextEditingController();
  AdministratorNoticeAudience _audience = AdministratorNoticeAudience.parents;
  AdministratorNoticeType _type =
      AdministratorNoticeType.generalAdministration;
  AdministratorNoticesSnapshot? _snapshot;
  String? _error;
  String? _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
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
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _status = null;
    });
    final result = await widget.repository.saveDraft(
      audience: _audience,
      type: _type,
      message: _messageController.text,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _status = result.message;
    });
    if (result.success) {
      _messageController.clear();
      widget.onNoticesChanged?.call();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot;
    if (snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        return ListView(
          padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 22, wide ? 28 : 16, 32),
          children: [
            Text(
              'ADMINISTRATION · COMMUNICATION',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Administrative Notices',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Prepare operational notices for approved audiences while keeping official emergency and leadership communications governed.',
            ),
            const SizedBox(height: 20),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildComposer(snapshot)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildRecent(snapshot.notices)),
                ],
              )
            else ...[
              _buildComposer(snapshot),
              const SizedBox(height: 16),
              _buildRecent(snapshot.notices),
            ],
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.gavel_outlined),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(administratorNoticesAuthorityBoundary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildComposer(AdministratorNoticesSnapshot snapshot) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create notice',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AdministratorNoticeAudience>(
              initialValue: _audience,
              decoration: const InputDecoration(labelText: 'Audience'),
              items: [
                for (final value in administratorNoticeAudienceOptions)
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              onChanged: snapshot.permissions.canCreateDrafts
                  ? (value) {
                      if (value != null) setState(() => _audience = value);
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AdministratorNoticeType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final value in administratorNoticeTypeOptions)
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              onChanged: snapshot.permissions.canCreateDrafts
                  ? (value) {
                      if (value != null) setState(() => _type = value);
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              enabled: snapshot.permissions.canCreateDrafts,
              minLines: 5,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Write notice...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: snapshot.permissions.canCreateDrafts && !_saving
                  ? _save
                  : null,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save notice'),
            ),
            const SizedBox(height: 10),
            const Text(
              administratorNoticesDraftBoundary,
              style: TextStyle(fontSize: 12),
            ),
            if (_status != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_status!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecent(List<AdministratorNotice> notices) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent notices',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            for (final notice in notices) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notice.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(notice.audience.label),
                          if (notice.message.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              notice.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Chip(label: Text(notice.status.label)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
