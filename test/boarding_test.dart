import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/boarding/data/boarding_policy_copy.dart';
import 'package:schoolos_app/features/boarding/domain/boarding_models.dart';

List<BoardingDorm> _dorms() => const [
      BoardingDorm(
        name: 'Amina Hall',
        houseParent: 'Mrs. Grace Daniel',
        capacity: 48,
        occupied: 44,
        onCampus: 42,
        approvedLeave: 2,
        maintenance: 0,
        status: DormStatus.normal,
        note: 'Girls senior dormitory; evening roll and welfare handover complete.',
      ),
      BoardingDorm(
        name: 'Peace Hall',
        houseParent: 'Mrs. Ruth Musa',
        capacity: 36,
        occupied: 32,
        onCampus: 31,
        approvedLeave: 1,
        maintenance: 2,
        status: DormStatus.review,
        note: 'Two maintenance items awaiting facilities follow-up.',
      ),
    ];

void main() {
  test('dorm totals are computed from the real dorms given', () {
    final dorms = _dorms();
    final occupied = dorms.fold<int>(0, (sum, dorm) => sum + dorm.occupied);
    final capacity = dorms.fold<int>(0, (sum, dorm) => sum + dorm.capacity);
    expect(occupied, 76);
    expect(capacity, 84);
  });

  test('Peace Hall carries its own review and maintenance state', () {
    final peace = _dorms().singleWhere((dorm) => dorm.name == 'Peace Hall');

    expect(peace.status, DormStatus.review);
    expect(peace.maintenance, 2);
    expect(peace.occupied, 32);
    expect(peace.capacity, 36);
    expect(peace.vacancies, 4);
  });

  test('boarding search covers dorm, house parent and status', () {
    final amina = _dorms().first;

    expect(amina.matches('amina'), isTrue);
    expect(amina.matches('grace daniel'), isTrue);
    expect(amina.matches('normal'), isTrue);
    expect(amina.matches('peace'), isFalse);
  });

  test('copyWith changes only the fields given, never the identity name', () {
    final reviewed = _dorms().first.copyWith(handoverReviewed: true, occupied: 45);
    expect(reviewed.handoverReviewed, isTrue);
    expect(reviewed.occupied, 45);
    expect(reviewed.name, 'Amina Hall');
    expect(reviewed.houseParent, 'Mrs. Grace Daniel');
  });

  test('handover review survives serialization without sensitive fields', () {
    final reviewed = _dorms().first.copyWith(handoverReviewed: true);
    final json = reviewed.toJson();
    final restored = BoardingDorm.fromJson(json);

    expect(restored.handoverReviewed, isTrue);
    expect(restored.name, reviewed.name);
    expect(restored.houseParent, reviewed.houseParent);

    expect(json.containsKey('medicalHistory'), isFalse);
    expect(json.containsKey('healthDetails'), isFalse);
    expect(json.containsKey('welfareCase'), isFalse);
    expect(json.containsKey('studentDiagnosis'), isFalse);
  });

  test('boarding stats are computed entirely from the real dorms given, never a fixed sample', () {
    final dorms = _dorms();
    final enabled = boardingStats(dorms, previewEnabled: true);
    final disabled = boardingStats(dorms, previewEnabled: false);

    expect(enabled.first.value, 'Enabled');
    expect(disabled.first.value, 'Off');
    expect(enabled[1].value, '76/84');
    expect(enabled[2].value, '73');
    expect(enabled[3].value, '3');
    expect(enabled[4].value, '2');

    final empty = boardingStats(const [], previewEnabled: true);
    expect(empty[1].value, '0/0');
    expect(empty[2].value, '0');
  });

  test('boarding boundary keeps configuration preview non-persistent', () {
    expect(boardingBoundaryRules, hasLength(3));
    expect(boardingBoundaryRules.keys, contains('Welfare, not surveillance'));
    expect(boardingBoundaryRules.keys, contains('Restricted records'));
    expect(boardingBoundaryRules.keys, contains('Optional by tenant'));
    expect(boardingDisabledPreviewNote, contains('settings have not changed'));
  });
}
