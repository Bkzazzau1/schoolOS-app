import 'package:flutter/material.dart';

import '../../../core/media/media_api.dart';
import '../../../core/media/media_upload_queue.dart';
import '../../../core/media/presentation/media_attachments_panel.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/gallery_models.dart';

/// One album's real photos and videos - the first real consumer of SchoolOS's shared media service. The album
/// record itself (its title, term, visibility) stays exactly what GalleryRepository already keeps; this page only
/// adds what is actually IN it.
///
/// Online only: a photo's real bytes, its checksum and whether it has been checked all only exist on the school
/// server. Without one, this page is never reached - see GalleryPage, which offers "Open" only when a server does.
class GalleryAlbumMediaPage extends StatelessWidget {
  const GalleryAlbumMediaPage({
    super.key,
    required this.membership,
    required this.album,
    required this.permissions,
    required this.api,
    required this.queue,
  });

  final SchoolMembership membership;
  final GalleryMediaItem album;
  final GalleryPermissions permissions;
  final MediaApi api;
  final MediaUploadQueue queue;

  @override
  Widget build(BuildContext context) {
    final mayManageThisAlbum = permissions.canManage;
    return Scaffold(
      appBar: AppBar(title: Text(album.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(album.album, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${album.termName.isEmpty ? '' : '${album.termName} · '}${album.visibility.label} · ${album.audience}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          MediaAttachmentsPanel(
            api: api,
            queue: queue,
            membership: membership,
            ownerType: 'gallery_media_album',
            ownerId: album.id,
            canContribute: permissions.canCreateAlbum,
            canManage: mayManageThisAlbum,
            emptyLabel: 'No photos or videos added yet.',
            tileSize: 110,
            options: const [
              MediaAttachmentOption(label: 'Add photo', category: 'gallery_photo', mediaType: 'image', icon: Icons.add_photo_alternate_outlined),
              MediaAttachmentOption(label: 'Add video', category: 'gallery_video', mediaType: 'video', icon: Icons.videocam_outlined),
            ],
          ),
        ],
      ),
    );
  }
}
