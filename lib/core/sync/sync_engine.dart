import '../database/local_database.dart';
import '../tenancy/school_session_controller.dart';
import 'sync_transport.dart';

class SyncRunSummary {
  const SyncRunSummary({
    required this.attempted,
    required this.synced,
    required this.failed,
    required this.conflicts,
  });

  final int attempted;
  final int synced;
  final int failed;
  final int conflicts;
}

class SyncEngine {
  SyncEngine({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required SyncTransport transport,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _transport = transport;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final SyncTransport _transport;

  bool _running = false;

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

    try {
      final mutations = await _localDatabase.pendingMutations(
        tenantId: membership.schoolId,
        limit: batchSize,
      );

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
        } catch (error) {
          _localDatabase.markMutationFailed(mutation.id, error.toString());
          failed += 1;
        }
      }

      return SyncRunSummary(
        attempted: mutations.length,
        synced: synced,
        failed: failed,
        conflicts: conflicts,
      );
    } finally {
      _running = false;
    }
  }
}
