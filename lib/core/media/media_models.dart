import 'media_json.dart';

/// One file SchoolOS knows about, exactly as the server sent it: its category and kind, its size, whether it has
/// finished being checked, and - never more than this - a caption and a preview. There is no account number, no
/// credential, and no raw filesystem path anywhere in this shape; the server never sends one.
class MediaAsset {
  const MediaAsset({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    required this.category,
    required this.fileName,
    required this.mimeType,
    required this.mediaType,
    required this.byteSize,
    required this.visibility,
    required this.status,
    required this.failureCode,
    required this.caption,
    required this.width,
    required this.height,
    required this.hasThumbnail,
    required this.uploadedByMembershipId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  factory MediaAsset.fromJson(Map<String, dynamic> json) => MediaAsset(
        id: json['id'] as String? ?? '',
        ownerType: json['ownerType'] as String? ?? '',
        ownerId: json['ownerId'] as String? ?? '',
        category: json['category'] as String? ?? '',
        fileName: json['fileName'] as String? ?? '',
        mimeType: json['mimeType'] as String? ?? '',
        mediaType: json['mediaType'] as String? ?? '',
        byteSize: (json['byteSize'] as num?)?.toInt() ?? 0,
        visibility: json['visibility'] as String? ?? 'private',
        status: json['status'] as String? ?? '',
        failureCode: json['failureCode'] as String? ?? '',
        caption: json['caption'] as String? ?? '',
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
        hasThumbnail: json['hasThumbnail'] == true,
        uploadedByMembershipId: json['uploadedByMembershipId'] as String?,
        createdAt: readTime(json['createdAt']),
        updatedAt: readTime(json['updatedAt']),
        version: (json['version'] as num?)?.toInt() ?? 1,
      );

  final String id;
  final String ownerType;
  final String ownerId;
  final String category;
  final String fileName;
  final String mimeType;
  final String mediaType;
  final int byteSize;
  final String visibility;
  final String status;
  final String failureCode;
  final String caption;
  final int? width;
  final int? height;
  final bool hasThumbnail;
  final String? uploadedByMembershipId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int version;

  bool get isImage => mediaType == 'image';
  bool get isVideo => mediaType == 'video';

  /// The server has finished checking it and it can be shown/opened. A file can exist (be `uploaded` or
  /// `verified`) without being this yet - never described to a person as ready before it truly is.
  bool get isAvailable => status == 'available';
  bool get isFailed => status == 'failed' || status == 'quarantined';
}

/// How a device should get a file's bytes into storage, exactly as the server said - see MediaUploadQueue for
/// what each mode means and what the app does with it. Never carries a credential: a presigned URL is
/// self-contained and short-lived by the time this reaches the app.
class MediaUploadInstructions {
  const MediaUploadInstructions({required this.mode, required this.uploadUrl, required this.method, required this.headers, required this.expiresAt});

  factory MediaUploadInstructions.fromJson(Map<String, dynamic> json) => MediaUploadInstructions(
        mode: json['mode'] as String? ?? 'direct',
        uploadUrl: json['uploadUrl'] as String? ?? '',
        method: json['method'] as String? ?? 'PUT',
        headers: {for (final e in readMap(json['headers']).entries) e.key: '${e.value}'},
        expiresAt: readTime(json['expiresAt']),
      );

  final String mode;
  final String uploadUrl;
  final String method;
  final Map<String, String> headers;
  final DateTime? expiresAt;
}

/// Where to read a file's bytes back from. `mode == "redirect"`: open [url] directly, no further token needed.
/// `mode == "stream"`: [url] is one more of the school server's own addresses, fetched the same authenticated way
/// as anything else.
class MediaDownloadInfo {
  const MediaDownloadInfo({required this.mode, required this.url, required this.mimeType, required this.expiresAt});

  factory MediaDownloadInfo.fromJson(Map<String, dynamic> json) => MediaDownloadInfo(
        mode: json['mode'] as String? ?? 'stream',
        url: json['url'] as String? ?? '',
        mimeType: json['mimeType'] as String? ?? '',
        expiresAt: readTime(json['expiresAt']),
      );

  final String mode;
  final String url;
  final String mimeType;
  final DateTime? expiresAt;
}
