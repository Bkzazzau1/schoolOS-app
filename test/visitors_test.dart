import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/visitors/data/visitor_policy_copy.dart';
import 'package:schoolos_app/features/visitors/domain/visitor_models.dart';

List<VisitorRecord> _visits() => const [
      VisitorRecord(
        id: 'VIS-TEST-101',
        visitor: 'Mrs. Zainab Ahmed',
        organization: 'Parent / Guardian',
        purpose: 'Scheduled meeting',
        host: 'Primary Office',
        area: 'Primary reception',
        arrival: '9:10 AM',
        departure: '10:02 AM',
        status: VisitStatus.checkedOut,
        pass: 'V-101',
        note: 'Scheduled guardian meeting; normal checkout completed.',
      ),
      VisitorRecord(
        id: 'VIS-TEST-102',
        visitor: 'Mr. Samuel Okoro',
        organization: 'EduTech Services',
        purpose: 'ICT maintenance',
        host: 'ICT Department',
        area: 'ICT Lab',
        arrival: '10:25 AM',
        departure: '—',
        status: VisitStatus.onCampus,
        pass: 'V-102',
        note: 'Vendor access limited to approved work area with staff host.',
      ),
      VisitorRecord(
        id: 'VIS-TEST-103',
        visitor: 'Dr. Mary James',
        organization: 'Guest speaker',
        purpose: 'Career talk',
        host: 'Principal Office',
        area: 'Assembly Hall',
        arrival: 'Expected 12:15 PM',
        departure: '—',
        status: VisitStatus.expected,
        pass: 'Pre-reg',
        note: 'Pre-registered guest for Secondary programme.',
      ),
    ];

void main() {
  test('visitor stats are computed entirely from the real visits given, never a fixed sample', () {
    final stats = visitorStats(_visits());
    expect(stats[0].value, '3');
    expect(stats[1].value, '1');
    expect(stats[2].value, '1');
    expect(stats[3].value, '1');

    final empty = visitorStats(const []);
    expect(empty.every((s) => s.value == '0'), isTrue);
  });

  test('visitor statuses and operational fields are preserved', () {
    final vendor = _visits().singleWhere((visit) => visit.id == 'VIS-TEST-102');
    final guest = _visits().singleWhere((visit) => visit.id == 'VIS-TEST-103');

    expect(vendor.status, VisitStatus.onCampus);
    expect(vendor.area, 'ICT Lab');
    expect(vendor.pass, 'V-102');
    expect(vendor.host, 'ICT Department');
    expect(guest.status, VisitStatus.expected);
    expect(guest.pass, 'Pre-reg');
  });

  test('visitor search and status filters match expected behavior', () {
    final guardian = _visits().first;
    final vendor = _visits()[1];

    expect(guardian.matches('zainab', null), isTrue);
    expect(guardian.matches('scheduled meeting', null), isTrue);
    expect(guardian.matches('primary office', null), isTrue);
    expect(guardian.matches('zainab', VisitStatus.onCampus), isFalse);
    expect(vendor.matches('edutech', VisitStatus.onCampus), isTrue);
  });

  test('copyWith only changes the fields given', () {
    final reviewed = _visits().first.copyWith(frontDeskReviewed: true, status: VisitStatus.review);
    final restored = VisitorRecord.fromJson(reviewed.toJson());

    expect(restored.frontDeskReviewed, isTrue);
    expect(restored.status, VisitStatus.review);
    expect(restored.id, reviewed.id);
    expect(restored.visitor, 'Mrs. Zainab Ahmed');
  });

  test('visitor records do not contain child pickup authorization', () {
    final json = _visits().first.toJson();

    expect(json.containsKey('childPickupAuthorized'), isFalse);
    expect(json.containsKey('studentRelationship'), isFalse);
    expect(json.containsKey('pickupStudentId'), isFalse);
    expect(visitorPickupBoundary, contains('does not authorize child pickup'));
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
