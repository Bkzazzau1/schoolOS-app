import '../../../core/database/local_database.dart';
import '../../../core/identity/identity_normalizer.dart';
import '../../administrator/data/administrator_staff_repository.dart';
import 'owner_staff_profile_repository.dart';

/// A staff member who already uses a phone number or NIN.
class StaffIdentityMatch {
  const StaffIdentityMatch({
    required this.staffId,
    required this.name,
    required this.field,
  });

  final String staffId;
  final String name;

  /// 'phone' or 'NIN'.
  final String field;

  String get message => 'This $field is already used by $name ($staffId).';
}

class _Identity {
  const _Identity(this.owner, this.name, this.phone, this.nin);
  final String owner;
  final String name;
  final String? phone;
  final String? nin;
}

Future<List<_Identity>> _identities(
  LocalDatabase database,
  String tenantId,
) async {
  final profiles = await database.getLocalRecords(
    tenantId: tenantId,
    entityType: OwnerStaffProfileRepository.entityType,
  );
  final directory = await database.getLocalRecords(
    tenantId: tenantId,
    entityType: AdministratorStaffRepository.directoryEntityType,
  );
  final names = {
    for (final d in directory) d.entityId: d.payload['name'] as String? ?? d.entityId,
  };
  return [
    for (final r in profiles)
      _Identity(
        r.entityId,
        names[r.entityId] ?? r.entityId,
        normalizeNigerianPhone(
          (r.payload['personal'] as Map?)?['phone'] as String? ?? '',
        ),
        normalizeNin((r.payload['personal'] as Map?)?['nin'] as String? ?? ''),
      ),
  ];
}

/// Staff who already use [phone] or [nin], apart from [excludeStaffId].
///
/// Values are compared after normalizing, so formatting differences do not
/// hide a duplicate. Pending proposals are checked too, so a person cannot be
/// proposed twice while waiting for approval.
Future<List<StaffIdentityMatch>> findStaffIdentityMatches(
  LocalDatabase database,
  String tenantId, {
  String? phone,
  String? nin,
  String? excludeStaffId,
  String? excludeProposalId,
}) async {
  final matches = <StaffIdentityMatch>[];
  for (final i in await _identities(database, tenantId)) {
    if (i.owner == excludeStaffId) continue;
    if (phone != null && i.phone == phone) {
      matches.add(StaffIdentityMatch(staffId: i.owner, name: i.name, field: 'phone'));
    }
    if (nin != null && i.nin == nin) {
      matches.add(StaffIdentityMatch(staffId: i.owner, name: i.name, field: 'NIN'));
    }
  }
  final proposals = await database.getLocalRecords(
    tenantId: tenantId,
    entityType: 'staff_proposal',
  );
  for (final p in proposals) {
    if (p.entityId == excludeProposalId) continue;
    if (p.payload['status'] != 'pending') continue;
    final name = p.payload['name'] as String? ?? 'a pending proposal';
    if (phone != null && p.payload['phone'] == phone) {
      matches.add(StaffIdentityMatch(staffId: p.entityId, name: '$name (pending proposal)', field: 'phone'));
    }
    if (nin != null && p.payload['nin'] == nin) {
      matches.add(StaffIdentityMatch(staffId: p.entityId, name: '$name (pending proposal)', field: 'NIN'));
    }
  }
  return matches;
}

/// Groups of staff records that share a phone number or NIN. Empty when every
/// staff member is unique.
class StaffDuplicateGroup {
  const StaffDuplicateGroup({
    required this.field,
    required this.value,
    required this.people,
  });

  final String field;
  final String value;
  final List<StaffIdentityMatch> people;
}

Future<List<StaffDuplicateGroup>> findStaffDuplicateGroups(
  LocalDatabase database,
  String tenantId,
) async {
  final all = await _identities(database, tenantId);
  final groups = <StaffDuplicateGroup>[];
  void collect(String field, String? Function(_Identity) pick) {
    final byValue = <String, List<_Identity>>{};
    for (final i in all) {
      final v = pick(i);
      if (v != null) byValue.putIfAbsent(v, () => []).add(i);
    }
    byValue.forEach((value, list) {
      if (list.length > 1) {
        groups.add(StaffDuplicateGroup(
          field: field,
          value: value,
          people: [
            for (final i in list)
              StaffIdentityMatch(staffId: i.owner, name: i.name, field: field),
          ],
        ));
      }
    });
  }

  collect('phone', (i) => i.phone);
  collect('NIN', (i) => i.nin);
  return groups;
}
