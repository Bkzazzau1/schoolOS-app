import 'package:flutter/material.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/network/api_exceptions.dart';

enum _Audience { studentOrParent, staffOrProprietor }

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, required this.auth});

  final AuthRepository auth;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  _Audience? _audience;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recover account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: switch (_audience) {
                    null => _AudienceChooser(onChosen: (a) => setState(() => _audience = a)),
                    _Audience.studentOrParent => _StudentOrParentForm(
                        auth: widget.auth,
                        onBack: () => setState(() => _audience = null),
                      ),
                    _Audience.staffOrProprietor => _StaffOrProprietorForm(
                        auth: widget.auth,
                        onBack: () => setState(() => _audience = null),
                      ),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AudienceChooser extends StatelessWidget {
  const _AudienceChooser({required this.onChosen});

  final ValueChanged<_Audience> onChosen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.lock_reset_rounded, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 18),
        Text(
          'Forgot your password?',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          'Which login do you use?',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: () => onChosen(_Audience.studentOrParent),
          icon: const Icon(Icons.person_search_outlined),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Student admission ID, or Parent phone number'),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => onChosen(_Audience.staffOrProprietor),
          icon: const Icon(Icons.email_outlined),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Staff or proprietor email'),
          ),
        ),
      ],
    );
  }
}

class _StudentOrParentForm extends StatefulWidget {
  const _StudentOrParentForm({required this.auth, required this.onBack});

  final AuthRepository auth;
  final VoidCallback onBack;

  @override
  State<_StudentOrParentForm> createState() => _StudentOrParentFormState();
}

class _StudentOrParentFormState extends State<_StudentOrParentForm> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  bool _busy = false;
  String? _result;

  @override
  void dispose() {
    _identifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _busy ? null : widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
              ),
              Expanded(
                child: Text(
                  'Student or Parent',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Enter the same login ID you normally use: Student admission ID or Parent phone number. SkulGen does not reveal whether an account exists; your school office will review a valid request.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 26),
          TextFormField(
            controller: _identifier,
            enabled: !_busy && _result == null,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_busy && _result == null) _submit();
            },
            decoration: const InputDecoration(
              labelText: 'Admission ID or Parent phone',
              prefixIcon: Icon(Icons.person_search_outlined),
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Enter your login ID' : null,
          ),
          const SizedBox(height: 18),
          if (_result == null)
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_outlined),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(_busy ? 'Submitting…' : 'Request recovery'),
              ),
            )
          else
            _DoneBanner(message: _result!, onDone: widget.onBack),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final message = await widget.auth.requestPasswordRecovery(_identifier.text);
      if (!mounted) return;
      setState(() => _result = message);
    } on ApiOfflineException {
      _showError(context, 'Could not reach SkulGen. Check your connection and try again.');
    } on ApiException catch (error) {
      _showError(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StaffOrProprietorForm extends StatefulWidget {
  const _StaffOrProprietorForm({required this.auth, required this.onBack});

  final AuthRepository auth;
  final VoidCallback onBack;

  @override
  State<_StaffOrProprietorForm> createState() => _StaffOrProprietorFormState();
}

class _StaffOrProprietorFormState extends State<_StaffOrProprietorForm> {
  final _requestFormKey = GlobalKey<FormState>();
  final _confirmFormKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _busy = false;
  bool _codeSent = false;
  bool _done = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _busy ? null : widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back',
            ),
            Expanded(
              child: Text(
                'Staff or Proprietor',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_done)
          _DoneBanner(message: 'Password changed. Sign in with your new password.', onDone: widget.onBack)
        else if (!_codeSent)
          _buildRequestStep(theme)
        else
          _buildConfirmStep(theme),
      ],
    );
  }

  Widget _buildRequestStep(ThemeData theme) {
    return Form(
      key: _requestFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter the email you sign in with. If it belongs to a SkulGen staff or proprietor account, we will email it a 6-digit reset code.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 26),
          TextFormField(
            controller: _email,
            enabled: !_busy,
            autocorrect: false,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_busy) _requestCode();
            },
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) =>
                value == null || !value.contains('@') ? 'Enter a real email address' : null,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _requestCode,
            icon: _busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_outlined),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(_busy ? 'Sending…' : 'Send reset code'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmStep(ThemeData theme) {
    return Form(
      key: _confirmFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.mark_email_read_outlined, color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'If that email belongs to an account, a code is on its way to ${_email.text}.',
                    style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _code,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: '6-digit code',
              prefixIcon: Icon(Icons.pin_outlined),
              counterText: '',
            ),
            validator: (value) => value == null || value.trim().length != 6 ? 'Enter the 6-digit code' : null,
          ),
          TextFormField(
            controller: _newPassword,
            enabled: !_busy,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (value) =>
                value == null || value.length < 10 ? 'At least 10 characters' : null,
          ),
          TextFormField(
            controller: _confirmPassword,
            enabled: !_busy,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_busy) _confirmReset();
            },
            decoration: const InputDecoration(
              labelText: 'Confirm new password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (value) =>
                value != _newPassword.text ? 'The two passwords do not match' : null,
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy ? null : _confirmReset,
            icon: _busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(_busy ? 'Saving…' : 'Set new password'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => setState(() => _codeSent = false),
            child: const Text('Use a different email'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestCode() async {
    if (_busy || !_requestFormKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.auth.requestEmailPasswordReset(_email.text);
      if (!mounted) return;
      setState(() => _codeSent = true);
    } on ApiOfflineException {
      _showError('Could not reach SkulGen. Check your connection and try again.');
    } on ApiException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmReset() async {
    if (_busy || !_confirmFormKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.auth.confirmEmailPasswordReset(
        email: _email.text,
        code: _code.text,
        newPassword: _newPassword.text,
      );
      if (!mounted) return;
      setState(() => _done = true);
    } on ApiOfflineException {
      _showError('Could not reach SkulGen. Check your connection and try again.');
    } on ApiException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DoneBanner extends StatelessWidget {
  const _DoneBanner({required this.message, required this.onDone});

  final String message;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_outline_rounded, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(message, style: TextStyle(color: theme.colorScheme.onPrimaryContainer)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }
}
