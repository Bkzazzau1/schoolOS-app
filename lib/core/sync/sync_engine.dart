import '../database/local_database.dart';
import '../network/api_exceptions.dart';
import '../tenancy/school_session_controller.dart';
import 'sync_coordinator.dart';
import 'sync_puller.dart';
import 'sync_transport.dart';

class SyncRunSummary {
  const SyncRunSummary({
    required this.attempted,
    required this.synced,
    required this.failed,
    required this.conflicts,
    this.pulled = 0,
    this.stoppedOffline = false,
    this.needsSignIn = false,
    this.accessLost = false,
    this.pullError,
  });

  final int attempted;
  final int synced;
  final int failed;
  final int conflicts;

  /// Records downloaded from the school since the last run.
  final int pulled;

  /// The run stopped because the server could not be reached; nothing was lost
  /// and the rest of the queue is still waiting.
  final bool stoppedOffline;

  /// The sign-in expired: the person must sign in again before anything more is sent.
  final bool needsSignIn;

  /// The server says the person no longer belongs to this school.
  final bool accessLost;

  /// Why downloading failed, in words for the person, when it did (and it was not just being offline).
  final String? pullError;
}

/// Sends the device's queued changes to the server, then downloads what changed
/// in the school. Send first, so the device's own edits reach the server before
/// it asks what changed.
class SyncEngine implements SyncRunner {
  SyncEngine({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required SyncTransport transport,
    SyncPuller? puller,
  }) : _localDatabase = localDatabase,
       _schoolSession = schoolSession,
       _transport = transport,
       _puller = puller;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final SyncTransport _transport;
  final SyncPuller? _puller;

  bool _running = false;

  @override
  Future<SyncRunSummary> syncActiveSchool({int batchSize = 50}) async {
    if (_running) {
      return const SyncRunSummary(
        attempted: 0,
        synced: 0,
        failed: 0,
        conflicts: 0,
      );
    }

    final membership = _schoolSession.requireActiveMembership();
    _running = true;

    var synced = 0;
    var failed = 0;
    var conflicts = 0;
    var stoppedOffline = false;
    var needsSignIn = false;
    var attempted = 0;

    try {
      final mutations = await _localDatabase.pendingMutations(
        tenantId: membership.schoolId,
        limit: batchSize,
      );
      attempted = mutations.length;

      for (final mutation in mutations) {
        if (mutation.tenantId != membership.schoolId ||
            mutation.membershipId != membership.id) {
          _localDatabase.markMutationFailed(
            mutation.id,
            'Active tenant or membership changed before synchronization.',
          );
          failed += 1;
          continue;
        }

        _localDatabase.markMutationSyncing(mutation.id);

        try {
          final result = await _transport.pushMutation(mutation);
          switch (result.disposition) {
            case SyncPushDisposition.accepted:
              _localDatabase.markMutationSynced(
                mutation.id,
                serverVersion: result.serverVersion,
              );
              synced += 1;
            case SyncPushDisposition.conflict:
              _localDatabase.markMutationFailed(
                mutation.id,
                'SYNC_CONFLICT: ${result.message ?? 'Server record changed.'}',
              );
              conflicts += 1;
            case SyncPushDisposition.rejected:
              _localDatabase.markMutationFailed(
                mutation.id,
                result.message ?? 'Server rejected the offline mutation.',
              );
              failed += 1;
          }
        } on SyncRetryLater catch (later) {
          // Not this change's fault: put it back and stop. Changes must reach
          // the server in the order they were made, so the rest wait too.
          _localDatabase.markMutationPending(mutation.id);
          stoppedOffline = true;
          needsSignIn = later.needsSignIn;
          break;
        } catch (error) {
          _localDatabase.markMutationFailed(mutation.id, error.toString());
          failed += 1;
        }
      }

      var pulled = 0;
      var accessLost = false;
      String? pullError;
      if (!stoppedOffline && _puller != null) {
        try {
          final summary = await _puller.pull(membership);
          pulled = summary.applied + summary.removed;
        } on SyncRetryLater catch (later) {
          stoppedOffline = true;
          needsSignIn = later.needsSignIn;
        } on ApiException catch (error) {
          accessLost = error.isForbidden;
          pullError = error.message;
        }
      }

      return SyncRunSummary(
        attempted: attempted,
        synced: synced,
        failed: failed,
        conflicts: conflicts,
        pulled: pulled,
        stoppedOffline: stoppedOffline,
        needsSignIn: needsSignIn,
        accessLost: accessLost,
        pullError: pullError,
      );
    } finally {
      _running = false;
    }
  }
}
