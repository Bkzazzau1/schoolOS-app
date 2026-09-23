import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/network/api_exceptions.dart';

class AccountReadinessCard extends StatefulWidget {
  const AccountReadinessCard({
    super.key,
    required this.profile,
    required this.auth,
    required this.onProfileChanged,
  });

  final AuthProfile profile;
  final AuthRepository auth;
  final ValueChanged<AuthProfile> onProfileChanged;

  @override
  State<AccountReadinessCard> createState() => _AccountReadinessCardState();
}

class _AccountReadinessCardState extends State<AccountReadinessCard> {
  final _codeController = TextEditingController();
  bool _confirming = false;
  bool _resending = false;

  bool get _busy => _confirming || _resending;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onboarding = widget.profile.onboarding;
    if (!onboarding.applicable) return const SizedBox.shrink();

    final progress = onboarding.totalCount == 0
        ? 1.0
        : onboarding.completedCount / onboarding.totalCount;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      onboarding.ready ? 'Account ready' : 'Finish account setup',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      onboarding.ready
                          ? 'Your SchoolOS account is ready for multi-school management.'
                          : '${onboarding.completedCount} of ${onboarding.totalCount} setup steps completed.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Chip(
                  avatar: Icon(
                    onboarding.ready
                        ? Icons.verified_rounded
                        : Icons.pending_actions_rounded,
                    size: 18,
                  ),
                  label: Text(onboarding.ready ? 'Ready' : 'Setup in progress'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0).toDouble(),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                for (final step in onboarding.steps)
                  _StepIndicator(step: step),
              ],
            ),
            if (!widget.profile.emailVerified) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Verify ${widget.profile.email}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter the 6-digit code sent to your email. You can create your first school before verification, but email verification is required before adding another school.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 560;
                        final codeField = TextField(
                          controller: _codeController,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          onSubmitted: (_) => _confirm(),
                          decoration: const InputDecoration(
                            labelText: 'Verification code',
                            hintText: '000000',
                            prefixIcon: Icon(Icons.password_rounded),
                          ),
                        );
                        final verifyButton = FilledButton.icon(
                          onPressed: _busy ? null : _confirm,
                          icon: _confirming
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.verified_user_outlined),
                          label: Text(_confirming ? 'Verifying…' : 'Verify email'),
                        );

                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              codeField,
                              const SizedBox(height: 10),
                              verifyButton,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: codeField),
                            const SizedBox(width: 12),
                            verifyButton,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _busy ? null : _resend,
                        icon: _resending
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(_resending ? 'Sending…' : 'Send a new code'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    if (_busy) return;
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _message('Enter the 6-digit verification code.');
      return;
    }

    setState(() => _confirming = true);
    try {
      final refreshed = await widget.auth.confirmEmailVerification(code);
      if (!mounted) return;
      _message('Email verified successfully.');
      widget.onProfileChanged(refreshed);
    } on ApiOfflineException {
      _message('Could not reach SchoolOS. Check your connection and try again.');
    } on ApiException catch (error) {
      _message(error.message);
    } on SessionExpiredException catch (error) {
      _message(error.message);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _resend() async {
    if (_busy) return;
    setState(() => _resending = true);
    try {
      final result = await widget.auth.sendEmailVerification();
      if (!mounted) return;
      if (result.verified) {
        final refreshed = await widget.auth.refreshProfile();
        if (!mounted) return;
        widget.onProfileChanged(refreshed);
        return;
      }
      _message(
        result.sent
            ? 'A new verification code was sent to ${widget.profile.email}.'
            : 'The code was created, but email delivery could not be confirmed. Try again shortly.',
      );
    } on ApiOfflineException {
      _message('Could not reach SchoolOS. Check your connection and try again.');
    } on ApiException catch (error) {
      _message(error.message);
    } on SessionExpiredException catch (error) {
      _message(error.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: step.completed
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            step.completed
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
          ),
          const SizedBox(width: 7),
          Text(step.label),
        ],
      ),
    );
  }
}
