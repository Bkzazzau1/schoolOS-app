import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_records_models.dart';

const _fixtureRecords = <AdministratorDocumentRecord>[
  AdministratorDocumentRecord(
    id: 'REC-FIX-001',
    document: 'Birth certificate',
    recordOwner: 'Maryam Abdullahi',
    status: AdministratorRecordStatus.verified,
    received: 'Sep 2026',
    visibility: 'Restricted',
  ),
  AdministratorDocumentRecord(
    id: 'REC-FIX-002',
    document: 'Previous school report',
    recordOwner: 'Aisha Sani',
    status: AdministratorRecordStatus.pending,
    received: 'Sep 2026',
    visibility: 'Restricted',
  ),
  AdministratorDocumentRecord(
    id: 'REC-FIX-003',
    document: 'Guardian ID',
    recordOwner: 'Umar Faruq family',
    status: AdministratorRecordStatus.verified,
    received: 'Sep 2026',
    visibility: 'Restricted',
  ),
  AdministratorDocumentRecord(
    id: 'REC-FIX-004',
    document: 'Staff qualification',
    recordOwner: 'Mr. Ahmad Sani',
    status: AdministratorRecordStatus.missing,
    received: '—',
    visibility: 'Restricted',
  ),
  AdministratorDocumentRecord(
    id: 'REC-FIX-005',
    document: 'Transfer letter',
    recordOwner: 'Yusuf Bello',
    status: AdministratorRecordStatus.draft,
    received: '—',
    visibility: 'Restricted',
  ),
];

void main() {
  test('a fixture row carries exact document, owner, status and received fields', () {
    expect(_fixtureRecords, hasLength(5));

    expect(_fixtureRecords[0].document, 'Birth certificate');
    expect(_fixtureRecords[0].recordOwner, 'Maryam Abdullahi');
    expect(_fixtureRecords[0].status, AdministratorRecordStatus.verified);
    expect(_fixtureRecords[0].received, 'Sep 2026');

    expect(_fixtureRecords[1].document, 'Previous school report');
    expect(_fixtureRecords[1].recordOwner, 'Aisha Sani');
    expect(_fixtureRecords[1].status, AdministratorRecordStatus.pending);

    expect(_fixtureRecords[2].document, 'Guardian ID');
    expect(_fixtureRecords[2].recordOwner, 'Umar Faruq family');

    expect(_fixtureRecords[3].document, 'Staff qualification');
    expect(_fixtureRecords[3].recordOwner, 'Mr. Ahmad Sani');
    expect(_fixtureRecords[3].status, AdministratorRecordStatus.missing);
    expect(_fixtureRecords[3].received, '—');

    expect(_fixtureRecords[4].document, 'Transfer letter');
    expect(_fixtureRecords[4].recordOwner, 'Yusuf Bello');
    expect(_fixtureRecords[4].status, AdministratorRecordStatus.draft);
    expect(_fixtureRecords[4].received, '—');
  });

  test('status mix and attention states', () {
    expect(
      _fixtureRecords
          .where((item) => item.status == AdministratorRecordStatus.verified),
      hasLength(2),
    );
    expect(
      _fixtureRecords
          .where((item) => item.status == AdministratorRecordStatus.pending),
      hasLength(1),
    );
    expect(
      _fixtureRecords
          .where((item) => item.status == AdministratorRecordStatus.missing),
      hasLength(1),
    );
    expect(
      _fixtureRecords
          .where((item) => item.status == AdministratorRecordStatus.draft),
      hasLength(1),
    );
    expect(_fixtureRecords.where((item) => item.needsAttention), hasLength(2));
  });

  test('all fixture records remain restricted', () {
    expect(
      _fixtureRecords.every((item) => item.visibility == 'Restricted'),
      isTrue,
    );
  });

  test('record serialization preserves restricted metadata', () {
    final original = _fixtureRecords[4];
    final restored = AdministratorDocumentRecord.fromJson(original.toJson());
    expect(restored.id, 'REC-FIX-005');
    expect(restored.document, 'Transfer letter');
    expect(restored.recordOwner, 'Yusuf Bello');
    expect(restored.status, AdministratorRecordStatus.draft);
    expect(restored.received, '—');
    expect(restored.visibility, 'Restricted');
  });

  test('records boundaries prevent broad visibility and invented workflows', () {
    expect(administratorRecordsVisibilityBoundary, contains('minimum-necessary'));
    expect(administratorRecordsVisibilityBoundary, contains('does not make it visible'));
    expect(administratorRecordsReviewBoundary, contains('nothing is deleted'));
    expect(administratorRecordsReviewBoundary, contains('history'));
    expect(administratorRecordsReviewBoundary, contains('shared more widely'));
  });
}
