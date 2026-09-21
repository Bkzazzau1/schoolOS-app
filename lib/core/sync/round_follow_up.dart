import '../access/access_controller.dart';
import '../notifications/notifications_controller.dart';
import '../../shared/models/school_membership.dart';
import 'sync_engine.dart';

/// Whether the device still has changes it has not managed to send.
abstract interface class UnsentWork {
  Future<bool> hasUnsentChanges(String tenantId);
}

/// What follows every sync round that reached the server: read what the person
/// may use and their inbox, and settle any block the owner has made.
///
/// A block waits for the app so the person's unsent work is not lost: the app
/// first sends what it has, and only when nothing is left unsent does it tell
/// the server ("acknowledge") that the block may take effect. If something could
/// not be sent, it does not acknowledge; the block then takes effect at its
/// deadline, which the server guarantees.
class RoundFollowUp {
  RoundFollowUp({
    required this.access,
    required this.notifications,
    required this.unsent,
    required this.activeMembership,
  });

  final AccessController access;
  final NotificationsController notifications;
  final UnsentWork unsent;
  final SchoolMembership? Function() activeMembership;

  Future<void> call(SyncRunSummary summary) async {
    final membership = activeMembership();
    if (membership == null) return;

    // Each is tried on its own: an inbox problem must not stop access from updating.
    await _attempt(() => notifications.refresh(membership));
    await _attempt(() => access.refresh(membership));

    final waiting = access.blocking;
    if (waiting.isEmpty) return;
    if (await unsent.hasUnsentChanges(membership.schoolId)) return;
    await _attempt(() => access.acknowledge(membership, waiting.map((b) => b.activity)));
  }

  Future<void> _attempt(Future<void> Function() step) async {
    try {
      await step();
    } catch (_) {
      // Offline, or the server said no: the last known answer stands, and the next round tries again.
    }
  }
}
