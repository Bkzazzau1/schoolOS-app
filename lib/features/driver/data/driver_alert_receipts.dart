import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';

/// The real "I have read this alert" receipt for `driver_alert`
/// (`apps/transport/driver_messages.py: AlertReceiptHandler`) - one-directional, Driver-only:
/// nothing ever sent *to* a Driver here needs a receipt from anyone else.
const driverAlertReceiptEntityType = 'driver_alert_receipt';

/// Every real alert id this membership has recorded as read - real state, computed from real
/// receipt rows, never a stored flag.
Future<Set<String>> loadOwnReadAlertIds(
  LocalDatabase db, {
  required String tenantId,
  required String membershipId,
}) async {
  final records = await db.getLocalRecords(
    tenantId: tenantId,
    entityType: driverAlertReceiptEntityType,
  );
  final read = <String>{};
  for (final record in records) {
    if (record.payload['membershipId'] != membershipId) continue;
    final alertId = record.payload['alertId'] as String?;
    if (alertId != null) read.add(alertId);
  }
  return read;
}

/// Queues this Driver's own real receipt for a real alert - create-only, the same append-only
/// shape every receipt in this app already uses. `routeId` is this Driver's own real, currently
/// assigned route (never taken from the app - the server re-derives it itself too), the same
/// operational context `DriverMessageHandler` already stamps onto a Driver's own messages.
Future<void> queueAlertReadReceipt(
  LocalDatabase db, {
  required String tenantId,
  required String membershipId,
  required String alertId,
  required String routeId,
}) async {
  final now = DateTime.now().toUtc();
  final receiptId = '$membershipId:alert-read:$alertId:${now.microsecondsSinceEpoch}';
  final wirePayload = <String, Object?>{
    'id': receiptId,
    'alertId': alertId,
    'routeId': routeId,
    'readAt': now.toIso8601String(),
  };
  final localPayload = <String, Object?>{
    ...wirePayload,
    'membershipId': membershipId,
  };
  await db.upsertLocalRecord(
    tenantId: tenantId,
    entityType: driverAlertReceiptEntityType,
    entityId: receiptId,
    payload: localPayload,
    isDirty: true,
  );
  await db.queueMutation(
    tenantId: tenantId,
    membershipId: membershipId,
    entityType: driverAlertReceiptEntityType,
    entityId: receiptId,
    operation: SyncOperation.create,
    payload: wirePayload,
  );
}
