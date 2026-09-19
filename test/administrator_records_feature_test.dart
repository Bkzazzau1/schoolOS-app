import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/data/administrator_records_demo_data.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_records_models.dart';

void main() {
  test('website seed preserves five exact records-office rows', () {
    expect(administratorRecordsWebsiteSeed, hasLength(5));

    expect(administratorRecordsWebsiteSeed[0].document, 'Birth certificate');
    expect(administratorRecordsWebsiteSeed[0].recordOwner, 'Maryam Abdullahi');
    expect(administratorRecordsWebsiteSeed[0].status, AdministratorRecordStatus.verified);
    expect(administratorRecordsWebsiteSeed[0].received, 'Sep 2026');

    expect(administratorRecordsWebsiteSeed[1].document, 'Previous school report');
    expect(administratorRecordsWebsiteSeed[1].recordOwner, 'Aisha Sani');
    expect(administratorRecordsWebsiteSeed[1].status, AdministratorRecordStatus.pending);

    expect(administratorRecordsWebsiteSeed[2].document, 'Guardian ID');
    expect(administratorRecordsWebsiteSeed[2].recordOwner, 'Umar Faruq family');

    expect(administratorRecordsWebsiteSeed[3].document, 'Staff qualification');
    expect(administratorRecordsWebsiteSeed[3].recordOwner, 'Mr. Ahmad Sani');
    expect(administratorRecordsWebsiteSeed[3].status, AdministratorRecordStatus.missing);
    expect(administratorRecordsWebsiteSeed[3].received, '—');

    expect(administratorRecordsWebsiteSeed[4].document, 'Transfer letter');
    expect(administratorRecordsWebsiteSeed[4].recordOwner, 'Yusuf Bello');
    expect(administratorRecordsWebsiteSeed[4].status, AdministratorRecordStatus.draft);
    expect(administratorRecordsWebsiteSeed[4].received, '—');
  });

  test('status mix and attention states match website', () {
    expect(
      administratorRecordsWebsiteSeed
          .where((item) => item.status == AdministratorRecordStatus.verified),
      hasLength(2),
    );
    expect(
      administratorRecordsWebsiteSeed
          .where((item) => item.status == AdministratorRecordStatus.pending),
      hasLength(1),
    );
    expect(
      administratorRecordsWebsiteSeed
          .where((item) => item.status == AdministratorRecordStatus.missing),
      hasLength(1),
    );
    expect(
      administratorRecordsWebsiteSeed
          .where((item) => item.status == AdministratorRecordStatus.draft),
      hasLength(1),
    );
    expect(administratorRecordsWebsiteSeed.where((item) => item.needsAttention), hasLength(2));
  });

  test('all website records remain restricted', () {
    expect(
      administratorRecordsWebsiteSeed.every((item) => item.visibility == 'Restricted'),
      isTrue,
    );
  });

  test('record serialization preserves restricted metadata', () {
    final original = administratorRecordsWebsiteSeed[4];
    final restored = AdministratorDocumentRecord.fromJson(original.toJson());
    expect(restored.id, 'REC-005');
    expect(restored.document, 'Transfer letter');
    expect(restored.recordOwner, 'Yusuf Bello');
    expect(restored.status, AdministratorRecordStatus.draft);
    expect(restored.received, '—');
    expect(restored.visibility, 'Restricted');
  });

  test('records boundaries prevent broad visibility and invented workflows', () {
    expect(administratorRecordsVisibilityBoundary, contains('minimum-necessary'));
    expect(administratorRecordsVisibilityBoundary, contains('does not make it visible'));
    expect(administratorRecordsReviewBoundary, contains('read-only'));
    expect(administratorRecordsReviewBoundary, contains('document editing'));
    expect(administratorRecordsReviewBoundary, contains('wider sharing'));
  });
}
