import 'package:flutter/material.dart';

import '../../../core/network/api_exceptions.dart';
import '../domain/bank_labels.dart';

/// The server's own words for a failure, or a plain fallback. Never the raw exception.
String describeBankError(Object error) {
  if (error is ApiException) return error.message;
  if (error is ApiOfflineException) return error.message;
  if (error is SessionExpiredException) return error.message;
  return 'Something went wrong. Please try again.';
}

void showBankMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Color connectionStatusColor(String status) => switch (status) {
      'connected' => const Color(0xFF1B7F3B),
      'pending' => const Color(0xFF8A6D00),
      'disabled' => const Color(0xFF5F6B7A),
      'revoked' => const Color(0xFF5F6B7A),
      _ => const Color(0xFFB3261E),
    };

Color paymentStatusColor(String status) => switch (status) {
      'matched' || 'unrelated_income' => const Color(0xFF1B7F3B),
      'possible_match' || 'partially_matched' => const Color(0xFF8A6D00),
      'refunded' || 'reversed' || 'not_applicable' => const Color(0xFF5F6B7A),
      'investigating' => const Color(0xFF3B5BA5),
      _ => const Color(0xFFB3261E),
    };

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class ConnectionStatusChip extends StatelessWidget {
  const ConnectionStatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) =>
      StatusChip(label: connectionStatusLabel(status), color: connectionStatusColor(status));
}

class PaymentStatusChip extends StatelessWidget {
  const PaymentStatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) =>
      StatusChip(label: paymentStatusLabel(status), color: paymentStatusColor(status));
}

/// Test data must never look like the school's money.
class SandboxTag extends StatelessWidget {
  const SandboxTag({super.key});

  @override
  Widget build(BuildContext context) => const StatusChip(label: 'Test data', color: Color(0xFF6B4FBB));
}

/// Shown where there is no school server: a bank account can only be connected through one, so
/// nothing is faked here.
class NoServerNotice extends StatelessWidget {
  const NoServerNotice({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 40, color: Color(0xFF5F6B7A)),
              SizedBox(height: 12),
              Text('Bank accounts need your school\'s server', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Text(
                'Connecting a bank account, and reading the payments it receives, happens on the SchoolOS server so that '
                'no bank credential is ever kept on a phone. This app is running without a school server, so there are no '
                'accounts and no payments to show.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
            ],
          ),
        ),
      );
}

/// A titled block on a white card, the shape every section on these screens shares.
class BankSection extends StatelessWidget {
  const BankSection({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );
}
