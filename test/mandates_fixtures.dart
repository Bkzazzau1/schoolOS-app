// Mandates & Direct Debit fixtures. Unlike a hand-written sample, every response in test/fixtures/mandates was RECORDED from the SchoolOS
// server's own API (the Django tests drive the real endpoints and write down what came back), so these tests break if the app and the server
// stop agreeing about a field. The server never sends a full account number or a credential, and neither does any file here.

import 'dart:convert';
import 'dart:io';

import 'package:schoolos_app/shared/models/school_membership.dart';

import 'bank_connect_fixtures.dart';

export 'bank_connect_fixtures.dart' show financeMembership, ownerMembership, schoolId;

/// A response the server really sent, by file name.
Map<String, Object?> real(String name) => jsonDecode(File('test/fixtures/mandates/$name.json').readAsStringSync()) as Map<String, Object?>;

/// A copy that can be changed without changing the recorded one.
Map<String, Object?> clone(Map<String, Object?> json) => jsonDecode(jsonEncode(json)) as Map<String, Object?>;

List<Map<String, Object?>> maps(Object? value) => [for (final e in value as List) e as Map<String, Object?>];

/// The maker and the checker in the recorded batch: their ids are the memberships the server recorded as having prepared and approved it.
const makerMembership = SchoolMembership(
  id: '0ec5dc93-d9ae-4ed3-ba3a-3e5e9d28a0e8',
  schoolId: schoolId,
  schoolName: 'BrightGate',
  role: SchoolRole.administrator,
);

const checkerMembership = SchoolMembership(
  id: '5f122576-c365-44a3-9489-be7bd1bd83c7',
  schoolId: schoolId,
  schoolName: 'BrightGate',
  role: SchoolRole.principal,
);

const parentMembership = SchoolMembership(
  id: '77777777-7777-7777-7777-777777777777',
  schoolId: schoolId,
  schoolName: 'BrightGate',
  role: SchoolRole.parent,
);

/// The account numbers the recorded mandates were made with. They must never appear in anything the server sent or the app shows.
const recordedAccountNumbers = ['0123456789', '0987654321'];

Map<String, Object?> mandatePermissions({bool view = true, bool providers = false, bool manage = false, bool prepare = false, bool approve = false}) => {
      'canView': view,
      'canManageProviders': providers,
      'canManage': manage,
      'canPrepare': prepare,
      'canApprove': approve,
    };

/// One recorded mandate with some fields changed.
Map<String, Object?> mandateWith(Map<String, Object?> base, Map<String, Object?> changes) => {...clone(base), ...changes};

/// A recorded batch (as the detail endpoints answer it) with the batch's own fields changed and the permissions of whoever is asking.
Map<String, Object?> batchDetail(Map<String, Object?> base, {Map<String, Object?> batch = const {}, Map<String, Object?>? permissions, Map<String, Object?>? retry}) {
  final copy = clone(base);
  copy['batch'] = {...(copy['batch'] as Map<String, Object?>), ...batch};
  if (permissions != null) copy['permissions'] = permissions;
  if (retry != null) copy['retry'] = retry;
  return copy;
}
