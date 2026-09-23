import 'package:flutter/material.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/network/api_exceptions.dart';

class ProprietorRegistrationPage extends StatefulWidget {
  const ProprietorRegistrationPage({
    super.key,
    required this.auth,
  });

  final AuthRepository auth;

  @override
  State<ProprietorRegistrationPage> createState() =>
      _ProprietorRegistrationPageState();
}

class _ProprietorRegistrationPageState
    extends State<ProprietorRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _organizationController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _busy = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _organizationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create SchoolOS account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          foregroundColor: theme.colorScheme.onPrimaryContainer,
                          child: const Icon(Icons.domain_add_rounded, size: 30),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Set up your school account',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create the owner account first. You can add your first school, and more schools later, from Account Home.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 28),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 500) {
                              return Column(
                                children: [
                                  _nameField(
                                    controller: _firstNameController,
                                    label: 'First name',
                                    icon: Icons.person_outline_rounded,
                                  ),
                                  const SizedBox(height: 16),
                                  _nameField(
                                    controller: _lastNameController,
                                    label: 'Last name',
                                    icon: Icons.person_outline_rounded,
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: _nameField(
                                    controller: _firstNameController,
                                    label: 'First name',
                                    icon: Icons.person_outline_rounded,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _nameField(
                                    controller: _lastNameController,
                                    label: 'Last name',
                                    icon: Icons.person_outline_rounded,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _organizationController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'School group / organization name',
                            prefixIcon: Icon(Icons.business_rounded),
                            helperText:
                                'This is the account that can own one or more schools.',
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.length < 2) {
                              return 'Enter your school or organization name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty ||
                                !text.contains('@') ||
                                !text.contains('.')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            helperText:
                                'Use at least 10 characters and avoid common or fully numeric passwords.',
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').length < 10) {
                              return 'Use at least 10 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmation,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Confirm password',
                            prefixIcon:
                                const Icon(Icons.verified_user_outlined),
                            suffixIcon: IconButton(
                              tooltip: _obscureConfirmation
                                  ? 'Show password confirmation'
                                  : 'Hide password confirmation',
                              onPressed: () => setState(
                                () => _obscureConfirmation =
                                    !_obscureConfirmation,
                              ),
                              icon: Icon(
                                _obscureConfirmation
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _busy ? null : _submit,
                          icon: _busy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward_rounded),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              _busy ? 'Creating account…' : 'Create account',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your organization and school tenants stay separate. Creating this account does not create or mix school data.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _nameField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      autofillHints: label == 'First name'
          ? const [AutofillHints.givenName]
          : const [AutofillHints.familyName],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: (value) => (value?.trim().isEmpty ?? true)
          ? 'Enter your ${label.toLowerCase()}'
          : null,
    );
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      final profile = await widget.auth.registerProprietor(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        organizationName: _organizationController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(profile);
    } on ApiOfflineException {
      _showError('Could not reach SchoolOS. Check your connection and try again.');
    } on ApiException catch (error) {
      _showError(error.message);
    } on SessionExpiredException catch (error) {
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
