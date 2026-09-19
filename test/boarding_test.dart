import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/boarding/data/boarding_demo_data.dart';
import 'package:schoolos_app/features/boarding/domain/boarding_models.dart';

void main() {
  test('website boarding seed preserves dorm and occupancy totals', () {
    expect(boardingWebsiteSeed, hasLength(3));

    final occupied = boardingWebsiteSeed.fold<int>(
      0,
      (sum, dorm) => sum + dorm.occupied,
    );
    final capacity = boardingWebsiteSeed.fold<int>(
      0,
      (sum, dorm) => sum + dorm.capacity,
    );
    final onCampus = boardingWebsiteSeed.fold<int>(
      0,
      (sum, dorm) => sum + dorm.onCampus,
    );
    final leave = boardingWebsiteSeed.fold<int>(
      0,
      (sum, dorm) => sum + dorm.approvedLeave,
    );
    final maintenance = boardingWebsiteSeed.fold<int>(
      0,
      (sum, dorm) => sum + dorm.maintenance,
    );

    expect(occupied, 125);
    expect(capacity, 136);
    expect(onCampus, 120);
    expect(leave, 5);
    expect(maintenance, 2);
  });

  test('Peace Hall carries the website review and maintenance state', () {
    final peace = boardingWebsiteSeed.singleWhere(
      (dorm) => dorm.name == 'Peace Hall',
    );

    expect(peace.status, DormStatus.review);
    expect(peace.maintenance, 2);
    expect(peace.occupied, 32);
    expect(peace.capacity, 36);
    expect(peace.vacancies, 4);
  });

  test('boarding search covers dorm, house parent and status', () {
    final amina = boardingWebsiteSeed.first;

    expect(amina.matches('amina'), isTrue);
    expect(amina.matches('grace daniel'), isTrue);
    expect(amina.matches('normal'), isTrue);
    expect(amina.matches('unity'), isFalse);
  });

  test('handover review survives serialization without sensitive fields', () {
    final reviewed = boardingWebsiteSeed.first.copyWith(
      handoverReviewed: true,
    );
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

  test('boarding stats preserve enabled and disabled preview semantics', () {
    final enabled = boardingStats(
      boardingWebsiteSeed,
      previewEnabled: true,
    );
    final disabled = boardingStats(
      boardingWebsiteSeed,
      previewEnabled: false,
    );

    expect(enabled.first.value, 'Enabled');
    expect(disabled.first.value, 'Off');
    expect(enabled[1].value, '125/136');
    expect(enabled[2].value, '120');
    expect(enabled[3].value, '5');
    expect(enabled[4].value, '2');
  });

  test('boarding boundary keeps configuration preview non-persistent', () {
    expect(boardingBoundaryRules, hasLength(3));
    expect(boardingBoundaryRules.keys, contains('Welfare, not surveillance'));
    expect(boardingBoundaryRules.keys, contains('Restricted records'));
    expect(boardingBoundaryRules.keys, contains('Optional by tenant'));
    expect(boardingDisabledPreviewNote, contains('does not persist'));
  });
}
