import 'package:flutter/material.dart';

import '../data/staff_onboarding_repository.dart';
import '../domain/owner_staff_profile_models.dart';

/// Shows a banner above [child] while the signed-in person has a registration
/// request waiting, and opens the form from it. Shows nothing otherwise, and
/// never blocks the rest of the app.
class StaffOnboardingBanner extends StatefulWidget {
  const StaffOnboardingBanner({
    super.key,
    required this.repository,
    required this.child,
    this.onSubmitted,
  });

  final StaffOnboardingRepository repository;
  final Widget child;
  final VoidCallback? onSubmitted;

  @override
  State<StaffOnboardingBanner> createState() => _StaffOnboardingBannerState();
}

class _StaffOnboardingBannerState extends State<StaffOnboardingBanner> {
  StaffProfile? _request;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final request = await widget.repository.openRequest();
      if (mounted) setState(() => _request = request);
    } catch (_) {
      // No banner if the check cannot run.
    }
  }

  Future<void> _open() async {
    final request = _request;
    if (request == null) return;
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StaffOnboardingPage(
          repository: widget.repository,
          profile: request,
        ),
      ),
    );
    if (done == true) {
      widget.onSubmitted?.call();
      await _check();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_request == null) return widget.child;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: scheme.primaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Welcome. Please complete your registration: your details, bank account and documents.',
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _open,
                  child: const Text('Complete registration'),
                ),
              ],
            ),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

class StaffOnboardingPage extends StatefulWidget {
  const StaffOnboardingPage({
    super.key,
    required this.repository,
    required this.profile,
  });

  final StaffOnboardingRepository repository;
  final StaffProfile profile;

  @override
  State<StaffOnboardingPage> createState() => _StaffOnboardingPageState();
}

class _StaffOnboardingPageState extends State<StaffOnboardingPage> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  late final Map<String, TextEditingController> _docs;
  bool _saving = false;
  String? _error;

  static const _fields = <String, String>{
    'phone': 'Phone number',
    'nin': 'NIN (11 digits)',
    'email': 'Email address',
    'address': 'Home address',
    'dateOfBirth': 'Date of birth (yyyy-mm-dd)',
    'gender': 'Gender',
    'stateOfOrigin': 'State of origin',
    'nextOfKinName': 'Next of kin name',
    'nextOfKinPhone': 'Next of kin phone',
    'bankName': 'Bank',
    'accountName': 'Account name',
    'accountNumber': 'Account number (10 digits)',
  };

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    final initial = <String, String>{
      ...p.personal.toJson().map((k, v) => MapEntry(k, '$v')),
      ...p.payment.toJson().map((k, v) => MapEntry(k, '$v')),
    };
    if ((initial['email'] ?? '').isEmpty) initial['email'] = p.onboardingEmail;
    _c = {
      for (final key in _fields.keys)
        key: TextEditingController(text: initial[key] ?? ''),
    };
    _docs = {
      for (final d in p.documents)
        if (d.status == StaffDocumentStatus.requested)
          d.name: TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final c in [..._c.values, ..._docs.values]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'Required' : null;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      String t(String k) => _c[k]!.text;
      await widget.repository.submit(
        personal: StaffPersonalInfo(
          phone: t('phone'),
          nin: t('nin'),
          email: t('email'),
          address: t('address'),
          dateOfBirth: t('dateOfBirth'),
          gender: t('gender'),
          stateOfOrigin: t('stateOfOrigin'),
          nextOfKinName: t('nextOfKinName'),
          nextOfKinPhone: t('nextOfKinPhone'),
        ),
        payment: StaffPaymentDetails(
          bankName: t('bankName'),
          accountName: t('accountName'),
          accountNumber: t('accountNumber'),
        ),
        documents: {for (final e in _docs.entries) e.key: e.value.text},
      );
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Thank you. Your registration was submitted for review.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is StateError
              ? error.message
              : error is ArgumentError
              ? '${error.message}'
              : error.toString();
        });
      }
    }
  }

  Widget _field(String key, {TextInputType? type, bool required = true}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: TextFormField(
          controller: _c[key],
          enabled: !_saving,
          keyboardType: type,
          decoration: InputDecoration(labelText: _fields[key]),
          validator: required ? _required : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Complete your registration')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Please fill in your details. Your phone number and NIN are unique to you. Your bank account can only be entered or changed by you.',
            ),
            const SizedBox(height: 16),
            Text('About you', style: theme.textTheme.titleLarge),
            _field('phone', type: TextInputType.phone),
            _field('nin', type: TextInputType.number),
            _field('email', required: false, type: TextInputType.emailAddress),
            _field('address'),
            _field('dateOfBirth'),
            _field('gender', required: false),
            _field('stateOfOrigin', required: false),
            _field('nextOfKinName'),
            _field('nextOfKinPhone', type: TextInputType.phone),
            const SizedBox(height: 16),
            Text('Bank account for salary', style: theme.textTheme.titleLarge),
            _field('bankName'),
            _field('accountName'),
            _field('accountNumber', type: TextInputType.number),
            const SizedBox(height: 16),
            Text('Documents', style: theme.textTheme.titleLarge),
            const Text(
              'Uploading files is not available in the app yet. For each document you have provided or will hand in, note how (for example "handed to the school office on 21 Sept" or the file name you emailed). The school will confirm each one.',
            ),
            for (final entry in _docs.entries)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextFormField(
                  controller: entry.value,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: entry.key,
                    helperText: 'Optional. Leave blank if not provided yet.',
                  ),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? 'Submitting…' : 'Submit registration'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
