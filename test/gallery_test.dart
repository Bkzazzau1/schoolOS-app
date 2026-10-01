import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/gallery/data/gallery_policy_copy.dart';
import 'package:schoolos_app/features/gallery/domain/gallery_models.dart';

List<GalleryMediaItem> _items() => const [
      GalleryMediaItem(
        id: 'GAL-TEST-001',
        title: 'Inter-House Sports Highlights',
        album: 'Sports Day',
        audience: 'Whole school',
        owner: 'Sports Committee',
        date: '20 Sep 2026',
        count: 48,
        visibility: GalleryVisibility.parents,
        consent: 'Checked',
        note: 'Approved athletics and team images available to school families.',
        termId: 'term-1',
        termName: 'First Term',
        sessionName: '2026/2027',
      ),
      GalleryMediaItem(
        id: 'GAL-TEST-002',
        title: 'Robotics Showcase',
        album: 'Coding & Robotics',
        audience: 'Coding & Robotics Club',
        owner: 'ICT Department',
        date: '18 Sep 2026',
        count: 19,
        visibility: GalleryVisibility.publicShowcase,
        consent: 'Approved media set',
        note: 'Selected showcase images cleared for public school promotion.',
        termId: 'term-1',
        termName: 'First Term',
        sessionName: '2026/2027',
        excursionId: 'trip-robotics',
        excursionTitle: 'Robotics Inter-School Showcase',
      ),
      GalleryMediaItem(
        id: 'GAL-TEST-003',
        title: 'Science Discovery Trip Album',
        album: 'Science Discovery Trip',
        audience: 'JSS 2A',
        owner: 'Science Department',
        date: '27 Sep 2026',
        count: 22,
        visibility: GalleryVisibility.parents,
        consent: 'Checked',
        note: 'Photos from the JSS 2A visit to Kaduna Science Centre.',
        termId: 'term-1',
        termName: 'First Term',
        sessionName: '2026/2027',
        classId: 'class-jss2a',
        className: 'JSS 2A',
        excursionId: 'trip-science',
        excursionTitle: 'Science Discovery Trip',
      ),
    ];

void main() {
  test('visibility scope is internal, parents and public showcase', () {
    expect(GalleryVisibility.values.map((item) => item.label).toList(), [
      'Internal',
      'Parents',
      'Public showcase',
    ]);
    expect(_items()[1].visibility, GalleryVisibility.publicShowcase);
    expect(_items()[1].consent, 'Approved media set');
  });

  test('search and visibility filtering match expected behavior', () {
    final robotics = _items()[1];
    expect(robotics.matches('robotics', null), isTrue);
    expect(robotics.matches('ict department', null), isTrue);
    expect(robotics.matches('', GalleryVisibility.publicShowcase), isTrue);
    expect(robotics.matches('', GalleryVisibility.parents), isFalse);
  });

  test('gallery serialization round-trips privacy metadata', () {
    final source = _items().first;
    final restored = GalleryMediaItem.fromJson(source.toJson());
    expect(restored.title, source.title);
    expect(restored.audience, source.audience);
    expect(restored.visibility, source.visibility);
    expect(restored.consent, source.consent);
    expect(restored.count, source.count);
  });

  test('media safety and manually entered counts remain clear', () {
    expect(gallerySafetyRules['Audience first'], contains('distinct'));
    expect(gallerySafetyRules['Consent-aware'], contains('guardian/media permissions'));
    expect(gallerySafetyRules['No automatic public posting'], contains('explicit approval'));
    expect(galleryProductionBoundary, contains('entered manually'));
    expect(galleryProductionBoundary, contains('may differ from the files'));
    expect(galleryProductionBoundary, isNot(contains('signed URL')));
  });

  test('a real album is tied to a real academic term, not free text', () {
    expect(_items().every((item) => item.hasCanonicalTerm), isTrue);
  });

  test('stats are computed live from the albums, not a stale hardcoded count', () {
    final items = _items();
    final stats = galleryStats(items);
    expect(stats.first.value, '3');
    expect(stats[1].value, '89');
    expect(stats[2].value, '70');
    expect(stats[3].value, '19');

    final withOneMore = [...items, items.first];
    expect(galleryStats(withOneMore).first.value, '4');

    final empty = galleryStats(const []);
    expect(empty.every((s) => s.value == '0'), isTrue);
  });

  test('the science trip album is linked to its real excursion and class', () {
    final album = _items().firstWhere((item) => item.id == 'GAL-TEST-003');
    expect(album.excursionId, 'trip-science');
    expect(album.className, 'JSS 2A');
    expect(album.hasCanonicalTerm, isTrue);
  });
}
