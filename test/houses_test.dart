import 'package:flutter_test/flutter_test.dart';
import 'package:school_os_app/features/houses/data/house_demo_data.dart';
import 'package:school_os_app/features/houses/domain/house_models.dart';

void main() {
  test('website house seed has four houses and 683 members', () {
    expect(houseWebsiteSeed, hasLength(4));
    expect(houseMemberTotal, 683);
    expect(houseKpis.first.value, '4');
    expect(houseKpis[1].value, '683');
  });

  test('Blue House leads with 428 points', () {
    expect(leadingHouse.name, 'Blue House');
    expect(leadingHouse.points, 428);
    expect(leadingHouse.status, 'Leading');
  });

  test('point components reconcile to displayed totals', () {
    for (final house in houseWebsiteSeed) {
      expect(house.componentTotal, house.points, reason: house.name);
    }
  });

  test('search matches house, captain and coordinator', () {
    expect(houseWebsiteSeed.where((house) => house.matches('Amina')), hasLength(1));
    expect(houseWebsiteSeed.where((house) => house.matches('Grace Audu')).single.name, 'Green House');
    expect(houseWebsiteSeed.where((house) => house.matches('Gold')).single.captain, 'Samuel Okafor');
  });

  test('house serialization round-trips', () {
    final source = houseWebsiteSeed.first;
    final restored = SchoolHouse.fromJson(source.toJson());
    expect(restored.id, source.id);
    expect(restored.points, source.points);
    expect(restored.academicCompetitions, source.academicCompetitions);
  });

  test('house points remain separate from academic grading', () {
    expect(houseAcademicBoundary, contains('must not secretly change exam results'));
    expect(houseAcademicBoundary, contains('promotion decisions'));
    expect(houseAcademicBoundary, contains('academic profiles'));
    expect(houseKpis.last.value, 'House only');
  });
}
