import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/proprietor/data/proprietor_school_life_data.dart';

void main() {
  test('proprietor School Life exposes the 16 shared website modules', () {
    expect(proprietorSchoolLifeCapabilities.length, 16);
    expect(
      proprietorSchoolLifeCapabilities.map((item) => item.module).toList(),
      [
        'Community',
        'Noticeboard',
        'Activities & Clubs',
        'Events & Calendar',
        'Houses & Teams',
        'Media Gallery',
        'Excursions & Consent',
        'School Transport',
        'Meals & Cafeteria',
        'Boarding & Hostel',
        'Assembly & Faith Activities',
        'Visitor Management',
        'Lost & Found',
        'Service & Volunteering',
        'Awards & Recognition',
        'Teaching Models',
      ],
    );
  });

  test('proprietor permissions preserve key owner authority levels', () {
    final byKey = {
      for (final item in proprietorSchoolLifeCapabilities) item.key: item,
    };

    expect(byKey['community']?.level, 'Manage school-wide');
    expect(byKey['noticeboard']?.level, 'Publish school-wide');
    expect(byKey['gallery']?.level, 'Approve visibility');
    expect(byKey['transport']?.level, 'Manage fleet & routes');
    expect(byKey['boarding']?.level, 'Configure / disable');
    expect(byKey['teaching-models']?.level, 'Configure all sections');
  });

  test('School Life retains its access and security boundaries', () {
    expect(proprietorSchoolLifeScope, 'Whole school');
    expect(
      proprietorSchoolLifeAccessPrinciple,
      contains('membership, campus, section, class and delegated duties'),
    );
    expect(
      proprietorSchoolLifeProductionRule,
      contains('authorized by the backend'),
    );
  });

  test('every capability has a stable shared route and descriptive policy', () {
    for (final capability in proprietorSchoolLifeCapabilities) {
      expect(capability.key, isNotEmpty);
      expect(capability.webPath, startsWith('/'));
      expect(capability.detail, isNotEmpty);
      expect(capability.description, isNotEmpty);
      expect(capability.level, isNotEmpty);
    }
  });
}
