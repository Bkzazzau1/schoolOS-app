import 'package:flutter/material.dart';

import '../data/alumni_profile_repository.dart';
import '../domain/alumni_profile_models.dart';

class AlumniProfilePage extends StatefulWidget {
  const AlumniProfilePage({
    super.key,
    required this.repository,
  });

  final AlumniProfileRepository repository;

  @override
  State<AlumniProfilePage> createState() => _AlumniProfilePageState();
}

class _AlumniProfilePageState extends State<AlumniProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _studentReference = TextEditingController();
  final _admissionNumber = TextEditingController();
  final _graduationYear = TextEditingController();
  final _graduationSet = TextEditingController();
  final _profession = TextEditingController();
  final _organisation = TextEditingController();
  final _location = TextEditingController();
  final _bio = TextEditingController();

  AlumniProfileRecord? _profile;
  bool _loading = true;
  bool _saving = false;
  bool _directoryVisible = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _studentReference.dispose();
    _admissionNumber.dispose();
    _graduationYear.dispose();
    _graduationSet.dispose();
    _profession.dispose();
    _organisation.dispose();
    _location.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await widget.repository.load();
      if (!mounted) return;
      _apply(profile);
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  void _apply(AlumniProfileRecord? profile) {
    _profile = profile;
    _studentReference.text = profile?.originalStudentReference ?? '';
    _admissionNumber.text = profile?.admissionNumber ?? '';
    _graduationYear.text = profile?.graduationYear?.toString() ?? '';
    _graduationSet.text = profile?.graduationSet ?? '';
    _profession.text = profile?.profession ?? '';
    _organisation.text = profile?.organisation ?? '';
    _location.text = profile?.locationText ?? '';
    _bio.text = profile?.bio ?? '';
    _directoryVisible = profile?.directoryVisible ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final yearText = _graduationYear.text.trim();
      final saved = await widget.repository.save(
        originalStudentReference: _studentReference.text,
        admissionNumber: _admissionNumber.text,
        graduationYear: yearText.isEmpty ? null : int.parse(yearText),
        graduationSet: _graduationSet.text,
        profession: _profession.text,
        organisation: _organisation.text,
        locationText: _location.text,
        bio: _bio.text,
        directoryVisible: _directoryVisible,
      );
      if (!mounted) return;
      _apply(saved);
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved.isVerified
                ? 'Alumni profile updated.'
                : 'Profile submitted. Verification remains a school decision.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null && _profile == null) {
      return _ErrorCard(message: _error!, onRetry: _load);
    }

    final profile = _profile;
    final verified = profile?.isVerified ?? false;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Alumni Profile',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Your former-student identity is reviewed by the school. Professional details can evolve over time without changing your historical student record.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 18),
          _VerificationCard(profile: profile),
          const SizedBox(height: 18),
          _SectionCard(
            title: 'Former-student identity',
            subtitle:
                'Changing these fields after verification returns the profile to Pending so the school can verify the new evidence.',
            children: [
              _field(
                controller: _admissionNumber,
                label: 'Admission number',
                hint: 'Your former school admission / student number',
              ),
              _field(
                controller: _studentReference,
                label: 'Former student reference',
                hint: 'Any legacy student reference used by the school',
              ),
              _field(
                controller: _graduationYear,
                label: 'Graduation year',
                keyboardType: TextInputType.number,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null;
                  final year = int.tryParse(text);
                  if (year == null || year < 1900 || year > DateTime.now().year + 1) {
                    return 'Enter a valid graduation year.';
                  }
                  return null;
                },
              ),
              _field(
                controller: _graduationSet,
                label: 'Graduation set / class',
                hint: 'Example: Class of 2024',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Current professional profile',
            subtitle:
                'Only information you choose to share later through Alumni Directory will be shown to other alumni.',
            children: [
              _field(controller: _profession, label: 'Profession / role'),
              _field(controller: _organisation, label: 'Organisation'),
              _field(controller: _location, label: 'Location'),
              TextFormField(
                controller: _bio,
                minLines: 3,
                maxLines: 6,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Short bio',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: SwitchListTile.adaptive(
              value: verified && _directoryVisible,
              onChanged: verified
                  ? (value) => setState(() => _directoryVisible = value)
                  : null,
              title: const Text(
                'Appear in Alumni Directory',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                verified
                    ? 'You control whether your verified profile can be discovered in the directory.'
                    : 'Directory visibility becomes available only after school verification.',
              ),
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saving || !widget.repository.hasServer ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving…' : 'Save profile'),
            ),
          ),
          if (!widget.repository.hasServer) ...[
            const SizedBox(height: 8),
            Text(
              'Offline/demo mode: the last downloaded profile can be viewed, but verification-sensitive edits require the SchoolOS server.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
      );
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.profile});

  final AlumniProfileRecord? profile;

  @override
  Widget build(BuildContext context) {
    final state = profile?.verificationState ?? AlumniVerificationState.pending;
    final icon = switch (state) {
      AlumniVerificationState.pending => Icons.hourglass_top_rounded,
      AlumniVerificationState.verified => Icons.verified_rounded,
      AlumniVerificationState.rejected => Icons.edit_note_rounded,
    };
    final message = switch (state) {
      AlumniVerificationState.pending => profile == null
          ? 'Submit your former-student identity for school verification.'
          : 'Your identity is waiting for school review.',
      AlumniVerificationState.verified =>
        'The school has verified this Alumni identity.',
      AlumniVerificationState.rejected =>
        'The school needs corrections before this Alumni identity can be verified.',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.label,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  Text(message),
                  if ((profile?.verificationNote ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'School note: ${profile!.verificationNote}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Alumni profile could not be loaded',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
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
      );
}
