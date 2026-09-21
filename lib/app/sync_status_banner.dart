import 'package:flutter/material.dart';

import '../core/sync/sync_coordinator.dart';

/// A strip across the top of the whole app that appears only when the person
/// needs to know something about syncing: they are offline (their work is safe),
/// their sign-in ended, or they lost access to the school.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({
    super.key,
    required this.coordinator,
    required this.child,
    required this.onSignInAgain,
  });

  final SyncCoordinator coordinator;
  final Widget child;

  /// Called when the person taps "Sign in" on the strip.
  final VoidCallback onSignInAgain;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: coordinator,
      builder: (context, _) {
        final status = coordinator.status;
        final strip = switch (status) {
          SyncStatus.offline => _Strip(
            icon: Icons.cloud_off_rounded,
            message:
                'You are offline. Your work is saved and will be sent when you are back online.',
            color: Theme.of(context).colorScheme.secondaryContainer,
            onColor: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          SyncStatus.needsSignIn => _Strip(
            icon: Icons.lock_clock_outlined,
            message: 'Your sign-in has ended. Your work is saved.',
            action: 'Sign in',
            onAction: onSignInAgain,
            color: Theme.of(context).colorScheme.errorContainer,
            onColor: Theme.of(context).colorScheme.onErrorContainer,
          ),
          SyncStatus.lostAccess => _Strip(
            icon: Icons.block_rounded,
            message: 'You no longer have access to this school.',
            action: 'Sign in',
            onAction: onSignInAgain,
            color: Theme.of(context).colorScheme.errorContainer,
            onColor: Theme.of(context).colorScheme.onErrorContainer,
          ),
          _ => null,
        };
        if (strip == null) return child;
        return Column(
          children: [
            strip,
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.icon,
    required this.message,
    required this.color,
    required this.onColor,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final Color color;
  final Color onColor;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: onColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: onColor),
                ),
              ),
              if (action != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(foregroundColor: onColor),
                  child: Text(action!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
