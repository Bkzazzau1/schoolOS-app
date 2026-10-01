import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/noticeboard/data/noticeboard_policy_copy.dart';
import 'package:schoolos_app/features/noticeboard/domain/noticeboard_models.dart';

List<NoticeboardNotice> _notices() => [
      NoticeboardNotice(
        id: 'NB-TEST-1',
        title: 'School closes at 12:00 PM on Friday',
        body: 'All academic sections will close at 12:00 PM on Friday for staff professional development.',
        author: 'School Proprietor Office',
        role: 'Proprietor',
        priority: NoticePriority.important,
        audience: NoticeAudience.wholeSchool,
        publishedLabel: 'Today · 8:00 AM',
        expiresLabel: 'Friday · 6:00 PM',
        acknowledgementRequired: true,
        readCount: 921,
        totalRecipients: 1084,
        pinned: true,
        createdAt: DateTime.utc(2026, 9, 19, 8),
      ),
      NoticeboardNotice(
        id: 'NB-TEST-2',
        title: 'JSS 3 mock examination timetable released',
        body: 'The mock examination timetable is now available.',
        author: 'Mr. Ibrahim Danladi',
        role: 'Principal · Secondary',
        priority: NoticePriority.normal,
        audience: NoticeAudience.jss3,
        publishedLabel: 'Yesterday · 3:30 PM',
        expiresLabel: '30 Sep 2026',
        acknowledgementRequired: false,
        readCount: 148,
        totalRecipients: 176,
        pinned: false,
        createdAt: DateTime.utc(2026, 9, 18, 15, 30),
      ),
      NoticeboardNotice(
        id: 'NB-TEST-3',
        title: 'Primary water interruption notice',
        body: 'A short water-supply interruption is expected between 10:00 and 11:00 AM.',
        author: 'Mrs. Hauwa Sule',
        role: 'Headmistress · Primary',
        priority: NoticePriority.important,
        audience: NoticeAudience.primary,
        publishedLabel: 'Today · 7:40 AM',
        expiresLabel: 'Today · 1:00 PM',
        acknowledgementRequired: false,
        readCount: 302,
        totalRecipients: 386,
        pinned: true,
        createdAt: DateTime.utc(2026, 9, 19, 7, 40),
      ),
    ];

void main() {
  test('Noticeboard has seven audiences and three priorities', () {
    expect(NoticeAudience.values.length, 7);
    expect(NoticePriority.values.map((p) => p.label).toList(), ['Normal', 'Important', 'Emergency']);
  });

  test('Noticeboard filtering searches and prioritizes pinned notices', () {
    final notices = _notices();
    final primary = filterNotices(notices: notices, audience: NoticeAudience.primary);
    expect(primary.single.id, 'NB-TEST-3');

    final mock = filterNotices(notices: notices, query: 'mock examination');
    expect(mock.single.id, 'NB-TEST-2');

    final all = filterNotices(notices: notices);
    expect(all.take(2).every((n) => n.pinned), isTrue);
  });

  test('Noticeboard serialization preserves authority and delivery fields', () {
    final original = _notices().first;
    final restored = NoticeboardNotice.fromJson(original.toJson());
    expect(restored.id, original.id);
    expect(restored.priority, NoticePriority.important);
    expect(restored.audience, NoticeAudience.wholeSchool);
    expect(restored.acknowledgementRequired, isTrue);
    expect(restored.pinned, isTrue);
    expect(restored.readRate, closeTo(921 / 1084, 0.000001));
  });

  test('publishing authority and delivery policy match website scope', () {
    expect(noticeboardPublishingAuthority.length, 5);
    expect(noticeboardPublishingAuthority.first.$1, 'Proprietor');
    expect(noticeboardDeliveryChannels.length, 3);
    expect(noticeboardBoundary, contains('authoritative'));
    expect(noticeboardBoundary, contains('Community'));
  });
}
