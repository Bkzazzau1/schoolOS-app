import 'package:flutter/material.dart';

import '../data/alumni_mentorship_repository.dart';
import '../domain/alumni_mentorship_models.dart';

class AlumniMentorshipPage extends StatefulWidget {
  const AlumniMentorshipPage({super.key, required this.repository});

  final AlumniMentorshipRepository repository;

  @override
  State<AlumniMentorshipPage> createState() => _AlumniMentorshipPageState();
}

class _AlumniMentorshipPageState extends State<AlumniMentorshipPage> {
  AlumniMentorshipSnapshot? _snapshot;
  bool _loading = true;
  String? _error;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!widget.repository.hasServer) {
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
      final snapshot = await widget.repository.load();
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

  Future<void> _openMentorProfileDialog() async {
    final profile = _snapshot?.myMentorProfile;
    final expertiseController = TextEditingController(text: profile?.expertise ?? '');
    final bioController = TextEditingController(text: profile?.bio ?? '');
    var isActive = profile?.isActive ?? true;

    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Your mentor profile'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: expertiseController,
                    decoration: const InputDecoration(labelText: 'What can you mentor on?'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bioController,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: 'Bio'),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Visible to other alumni as a mentor'),
                    value: isActive,
                    onChanged: (value) => setDialogState(() => isActive = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (expertiseController.text.trim().isEmpty || bioController.text.trim().isEmpty) return;
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (submit != true) {
      expertiseController.dispose();
      bioController.dispose();
      return;
    }

    try {
      await widget.repository.saveMyMentorProfile(
        expertise: expertiseController.text,
        bio: bioController.text,
        isActive: isActive,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mentor profile saved.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      expertiseController.dispose();
      bioController.dispose();
    }
  }

  Future<void> _requestMentor(AlumniMentorProfile mentor) async {
    final controller = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Request ${mentor.name} as a mentor'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'A short message (optional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Send request')),
        ],
      ),
    );
    if (submit != true) {
      controller.dispose();
      return;
    }
    if (!_busy.add('request-${mentor.membershipId}')) {
      controller.dispose();
      return;
    }
    setState(() {});
    try {
      await widget.repository.requestMentor(mentorMembershipId: mentor.membershipId, message: controller.text);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      controller.dispose();
      _busy.remove('request-${mentor.membershipId}');
      if (mounted) setState(() {});
    }
  }

  Future<void> _respond(AlumniMentorshipRequest request, bool accept) async {
    if (!_busy.add(request.id)) return;
    setState(() {});
    try {
      await widget.repository.respond(request.id, accept: accept);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      _busy.remove(request.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _withdraw(AlumniMentorshipRequest request) async {
    if (!_busy.add(request.id)) return;
    setState(() {});
    try {
      await widget.repository.withdraw(request.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      _busy.remove(request.id);
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
      return _MentorshipError(message: _error!, onRetry: _load);
    }

    final snapshot = _snapshot!;
    final myProfile = snapshot.myMentorProfile;
    final otherMentors = snapshot.mentors.where((m) => m.membershipId != snapshot.membershipId).toList();

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
                    'Mentorship',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  const Text('Alumni mentoring alumni - find a mentor, or offer to be one.'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _openMentorProfileDialog,
              icon: Icon(myProfile == null ? Icons.add_circle_outline : Icons.edit_outlined),
              label: Text(myProfile == null ? 'Become a mentor' : 'Edit mentor profile'),
            ),
          ],
        ),
        if (myProfile != null) ...[
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('You mentor on: ${myProfile.expertise}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(myProfile.bio, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Chip(label: Text(myProfile.isActive ? 'Visible' : 'Paused')),
                ],
              ),
            ),
          ),
        ],
        if (snapshot.requestsAsMentor.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('Requests to mentor you\'ve received', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 10),
          for (final request in snapshot.requestsAsMentor) ...[
            _RequestCard(
              request: request,
              viewAsMentor: true,
              busy: _busy.contains(request.id),
              onAccept: request.status == AlumniMentorshipRequestStatus.pending
                  ? () => _respond(request, true)
                  : null,
              onDecline: request.status == AlumniMentorshipRequestStatus.pending
                  ? () => _respond(request, false)
                  : null,
              onWithdraw: null,
            ),
            const SizedBox(height: 8),
          ],
        ],
        if (snapshot.requestsAsMentee.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('Your own requests', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 10),
          for (final request in snapshot.requestsAsMentee) ...[
            _RequestCard(
              request: request,
              viewAsMentor: false,
              busy: _busy.contains(request.id),
              onAccept: null,
              onDecline: null,
              onWithdraw: request.status == AlumniMentorshipRequestStatus.pending
                  ? () => _withdraw(request)
                  : null,
            ),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 24),
        const Text('Mentor directory', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 10),
        if (otherMentors.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('No alumnus has opted in as a mentor yet.'),
            ),
          )
        else
          for (final mentor in otherMentors) ...[
            _MentorCard(
              mentor: mentor,
              busy: _busy.contains('request-${mentor.membershipId}'),
              onRequest: () => _requestMentor(mentor),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _MentorCard extends StatelessWidget {
  const _MentorCard({required this.mentor, required this.busy, required this.onRequest});

  final AlumniMentorProfile mentor;
  final bool busy;
  final VoidCallback onRequest;

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
                  Text(mentor.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(mentor.expertise, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(mentor.bio),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(onPressed: busy ? null : onRequest, child: const Text('Request')),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.viewAsMentor,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onWithdraw,
  });

  final AlumniMentorshipRequest request;
  final bool viewAsMentor;
  final bool busy;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final counterpart = viewAsMentor ? request.menteeName : request.mentorName;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(counterpart, style: const TextStyle(fontWeight: FontWeight.w800))),
                Chip(label: Text(request.status.label)),
              ],
            ),
            if (request.message.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(request.message),
            ],
            if (request.status == AlumniMentorshipRequestStatus.accepted) ...[
              const SizedBox(height: 8),
              Text(
                'Contact: ${viewAsMentor ? request.menteeEmail : request.mentorEmail}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            if (onAccept != null || onDecline != null || onWithdraw != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onAccept != null)
                    FilledButton(onPressed: busy ? null : onAccept, child: const Text('Accept')),
                  if (onDecline != null)
                    OutlinedButton(onPressed: busy ? null : onDecline, child: const Text('Decline')),
                  if (onWithdraw != null)
                    OutlinedButton(onPressed: busy ? null : onWithdraw, child: const Text('Withdraw')),
                ],
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
              child: Text('Connect to your school to see Alumni Mentorship.'),
            ),
          ),
        ),
      );
}

class _MentorshipError extends StatelessWidget {
  const _MentorshipError({required this.message, required this.onRetry});

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
