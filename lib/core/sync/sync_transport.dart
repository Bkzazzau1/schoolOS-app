import 'sync_mutation.dart';

enum SyncPushDisposition { accepted, conflict, rejected }

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

/// Thrown by a transport when the change could not be delivered *yet* (no
/// signal, server down, sign-in expired). It is not a refusal: the change stays
/// in the queue and the run stops, to be tried again later.
class SyncRetryLater implements Exception {
  const SyncRetryLater(this.reason, {this.needsSignIn = false});

  final String reason;
  final bool needsSignIn;

  @override
  String toString() => reason;
}

/// Network boundary between the sync engine and the SchoolOS backend
/// (`HttpSyncTransport`).
///
/// Keeping transport separate from the sync engine means offline persistence,
/// conflict handling and retry behavior can be tested without HTTP.
abstract interface class SyncTransport {
  Future<SyncPushResult> pushMutation(SyncMutation mutation);
}
