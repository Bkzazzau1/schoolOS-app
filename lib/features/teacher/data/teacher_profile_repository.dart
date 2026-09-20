import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_profile_models.dart';
import 'teacher_profile_demo_data.dart';

class TeacherProfileSnapshot {
  const TeacherProfileSnapshot({
    required this.profile,
    required this.permissions,
  });

  final TeacherProfileSnapshotData profile;
  final TeacherProfilePermissions permissions;
}

class TeacherProfileUpdateResult {
  const TeacherProfileUpdateResult({
    required this.success,
    required this.message,
    this.contact,
  });

  final bool success;
  final String message;
  final TeacherProfileContact? contact;
}

abstract interface class TeacherProfileDataSource {
  TeacherProfilePermissions permissionsFor(SchoolMembership membership);
  Future<TeacherProfileSnapshot> load();
  Future<TeacherProfileUpdateResult> saveContact(TeacherProfileContact contact);
}

class TeacherProfileRepository implements TeacherProfileDataSource {
  TeacherProfileRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _profileType = 'teacher_profile_snapshot';
  static const _contactType = 'teacher_profile_contact';
  static const _contactEventType = 'teacher_profile_contact_event';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  @override
  TeacherProfilePermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherProfilePermissions(
      canViewOwnProfile: teacher,
      canUpdateOwnContact: teacher,
      canEditEmploymentAuthority: false,
      canEditPayroll: false,
      canEditTeachingAssignments: false,
      canViewOtherStaffPayroll: false,
      canSelfApproveSecurityChanges: false,
    );
  }

  @override
  Future<TeacherProfileSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    await _seedIfNeeded(membership);

    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _profileType,
    );
    var profile = TeacherProfileSnapshotData.fromJson(records.first.payload);

    final contactRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _contactType,
    );
    if (contactRecords.isNotEmpty) {
      final contact = TeacherProfileContact.fromJson(contactRecords.first.payload);
      profile = profile.copyWith(contact: contact.copyWith(
        pendingSync: contactRecords.first.isDirty,
      ));
    }

    return TeacherProfileSnapshot(
      profile: profile,
      permissions: permissionsFor(membership),
    );
  }

  @override
  Future<TeacherProfileUpdateResult> saveContact(
    TeacherProfileContact contact,
  ) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canUpdateOwnContact) {
      return const TeacherProfileUpdateResult(
        success: false,
        message: 'This membership cannot update the Teacher self-service profile.',
      );
    }

    if (contact.phone.trim().isEmpty ||
        contact.email.trim().isEmpty ||
        contact.address.trim().isEmpty ||
        contact.emergencyPhone.trim().isEmpty) {
      return const TeacherProfileUpdateResult(
        success: false,
        message: 'Phone, email, address and emergency contact are required.',
      );
    }

    final existing = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _contactType,
    );
    final current = existing.isEmpty
        ? teacherProfile.contact
        : TeacherProfileContact.fromJson(existing.first.payload);
    final updated = TeacherProfileContact(
      phone: contact.phone.trim(),
      email: contact.email.trim(),
      address: contact.address.trim(),
      nextOfKin: contact.nextOfKin.trim(),
      emergencyPhone: contact.emergencyPhone.trim(),
      version: current.version + 1,
      pendingSync: true,
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _contactType,
      entityId: membership.id,
      payload: updated.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _contactType,
      entityId: membership.id,
      operation: existing.isEmpty ? SyncOperation.create : SyncOperation.update,
      payload: updated.toJson(),
    );

    final occurredAt = DateTime.now().toUtc().toIso8601String();
    final eventId = '${membership.id}-${DateTime.now().microsecondsSinceEpoch}';
    final event = <String, Object?>{
      'id': eventId,
      'actorMembershipId': membership.id,
      'action': 'updatedSelfServiceContact',
      'version': updated.version,
      'occurredAt': occurredAt,
      'fields': const ['phone', 'email', 'address', 'nextOfKin', 'emergencyPhone'],
    };
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _contactEventType,
      entityId: eventId,
      payload: event,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _contactEventType,
      entityId: eventId,
      operation: SyncOperation.create,
      payload: event,
    );

    return TeacherProfileUpdateResult(
      success: true,
      message: 'Contact changes saved locally and queued for HR synchronization. Employment, payroll and teaching assignments are unchanged.',
      contact: updated,
    );
  }

  Future<void> _seedIfNeeded(SchoolMembership membership) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _profileType,
    );
    if (records.isNotEmpty) return;
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _profileType,
      entityId: membership.id,
      payload: teacherProfile.toJson(),
    );
  }
}
