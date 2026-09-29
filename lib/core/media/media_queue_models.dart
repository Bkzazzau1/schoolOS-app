/// Where one queued upload stands. A file is never shown as "uploaded" until the server has said so - `waiting`
/// and `uploading` both mean "only on this phone so far", whatever the screen that started it might otherwise
/// suggest.
enum MediaUploadState {
  /// Copied into this app's own storage, waiting for its turn (or for a network) to be sent.
  waiting,

  /// Being sent right now.
  uploading,

  /// The server has confirmed it. [QueuedMediaUpload.serverAssetId] is the real, canonical file from here on.
  uploaded,

  /// The server refused it outright (a bad file, a size or type it will never accept) or every retry was used up.
  /// Never retried automatically again; a person may still choose to retry by hand.
  failed,
}

MediaUploadState mediaUploadStateFrom(String value) => MediaUploadState.values.firstWhere(
      (s) => s.name == value,
      orElse: () => MediaUploadState.waiting,
    );

/// One file on its way from this phone to the school's server: its own bytes already safe in this app's storage
/// (so a picker's own temporary handle can never lose them), and where it stands in being sent.
class QueuedMediaUpload {
  const QueuedMediaUpload({
    required this.id,
    required this.tenantId,
    required this.membershipId,
    required this.ownerType,
    required this.ownerId,
    required this.category,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
    required this.sha256,
    required this.localPath,
    required this.caption,
    required this.visibility,
    required this.state,
    required this.serverAssetId,
    required this.serverStatus,
    required this.attemptCount,
    required this.nextAttemptAt,
    required this.lastErrorCode,
    required this.lastErrorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String membershipId;
  final String ownerType;
  final String ownerId;
  final String category;
  final String fileName;
  final String mimeType;
  final int byteSize;
  final String sha256;

  /// Where the file's real bytes live on this device - never a picker's own temporary handle, which can stop
  /// working the moment the picker screen closes.
  final String localPath;
  final String caption;
  final String visibility;
  final MediaUploadState state;

  /// The real, server-issued id, once [state] is [MediaUploadState.uploaded]. Null until then.
  final String? serverAssetId;

  /// The server's own status word for it (e.g. "available", "verified") once known - for showing the same
  /// "not ready yet" wording the rest of the app uses for a file that exists but has not finished being checked.
  final String? serverStatus;
  final int attemptCount;
  final DateTime? nextAttemptAt;
  final String? lastErrorCode;
  final String? lastErrorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLocalOnly => state == MediaUploadState.waiting || state == MediaUploadState.uploading;
}
