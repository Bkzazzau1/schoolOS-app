import 'package:flutter/material.dart';

import '../../../core/sync/sync_mutation.dart';
import '../data/job_assignment_repository.dart';

class OwnerJobsPage extends StatefulWidget {
  const OwnerJobsPage({
    super.key,
    required this.repository,
    required this.onChanged,
  });
  final JobAssignmentRepository repository;
  final VoidCallback onChanged;

  @override
  State<OwnerJobsPage> createState() => _OwnerJobsPageState();
}

class _OwnerJobsPageState extends State<OwnerJobsPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _title = TextEditingController();
  final _duties = <String>{};
  List<LocalRecord> _jobs = [];
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final jobs = await widget.repository.load();
      if (mounted) {
        setState(() {
          _jobs = jobs;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.assign(
        name: _name.text,
        email: _email.text,
        title: _title.text,
        duties: _duties,
      );
      if (!mounted) return;
      widget.onChanged();
      _name.clear();
      _email.clear();
      _title.clear();
      _duties.clear();
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _busy = false;
        });
      }
    }
  }

  Future<void> _revoke(LocalRecord job) async {
    setState(() => _busy = true);
    try {
      await widget.repository.revoke(job.entityId);
      if (!mounted) return;
      widget.onChanged();
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Jobs & Delegation',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'The owner retains school-wide authority over finance, administration and operations. Assign responsibilities to any person, including someone who has not registered.',
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Assignments are saved on this device and queued for sync. Invitation delivery and account activation are not connected yet. Saving here does not send an email or grant account access.',
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          enabled: !_busy,
          decoration: const InputDecoration(labelText: 'Person’s full name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email address'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          enabled: !_busy,
          decoration: const InputDecoration(
            labelText: 'Job title',
            hintText:
                'For example: Bursar, Admissions Officer, Transport Coordinator',
          ),
        ),
        const SizedBox(height: 16),
        Text('Assigned duties', style: Theme.of(context).textTheme.titleMedium),
        Wrap(
          spacing: 8,
          children: [
            for (final group in {
              'finance.': 'All finance duties',
              'administration.': 'All administration duties',
            }.entries)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _duties.addAll(
                          assignableDuties.keys.where(
                            (key) => key.startsWith(group.key),
                          ),
                        );
                      }),
                child: Text(group.value),
              ),
            TextButton(
              onPressed: _busy ? null : () => setState(_duties.clear),
              child: const Text('Clear duties'),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final duty in assignableDuties.entries)
              FilterChip(
                label: Text(duty.value),
                selected: _duties.contains(duty.key),
                onSelected: _busy
                    ? null
                    : (selected) => setState(() {
                        if (selected) {
                          _duties.add(duty.key);
                        } else {
                          _duties.remove(duty.key);
                        }
                      }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Save assignment'),
        ),
        if (_busy) const LinearProgressIndicator(),
        const SizedBox(height: 24),
        Text(
          'School assignments',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (!_busy && _jobs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No jobs assigned yet.'),
          ),
        for (final job in _jobs)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${job.payload['name']} — ${job.payload['title']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('${job.payload['email']}'),
                  Text(
                    ((job.payload['duties'] as List).cast<String>())
                        .map((key) => assignableDuties[key] ?? key)
                        .join(', '),
                  ),
                  Text(
                    job.payload['status'] == 'revoked'
                        ? 'Revoked locally · pending sync'
                        : 'Pending account activation',
                  ),
                  if (job.payload['status'] != 'revoked')
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _name.text = job.payload['name']! as String;
                                  _email.text = job.payload['email']! as String;
                                  _title.text = job.payload['title']! as String;
                                  _duties
                                    ..clear()
                                    ..addAll(
                                      (job.payload['duties'] as List)
                                          .cast<String>(),
                                    );
                                }),
                          child: const Text('Edit duties'),
                        ),
                        TextButton(
                          onPressed: _busy ? null : () => _revoke(job),
                          child: const Text('Revoke assignment'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
