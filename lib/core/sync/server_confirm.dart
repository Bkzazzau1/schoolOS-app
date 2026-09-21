import '../database/local_database.dart';
import 'sync_mutation.dart';

/// Turns "queued, and the server will decide later" into an answer the person sees now.
///
/// Most changes are saved on the device and sent when there is a connection. That is
/// right offline, but when the server *refuses* a change (only the owner may decide this,
/// the salary changed, that phone number belongs to someone else) the person would only
/// find out later in the Sync Center, with the screen showing a state the server never
/// accepted. So right after queueing, a screen asks this to send it and report back:
///
/// - **accepted**: nothing to say.
/// - **refused**: the change is dropped, the device gets the server's version back, and the
///   server's own words are thrown as a `StateError`, for the screen to show.
/// - **not sent yet** (offline, or someone else changed the record first): it stays queued and
///   is shown as waiting; nothing is thrown, and the Sync Center has the details.
class ServerConfirm {
  ServerConfirm({required LocalDatabase database, required Future<void> Function() syncNow})
      : _database = database,
        _syncNow = syncNow;

  final LocalDatabase _database;
  final Future<void> Function() _syncNow;

  Future<void> afterQueued(String tenantId, String entityType, String entityId) async {
    await _syncNow();
    final refused = _database
        .syncQueueItems(tenantId: tenantId)
        .where((i) => i.entityType == entityType && i.entityId == entityId)
        .where((i) => i.status == SyncMutationStatus.failed && !i.isConflict)
        .toList();
    if (refused.isEmpty) return;

    final item = refused.first;
    _database.discardMutation(tenantId: tenantId, mutationId: item.id);
    // Bring the server's version of the record back onto the device.
    await _syncNow();
    throw StateError(item.lastError ?? 'The school did not accept this change.');
  }
}
