import 'package:flutter/widgets.dart';

import '../../shared/models/school_membership.dart';
import '../network/api_client.dart';
import 'media_json.dart';
import 'media_models.dart';
import 'media_upload_queue.dart';

/// Talks to SchoolOS's one canonical file/media service. Every feature that shows or attaches a real file - the
/// school logo excepted, still its own small path for now - goes through this, never a feature-specific upload
/// of its own.
///
/// Online only, on purpose: a file's real bytes, its checksum and its verification only exist once the server has
/// them. What happens before that (copying a picked file into this app's own storage, queuing it, retrying) is
/// [MediaUploadQueue]'s job, not this client's.
class MediaApi {
  MediaApi({required ApiClient api}) : _api = api;

  final ApiClient _api;

  String _base(SchoolMembership m) => 'schools/${m.schoolId}/media/';
  Map<String, String> _who(SchoolMembership m) => {'membership': m.id};

  Future<List<MediaAsset>> list(SchoolMembership m, {required String ownerType, required String ownerId}) async {
    final data = readMap(
      await _api.get('${_base(m)}assets/', query: {..._who(m), 'ownerType': ownerType, 'ownerId': ownerId}),
    );
    return [for (final a in readMaps(data['assets'])) MediaAsset.fromJson(a)];
  }

  Future<MediaAsset> get(SchoolMembership m, String assetId) async =>
      MediaAsset.fromJson(readMap(readMap(await _api.get('${_base(m)}assets/$assetId/', query: _who(m)))['asset']));

  /// Starts an upload: the server makes a place for the file and says how to get its bytes there (see
  /// [MediaUploadInstructions]). Nothing about the file exists anywhere but this one row until its bytes really
  /// arrive.
  Future<(MediaAsset, MediaUploadInstructions)> initiate(
    SchoolMembership m, {
    required String ownerType,
    required String ownerId,
    required String category,
    required String fileName,
    required String mimeType,
    required int byteSize,
    required String sha256,
    String caption = '',
    String visibility = 'private',
  }) async {
    final data = readMap(
      await _api.post(
        '${_base(m)}assets/',
        query: _who(m),
        body: {
          'ownerType': ownerType,
          'ownerId': ownerId,
          'category': category,
          'fileName': fileName,
          'mimeType': mimeType,
          'byteSize': byteSize,
          'sha256': sha256,
          'caption': caption,
          'visibility': visibility,
        },
      ),
    );
    return (MediaAsset.fromJson(readMap(data['asset'])), MediaUploadInstructions.fromJson(readMap(data['upload'])));
  }

  /// PUTs bytes to a LOCAL-storage upload address (one of this server's own, relative). An object-storage
  /// (presigned) address is never sent through this client at all - it needs no SchoolOS token, and sending one
  /// would only leak it to a URL that is not SchoolOS's own. See MediaUploadQueue for the full flow.
  Future<void> uploadDirect(MediaUploadInstructions instructions, List<int> bytes, {required String mimeType}) =>
      _api.putBytes(instructions.uploadUrl, bytes, mimeType: mimeType);

  Future<MediaAsset> complete(SchoolMembership m, String assetId) async =>
      MediaAsset.fromJson(readMap(readMap(await _api.post('${_base(m)}assets/$assetId/complete/', query: _who(m)))['asset']));

  Future<MediaDownloadInfo> downloadInfo(SchoolMembership m, String assetId, {bool thumbnail = false}) async =>
      MediaDownloadInfo.fromJson(
        readMap(await _api.get('${_base(m)}assets/$assetId/download/', query: {..._who(m), if (thumbnail) 'thumbnail': '1'})),
      );

  /// The real bytes, once [downloadInfo] answered `mode: "stream"` - `url` there is relative to this school's own
  /// media address, exactly as this expects.
  Future<List<int>> streamBytes(SchoolMembership m, String relativeUrl) => _api.getBytes('${_base(m)}$relativeUrl', query: _who(m));

  Future<MediaAsset> retire(SchoolMembership m, String assetId, {String reason = ''}) async =>
      MediaAsset.fromJson(
        readMap(readMap(await _api.post('${_base(m)}assets/$assetId/retire/', query: _who(m), body: {'reason': reason}))['asset']),
      );
}

/// Makes the media service available app-wide: [api] to list, read and retire files, [queue] to pick or capture
/// one and queue it for upload, offline-tolerant, without ever waiting on the network itself. Both are absent
/// together when the app has no school server - a file's real bytes, checksum and verification only exist there,
/// so there is nothing honest to queue towards.
class MediaScope extends InheritedWidget {
  const MediaScope({super.key, required this.api, required this.queue, required super.child});

  final MediaApi api;
  final MediaUploadQueue queue;

  static MediaApi? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<MediaScope>()?.api;

  static MediaUploadQueue? queueOf(BuildContext context) => context.getInheritedWidgetOfExactType<MediaScope>()?.queue;

  @override
  bool updateShouldNotify(MediaScope oldWidget) => api != oldWidget.api || queue != oldWidget.queue;
}
