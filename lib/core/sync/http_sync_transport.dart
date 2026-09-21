import '../network/api_client.dart';
import '../network/api_exceptions.dart';
import 'sync_mutation.dart';
import 'sync_transport.dart';

/// Sends one queued change to `POST sync/push/`.
///
/// The server's answers map to the engine's: 200 accepted, 409 conflict, 422
/// rejected (with words to show). Anything that only means "not now" (offline,
/// server trouble, sign-in expired) becomes [SyncRetryLater], so the change is
/// never marked failed for a reason that is not its fault. The same mutation id
/// always gets the same answer from the server, so sending twice is safe.
class HttpSyncTransport implements SyncTransport {
  HttpSyncTransport(this._api);

  final ApiClient _api;

  @override
  Future<SyncPushResult> pushMutation(SyncMutation mutation) async {
    final body = <String, Object?>{
      'id': mutation.id,
      'tenantId': mutation.tenantId,
      'membershipId': mutation.membershipId,
      'entityType': mutation.entityType,
      'entityId': mutation.entityId,
      'operation': mutation.operation.name,
      if (mutation.operation != SyncOperation.delete)
        'payload': mutation.payload,
      if (mutation.baseVersion != null) 'baseVersion': mutation.baseVersion,
      'createdAt': mutation.createdAt.toUtc().toIso8601String(),
    };

    try {
      final data = await _api.post('sync/push/', body: body);
      return _result(data, SyncPushDisposition.accepted);
    } on ApiException catch (error) {
      // 409 and 422 carry the decision in their body.
      if (error.isConflict || error.statusCode == 422) {
        final details = error.details;
        return _result(
          details,
          error.isConflict
              ? SyncPushDisposition.conflict
              : SyncPushDisposition.rejected,
          fallbackMessage: error.message,
        );
      }
      if (error.isForbidden) {
        return SyncPushResult(
          disposition: SyncPushDisposition.rejected,
          message: 'You no longer have access to this school.',
        );
      }
      // A malformed change (400) is the change's own fault; it will not get better by waiting.
      return SyncPushResult(
        disposition: SyncPushDisposition.rejected,
        message: error.message,
      );
    } on ApiOfflineException catch (error) {
      throw SyncRetryLater(error.message);
    } on SessionExpiredException catch (error) {
      throw SyncRetryLater(error.message, needsSignIn: true);
    }
  }

  SyncPushResult _result(
    Object? data,
    SyncPushDisposition fallback, {
    String? fallbackMessage,
  }) {
    final map = data is Map ? data : const {};
    final message =
        map['message'] is String && (map['message'] as String).isNotEmpty
        ? map['message'] as String
        : fallbackMessage;
    return SyncPushResult(
      disposition: fallback,
      serverVersion: map['serverVersion'] is int
          ? map['serverVersion'] as int
          : null,
      message: message,
    );
  }
}
