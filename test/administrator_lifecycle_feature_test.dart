import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_lifecycle_models.dart';

const _fixtureRecords = <AdministratorLifecycleRecord>[
  AdministratorLifecycleRecord(
    id: 'LC-FIX-001',
    studentName: 'Yusuf Bello',
    workflow: 'Transfer out',
    change: 'Awaiting records pack',
    status: AdministratorLifecycleStatus.pending,
  ),
  AdministratorLifecycleRecord(
    id: 'LC-FIX-002',
    studentName: 'Ahmad Musa',
    workflow: 'Promotion',
    change: 'Primary 6 → JSS 1',
    status: AdministratorLifecycleStatus.pending,
    fromClass: 'Primary 6',
    toClass: 'JSS 1',
  ),
  AdministratorLifecycleRecord(
    id: 'LC-FIX-003',
    studentName: 'Abdullahi Umar',
    workflow: 'Class change',
    change: 'SS1A → SS1B',
    status: AdministratorLifecycleStatus.pending,
    fromClass: 'SS1A',
    toClass: 'SS1B',
  ),
  AdministratorLifecycleRecord(
    id: 'LC-FIX-004',
    studentName: 'Fatima Musa',
    workflow: 'Alumni',
    change: 'Completed',
    status: AdministratorLifecycleStatus.completed,
  ),
];

void main() {
  test('a fixture record carries exact transfer, promotion, class-change and alumni fields', () {
    expect(_fixtureRecords, hasLength(4));

    final transfer = _fixtureRecords[0];
    expect(transfer.studentName, 'Yusuf Bello');
    expect(transfer.workflow, 'Transfer out');
    expect(transfer.change, 'Awaiting records pack');
    expect(transfer.status, AdministratorLifecycleStatus.pending);

    final promotion = _fixtureRecords[1];
    expect(promotion.studentName, 'Ahmad Musa');
    expect(promotion.workflow, 'Promotion');
    expect(promotion.change, 'Primary 6 → JSS 1');
    expect(promotion.isPromotion, isTrue);

    final classChange = _fixtureRecords[2];
    expect(classChange.studentName, 'Abdullahi Umar');
    expect(classChange.workflow, 'Class change');
    expect(classChange.change, 'SS1A → SS1B');

    final alumni = _fixtureRecords[3];
    expect(alumni.studentName, 'Fatima Musa');
    expect(alumni.workflow, 'Alumni');
    expect(alumni.change, 'Completed');
    expect(alumni.status, AdministratorLifecycleStatus.completed);
  });

  test('status mix preserves three pending and one completed', () {
    expect(
      _fixtureRecords.where((item) => item.status == AdministratorLifecycleStatus.pending),
      hasLength(3),
    );
    expect(
      _fixtureRecords.where(
        (item) => item.status == AdministratorLifecycleStatus.completed,
      ),
      hasLength(1),
    );
  });

  test('workflow helpers preserve transfer promotion class-change alumni types', () {
    expect(_fixtureRecords[0].isTransferOut, isTrue);
    expect(_fixtureRecords[1].isPromotion, isTrue);
    expect(_fixtureRecords[2].isClassChange, isTrue);
    expect(_fixtureRecords[3].isAlumni, isTrue);
  });

  test('lifecycle serialization preserves operational fields', () {
    final original = _fixtureRecords[2];
    final restored = AdministratorLifecycleRecord.fromJson(original.toJson());
    expect(restored.id, 'LC-FIX-003');
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
