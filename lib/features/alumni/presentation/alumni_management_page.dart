import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../data/alumni_server_api.dart';
import '../domain/alumni_event_models.dart';
import '../domain/alumni_opportunity_models.dart';
import '../domain/alumni_pledge_models.dart';
import '../domain/alumni_profile_models.dart';

class AlumniManagementPage extends StatefulWidget {
  const AlumniManagementPage({
    super.key,
    required this.manager,
    required this.api,
  });

  final SchoolMembership manager;
  final AlumniServerApi? api;

  @override
  State<AlumniManagementPage> createState() => _AlumniManagementPageState();
}

class _AlumniManagementPageState extends State<AlumniManagementPage> {
  AlumniManagementSnapshot? _snapshot;
  bool _loading = true;
  String? _error;
  String _status = 'all';
  List<AlumniEvent>? _events;
  bool _eventsLoading = true;
  final _pledgeBusy = <String>{};
  final _opportunityBusy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
    _loadEvents();
  }

  Future<void> _load() async {
    final api = widget.api;
    if (api == null) {
      setState(() {
        _loading = false;
        _snapshot = null;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await api.loadManagement(
        widget.manager,
        status: _status,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
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

  Future<void> _loadEvents() async {
    final api = widget.api;
    if (api == null) {
      setState(() {
        _eventsLoading = false;
        _events = null;
      });
      return;
    }
    setState(() => _eventsLoading = true);
    try {
      final events = await api.loadEvents(widget.manager);
      if (!mounted) return;
      setState(() {
        _events = events;
        _eventsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _eventsLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _addEvent() async {
    final api = widget.api;
    if (api == null) return;

    final title = TextEditingController();
    final date = TextEditingController();
    final time = TextEditingController();
    final venue = TextEditingController();
    final note = TextEditingController();

    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Schedule a reunion or event'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 12),
                TextField(
                  controller: date,
                  decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
                ),
                const SizedBox(height: 12),
                TextField(controller: time, decoration: const InputDecoration(labelText: 'Time (optional)')),
                const SizedBox(height: 12),
                TextField(controller: venue, decoration: const InputDecoration(labelText: 'Venue (optional)')),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Note (optional)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty || date.text.trim().isEmpty) return;
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Schedule'),
          ),
        ],
      ),
    );

    if (submit != true) {
      title.dispose();
      date.dispose();
      time.dispose();
      venue.dispose();
      note.dispose();
      return;
    }

    try {
      await api.createEvent(
        widget.manager,
        title: title.text,
        date: date.text,
        timeText: time.text,
        venue: venue.text,
        note: note.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${title.text.trim()} scheduled.')),
      );
      await _loadEvents();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      title.dispose();
      date.dispose();
      time.dispose();
      venue.dispose();
      note.dispose();
    }
  }

  Future<String?> _noteDialog({
    required String title,
    required String actionLabel,
    required bool noteRequired,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: noteRequired ? 'Reason / correction note' : 'Review note (optional)',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final note = controller.text.trim();
              if (noteRequired && note.isEmpty) return;
              Navigator.of(dialogContext).pop(note);
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _verify(AlumniProfileRecord profile) async {
    final api = widget.api;
    if (api == null) return;
    final note = await _noteDialog(
      title: 'Verify ${profile.name}',
      actionLabel: 'Verify Alumni',
      noteRequired: false,
    );
    if (note == null) return;
    try {
      await api.verify(widget.manager, profile.membershipId, note: note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${profile.name} verified as Alumni.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _reject(AlumniProfileRecord profile) async {
    final api = widget.api;
    if (api == null) return;
    final note = await _noteDialog(
      title: 'Request correction from ${profile.name}',
      actionLabel: 'Send correction',
      noteRequired: true,
    );
    if (note == null || note.isEmpty) return;
    try {
      await api.reject(widget.manager, profile.membershipId, note: note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${profile.name} was returned for correction.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _updatePledgeStatus(AlumniPledge pledge, AlumniPledgeStatus status) async {
    final api = widget.api;
    if (api == null || !_pledgeBusy.add(pledge.id)) return;
    setState(() {});
    try {
      await api.updatePledgeStatus(widget.manager, pledge.id, status: status);
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      _pledgeBusy.remove(pledge.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _closeOpportunity(AlumniOpportunity opportunity) async {
    final api = widget.api;
    if (api == null || !_opportunityBusy.add(opportunity.id)) return;
    setState(() {});
    try {
      await api.closeOpportunity(widget.manager, opportunity.id);
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      _opportunityBusy.remove(opportunity.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _transitionStudent() async {
    final api = widget.api;
    final candidates = _snapshot?.transitionCandidates ?? const [];
    if (api == null || candidates.isEmpty) return;

    var selected = candidates.first;
    final reference = TextEditingController();
    final admission = TextEditingController();
    final year = TextEditingController(text: '${DateTime.now().year}');
    final graduationSet = TextEditingController();

    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Alumni identity'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<AlumniTransitionCandidate>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Student account'),
                    items: [
                      for (final candidate in candidates)
                        DropdownMenuItem(
                          value: candidate,
                          child: Text('${candidate.name} · ${candidate.email}'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => selected = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: admission,
                    decoration: const InputDecoration(labelText: 'Admission number'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reference,
                    decoration: const InputDecoration(labelText: 'Former student reference'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: year,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Graduation year'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: graduationSet,
                    decoration: const InputDecoration(labelText: 'Graduation set / class'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This creates a separate Alumni membership. The Student membership and historical student record are not overwritten.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsedYear = int.tryParse(year.text.trim());
                if (parsedYear == null) return;
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Create identity'),
            ),
          ],
        ),
      ),
    );

    if (submit != true) {
      reference.dispose();
      admission.dispose();
      year.dispose();
      graduationSet.dispose();
      return;
    }

    try {
      await api.transitionStudent(
        widget.manager,
        studentMembershipId: selected.membershipId,
        originalStudentReference: reference.text,
        admissionNumber: admission.text,
        graduationYear: int.parse(year.text.trim()),
        graduationSet: graduationSet.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alumni identity created for ${selected.name}.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      reference.dispose();
      admission.dispose();
      year.dispose();
      graduationSet.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.api == null) {
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
      return _ManagementError(message: _error!, onRetry: _load);
    }

    final snapshot = _snapshot ??
        const AlumniManagementSnapshot(
          profiles: [],
          transitionCandidates: [],
        );
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
                    'Alumni Management',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Create Alumni identities from existing Student accounts, review former-student evidence and make verification decisions on the server.',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: snapshot.transitionCandidates.isEmpty
                  ? null
                  : _transitionStudent,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Transition student'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Metric(label: 'Pending', value: snapshot.pendingCount),
            _Metric(label: 'Verified', value: snapshot.verifiedCount),
            _Metric(label: 'Needs correction', value: snapshot.correctionCount),
            _Metric(
              label: 'Eligible student accounts',
              value: snapshot.transitionCandidates.length,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Reunions & Events',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
            FilledButton.icon(
              onPressed: _addEvent,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add event'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_eventsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if ((_events ?? const []).isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('No reunion or event has been scheduled yet.'),
            ),
          )
        else
          for (final event in _events!) ...[
            _EventSummaryCard(event: event),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 24),
        const Text(
          'Give Back pledges',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 10),
        if (snapshot.pledges.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('No alumnus has made a pledge yet.'),
            ),
          )
        else
          for (final pledge in snapshot.pledges) ...[
            _PledgeReviewCard(
              pledge: pledge,
              busy: _pledgeBusy.contains(pledge.id),
              onAcknowledge: () => _updatePledgeStatus(pledge, AlumniPledgeStatus.acknowledged),
              onFulfil: () => _updatePledgeStatus(pledge, AlumniPledgeStatus.fulfilled),
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 24),
        const Text(
          'Jobs & Opportunities',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 10),
        if (snapshot.opportunities.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('No alumnus has posted an opportunity yet.'),
            ),
          )
        else
          for (final opportunity in snapshot.opportunities) ...[
            _OpportunitySummaryCard(
              opportunity: opportunity,
              busy: _opportunityBusy.contains(opportunity.id),
              onClose: opportunity.status == AlumniOpportunityStatus.open
                  ? () => _closeOpportunity(opportunity)
                  : null,
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 18),
        Row(
          children: [
            const Text(
              'Profiles',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const Spacer(),
            DropdownButton<String>(
              value: _status,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All statuses')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'verified', child: Text('Verified')),
                DropdownMenuItem(value: 'rejected', child: Text('Needs correction')),
              ],
              onChanged: (value) {
                if (value == null || value == _status) return;
                setState(() => _status = value);
                _load();
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (snapshot.profiles.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Text('No Alumni profiles match this filter.'),
            ),
          )
        else
          for (final profile in snapshot.profiles) ...[
            _ProfileReviewCard(
              profile: profile,
              onVerify: () => _verify(profile),
              onReject: () => _reject(profile),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _OpportunitySummaryCard extends StatelessWidget {
  const _OpportunitySummaryCard({required this.opportunity, required this.busy, required this.onClose});

  final AlumniOpportunity opportunity;
  final bool busy;
  final VoidCallback? onClose;

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(opportunity.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                        '${opportunity.organisation} · ${opportunity.type.label}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text('Posted by ${opportunity.postedByName}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Chip(label: Text(opportunity.status.label)),
              ],
            ),
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

class _PledgeReviewCard extends StatelessWidget {
  const _PledgeReviewCard({
    required this.pledge,
    required this.busy,
    required this.onAcknowledge,
    required this.onFulfil,
  });

  final AlumniPledge pledge;
  final bool busy;
  final VoidCallback onAcknowledge;
  final VoidCallback onFulfil;

  @override
  Widget build(BuildContext context) {
    final actionable = pledge.status == AlumniPledgeStatus.offered ||
        pledge.status == AlumniPledgeStatus.acknowledged;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pledge.alumniName, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(pledge.category.label, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Chip(label: Text(pledge.status.label)),
              ],
            ),
            const SizedBox(height: 6),
            Text(pledge.description),
            if (actionable) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (pledge.status == AlumniPledgeStatus.offered)
                    OutlinedButton(
                      onPressed: busy ? null : onAcknowledge,
                      child: const Text('Acknowledge'),
                    ),
                  FilledButton(
                    onPressed: busy ? null : onFulfil,
                    child: const Text('Mark fulfilled'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EventSummaryCard extends StatelessWidget {
  const _EventSummaryCard({required this.event});

  final AlumniEvent event;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(
                    event.timeText.isEmpty ? event.date : '${event.date} · ${event.timeText}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (event.venue.trim().isNotEmpty)
                    Text(event.venue, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Chip(label: Text('${event.attendingCount} attending')),
          ],
        ),
      ),
    );
  }
}

class _ProfileReviewCard extends StatelessWidget {
  const _ProfileReviewCard({
    required this.profile,
    required this.onVerify,
    required this.onReject,
  });

  final AlumniProfileRecord profile;
  final VoidCallback onVerify;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final status = profile.verificationState;
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
                      Text(
                        profile.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      Text(profile.email),
                    ],
                  ),
                ),
                Chip(label: Text(status.label)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _Fact('Admission no.', profile.admissionNumber.isEmpty ? '—' : profile.admissionNumber),
                _Fact('Student ref.', profile.originalStudentReference.isEmpty ? '—' : profile.originalStudentReference),
                _Fact('Graduation', profile.graduationYear?.toString() ?? '—'),
                _Fact('Set', profile.graduationSet.isEmpty ? '—' : profile.graduationSet),
                _Fact('Profession', profile.profession.isEmpty ? '—' : profile.profession),
              ],
            ),
            if (profile.verificationNote.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Last review note: ${profile.verificationNote}'),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Request correction'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: profile.hasIdentityEvidence ? onVerify : null,
                  icon: const Icon(Icons.verified_outlined),
                  label: Text(
                    status == AlumniVerificationState.verified
                        ? 'Re-verify'
                        : 'Verify',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
        width: 185,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              '$value',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
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
              child: Text(
                'Connect to your school to verify alumni.',
              ),
            ),
          ),
        ),
      );
}

class _ManagementError extends StatelessWidget {
  const _ManagementError({required this.message, required this.onRetry});

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
