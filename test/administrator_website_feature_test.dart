import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/data/administrator_website_demo_data.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_website_models.dart';

void main() {
  test('website manager seed preserves exact homepage settings', () {
    expect(administratorWebsiteSeed.heroHeadline,
        'A strong beginning. A confident future.');
    expect(
      administratorWebsiteSeed.heroSupportingText,
      'Nursery, Primary and Secondary education in a caring, structured learning environment.',
    );
    expect(administratorWebsiteSeed.admissionsOpen, isTrue);
    expect(administratorWebsiteSeed.admissionSession, '2026/2027');
  });

  test('website manager preserves headline KPI values without a disconnected fixed count', () {
    expect(administratorWebsiteDomain, 'brightgateacademy.ng');
    // Real application and published-notice counts belong to the real Admissions and Notices
    // screens; this settings/preview screen no longer duplicates them with a fixed number.
    expect(administratorWebsiteKpis, hasLength(2));
    expect(administratorWebsiteKpis.map((k) => k.label), ['Domain', 'Admissions']);
  });

  test('all five public website sections are published', () {
    expect(administratorPublicWebsiteSections, hasLength(5));
    expect(
      administratorPublicWebsiteSections.map((item) => item.title),
      containsAll([
        'About the school',
        'Admissions',
        'School Life',
        'News & Notices',
        'Contact',
      ]),
    );
    expect(
      administratorPublicWebsiteSections.every((item) => item.status == 'Published'),
      isTrue,
    );
  });

  test('admissions form preserves four website requirement groups', () {
    expect(administratorAdmissionFormRequirements, hasLength(4));
    expect(
      administratorAdmissionFormRequirements.map((item) => item.title),
      containsAll(['Child identity', 'Guardian details', 'Previous school', 'Documents']),
    );
    expect(
      administratorAdmissionFormRequirements
          .firstWhere((item) => item.title == 'Previous school')
          .status,
      'Configurable',
    );
  });

  test('branding identity preserves website name domain logo and theme', () {
    expect(administratorWebsiteBrandIdentity, hasLength(4));
    expect(
      administratorWebsiteBrandIdentity.map((item) => '${item.label}:${item.value}'),
      containsAll([
        'Website name:BrightGate Academy',
        'Domain:brightgateacademy.ng',
        'Logo:BGA mark',
        'Theme:School theme variables',
      ]),
    );
  });

  test('settings serialization preserves editable homepage fields', () {
    const original = AdministratorWebsiteSettings(
      heroHeadline: 'Welcome',
      heroSupportingText: 'Supporting copy',
      admissionsOpen: false,
      admissionSession: '2027/2028',
    );
    final restored = AdministratorWebsiteSettings.fromJson(original.toJson());
    expect(restored.heroHeadline, 'Welcome');
    expect(restored.heroSupportingText, 'Supporting copy');
    expect(restored.admissionsOpen, isFalse);
    expect(restored.admissionSession, '2027/2028');
  });

  test('white-label and native preview boundaries remain explicit', () {
    expect(administratorWebsiteWhiteLabelPrinciple, contains('BrightGate Academy'));
    expect(administratorWebsiteWhiteLabelPrinciple, contains('SchoolOS'));
    expect(administratorWebsitePreviewBoundary, contains('native app'));
    expect(administratorWebsitePreviewBoundary, contains('production public site'));
  });
}
