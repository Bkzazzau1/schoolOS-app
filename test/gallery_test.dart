import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/gallery/data/gallery_demo_data.dart';
import 'package:schoolos_app/features/gallery/domain/gallery_models.dart';

void main() {
  test('gallery seed matches the website media library', () {
    expect(galleryWebsiteSeed, hasLength(4));
    expect(galleryWebsiteSeed.map((item) => item.id).toList(), [
      'GAL-001',
      'GAL-002',
      'GAL-003',
      'GAL-004',
    ]);
    expect(galleryMediaItemTotal, 107);
    expect(galleryParentVisibleTotal, 74);
    expect(galleryPublicShowcaseTotal, 19);
  });

  test('visibility scope is internal, parents and public showcase', () {
    expect(GalleryVisibility.values.map((item) => item.label).toList(), [
      'Internal',
      'Parents',
      'Public showcase',
    ]);
    expect(galleryWebsiteSeed[2].visibility, GalleryVisibility.publicShowcase);
    expect(galleryWebsiteSeed[2].consent, 'Approved media set');
  });

  test('search and visibility filtering match website behavior', () {
    final robotics = galleryWebsiteSeed[2];
    expect(robotics.matches('robotics', null), isTrue);
    expect(robotics.matches('ict department', null), isTrue);
    expect(robotics.matches('', GalleryVisibility.publicShowcase), isTrue);
    expect(robotics.matches('', GalleryVisibility.parents), isFalse);
  });

  test('gallery serialization round-trips privacy metadata', () {
    final source = galleryWebsiteSeed.first;
    final restored = GalleryMediaItem.fromJson(source.toJson());
    expect(restored.title, source.title);
    expect(restored.audience, source.audience);
    expect(restored.visibility, source.visibility);
    expect(restored.consent, source.consent);
    expect(restored.count, source.count);
  });

  test('media safety and production boundaries remain explicit', () {
    expect(gallerySafetyRules['Audience first'], contains('distinct'));
    expect(gallerySafetyRules['Consent-aware'], contains('guardian/media permissions'));
    expect(gallerySafetyRules['No automatic public posting'], contains('explicit approval'));
    // The album record itself is honestly real, only the file storage isn't.
    expect(galleryProductionBoundary, contains('Album records'));
    expect(galleryProductionBoundary, contains('real and sync'));
    expect(galleryProductionBoundary, contains('signed URL'));
  });

  test('every seeded album is tied to a real academic term, not free text', () {
    expect(galleryWebsiteSeed.every((item) => item.hasCanonicalTerm), isTrue);
  });

  test('stats are computed live from the albums, not a stale hardcoded count', () {
    final stats = galleryStats(galleryWebsiteSeed);
    expect(stats.first.value, '4');
    expect(stats[1].value, '107');
    expect(stats[2].value, '74');
    expect(stats[3].value, '19');

    final withOneMore = [
      ...galleryWebsiteSeed,
      galleryWebsiteSeed.first,
    ];
    expect(galleryStats(withOneMore).first.value, '5');
  });
}
