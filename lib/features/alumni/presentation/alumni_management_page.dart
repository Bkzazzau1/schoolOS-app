import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../data/alumni_server_api.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
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
                    value: selected,
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
                'Alumni verification is server-authoritative and is unavailable in demo-only mode.',
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
