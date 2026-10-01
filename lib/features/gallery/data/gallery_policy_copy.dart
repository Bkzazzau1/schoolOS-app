import '../domain/gallery_models.dart';

/// Static guidance copy for the Media Gallery - not data about this school, so it never needs a
/// real backend source. Real activity (albums) lives in [GalleryRepository] instead.
const gallerySafetyRules = <String, String>{
  'Audience first': 'Internal, parent and public visibility are distinct.',
  'Consent-aware': 'Child media should respect configured guardian/media permissions.',
  'No automatic public posting': 'Public showcase requires explicit approval.',
};

const galleryProductionBoundary =
    'Album details include the term, class, audience and consent status. '
    'The media count is entered manually and may differ from the files attached to an album.';

/// Computed entirely from [items] - the real, locally-held albums a school has actually created,
/// never fixed sample counts.
List<GalleryStat> galleryStats(List<GalleryMediaItem> items) => [
      GalleryStat('Albums', '${items.length}', 'Recorded for this school'),
      GalleryStat(
        'Media items',
        '${items.fold<int>(0, (sum, item) => sum + item.count)}',
        'Manually entered counts, not real files',
      ),
      GalleryStat(
        'Parent visible',
        '${items.where((item) => item.visibility == GalleryVisibility.parents).fold<int>(0, (sum, item) => sum + item.count)}',
        'Across approved albums',
      ),
      GalleryStat(
        'Public showcase',
        '${items.where((item) => item.visibility == GalleryVisibility.publicShowcase).fold<int>(0, (sum, item) => sum + item.count)}',
        'Separately approved by leadership',
      ),
      GalleryStat(
        'No term linked',
        '${items.where((item) => !item.hasCanonicalTerm).length}',
        'Legacy albums recorded before term linking',
      ),
    ];
