import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/open_home.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/network/api_exceptions.dart';
import '../domain/invitation_link.dart';

/// Accepting an invitation to a school: paste the link from the email, see what it is for,
/// then choose a password (new account) or sign in (an account that already exists).
/// The same link opens a web page for people without the app; this is the in-app way.
class InvitationAcceptPage extends StatefulWidget {
  const InvitationAcceptPage({super.key, required this.services, this.initialLink});

  final AppServices services;

  /// A link the app was opened with (or the person already pasted).
  final String? initialLink;

  @override
  State<InvitationAcceptPage> createState() => _InvitationAcceptPageState();
}

class _InvitationAcceptPageState extends State<InvitationAcceptPage> {
  final _link = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _again = TextEditingController();

  String? _token;
  InvitationPreview? _preview;
  String? _error;
  bool _busy = false;
  bool _showPassword = false;

  AuthRepository get _auth => widget.services.auth!;

  @override
  void initState() {
    super.initState();
    if (widget.initialLink != null) {
      _link.text = widget.initialLink!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  @override
  void dispose() {
    for (final c in [_link, _first, _last, _email, _password, _again]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _check() async {
    final token = invitationTokenFrom(_link.text);
    if (token == null) {
      setState(() => _error = 'That does not look like an invitation link. Paste the whole link from your email.');
      return;
    }
    await _run(() async {
      final preview = await _auth.previewInvitation(token);
      setState(() {
        _token = token;
        _preview = preview;
      });
    });
  }

  Future<void> _accept() async {
    final preview = _preview!;
    final problem = _validate(preview);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    await _run(() async {
      final accepted = preview.accountExists
          ? await _auth.acceptInvitationWithAccount(_token!, email: _email.text, password: _password.text)
          : await _auth.acceptInvitation(_token!, firstName: _first.text, lastName: _last.text, password: _password.text);
      if (!mounted) return;
      await openMembershipHome(context, widget.services, accepted.membership);
    });
  }

  String? _validate(InvitationPreview preview) {
    if (preview.accountExists) {
      if (_email.text.trim().isEmpty) return 'Enter the email address of your SchoolOS account.';
      if (_password.text.isEmpty) return 'Enter your password.';
      return null;
    }
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) return 'Enter your first and last name.';
    if (_password.text.length < 8) return 'Choose a password of at least 8 characters.';
    if (_password.text != _again.text) return 'The two passwords do not match.';
    return null;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiOfflineException {
      _fail('Could not reach SchoolOS. Check your connection and try again.');
    } on ApiException catch (error) {
      _fail(_explain(error));
    } on SessionExpiredException catch (error) {
      _fail(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(String message) {
    if (mounted) setState(() => _error = message);
  }

  String _explain(ApiException error) {
    switch (error.code) {
      case 'invitation_invalid':
        return 'This link is not valid. It may have expired or been replaced by a newer one. '
            'Ask the school office to send you a new invitation.';
      case 'already_accepted':
        return 'This invitation was already used. Go back and sign in with your email and password.';
      case 'already_linked':
        return 'This staff member already has a login. Ask the school office for help.';
      case 'wrong_account':
        return 'That account is not the one this invitation was sent to. Use the email address it was sent to.';
      case 'invalid_password':
        final details = error.details;
        final reasons = details is Map && details['details'] is List
            ? (details['details'] as List).whereType<String>().join(' ')
            : '';
        return reasons.isEmpty ? error.message : reasons;
    }
    // Signing in with an existing account: wrong details are always the same words.
    if (error.statusCode == 401) return 'The email or password is not correct.';
    return error.message;
  }

  void _startOver() => setState(() {
        _preview = null;
        _token = null;
        _error = null;
        for (final c in [_first, _last, _email, _password, _again]) {
          c.clear();
        }
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accept your invitation')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_preview == null) ..._linkStep(context) else ..._detailsStep(context, _preview!),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  key: const ValueKey('invitation-error'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _linkStep(BuildContext context) => [
        Text('Paste the link from your invitation email.', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        TextField(
          controller: _link,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Invitation link', prefixIcon: Icon(Icons.link_rounded)),
          onSubmitted: (_) => _check(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _check,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Continue'),
          ),
        ),
      ];

  List<Widget> _detailsStep(BuildContext context, InvitationPreview preview) {
    final theme = Theme.of(context);
    return [
      Text('${preview.schoolName} invited you', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text('For ${preview.staffName} · ${preview.maskedEmail}', style: theme.textTheme.bodyMedium),
      const SizedBox(height: 20),
      if (preview.accountExists) ...[
        const Text('You already have a SchoolOS account. Sign in to join this school.'),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.email_outlined)),
        ),
      ] else ...[
        const Text('Choose a password. You will use it, with your email address, to sign in next time.'),
        const SizedBox(height: 12),
        TextField(controller: _first, decoration: const InputDecoration(labelText: 'First name')),
        const SizedBox(height: 12),
        TextField(controller: _last, decoration: const InputDecoration(labelText: 'Last name')),
      ],
      const SizedBox(height: 12),
      TextField(
        controller: _password,
        obscureText: !_showPassword,
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            tooltip: _showPassword ? 'Hide password' : 'Show password',
            onPressed: () => setState(() => _showPassword = !_showPassword),
            icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          ),
        ),
      ),
      if (!preview.accountExists) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _again,
          obscureText: !_showPassword,
          decoration: const InputDecoration(labelText: 'Password again', prefixIcon: Icon(Icons.lock_outline_rounded)),
        ),
      ],
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _busy ? null : _accept,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: _busy
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(preview.accountExists ? 'Sign in and join' : 'Create my account'),
        ),
      ),
      TextButton(onPressed: _busy ? null : _startOver, child: const Text('Use a different link')),
    ];
  }
}
