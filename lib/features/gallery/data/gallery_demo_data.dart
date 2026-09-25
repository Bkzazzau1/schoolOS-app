import '../domain/gallery_models.dart';

// These ids match the current-session/first-term rows seeded by
// AdministratorAcademicsRepository, so an album here links to the same real
// academic-structure records any role would see, not a lookalike.
const _currentSessionName = '2026/2027';
const _firstTermId = '41111111-1111-4111-8111-111111111111';
const _firstTermName = 'First Term';

const galleryWebsiteSeed = <GalleryMediaItem>[
  GalleryMediaItem(
    id: 'GAL-001',
    title: 'Inter-House Sports Highlights',
    album: 'Sports Day',
    audience: 'Whole school',
    owner: 'Sports Committee',
    date: '20 Sep 2026',
    count: 48,
    visibility: GalleryVisibility.parents,
    consent: 'Checked',
    note: 'Approved athletics and team images available to school families.',
    termId: _firstTermId,
    termName: _firstTermName,
    sessionName: _currentSessionName,
  ),
  GalleryMediaItem(
    id: 'GAL-002',
    title: 'Early Years Creative Morning',
    album: 'Early Years',
    audience: 'Early Years families',
    owner: 'Mrs. Mary Daniel',
    date: '19 Sep 2026',
    count: 26,
    visibility: GalleryVisibility.parents,
    consent: 'Checked',
    note: 'Classroom activity images with guardian-visibility controls.',
    termId: _firstTermId,
    termName: _firstTermName,
    sessionName: _currentSessionName,
  ),
  GalleryMediaItem(
    id: 'GAL-003',
    title: 'Robotics Showcase',
    album: 'Coding & Robotics',
    audience: 'Coding & Robotics Club',
    owner: 'ICT Department',
    date: '18 Sep 2026',
    count: 19,
    visibility: GalleryVisibility.publicShowcase,
    consent: 'Approved media set',
    note: 'Selected showcase images cleared for public school promotion.',
    termId: _firstTermId,
    termName: _firstTermName,
    sessionName: _currentSessionName,
    // This is literally "the album in the excursion": the Robotics
    // Inter-School Showcase trip's own photo album.
    excursionId: 'TRIP-004',
    excursionTitle: 'Robotics Inter-School Showcase',
  ),
  GalleryMediaItem(
    id: 'GAL-004',
    title: 'Staff Development Workshop',
    album: 'Staff',
    audience: 'Staff only',
    owner: 'Proprietor Office',
    date: '16 Sep 2026',
    count: 14,
    visibility: GalleryVisibility.internal,
    consent: 'Not applicable',
    note: 'Internal professional-development media.',
    termId: _firstTermId,
    termName: _firstTermName,
    sessionName: _currentSessionName,
  ),
];

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

const gallerySafetyRules = <String, String>{
  'Audience first': 'Internal, parent and public visibility are distinct.',
  'Consent-aware': 'Child media should respect configured guardian/media permissions.',
  'No automatic public posting': 'Public showcase requires explicit approval.',
};

const galleryProductionBoundary =
    'Album records (title, term, class, audience, visibility, consent status) are real and sync to the school\'s '
    'server like any other record. Actual photo/video files are not: there is no upload, secure storage, signed '
    'URL or moderation pipeline yet, so "media items" is a manually entered count, not a real file library.';

int get galleryMediaItemTotal =>
    galleryWebsiteSeed.fold<int>(0, (sum, item) => sum + item.count);

int get galleryParentVisibleTotal => galleryWebsiteSeed
    .where((item) => item.visibility == GalleryVisibility.parents)
    .fold<int>(0, (sum, item) => sum + item.count);

int get galleryPublicShowcaseTotal => galleryWebsiteSeed
    .where((item) => item.visibility == GalleryVisibility.publicShowcase)
    .fold<int>(0, (sum, item) => sum + item.count);
