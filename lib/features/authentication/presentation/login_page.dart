import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/demo_people.dart';
import '../../../app/open_home.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/network/api_exceptions.dart';
import '../../account/presentation/account_home_page.dart';
import '../../invitations/presentation/invitation_accept_page.dart';
import '../../../shared/layout/app_breakpoints.dart';
import '../../../shared/models/school_membership.dart';
import '../../school_switcher/presentation/school_selection_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.services});

  final AppServices services;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identityController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _busy = false;

  @override
  void dispose() {
    _identityController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final compact = AppBreakpoints.isPhone(width);

            if (compact) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BrandHeader(compact: true),
                    const SizedBox(height: 40),
                    _LoginCard(
                      demoMemberships: demoMemberships,
                      formKey: _formKey,
                      identityController: _identityController,
                      passwordController: _passwordController,
                      obscurePassword: _obscurePassword,
                      onTogglePassword: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      onSubmit: _submit,
                      backend: widget.services.usesBackend,
                      onInvitation: _openInvitation,
                    ),
                  ],
                ),
              );
            }

            return Row(
              children: [
                const Expanded(flex: 5, child: _DesktopBrandPanel()),
                Expanded(
                  flex: 4,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(40),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: _LoginCard(
                          demoMemberships: demoMemberships,
                          formKey: _formKey,
                          identityController: _identityController,
                          passwordController: _passwordController,
                          obscurePassword: _obscurePassword,
                          onTogglePassword: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                          onSubmit: _submit,
                          backend: widget.services.usesBackend,
                          onInvitation: _openInvitation,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;

    final auth = widget.services.auth;
    if (auth == null) {
      // No backend configured: the built-in demo, exactly as before.
      await widget.services.schoolSession.setMemberships(
        widget.services.localAccess?.memberships ?? demoMemberships,
      );
      if (!mounted) return;
      _chooseSchool(widget.services.localAccess?.memberships ?? demoMemberships);
      return;
    }

    setState(() => _busy = true);
    try {
      final profile = await auth.signIn(
        _identityController.text,
        _passwordController.text,
      );
      if (!mounted) return;

      // An organization owner may legitimately have no school yet: Account Home
      // is where they create the first one. A person with neither an organization
      // nor a school still has no usable SchoolOS access.
      if (profile.memberships.isEmpty && profile.organizations.isEmpty) {
        await auth.signOut();
        _showError(
          'You are signed in, but not connected to a school or school account yet. '
          'Ask your school office to send you an invitation.',
        );
        return;
      }

      _openAfterSignIn(profile);
    } on ApiOfflineException {
      _showError(
        'Could not reach SchoolOS. Check your connection and try again.',
      );
    } on ApiException catch (error) {
      // A wrong email or a wrong password get the same words, so the screen
      // never tells anyone which of the two was wrong.
      _showError(
        error.statusCode == 401
            ? 'The email or password is not correct.'
            : error.message,
      );
    } on SessionExpiredException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openInvitation() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InvitationAcceptPage(services: widget.services),
      ),
    );
  }

  void _openAfterSignIn(AuthProfile profile) {
    if (profile.organizations.isNotEmpty) {
      final services = widget.services;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AccountHomePage(
            profile: profile,
            services: services,
            onSignOut: (accountContext) async {
              await services.endSession();
              if (!accountContext.mounted) return;
              Navigator.of(accountContext).pushAndRemoveUntil(
                MaterialPageRoute<void>(
                  builder: (_) => LoginPage(services: services),
                ),
                (route) => false,
              );
            },
          ),
        ),
      );
      return;
    }

    _chooseSchool(profile.memberships);
  }

  void _chooseSchool(List<SchoolMembership> memberships) {
    if (memberships.length == 1) {
      _openMembershipHome(context, memberships.single);
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => SchoolSelectionPage(
          memberships: memberships,
          onSelected: (membership) => _openMembershipHome(context, membership),
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openMembershipHome(
    BuildContext context,
    SchoolMembership membership,
  ) => openMembershipHome(context, widget.services, membership);
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.demoMemberships,
    required this.formKey,
    required this.identityController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onSubmit,
    this.backend = false,
    this.onInvitation,
  });

  /// A backend is configured: real sign-in, and no demo panel.
  final bool backend;

  /// Opens the accept-an-invitation page (only offered with a backend).
  final VoidCallback? onInvitation;
  final GlobalKey<FormState> formKey;
  final List<SchoolMembership> demoMemberships;
  static const _demoUsername = 'demo';
  static const _demoPassword = 'SchoolOS123!';
  final TextEditingController identityController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome back',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in once to access the schools connected to your SchoolOS account.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: identityController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: backend
                      ? 'Email address'
                      : 'Username, email or phone',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return backend
                        ? 'Enter your email address'
                        : 'Enter your username, email or phone';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => onSubmit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: onTogglePassword,
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onSubmit,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Sign in'),
                ),
              ),
              if (backend && onInvitation != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onInvitation,
                  icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                  label: const Text('I have an invitation link'),
                ),
              ],
              if (!backend) ...[
                const SizedBox(height: 14),
                Text(
                  'Demo mode: use the sample details below, or any non-empty username and password.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Try the demo',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const SelectableText('Username: $_demoUsername'),
                      const SelectableText('Password: $_demoPassword'),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          identityController.text = _demoUsername;
                          passwordController.text = _demoPassword;
                        },
                        icon: const Icon(Icons.edit_note_rounded),
                        label: const Text('Use demo details'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Available demo roles',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Sign in, then choose a school and role. These details work for all roles below.',
                      ),
                      const SizedBox(height: 8),
                      for (final membership in demoMemberships)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                membership.roleLabel,
                                style: theme.textTheme.labelLarge,
                              ),
                              Text(
                                membership.schoolName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: compact ? 46 : 56,
          height: compact ? 46 : 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.school_rounded, color: theme.colorScheme.onPrimary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SchoolOS',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Work anywhere. Sync when connected.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopBrandPanel extends StatelessWidget {
  const _DesktopBrandPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.primaryContainer,
      padding: const EdgeInsets.all(56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandHeader(compact: false),
          const Spacer(),
          Text(
            'One account.\nEvery school you belong to.',
            style: theme.textTheme.displaySmall?.copyWith(
              height: 1.08,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'SchoolOS is designed for Android phones, tablets and Windows PCs, with offline-first daily operations and intelligent synchronization.',
            style: theme.textTheme.titleMedium?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onPrimaryContainer.withValues(
                alpha: 0.78,
              ),
            ),
          ),
          const SizedBox(height: 36),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _CapabilityChip(
                icon: Icons.cloud_off_rounded,
                label: 'Offline-first',
              ),
              _CapabilityChip(icon: Icons.sync_rounded, label: 'Smart sync'),
              _CapabilityChip(
                icon: Icons.auto_awesome_rounded,
                label: 'Edge AI ready',
              ),
            ],
          ),
          const Spacer(),
          Text(
            'SchoolOS native application foundation',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}
