import 'package:flutter/material.dart';

import 'billing_scope.dart';

/// A small, informational notice for a premium capability a teacher or administrator is
/// about to use - never the confidential payment detail behind it, only why the capability
/// is or isn't available right now (Phase D, Task 4). Resolves [BillingScope] itself, so a
/// host screen needs nothing but a school id and the premium code to drop this in.
///
/// Fails open on any error (offline, no BillingScope, a server error): an indicator that
/// cannot load must never block or alarm the action it decorates, since the backend remains
/// the real authority regardless of what this widget manages to show (Task 5).
///
/// [onStatus] lets the host screen also decide whether to disable its own action button -
/// but only once `premiumEnforcementEnabled` is actually true, so the button is never shown
/// as hard-disabled while enforcement itself stays off (Task 5: "Do not show a hard-disabled
/// action as though enforcement is active while the backend still permits it").
class PremiumCapabilityNotice extends StatefulWidget {
  const PremiumCapabilityNotice({
    super.key,
    required this.schoolId,
    required this.code,
    required this.featureLabel,
    this.onStatus,
  });

  final String schoolId;
  final String code;
  final String featureLabel;
  final void Function(bool premiumEnforcementEnabled, bool available)? onStatus;

  @override
  State<PremiumCapabilityNotice> createState() => _PremiumCapabilityNoticeState();
}

class _PremiumCapabilityNoticeState extends State<PremiumCapabilityNotice> {
  bool _premiumEnforcementEnabled = false;
  bool _available = true;
  String _reason = '';
  bool _ready = false;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    _load();
  }

  Future<void> _load() async {
    final repository = BillingScope.maybeOf(context);
    if (repository == null || widget.schoolId.isEmpty) return;
    try {
      final summary = await repository.schoolEntitlements(widget.schoolId);
      if (!mounted) return;
      final capability = summary.capability(widget.code);
      setState(() {
        _premiumEnforcementEnabled = summary.premiumEnforcementEnabled;
        _available = capability.available;
        _reason = capability.reason;
        _ready = true;
      });
      widget.onStatus?.call(summary.premiumEnforcementEnabled, capability.available);
    } catch (_) {
      // Fail open - see class doc.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _available) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final message = _premiumEnforcementEnabled
        ? (_reason.isEmpty
            ? "${widget.featureLabel} needs this school's current term subscription to be paid."
            : _reason)
        : "${widget.featureLabel} will need this school's subscription to be paid once "
            'premium billing starts.';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
