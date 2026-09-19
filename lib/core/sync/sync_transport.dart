import 'sync_mutation.dart';

enum SyncPushDisposition {
  accepted,
  conflict,
  rejected,
}

class SyncPushResult {
  const SyncPushResult({
    required this.disposition,
    this.serverVersion,
    this.message,
  });

  final SyncPushDisposition disposition;
  final int? serverVersion;
  final String? message;
}

/// Network boundary implemented later by the SchoolOS Django/DRF client.
///
/// Keeping transport separate from the sync engine means offline persistence,
/// conflict handling and retry behavior can be tested without HTTP.
abstract interface class SyncTransport {
  Future<SyncPushResult> pushMutation(SyncMutation mutation);
}
