import 'package:flutter/material.dart';

import '../../../core/sync/sync_scope.dart';

import '../../../core/sync/sync_mutation.dart';
import '../data/job_assignment_repository.dart';
import '../../administrator/domain/administrator_staff_models.dart';
import '../domain/proprietor_structure_models.dart';

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

class _OwnerJobsPageState extends State<OwnerJobsPage> with SyncRefresh<OwnerJobsPage> {
  @override
  void onSynced() => _load();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _title = TextEditingController();
  final _duties = <String>{};
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  List<AdministratorStaffRecord> _people = [];
  List<AcademicSection> _sections = [];
  bool _registered = false;
  String? _personId;
  String? _sectionId;
  String? _editingId;
  String _role = 'custom';
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
      final people = await widget.repository.people();
      final sections = await widget.repository.sections();
      if (mounted) {
        setState(() {
          _jobs = jobs;
          _people = people;
          _sections = sections;
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
    if (!_form.currentState!.validate()) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
    if (_duties.isEmpty) {
      setState(() => _error = 'Select at least one duty.');
      return;
    }
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
        registeredStaffId: _registered ? _personId : null,
        sectionId: _sectionId,
        role: _role,
        assignmentId: _editingId,
      );
      if (!mounted) return;
      widget.onChanged();
      _name.clear();
      _email.clear();
      _title.clear();
      _duties.clear();
      _editingId = null;
      _personId = null;
      _sectionId = null;
      _role = 'custom';
      _form.currentState!.reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Assignment saved. Account access remains pending activation.',
          ),
        ),
      );
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
    _scroll.dispose();
    _name.dispose();
    _email.dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            Text(
              '1. Choose a person',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Registered person'),
                  selected: _registered,
                  onSelected: _busy || _editingId != null
                      ? null
                      : (_) => setState(() {
                          _registered = true;
                          _personId = null;
                          _name.clear();
                          _email.clear();
                        }),
                ),
                ChoiceChip(
                  label: const Text('Unregistered person'),
                  selected: !_registered,
                  onSelected: _busy || _editingId != null
                      ? null
                      : (_) => setState(() {
                          _registered = false;
                          _personId = null;
                          _name.clear();
                          _email.clear();
                        }),
                ),
              ],
            ),
            if (_registered) ...[
              const Text(
                'School staff records, including demo records in demo mode. A staff record does not confirm an activated login account.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('person-$_personId'),
                initialValue: _personId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Select registered person',
                ),
                items: [
                  for (final person in _people)
                    DropdownMenuItem(
                      value: person.id,
                      child: Text(
                        '${person.name} (${person.section})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy || _editingId != null
                    ? null
                    : (id) => setState(() {
                        _personId = id;
                        _name.text = _people.firstWhere((p) => p.id == id).name;
                      }),
                validator: (id) =>
                    id == null ? 'Select a person from the directory.' : null,
              ),
              if (_people.isEmpty)
                const Text(
                  'No staff records available. Add the person through staff registration first or select Unregistered person.',
                ),
            ],
            const SizedBox(height: 12),
            if (!_registered)
              TextFormField(
                controller: _name,
                enabled: !_busy,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the person’s full name.'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Person’s full name',
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              enabled: !_busy,
              validator: (value) =>
                  _registered && (value?.trim().isEmpty ?? true)
                  ? null
                  : RegExp(
                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                    ).hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Enter a valid email address.',
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: _registered
                    ? 'Email address (optional)'
                    : 'Email address',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '2. Role and section',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('role-$_role'),
              initialValue: _role,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Role preset'),
              items: [
                for (final role in jobRolePresets.entries)
                  DropdownMenuItem(value: role.key, child: Text(role.value)),
              ],
              onChanged: _busy
                  ? null
                  : (role) => setState(() {
                      _role = role!;
                      _title.text = role == 'custom'
                          ? ''
                          : jobRolePresets[role]!;
                      _duties
                        ..clear()
                        ..addAll(dutiesForJobRole(role));
                    }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('section-$_sectionId-$_role'),
              initialValue: _sectionId ?? 'school',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Assignment scope'),
              items: [
                const DropdownMenuItem(
                  value: 'school',
                  child: Text('Whole school'),
                ),
                for (final section in _sections)
                  DropdownMenuItem(
                    value: section.id,
                    child: Text(
                      '${section.name} · ${section.campus}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (id) =>
                        setState(() => _sectionId = id == 'school' ? null : id),
              validator: (_) => _role == 'sectionHead' && _sectionId == null
                  ? 'Choose the section this person will head.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              enabled: !_busy,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a job title or choose a role preset.'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Job title',
                hintText:
                    'For example: Bursar, Admissions Officer, Transport Coordinator',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '3. Allowed duties',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Only the selected duties are requested, within the selected scope. A role preset is a starting point; remove or add duties as needed.',
            ),
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
                            _duties.addAll(dutiesInGroup(group.key));
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
              child: Text(
                _editingId == null ? 'Save assignment' : 'Update assignment',
              ),
            ),
            if (_editingId != null)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _editingId = null;
                        _personId = null;
                        _sectionId = null;
                        _role = 'custom';
                        _name.clear();
                        _email.clear();
                        _title.clear();
                        _duties.clear();
                        _error = null;
                        _form.currentState!.reset();
                      }),
                child: const Text('Cancel editing'),
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
                        'Scope: ${job.payload['sectionName'] ?? 'Whole school'}',
                      ),
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
                                      _name.text =
                                          job.payload['name']! as String;
                                      _email.text =
                                          job.payload['email']! as String;
                                      _title.text =
                                          job.payload['title']! as String;
                                      _editingId = job.entityId;
                                      _registered =
                                          job.payload['recipientType'] ==
                                          'registered';
                                      _personId =
                                          job.payload['registeredStaffId']
                                              as String?;
                                      _role =
                                          job.payload['role'] as String? ??
                                          'custom';
                                      _sectionId =
                                          job.payload['sectionId'] as String?;
                                      _duties
                                        ..clear()
                                        ..addAll(
                                          (job.payload['duties'] as List)
                                              .cast<String>(),
                                        );
                                      _scroll.animateTo(
                                        0,
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        curve: Curves.easeOut,
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
        ),
      ),
    );
  }
}
