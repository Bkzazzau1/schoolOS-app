import '../domain/gallery_models.dart';

const galleryWebsiteSeed = <GalleryMediaItem>[
  GalleryMediaItem(
    id: 'GAL-001',
    title: 'Inter-House Sports Highlights',
    album: 'Sports Day',
    audience: 'Whole school',
    owner: 'Sports Committee',
    date: '10 Sep 2026',
    count: 48,
    visibility: GalleryVisibility.parents,
    consent: 'Checked',
    note: 'Approved athletics and team images available to school families.',
  ),
  GalleryMediaItem(
    id: 'GAL-002',
    title: 'Early Years Creative Morning',
    album: 'Early Years',
    audience: 'Early Years families',
    owner: 'Mrs. Mary Daniel',
    date: '9 Sep 2026',
    count: 26,
    visibility: GalleryVisibility.parents,
    consent: 'Checked',
    note: 'Classroom activity images with guardian-visibility controls.',
  ),
  GalleryMediaItem(
    id: 'GAL-003',
    title: 'Robotics Showcase',
    album: 'Coding & Robotics',
    audience: 'Whole school',
    owner: 'ICT Department',
    date: '8 Sep 2026',
    count: 19,
    visibility: GalleryVisibility.publicShowcase,
    consent: 'Approved media set',
    note: 'Selected showcase images cleared for public school promotion.',
  ),
  GalleryMediaItem(
    id: 'GAL-004',
    title: 'Staff Development Workshop',
    album: 'Staff',
    audience: 'Staff only',
    owner: 'Proprietor Office',
    date: '6 Sep 2026',
    count: 14,
    visibility: GalleryVisibility.internal,
    consent: 'Not applicable',
    note: 'Internal professional-development media.',
  ),
];

const galleryStats = <GalleryStat>[
  GalleryStat('Albums', '4', 'Representative UI albums'),
  GalleryStat('Media items', '107', 'Photos/videos represented'),
  GalleryStat('Parent visible', '74', 'Across approved albums'),
  GalleryStat('Public showcase', '19', 'Separately approved'),
  GalleryStat('Consent review', '0', 'Current mock set clear'),
];

const gallerySafetyRules = <String, String>{
  'Audience first': 'Internal, parent and public visibility are distinct.',
  'Consent-aware': 'Child media should respect configured guardian/media permissions.',
  'No automatic public posting': 'Public showcase requires explicit approval.',
};

const galleryProductionBoundary =
    'Actual uploads, secure storage, signed URLs, moderation and consent enforcement are not implemented in this UI phase.';

int get galleryMediaItemTotal =>
    galleryWebsiteSeed.fold<int>(0, (sum, item) => sum + item.count);

int get galleryParentVisibleTotal => galleryWebsiteSeed
    .where((item) => item.visibility == GalleryVisibility.parents)
    .fold<int>(0, (sum, item) => sum + item.count);

int get galleryPublicShowcaseTotal => galleryWebsiteSeed
    .where((item) => item.visibility == GalleryVisibility.publicShowcase)
    .fold<int>(0, (sum, item) => sum + item.count);
