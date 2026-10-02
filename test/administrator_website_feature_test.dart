import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/data/administrator_website_policy_copy.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_website_models.dart';

void main() {
  test('a fixture homepage settings record carries exact editable fields', () {
    const fixture = AdministratorWebsiteSettings(
      heroHeadline: 'A strong beginning. A confident future.',
      heroSupportingText:
          'Nursery, Primary and Secondary education in a caring, structured learning environment.',
      admissionsOpen: true,
      admissionSession: '2026/2027',
    );
    expect(fixture.heroHeadline, 'A strong beginning. A confident future.');
    expect(
      fixture.heroSupportingText,
      'Nursery, Primary and Secondary education in a caring, structured learning environment.',
    );
    expect(fixture.admissionsOpen, isTrue);
    expect(fixture.admissionSession, '2026/2027');
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

  test('branding identity uses the real school name, and is honest about what is not set yet', () {
    final identity = administratorWebsiteBrandIdentity('Green Valley International School');
    expect(identity, hasLength(4));
    expect(
      identity.map((item) => '${item.label}:${item.value}'),
      containsAll([
        'Website name:Green Valley International School',
        'Domain:Not set yet',
        'Logo:Not set yet',
        'Theme:Not set yet',
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
    expect(administratorWebsiteWhiteLabelPrinciple, isNot(contains('BrightGate')));
    expect(administratorWebsiteWhiteLabelPrinciple, contains('SchoolOS'));
    expect(administratorWebsitePreviewBoundary, contains('Connect to the internet'));
    expect(administratorWebsitePreviewBoundary, isNot(contains('production')));
  });
}
