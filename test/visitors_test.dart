import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/visitors/data/visitor_demo_data.dart';
import 'package:schoolos_app/features/visitors/domain/visitor_models.dart';

void main() {
  test('website visitor seed preserves register and KPI totals', () {
    expect(visitorWebsiteSeed, hasLength(4));

    final stats = visitorStats(visitorWebsiteSeed);
    expect(stats[0].value, '4');
    expect(stats[1].value, '1');
    expect(stats[2].value, '1');
    expect(stats[3].value, '2');
    expect(stats[4].value, '0');
  });

  test('website visitor statuses and operational fields are preserved', () {
    final vendor = visitorWebsiteSeed.singleWhere(
      (visit) => visit.id == 'VIS-102',
    );
    final guest = visitorWebsiteSeed.singleWhere(
      (visit) => visit.id == 'VIS-103',
    );

    expect(vendor.status, VisitStatus.onCampus);
    expect(vendor.area, 'ICT Lab');
    expect(vendor.pass, 'V-102');
    expect(vendor.host, 'ICT Department');
    expect(guest.status, VisitStatus.expected);
    expect(guest.pass, 'Pre-reg');
  });

  test('visitor search and status filters match website behavior', () {
    final guardian = visitorWebsiteSeed.first;
    final vendor = visitorWebsiteSeed[1];

    expect(guardian.matches('zainab', null), isTrue);
    expect(guardian.matches('scheduled meeting', null), isTrue);
    expect(guardian.matches('primary office', null), isTrue);
    expect(guardian.matches('zainab', VisitStatus.onCampus), isFalse);
    expect(vendor.matches('edutech', VisitStatus.onCampus), isTrue);
  });

  test('front-desk review survives serialization', () {
    final reviewed = visitorWebsiteSeed.first.copyWith(
      frontDeskReviewed: true,
    );
    final restored = VisitorRecord.fromJson(reviewed.toJson());

    expect(restored.frontDeskReviewed, isTrue);
    expect(restored.id, reviewed.id);
    expect(restored.status, reviewed.status);
  });

  test('visitor records do not contain child pickup authorization', () {
    final json = visitorWebsiteSeed.first.toJson();

    expect(json.containsKey('childPickupAuthorized'), isFalse);
    expect(json.containsKey('studentRelationship'), isFalse);
    expect(json.containsKey('pickupStudentId'), isFalse);
    expect(visitorPickupBoundary, contains('must not automatically authorize'));
  });

  test('visitor access rules preserve restricted-log boundary', () {
    expect(visitorAccessRules, hasLength(3));
    expect(visitorAccessRules.keys, contains('Host required'));
    expect(visitorAccessRules.keys, contains('Minimum data'));
    expect(visitorAccessRules.keys, contains('Restricted log'));
    expect(
      visitorAccessRules['Restricted log'],
      contains('ordinary students'),
    );
  });
}
