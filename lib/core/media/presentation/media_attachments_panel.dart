import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../media_api.dart';
import '../media_mime.dart';
import '../media_models.dart';
import '../media_queue_models.dart';
import '../media_thumbnail_view.dart';
import '../media_upload_queue.dart';

/// One kind of file a screen offers to add here - Gallery offers a photo and a video; a staff document row
/// offers one document kind.
class MediaAttachmentOption {
  const MediaAttachmentOption({
    required this.label,
    required this.category,
    required this.mediaType,
    this.icon = Icons.attach_file_rounded,
    this.allowedExtensions,
  });

  final String label;
  final String category;

  /// 'image', 'video' or 'document' - decides which picker SchoolOS opens and how the picked bytes are checked
  /// before they are even queued.
  final String mediaType;
  final IconData icon;

  /// For a document: the extensions accepted (without the dot). Left null for image/video, which pick by kind.
  final List<String>? allowedExtensions;
}

/// What was picked, decoupled from `package:file_picker`'s own type so this panel's picking step can be replaced
/// in a test the same way `proprietor_appearance_page.dart`'s `LogoPicker` already is - real bytes in memory,
/// already read, never a path that might stop working the moment the picker's own screen closes.
class PickedMediaFile {
  const PickedMediaFile({required this.name, required this.extension, required this.bytes});

  final String name;
  final String? extension;
  final Uint8List bytes;
}

typedef MediaFilePicker = Future<PickedMediaFile?> Function(MediaAttachmentOption option);

Future<PickedMediaFile?> pickMediaFileFromDevice(MediaAttachmentOption option) async {
  final fileType = switch (option.mediaType) {
    'image' => FileType.image,
    'video' => FileType.video,
    _ => FileType.custom,
  };
  final file = await FilePicker.pickFile(type: fileType, allowedExtensions: option.allowedExtensions, dialogTitle: option.label);
  if (file == null) return null;
  return PickedMediaFile(name: file.name, extension: file.extension, bytes: await file.readAsBytes());
}

/// The one reusable "files attached to this record" panel: Gallery's album photos and videos, a staff member's
/// onboarding document, an administrator's document record, and anything else that registers an owner kind with
/// the media service (apps/media/registry.py) all show and add their files through this, rather than each
/// screen building its own upload UI.
///
/// Shows the server's own confirmed files and this device's own still-queued or failed ones side by side, never
/// claiming a queued file is uploaded before the server has said so.
class MediaAttachmentsPanel extends StatefulWidget {
  const MediaAttachmentsPanel({
    super.key,
    required this.api,
    required this.queue,
    required this.membership,
    required this.ownerType,
    required this.ownerId,
    required this.canContribute,
    required this.canManage,
    this.options = const [],
    this.emptyLabel = 'No files yet.',
    this.tileSize = 96,
    this.pickFile = pickMediaFileFromDevice,
  });

  final MediaApi api;
  final MediaUploadQueue queue;
  final SchoolMembership membership;
  final String ownerType;
  final String ownerId;
  final bool canContribute;
  final bool canManage;
  final List<MediaAttachmentOption> options;
  final String emptyLabel;
  final double tileSize;
  final MediaFilePicker pickFile;

  @override
  State<MediaAttachmentsPanel> createState() => _MediaAttachmentsPanelState();
}

class _MediaAttachmentsPanelState extends State<MediaAttachmentsPanel> {
  List<MediaAsset>? _assets;
  String? _error;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _load();
    widget.queue.addListener(_onQueueChanged);
  }

  @override
  void dispose() {
    widget.queue.removeListener(_onQueueChanged);
    super.dispose();
  }

  void _onQueueChanged() {
    if (mounted) setState(() {}); // re-reads uploadsForOwner (a plain local read) and re-fetches the server list below
    _load();
  }

  Future<void> _load() async {
    try {
      final assets = await widget.api.list(widget.membership, ownerType: widget.ownerType, ownerId: widget.ownerId);
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  List<QueuedMediaUpload> get _localOnly => widget.queue
      .uploadsForOwner(widget.membership, ownerType: widget.ownerType, ownerId: widget.ownerId)
      .where((u) => u.state != MediaUploadState.uploaded)
      .toList(growable: false);

  Future<void> _pick(MediaAttachmentOption option) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final file = await widget.pickFile(option);
      if (file == null) return;
      final mimeType = mimeTypeForExtension(file.extension, mediaType: option.mediaType);
      if (mimeType == null) {
        _message('SchoolOS does not accept a ${file.extension ?? "that kind of"} file here.');
        return;
      }
      await widget.queue.enqueue(
        membership: widget.membership,
        ownerType: widget.ownerType,
        ownerId: widget.ownerId,
        category: option.category,
        fileName: file.name,
        mimeType: mimeType,
        bytes: file.bytes,
      );
      if (mounted) setState(() {});
    } catch (error) {
      _message('Could not add that file ($error).');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _retire(MediaAsset asset) async {
    final reason = await _askReason(context, title: 'Remove this file?');
    if (reason == null) return;
    try {
      await widget.api.retire(widget.membership, asset.id, reason: reason);
      await _load();
    } catch (error) {
      _message('Could not remove that file ($error).');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final assets = _assets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.canContribute && widget.options.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 8,
              children: [
                for (final option in widget.options)
                  OutlinedButton.icon(
                    key: ValueKey('add-${option.category}'),
                    onPressed: _picking ? null : () => _pick(option),
                    icon: Icon(option.icon, size: 18),
                    label: Text(option.label),
                  ),
              ],
            ),
          ),
        if (assets == null && _error == null) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Could not load files: $_error', key: const ValueKey('attachments-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (assets != null && assets.isEmpty && _localOnly.isEmpty) Text(widget.emptyLabel, key: const ValueKey('attachments-empty')),
        if (assets != null && (assets.isNotEmpty || _localOnly.isNotEmpty))
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final asset in assets) _assetTile(asset),
              for (final queued in _localOnly) _queuedTile(queued),
            ],
          ),
      ],
    );
  }

  Widget _assetTile(MediaAsset asset) {
    final mayRemove = widget.canManage || asset.uploadedByMembershipId == widget.membership.id;
    return SizedBox(
      key: ValueKey('asset-${asset.id}'),
      width: widget.tileSize,
      child: Column(
        children: [
          Stack(
            children: [
              MediaThumbnailView(api: widget.api, membership: widget.membership, asset: asset, size: widget.tileSize),
              if (mayRemove)
                Positioned(
                  right: 0,
                  top: 0,
                  child: InkWell(
                    key: ValueKey('retire-${asset.id}'),
                    onTap: () => _retire(asset),
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(3),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          if (!asset.isAvailable) Text(_statusWord(asset.status), key: ValueKey('asset-status-${asset.id}'), style: const TextStyle(fontSize: 11)),
          if (asset.caption.isNotEmpty) Text(asset.caption, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _queuedTile(QueuedMediaUpload item) {
    return SizedBox(
      key: ValueKey('queued-${item.id}'),
      width: widget.tileSize,
      child: Column(
        children: [
          Container(
            width: widget.tileSize,
            height: widget.tileSize,
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: item.state == MediaUploadState.failed
                ? Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error)
                : const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          Text(
            item.state == MediaUploadState.failed ? 'Failed - not sent yet' : (item.state == MediaUploadState.uploading ? 'Sending...' : 'Waiting to send'),
            key: ValueKey('queued-status-${item.id}'),
            style: const TextStyle(fontSize: 11),
          ),
          if (item.state == MediaUploadState.failed)
            TextButton(
              key: ValueKey('retry-${item.id}'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 24)),
              onPressed: () => widget.queue.retry(item.id),
              child: const Text('Retry', style: TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }

  String _statusWord(String status) => switch (status) {
        'pending_upload' || 'uploaded' => 'Checking...',
        'verified' => 'Almost ready...',
        'failed' => 'Failed',
        'quarantined' => 'Under review',
        _ => status,
      };

  Future<String?> _askReason(BuildContext context, {required String title}) =>
      showDialog<String>(context: context, builder: (_) => _ReasonDialog(title: title));
}

/// Owns its own text controller, so it is disposed only once this dialog has truly left the screen: disposing it
/// the moment the dialog is popped would leave the closing animation drawing a text field whose controller is
/// already gone.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title});

  final String title;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(key: const ValueKey('remove-reason'), controller: _controller, decoration: const InputDecoration(hintText: 'Why?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(key: const ValueKey('remove-confirm'), onPressed: () => Navigator.pop(context, _controller.text.trim()), child: const Text('Remove')),
        ],
      );
}
