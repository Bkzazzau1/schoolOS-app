import 'package:flutter/material.dart';

import '../data/billing_repository.dart';
import 'billing_scope.dart';

/// A small, informational notice for a premium capability a teacher or administrator is
/// about to use - never the confidential payment detail behind it, only why the capability
/// is or isn't available right now. Resolves [BillingScope] itself, so a host screen needs
/// nothing but a school id and the premium code to drop this in.
///
/// Shows nothing at all while premium enforcement is off (Phase D Stage 1.5, Task 4): a
/// capability that is fully usable today must never look locked just because payment will
/// matter once SkulGen turns enforcement on elsewhere - that would mislead the person using
/// it, and this widget has no business naming an internal rollout flag to them anyway. Once
/// enforcement is on and the capability is genuinely unavailable, the notice shows only the
/// server's own plain-language reason.
///
/// Fails open on any error (offline, no BillingScope, a server error): an indicator that
/// cannot load must never block or alarm the action it decorates, since the backend remains
/// the real authority regardless of what this widget manages to show.
///
/// Refetches when the selected school or code changes, when the app returns to the
/// foreground (if its last read is stale), and whenever [BillingRepository] reports an
/// entitlement-affecting change (Task 3) - never on a fixed poll, to avoid unnecessary
/// repeated requests.
///
/// [onStatus] lets the host screen also decide whether to disable its own action button -
/// but only once `premiumEnforcementEnabled` is actually true, so the button is never shown
/// as hard-disabled while enforcement itself stays off (Task 5 of Stage 1: "Do not show a
/// hard-disabled action as though enforcement is active while the backend still permits it").
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

class _PremiumCapabilityNoticeState extends State<PremiumCapabilityNotice>
    with WidgetsBindingObserver {
  static const _staleAfter = Duration(seconds: 20);

  bool _premiumEnforcementEnabled = false;
  bool _available = true;
  String _reason = '';
  bool _ready = false;
  DateTime? _lastFetchedAt;
  BillingRepository? _subscribedRepository;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribe();
    if (_lastFetchedAt == null) _load();
  }

  @override
  void didUpdateWidget(covariant PremiumCapabilityNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId || oldWidget.code != widget.code) {
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final lastFetchedAt = _lastFetchedAt;
    if (lastFetchedAt == null || DateTime.now().difference(lastFetchedAt) > _staleAfter) {
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscribedRepository?.removeListener(_onEntitlementsChanged);
    super.dispose();
  }

  void _subscribe() {
    final repository = BillingScope.maybeOf(context);
    if (repository == null || repository == _subscribedRepository) return;
    _subscribedRepository?.removeListener(_onEntitlementsChanged);
    repository.addListener(_onEntitlementsChanged);
    _subscribedRepository = repository;
  }

  void _onEntitlementsChanged() => _load();

  Future<void> _load() async {
    final repository = BillingScope.maybeOf(context);
    if (repository == null || widget.schoolId.isEmpty) return;
    _lastFetchedAt = DateTime.now();
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
    if (!_ready || _available || !_premiumEnforcementEnabled) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final message = _reason.isEmpty
        ? "${widget.featureLabel} needs this school's current term subscription to be paid."
        : _reason;
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
