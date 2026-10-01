import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/houses/data/house_policy_copy.dart';
import 'package:schoolos_app/features/houses/domain/house_models.dart';

List<SchoolHouse> _houses() => const [
      SchoolHouse(
        id: 'HOUSE-TEST-BLUE',
        name: 'Blue House',
        captain: 'Amina Bello',
        coordinator: 'Mrs. Fatima Bello',
        members: 172,
        points: 428,
        sports: 170,
        academicCompetitions: 138,
        service: 120,
        status: 'Leading',
      ),
      SchoolHouse(
        id: 'HOUSE-TEST-GREEN',
        name: 'Green House',
        captain: 'Hauwa Musa',
        coordinator: 'Mrs. Grace Audu',
        members: 174,
        points: 389,
        sports: 142,
        academicCompetitions: 132,
        service: 115,
        status: 'Strong',
      ),
      SchoolHouse(
        id: 'HOUSE-TEST-GOLD',
        name: 'Gold House',
        captain: 'Samuel Okafor',
        coordinator: 'Mr. Peter James',
        members: 169,
        points: 371,
        sports: 135,
        academicCompetitions: 129,
        service: 107,
        status: 'On track',
      ),
    ];

void main() {
  test('point components reconcile to displayed totals', () {
    for (final house in _houses()) {
      expect(house.componentTotal, house.points, reason: house.name);
    }
  });

  test('search matches house, captain and coordinator', () {
    final houses = _houses();
    expect(houses.where((house) => house.matches('Amina')), hasLength(1));
    expect(houses.where((house) => house.matches('Grace Audu')).single.name, 'Green House');
    expect(houses.where((house) => house.matches('Gold')).single.captain, 'Samuel Okafor');
  });

  test('house serialization round-trips', () {
    final source = _houses().first;
    final restored = SchoolHouse.fromJson(source.toJson());
    expect(restored.id, source.id);
    expect(restored.points, source.points);
    expect(restored.academicCompetitions, source.academicCompetitions);
  });

  test('copyWith only changes the fields given', () {
    final source = _houses().first;
    final updated = source.copyWith(points: 500, status: 'Updated');
    expect(updated.points, 500);
    expect(updated.status, 'Updated');
    expect(updated.name, source.name);
    expect(updated.captain, source.captain);
  });

  test('house points remain separate from academic grading', () {
    expect(houseAcademicBoundary, contains('must not secretly change exam results'));
    expect(houseAcademicBoundary, contains('promotion decisions'));
    expect(houseAcademicBoundary, contains('academic profiles'));
  });
}
