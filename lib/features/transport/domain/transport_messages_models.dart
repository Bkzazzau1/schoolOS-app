import '../../driver/domain/driver_messages_models.dart';

/// Transport Control's own side of the real channel with each real Driver - reuses
/// [DriverMessageThread]/[DriverMessageItem] as-is rather than duplicating them, since both
/// sides read and write the exact same server-side `driver_message` row
/// (`apps/transport/driver_messages.py`), just from the other real participant's point of view.
class TransportMessagesSnapshot {
  const TransportMessagesSnapshot({required this.threads, required this.canReply});

  final List<DriverMessageThread> threads;
  final bool canReply;

  DriverMessageThread? threadById(String id) {
    for (final thread in threads) {
      if (thread.id == id) return thread;
    }
    return null;
  }
}
