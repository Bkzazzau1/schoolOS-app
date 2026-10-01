import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import 'dart:math';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../proprietor/data/owner_staff_profile_repository.dart';
import '../../proprietor/domain/owner_staff_profile_models.dart';
import '../domain/administrator_staff_models.dart';
import '../domain/support_staff_roles.dart';

class AdministratorStaffSnapshot {
  const AdministratorStaffSnapshot({
    required this.staff,
    required this.permissions,
  });

  final List<AdministratorStaffRecord> staff;
  final AdministratorStaffPermissions permissions;
}

class AdministratorStaffRepository {
  AdministratorStaffRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const directoryEntityType = 'administrator_staff_directory';
  static const _entityType = directoryEntityType;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  AdministratorStaffPermissions permissionsFor(SchoolMembership membership) {
    final allowed = membership.role == SchoolRole.administrator || membership.role == SchoolRole.proprietor;
    return AdministratorStaffPermissions(
      canViewDirectory: allowed,
      canReviewOperationalFile: allowed,
    );
  }

  Future<AdministratorStaffSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    final staff = records
        .map((record) => AdministratorStaffRecord.fromJson(record.payload))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    return AdministratorStaffSnapshot(
      staff: staff,
      permissions: permissionsFor(membership),
    );
  }

  /// With an [email], also queues an onboarding request asking the new staff
  /// member to fill in their details and provide documents. The email itself
  /// is sent by the school backend once connected.
  Future<void> registerSupportStaff({required String name, required String role,
    required String workArea, String email = ''}) async {
    final member = _schoolSession.requireActiveMembership();
    if (member.role != SchoolRole.proprietor) {
      throw StateError('Only the owner can add staff directly. Others propose staff for the owner to approve.');
    }
    if (name.trim().isEmpty || workArea.trim().isEmpty || !supportStaffRoles.containsKey(role)) {
      throw ArgumentError('Enter a name, support role and assigned work area.');
    }
    final id = 'STAFF-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    final record = AdministratorStaffRecord(id: id, name: name.trim(),
      role: supportStaffRoles[role]!, section: workArea.trim(),
      fileStatus: AdministratorStaffFileStatus.missingDocument);
    final payload = <String, Object?>{...record.toJson(),
      'staffCategory': 'support', 'supportRole': role,
      'createdByMembershipId': member.id,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    final contact = email.trim().toLowerCase();
    if (contact.isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(contact)) {
      throw ArgumentError('Enter a valid email address.');
    }
    await _localDatabase.upsertLocalRecord(tenantId: member.schoolId,
      entityType: _entityType, entityId: id, payload: payload, isDirty: true);
    await _localDatabase.queueMutation(tenantId: member.schoolId, membershipId: member.id,
      entityType: _entityType, entityId: id, operation: SyncOperation.create, payload: payload);
    if (contact.isNotEmpty) {
      final onboarding = <String, Object?>{
        ...StaffProfile(
          staffId: id,
          onboardingEmail: contact,
          onboardingStatus: StaffOnboardingStatus.invitePending,
          documents: [for (final n in defaultRequiredDocuments) StaffRequiredDocument(name: n)],
        ).toJson(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'updatedByMembershipId': member.id,
      };
      await _localDatabase.upsertLocalRecord(tenantId: member.schoolId,
        entityType: OwnerStaffProfileRepository.entityType, entityId: id, payload: onboarding, isDirty: true);
      await _localDatabase.queueMutation(tenantId: member.schoolId, membershipId: member.id,
        entityType: OwnerStaffProfileRepository.entityType, entityId: id, operation: SyncOperation.create, payload: onboarding);
    }
  }
}
