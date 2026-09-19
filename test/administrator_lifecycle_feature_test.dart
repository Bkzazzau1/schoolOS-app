import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/data/administrator_lifecycle_demo_data.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_lifecycle_models.dart';

void main() {
  test('website lifecycle seed preserves four exact records', () {
    expect(administratorLifecycleWebsiteSeed, hasLength(4));

    final transfer = administratorLifecycleWebsiteSeed[0];
    expect(transfer.id, 'STU-003');
    expect(transfer.studentName, 'Yusuf Bello');
    expect(transfer.workflow, 'Transfer out');
    expect(transfer.change, 'Awaiting records pack');
    expect(transfer.status, AdministratorLifecycleStatus.pending);

    final promotion = administratorLifecycleWebsiteSeed[1];
    expect(promotion.id, 'PRI-006');
    expect(promotion.studentName, 'Ahmad Musa');
    expect(promotion.workflow, 'Promotion');
    expect(promotion.change, 'Primary 6 → JSS 1');
    expect(promotion.isPromotion, isTrue);

    final classChange = administratorLifecycleWebsiteSeed[2];
    expect(classChange.id, 'STU-005');
    expect(classChange.studentName, 'Abdullahi Umar');
    expect(classChange.workflow, 'Class change');
    expect(classChange.change, 'SS1A → SS1B');

    final alumni = administratorLifecycleWebsiteSeed[3];
    expect(alumni.id, 'ALM-001');
    expect(alumni.studentName, 'Fatima Musa');
    expect(alumni.workflow, 'Alumni');
    expect(alumni.change, 'Completed');
    expect(alumni.status, AdministratorLifecycleStatus.completed);
  });

  test('website status mix is three pending and one completed', () {
    expect(
      administratorLifecycleWebsiteSeed
          .where((item) => item.status == AdministratorLifecycleStatus.pending),
      hasLength(3),
    );
    expect(
      administratorLifecycleWebsiteSeed.where(
        (item) => item.status == AdministratorLifecycleStatus.completed,
      ),
      hasLength(1),
    );
  });

  test('workflow helpers preserve transfer promotion class-change alumni types', () {
    expect(administratorLifecycleWebsiteSeed[0].isTransferOut, isTrue);
    expect(administratorLifecycleWebsiteSeed[1].isPromotion, isTrue);
    expect(administratorLifecycleWebsiteSeed[2].isClassChange, isTrue);
    expect(administratorLifecycleWebsiteSeed[3].isAlumni, isTrue);
  });

  test('lifecycle serialization preserves operational fields', () {
    final original = administratorLifecycleWebsiteSeed[2];
    final restored = AdministratorLifecycleRecord.fromJson(original.toJson());
    expect(restored.id, 'STU-005');
    expect(restored.studentName, 'Abdullahi Umar');
    expect(restored.workflow, 'Class change');
    expect(restored.change, 'SS1A → SS1B');
    expect(restored.status, AdministratorLifecycleStatus.pending);
  });

  test('authority boundary reserves promotion decisions for academic leadership', () {
    expect(administratorLifecycleAuthorityBoundary, contains('executes approved'));
    expect(administratorLifecycleAuthorityBoundary, contains('academic promotion decisions'));
    expect(administratorLifecycleAuthorityBoundary, contains('academic leadership'));
  });

  test('history boundary requires append rather than overwrite', () {
    expect(administratorLifecycleHistoryBoundary, contains('appended'));
    expect(administratorLifecycleHistoryBoundary, contains('rather than overwritten'));
    expect(administratorLifecycleHistoryBoundary, contains('auditable'));
  });

  test('Open does not invent approval or destructive lifecycle authority', () {
    expect(administratorLifecycleOpenBoundary, contains('operational review'));
    expect(administratorLifecycleOpenBoundary, contains('must not be upgraded into an approval'));
    expect(administratorLifecycleOpenBoundary, contains('promotion decision'));
    expect(administratorLifecycleOpenBoundary, contains('destructive class-history rewrite'));
  });
}
