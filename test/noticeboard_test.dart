import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/noticeboard/data/noticeboard_demo_data.dart';
import 'package:schoolos_app/features/noticeboard/domain/noticeboard_models.dart';

void main() {
  test('website Noticeboard seed data and KPIs are preserved', () {
    expect(noticeboardSeedNotices.length, 4);
    expect(noticeboardSeedNotices.where((n) => n.pinned).length, 2);
    expect(noticeboardSeedNotices.where((n) => n.acknowledgementRequired).length, 1);
    expect(noticeboardAverageReadRate, 82);
    expect(noticeboardScheduledCount, 3);
    expect(noticeboardSeedNotices.first.id, 'NB-001');
    expect(noticeboardSeedNotices.first.readCount, 921);
    expect(noticeboardSeedNotices.first.totalRecipients, 1084);
  });

  test('Noticeboard has seven audiences and three priorities', () {
    expect(NoticeAudience.values.length, 7);
    expect(NoticePriority.values.map((p) => p.label).toList(), ['Normal', 'Important', 'Emergency']);
  });

  test('Noticeboard filtering searches and prioritizes pinned notices', () {
    final primary = filterNotices(notices: noticeboardSeedNotices, audience: NoticeAudience.primary);
    expect(primary.single.id, 'NB-004');

    final mock = filterNotices(notices: noticeboardSeedNotices, query: 'mock examination');
    expect(mock.single.id, 'NB-002');

    final all = filterNotices(notices: noticeboardSeedNotices);
    expect(all.take(2).every((n) => n.pinned), isTrue);
  });

  test('Noticeboard serialization preserves authority and delivery fields', () {
    final original = noticeboardSeedNotices.first;
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
