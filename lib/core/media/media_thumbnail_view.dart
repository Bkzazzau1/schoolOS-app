import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../shared/models/school_membership.dart';
import 'media_api.dart';
import 'media_models.dart';

/// A file's preview: its thumbnail once the server has built one, an icon for anything else (a video, a document,
/// or an image not ready yet) - never a placeholder that could be mistaken for a real photo. Works the same way
/// whichever storage backend the school server uses: it always asks [MediaApi.downloadInfo] first and only then
/// reads the bytes, from wherever that call says to.
class MediaThumbnailView extends StatefulWidget {
  const MediaThumbnailView({super.key, required this.api, required this.membership, required this.asset, this.size = 64});

  final MediaApi api;
  final SchoolMembership membership;
  final MediaAsset asset;
  final double size;

  @override
  State<MediaThumbnailView> createState() => _MediaThumbnailViewState();
}

class _MediaThumbnailViewState extends State<MediaThumbnailView> {
  Future<Object>? _future; // either a String (an openable url) or bytes (List<int>) to show with Image.memory

  /// Whether the server could ever have built a real preview for this asset - an image always gets one; a video
  /// only where the school's own server has a real transcoder installed (see the backend's transcoding.py),
  /// which [MediaAsset.hasThumbnail] already reflects either way - this never assumes on its own.
  bool get _mayHaveThumbnail => widget.asset.isImage || widget.asset.isVideo;

  @override
  void initState() {
    super.initState();
    if (_mayHaveThumbnail && widget.asset.hasThumbnail) _future = _load();
  }

  @override
  void didUpdateWidget(MediaThumbnailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.asset.id != oldWidget.asset.id || (widget.asset.hasThumbnail && !oldWidget.asset.hasThumbnail)) {
      _future = _mayHaveThumbnail && widget.asset.hasThumbnail ? _load() : null;
    }
  }

  Future<Object> _load() async {
    final info = await widget.api.downloadInfo(widget.membership, widget.asset.id, thumbnail: true);
    if (info.mode == 'redirect') return info.url;
    return await widget.api.streamBytes(widget.membership, info.url);
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: future == null
            ? _placeholder(context)
            : FutureBuilder<Object>(
                future: future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return _placeholder(context, loading: !snapshot.hasError);
                  final data = snapshot.data!;
                  final image = data is String ? Image.network(data, fit: BoxFit.cover) : Image.memory(_bytes(data), fit: BoxFit.cover);
                  return image;
                },
              ),
      ),
    );
  }

  Uint8List _bytes(Object data) => Uint8List.fromList(data as List<int>);

  Widget _placeholder(BuildContext context, {bool loading = false}) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHigh,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(_iconFor(widget.asset), color: theme.colorScheme.onSurfaceVariant),
    );
  }

  IconData _iconFor(MediaAsset asset) => switch (asset.mediaType) {
        'video' => Icons.videocam_outlined,
        'audio' => Icons.audiotrack_outlined,
        'image' => Icons.image_outlined,
        _ => Icons.insert_drive_file_outlined,
      };
}
