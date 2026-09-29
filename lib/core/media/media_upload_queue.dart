import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../../shared/models/school_membership.dart';
import '../database/local_database.dart';
import '../network/api_exceptions.dart';
import '../tenancy/school_session_controller.dart';
import 'media_api.dart';
import 'media_local_files.dart';
import 'media_models.dart';
import 'media_queue_models.dart';

/// Sends whatever is waiting in the media upload queue, without any screen having to ask - the offline-first
/// counterpart to [SyncCoordinator] for real files rather than JSON records.
///
/// A file is copied into this app's own storage and queued the moment [enqueue] is called (see
/// media_local_files.dart), which never touches the network. From there this coordinator sends what it can:
/// [initiate] on the school server, the bytes themselves (straight to this server for local/dev storage, straight
/// to the object store with no SchoolOS token at all for S3-compatible storage), then [complete]. A network
/// problem is retried with a growing gap, the same shape [SyncCoordinator] uses; a file the server refuses
/// outright is marked failed and is not retried automatically again. A local copy is only ever deleted once the
/// server has confirmed the upload, or if the person cancels a still-queued one themselves - never on a mere
/// send failure.
class MediaUploadQueue extends ChangeNotifier with WidgetsBindingObserver {
  MediaUploadQueue({
    required LocalDatabase database,
    required SchoolSessionController schoolSession,
    MediaLocalFiles files = const MediaLocalFiles(),
    this.interval = const Duration(seconds: 20),
    this.debounce = const Duration(seconds: 2),
    this.firstBackoff = const Duration(seconds: 10),
    this.maxBackoff = const Duration(minutes: 5),
    bool observeLifecycle = true,
  })  : _database = database,
        _schoolSession = schoolSession,
        _files = files,
        _observeLifecycle = observeLifecycle;

  final LocalDatabase _database;
  final SchoolSessionController _schoolSession;
  final MediaLocalFiles _files;
  final Duration interval;
  final Duration debounce;
  final Duration firstBackoff;
  final Duration maxBackoff;
  final bool _observeLifecycle;

  /// The online client to send through. Left null in demo/offline mode - the queue then simply never runs;
  /// files still queue and wait for a server to exist.
  MediaApi? api;

  bool _started = false;
  bool _running = false;
  bool _again = false;
  Duration? _backoff;
  Timer? _periodic;
  Timer? _pending;

  bool get isSending => _running;

  /// How many of this school's uploads are still local-only (waiting or uploading).
  int pendingCount(SchoolMembership membership) => _database.pendingMediaUploadCount(tenantId: membership.schoolId);

  /// Every upload attached to one owner - queued, sent, done, or given up on - oldest first, so a screen can show
  /// a file the server has not caught up to yet without it simply being missing.
  List<QueuedMediaUpload> uploadsForOwner(SchoolMembership membership, {required String ownerType, required String ownerId}) =>
      _database.mediaUploadsForOwner(tenantId: membership.schoolId, ownerType: ownerType, ownerId: ownerId);

  /// Copies [bytes] into this app's own storage and queues it. Returns at once - the caller never waits for the
  /// network - with the local queue id (`QueuedMediaUpload.id`), which becomes `serverAssetId` once uploaded.
  Future<String> enqueue({
    required SchoolMembership membership,
    required String ownerType,
    required String ownerId,
    required String category,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    String caption = '',
    String visibility = 'private',
  }) async {
    final copied = await _files.copyIntoAppStorage(bytes, suggestedExtension: _extensionFor(fileName, mimeType));
    final id = await _database.queueMediaUpload(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      ownerType: ownerType,
      ownerId: ownerId,
      category: category,
      fileName: fileName,
      mimeType: mimeType,
      byteSize: copied.byteSize,
      sha256: copied.sha256,
      localPath: copied.localPath,
      caption: caption,
      visibility: visibility,
    );
    requestRun(immediately: true);
    notifyListeners();
    return id;
  }

  /// Tries a failed upload again, by hand.
  void retry(String queueId) {
    _database.retryMediaUpload(queueId);
    requestRun(immediately: true);
    notifyListeners();
  }

  /// Forgets a still-queued (never sent) upload and its local copy. Refuses anything already sent - retire that
  /// through [MediaApi.retire] instead, which the school server must know about.
  Future<void> cancel(String queueId) async {
    final item = _database.mediaUpload(queueId);
    if (item == null || item.state == MediaUploadState.uploaded) return;
    _database.deleteMediaUpload(queueId);
    await _files.delete(item.localPath);
    notifyListeners();
  }

  // -- driving the queue, the same shape as SyncCoordinator ---------------------------------------------------

  void start() {
    if (!_started) {
      _started = true;
      if (_observeLifecycle) WidgetsBinding.instance.addObserver(this);
    }
    _periodic?.cancel();
    _periodic = Timer.periodic(interval, (_) => requestRun(immediately: true));
    requestRun(immediately: true);
  }

  void stop() {
    _started = false;
    _periodic?.cancel();
    _pending?.cancel();
    _periodic = _pending = null;
    if (_observeLifecycle) WidgetsBinding.instance.removeObserver(this);
  }

  void requestRun({bool immediately = false}) {
    if (!_started || api == null) return;
    _pending?.cancel();
    _pending = Timer(immediately ? Duration.zero : debounce, _runNow);
  }

  Future<void> _runNow() {
    if (!_started || api == null) return Future.value();
    if (_running) {
      _again = true;
      return Future.value();
    }
    return _runRounds();
  }

  Future<void> _runRounds() async {
    _running = true;
    _pending?.cancel();
    _pending = null;
    try {
      do {
        _again = false;
        await _round();
      } while (_again && _started && api != null);
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  Future<void> _round() async {
    final api = this.api;
    final membership = _schoolSession.activeMembership;
    if (api == null || membership == null) return;

    final due = _database.dueMediaUploads(tenantId: membership.schoolId);
    if (due.isEmpty) {
      _backoff = null;
      return;
    }
    for (final item in due) {
      await _send(api, item);
    }
  }

  Future<void> _send(MediaApi api, QueuedMediaUpload item) async {
    _database.markMediaUploadUploading(item.id);
    final who = _memberOf(item);
    try {
      if (!await _files.exists(item.localPath)) {
        _database.markMediaUploadFailed(item.id, errorCode: 'file_missing', errorMessage: 'This file is no longer on the device.');
        return;
      }
      final bytes = await _files.read(item.localPath);
      final (asset, instructions) = await api.initiate(
        who,
        ownerType: item.ownerType,
        ownerId: item.ownerId,
        category: item.category,
        fileName: item.fileName,
        mimeType: item.mimeType,
        byteSize: item.byteSize,
        sha256: item.sha256,
        caption: item.caption,
        visibility: item.visibility,
      );
      switch (instructions.mode) {
        case 'direct':
          await api.uploadDirect(instructions, bytes, mimeType: item.mimeType);
        case 'presigned_put':
          await _putToPresignedUrl(instructions, bytes, mimeType: item.mimeType);
        default:
          throw StateError('Unknown upload mode: ${instructions.mode}');
      }
      final completed = await api.complete(who, asset.id);
      _database.markMediaUploadUploaded(item.id, serverAssetId: completed.id, serverStatus: completed.status);
      _backoff = null;
    } on ApiOfflineException {
      _retryLater(item);
    } on ApiException catch (error) {
      if (error.statusCode >= 500) {
        _retryLater(item, code: error.code ?? 'server_error', message: error.message);
      } else {
        _database.markMediaUploadFailed(item.id, errorCode: error.code ?? 'refused', errorMessage: error.message);
      }
    } catch (error) {
      _retryLater(item, code: 'unexpected_error', message: 'Something went wrong ($error).');
    }
  }

  Future<void> _putToPresignedUrl(MediaUploadInstructions instructions, List<int> bytes, {required String mimeType}) async {
    final headers = instructions.headers.isNotEmpty ? instructions.headers : {'Content-Type': mimeType};
    late final http.Response response;
    try {
      response = await http.put(Uri.parse(instructions.uploadUrl), headers: headers, body: bytes).timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw const ApiOfflineException('The storage provider took too long to answer.');
    } catch (_) {
      throw const ApiOfflineException('Could not reach the storage provider.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiOfflineException('The storage provider did not accept the file (${response.statusCode}).');
    }
  }

  void _retryLater(QueuedMediaUpload item, {String code = 'offline', String message = 'Could not reach the server. Your file is saved and will be sent when you are back online.'}) {
    _backoff = _backoff == null ? firstBackoff : _min(_backoff! * 2, maxBackoff);
    _database.markMediaUploadWaitingRetry(item.id, errorCode: code, errorMessage: message, nextAttemptAt: DateTime.now().add(_backoff!));
    // A row's own next_attempt_at only decides whether it is picked up once something asks the queue to run
    // again; without this, nothing would ask again until the next periodic tick (minutes away). This is the
    // media queue's counterpart to SyncCoordinator's own _goOffline scheduling a retry Timer.
    if (_started) {
      _pending?.cancel();
      _pending = Timer(_backoff!, _runNow);
    }
  }

  Duration _min(Duration a, Duration b) => a < b ? a : b;

  /// A membership object for whoever queued this upload - never necessarily the one active right now, since a
  /// file may still be waiting from before a school or role switch. Only `schoolId` and `id` are ever read by
  /// [MediaApi]; the rest is a harmless placeholder.
  SchoolMembership _memberOf(QueuedMediaUpload item) => SchoolMembership(
        id: item.membershipId,
        schoolId: item.tenantId,
        schoolName: '',
        role: SchoolRole.staff,
      );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _backoff = null;
      requestRun(immediately: true);
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

String _extensionFor(String fileName, String mimeType) {
  final dot = fileName.lastIndexOf('.');
  if (dot > 0 && dot < fileName.length - 1) return fileName.substring(dot).toLowerCase();
  return switch (mimeType) {
    'image/png' => '.png',
    'image/jpeg' => '.jpg',
    'image/webp' => '.webp',
    'image/gif' => '.gif',
    'video/mp4' => '.mp4',
    'video/quicktime' => '.mov',
    'video/webm' => '.webm',
    'application/pdf' => '.pdf',
    _ => '',
  };
}
