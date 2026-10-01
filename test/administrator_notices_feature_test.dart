import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/data/administrator_notices_policy_copy.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_notices_models.dart';

const _fixtureNotices = <AdministratorNotice>[
  AdministratorNotice(
    id: 'NOTICE-001',
    title: 'Term fee reminder',
    audience: AdministratorNoticeAudience.parents,
    type: AdministratorNoticeType.feeReminder,
    message: '',
    status: AdministratorNoticeStatus.scheduled,
    createdLabel: 'Fixture',
  ),
  AdministratorNotice(
    id: 'NOTICE-002',
    title: 'Primary reading week',
    audience: AdministratorNoticeAudience.primary,
    type: AdministratorNoticeType.generalAdministration,
    message: '',
    status: AdministratorNoticeStatus.published,
    createdLabel: 'Fixture',
  ),
  AdministratorNotice(
    id: 'NOTICE-003',
    title: 'Staff document update',
    audience: AdministratorNoticeAudience.staff,
    type: AdministratorNoticeType.documentRequest,
    message: '',
    status: AdministratorNoticeStatus.draft,
    createdLabel: 'Fixture',
  ),
];

void main() {
  test('notice fixture carries three recent records', () {
    expect(_fixtureNotices, hasLength(3));

    final fee = _fixtureNotices[0];
    expect(fee.title, 'Term fee reminder');
    expect(fee.audience, AdministratorNoticeAudience.parents);
    expect(fee.status, AdministratorNoticeStatus.scheduled);

    final reading = _fixtureNotices[1];
    expect(reading.title, 'Primary reading week');
    expect(reading.audience, AdministratorNoticeAudience.primary);
    expect(reading.status, AdministratorNoticeStatus.published);

    final staff = _fixtureNotices[2];
    expect(staff.title, 'Staff document update');
    expect(staff.audience, AdministratorNoticeAudience.staff);
    expect(staff.status, AdministratorNoticeStatus.draft);
  });

  test('website exposes five audiences in exact order', () {
    expect(
      administratorNoticeAudienceOptions.map((item) => item.label).toList(),
      [
        'Parents',
        'Staff',
        'Whole school',
        'Primary',
        'Secondary',
      ],
    );
  });

  test('website exposes four notice types in exact order', () {
    expect(
      administratorNoticeTypeOptions.map((item) => item.label).toList(),
      [
        'General administration',
        'Document request',
        'Fee reminder',
        'Service update',
      ],
    );
  });

  test('notice serialization preserves authoritative metadata', () {
    const original = AdministratorNotice(
      id: 'NOTICE-X',
      title: 'Document update',
      audience: AdministratorNoticeAudience.secondary,
      type: AdministratorNoticeType.documentRequest,
      message: 'Please submit the required document.',
      status: AdministratorNoticeStatus.draft,
      createdLabel: 'Local draft',
    );
    final restored = AdministratorNotice.fromJson(original.toJson());
    expect(restored.id, 'NOTICE-X');
    expect(restored.audience, AdministratorNoticeAudience.secondary);
    expect(restored.type, AdministratorNoticeType.documentRequest);
    expect(restored.status, AdministratorNoticeStatus.draft);
    expect(restored.message, 'Please submit the required document.');
  });

  test('new native notices must remain drafts before governed publishing', () {
    expect(administratorNoticesDraftBoundary, contains('Draft only'));
    expect(administratorNoticesDraftBoundary, contains('must not silently publish'));
    expect(administratorNoticesDraftBoundary, contains('approval'));
  });

  test('notices remain authoritative and distinct from community discussion', () {
    expect(administratorNoticesAuthorityBoundary, contains('conversational'));
    expect(administratorNoticesAuthorityBoundary, contains('authoritative'));
    expect(administratorNoticesAuthorityBoundary, contains('permission checks'));
    expect(administratorNoticesAuthorityBoundary, contains('audit trail'));
  });

  test('status mix preserves scheduled published and draft', () {
    expect(_fixtureNotices.where((n) => n.isScheduled), hasLength(1));
    expect(_fixtureNotices.where((n) => n.isPublished), hasLength(1));
    expect(_fixtureNotices.where((n) => n.isDraft), hasLength(1));
  });
}
