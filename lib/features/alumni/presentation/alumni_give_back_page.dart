import 'package:flutter/material.dart';

import '../data/alumni_give_back_repository.dart';
import '../domain/alumni_pledge_models.dart';

class AlumniGiveBackPage extends StatefulWidget {
  const AlumniGiveBackPage({super.key, required this.repository});

  final AlumniGiveBackRepository repository;

  @override
  State<AlumniGiveBackPage> createState() => _AlumniGiveBackPageState();
}

class _AlumniGiveBackPageState extends State<AlumniGiveBackPage> {
  List<AlumniPledge>? _pledges;
  bool _loading = true;
  String? _error;
  final _descriptionController = TextEditingController();
  AlumniPledgeCategory _category = AlumniPledgeCategory.volunteering;
  bool _submitting = false;
  final _withdrawing = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!widget.repository.hasServer) {
      setState(() {
        _loading = false;
        _pledges = null;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pledges = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _pledges = pledges;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.repository.create(category: _category, description: _descriptionController.text);
      if (!mounted) return;
      _descriptionController.clear();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pledge sent to the school.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _withdraw(AlumniPledge pledge) async {
    if (!_withdrawing.add(pledge.id)) return;
    setState(() {});
    try {
      await widget.repository.withdraw(pledge.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      _withdrawing.remove(pledge.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.repository.hasServer) {
      return const _BackendRequiredCard();
    }
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null) {
      return _GiveBackError(message: _error!, onRetry: _load);
    }

    final pledges = _pledges ?? const [];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Give Back',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        const Text('Offer your time, expertise or materials to the school - no money involved.'),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Make a pledge', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 10),
                DropdownButtonFormField<AlumniPledgeCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'What can you offer?', border: OutlineInputBorder()),
                  items: [
                    for (final item in AlumniPledgeCategory.values)
                      DropdownMenuItem(value: item, child: Text(item.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Describe what you can offer',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: const Icon(Icons.volunteer_activism_outlined),
                  label: Text(_submitting ? 'Sending...' : 'Send pledge'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text('Your pledges', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 10),
        if (pledges.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('You have not made a pledge yet.'),
            ),
          )
        else
          for (final pledge in pledges) ...[
            _PledgeCard(
              pledge: pledge,
              busy: _withdrawing.contains(pledge.id),
              onWithdraw: pledge.canWithdraw ? () => _withdraw(pledge) : null,
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _PledgeCard extends StatelessWidget {
  const _PledgeCard({required this.pledge, required this.busy, required this.onWithdraw});

  final AlumniPledge pledge;
  final bool busy;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(pledge.category.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                Chip(label: Text(pledge.status.label)),
              ],
            ),
            const SizedBox(height: 6),
            Text(pledge.description),
            if (pledge.schoolNote.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('School: ${pledge.schoolNote}', style: Theme.of(context).textTheme.bodySmall),
            ],
            if (onWithdraw != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: busy ? null : onWithdraw,
                  child: const Text('Withdraw'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BackendRequiredCard extends StatelessWidget {
  const _BackendRequiredCard();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Text('Connect to your school to make a Give Back pledge.'),
            ),
          ),
        ),
      );
}

class _GiveBackError extends StatelessWidget {
  const _GiveBackError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
