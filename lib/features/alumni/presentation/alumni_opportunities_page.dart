import 'package:flutter/material.dart';

import '../data/alumni_opportunities_repository.dart';
import '../domain/alumni_opportunity_models.dart';

class AlumniOpportunitiesPage extends StatefulWidget {
  const AlumniOpportunitiesPage({super.key, required this.repository, required this.membershipId});

  final AlumniOpportunitiesRepository repository;
  final String membershipId;

  @override
  State<AlumniOpportunitiesPage> createState() => _AlumniOpportunitiesPageState();
}

class _AlumniOpportunitiesPageState extends State<AlumniOpportunitiesPage> {
  List<AlumniOpportunity>? _opportunities;
  bool _loading = true;
  String? _error;
  final _closing = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!widget.repository.hasServer) {
      setState(() {
        _loading = false;
        _opportunities = null;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final opportunities = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _opportunities = opportunities;
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

  Future<void> _openPostDialog() async {
    final titleController = TextEditingController();
    final organisationController = TextEditingController();
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();
    final contactController = TextEditingController();
    var type = AlumniOpportunityType.fullTime;

    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Post an opportunity'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: organisationController,
                    decoration: const InputDecoration(labelText: 'Organisation'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AlumniOpportunityType>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: [
                      for (final item in AlumniOpportunityType.values)
                        DropdownMenuItem(value: item, child: Text(item.label)),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => type = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'Location (optional)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contactController,
                    decoration: const InputDecoration(labelText: 'Contact (email/phone/link)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty ||
                    organisationController.text.trim().isEmpty ||
                    descriptionController.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );

    if (submit != true) {
      titleController.dispose();
      organisationController.dispose();
      locationController.dispose();
      descriptionController.dispose();
      contactController.dispose();
      return;
    }

    try {
      await widget.repository.post(
        title: titleController.text,
        organisation: organisationController.text,
        type: type,
        locationText: locationController.text,
        description: descriptionController.text,
        contactInfo: contactController.text,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opportunity posted.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      titleController.dispose();
      organisationController.dispose();
      locationController.dispose();
      descriptionController.dispose();
      contactController.dispose();
    }
  }

  Future<void> _close(AlumniOpportunity opportunity) async {
    if (!_closing.add(opportunity.id)) return;
    setState(() {});
    try {
      await widget.repository.close(opportunity.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      _closing.remove(opportunity.id);
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
      return _OpportunitiesError(message: _error!, onRetry: _load);
    }

    final opportunities = _opportunities ?? const [];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jobs & Opportunities',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  const Text('Real openings alumni have shared with each other.'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _openPostDialog,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Post'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (opportunities.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('No alumnus has posted an opportunity yet.'),
            ),
          )
        else
          for (final opportunity in opportunities) ...[
            _OpportunityCard(
              opportunity: opportunity,
              busy: _closing.contains(opportunity.id),
              onClose: opportunity.status == AlumniOpportunityStatus.open &&
                      opportunity.postedByMembershipId == widget.membershipId
                  ? () => _close(opportunity)
                  : null,
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({required this.opportunity, required this.busy, required this.onClose});

  final AlumniOpportunity opportunity;
  final bool busy;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(opportunity.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                      Text('${opportunity.organisation} · ${opportunity.type.label}'),
                    ],
                  ),
                ),
                Chip(label: Text(opportunity.status.label)),
              ],
            ),
            if (opportunity.locationText.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(opportunity.locationText, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Text(opportunity.description),
            if (opportunity.contactInfo.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Contact: ${opportunity.contactInfo}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 6),
            Text('Posted by ${opportunity.postedByName}', style: Theme.of(context).textTheme.bodySmall),
            if (onClose != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: busy ? null : onClose,
                  child: const Text('Close'),
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
              child: Text('Connect to your school to see Jobs & Opportunities.'),
            ),
          ),
        ),
      );
}

class _OpportunitiesError extends StatelessWidget {
  const _OpportunitiesError({required this.message, required this.onRetry});

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
