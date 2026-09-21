import '../../shared/models/school_membership.dart';
import '../network/api_client.dart';
import '../network/api_exceptions.dart';
import 'sync_store.dart';
import 'sync_transport.dart';

class PullSummary {
  const PullSummary({
    required this.applied,
    required this.skippedUnsent,
    required this.removed,
  });

  final int applied;

  /// Records left alone because this device has an unsent edit of them. The unsent
  /// edit is sent first; if the server's copy moved on, the person sees a conflict.
  final int skippedUnsent;
  final int removed;
}

/// Downloads what changed in the school since this device last looked
/// (`GET sync/pull/`) and keeps it on the device.
///
/// The server numbers every change in a school and never skips one, so the
/// device only has to remember the last number it read (its cursor). It is saved
/// after each page, so an interrupted download carries on where it stopped, and
/// applying a page twice does no harm.
class SyncPuller {
  SyncPuller({
    required ApiClient api,
    required SyncStore store,
    this.pageSize = 200,
  }) : _api = api,
       _store = store;

  final ApiClient _api;
  final SyncStore _store;
  final int pageSize;

  Future<PullSummary> pull(SchoolMembership membership) async {
    var applied = 0, skipped = 0, removed = 0;
    var cursor = await _store.readSyncCursor(
      tenantId: membership.schoolId,
      membershipId: membership.id,
    );

    while (true) {
      final Object? data;
      try {
        data = await _api.get(
          'sync/pull/',
          query: {
            'school': membership.schoolId,
            'membership': membership.id,
            'since': '$cursor',
            'limit': '$pageSize',
          },
        );
      } on ApiOfflineException catch (error) {
        throw SyncRetryLater(error.message);
      } on SessionExpiredException catch (error) {
        throw SyncRetryLater(error.message, needsSignIn: true);
      }
      if (data is! Map || data['records'] is! List || data['cursor'] is! int) {
        throw const ApiException(500, 'The server sent an unexpected answer.');
      }

      for (final raw in (data['records'] as List)) {
        final record = Map<String, dynamic>.from(raw as Map);
        final result = await _apply(membership.schoolId, record);
        switch (result) {
          case _Applied.written:
            applied += 1;
          case _Applied.removed:
            removed += 1;
          case _Applied.skipped:
            skipped += 1;
        }
      }

      cursor = data['cursor'] as int;
      await _store.writeSyncCursor(
        tenantId: membership.schoolId,
        membershipId: membership.id,
        cursor: cursor,
      );
      if (data['hasMore'] != true) break;
    }
    return PullSummary(
      applied: applied,
      skippedUnsent: skipped,
      removed: removed,
    );
  }

  Future<_Applied> _apply(String tenantId, Map<String, dynamic> record) async {
    final type = record['entityType'] as String;
    final id = record['entityId'] as String;
    final existing = await _store.getLocalRecord(
      tenantId: tenantId,
      entityType: type,
      entityId: id,
    );
    if (existing != null && existing.isDirty) return _Applied.skipped;

    if (record['deleted'] == true) {
      if (existing != null) {
        await _store.deleteLocalRecord(
          tenantId: tenantId,
          entityType: type,
          entityId: id,
        );
      }
      return _Applied.removed;
    }
    await _store.upsertLocalRecord(
      tenantId: tenantId,
      entityType: type,
      entityId: id,
      payload: Map<String, Object?>.from(record['payload'] as Map),
      serverVersion: record['version'] as int?,
      isDirty: false,
    );
    return _Applied.written;
  }
}

enum _Applied { written, removed, skipped }
