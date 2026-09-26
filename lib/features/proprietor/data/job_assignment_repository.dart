import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_staff_repository.dart';
import '../../administrator/domain/administrator_staff_models.dart';
import '../../administrator/domain/support_staff_roles.dart';
import '../domain/proprietor_structure_models.dart';
import 'proprietor_structure_repository.dart';

const jobRolePresets = <String, String>{
  'custom': 'Custom role',
  'sectionHead': 'Head of section',
  'finance': 'Finance Officer',
  'administrator': 'Administrator',
  'teacher': 'Teacher',
  ...supportStaffRoles,
};

/// Duties that only the owner's own, deliberate choice can give: a role preset or an "all duties" shortcut
/// never includes them. Connecting the school's bank accounts, and deciding what families owe (fees, discounts,
/// scholarships), are two: being in the Finance Office is not enough on its own.
const explicitOnlyDuties = <String>{'finance.bank_connections', 'finance.billing_authority'};

Set<String> dutiesInGroup(String prefix) => assignableDuties.keys
    .where((key) => key.startsWith(prefix) && !explicitOnlyDuties.contains(key))
    .toSet();

Set<String> dutiesForJobRole(String role) => switch (role) {
  'finance' => dutiesInGroup('finance.'),
  'administrator' => dutiesInGroup('administration.'),
  'sectionHead' => {
    'administration.students',
    'administration.attendance',
    'administration.communications',
    'academics.teaching',
  },
  'teacher' => {'academics.teaching'},
  'driver' || 'cleaner' || 'security' || 'cook' || 'maintenance' || 'gardener' || 'support' => supportDutiesForRole(role),
  _ => <String>{},
};

/// Duties requested by an owner. These are not authenticated access grants.
const assignableDuties = <String, String>{
  ...supportStaffDuties,
  'finance.fees': 'Fee structure',
  'finance.collections': 'Collections and receipts',
  'finance.concessions': 'Scholarships and discounts',
  'finance.approvals': 'Financial approvals',
  'finance.accounts': 'Student accounts and payment mandates',
  'finance.reconciliation': 'Bank reconciliation',
  'finance.expenses': 'Expenses and income',
  'finance.payroll': 'Payroll',
  'finance.store': 'School store',
  'finance.reports': 'Finance reports',
  'finance.bad_debt_classification': 'Bad debt classification',
  'finance.bank_connections': 'Connect and manage the school bank accounts',
  'finance.billing_authority': 'Decide what families owe (fees, discounts, scholarships)',
  'administration.admissions': 'Admissions and enrollment',
  'administration.students': 'Student records',
  'administration.staff': 'Staff administration',
  'administration.attendance': 'Attendance administration',
  'administration.communications': 'School communications',
  'academics.teaching': 'Teaching and learning',
  'operations.school_life': 'School life and operations',
};

class JobAssignmentRepository {
  JobAssignmentRepository({required this.database, required this.session});

  final LocalDatabase database;
  final SchoolSessionController session;
  static const entityType = 'owner_job_assignment';

  Future<List<AdministratorStaffRecord>> people() async {
    _owner();
    return (await AdministratorStaffRepository(
      localDatabase: database,
      schoolSession: session,
    ).load()).staff;
  }

  Future<List<AcademicSection>> sections() async {
    _owner();
    return (await ProprietorStructureRepository(
      localDatabase: database,
      schoolSession: session,
    ).load()).sections;
  }

  SchoolMembership _owner() {
    final member = session.requireActiveMembership();
    if (member.role != SchoolRole.proprietor) {
      throw StateError('Only the school owner can manage job assignments.');
    }
    return member;
  }

  Future<List<LocalRecord>> load() {
    final owner = _owner();
    return database.getLocalRecords(
      tenantId: owner.schoolId,
      entityType: entityType,
    );
  }

  Future<void> assign({
    required String name,
    required String email,
    required String title,
    required Set<String> duties,
    String? registeredStaffId,
    String role = 'custom',
    String? sectionId,
    String? assignmentId,
  }) async {
    final owner = _owner();
    if (!jobRolePresets.containsKey(role)) {
      throw ArgumentError('Choose a valid role.');
    }
    if (role == 'sectionHead' && sectionId == null) {
      throw ArgumentError('Choose a section for its head.');
    }
    String? sectionName;
    if (sectionId != null) {
      final matches = (await sections()).where((s) => s.id == sectionId);
      if (matches.isEmpty) {
        throw ArgumentError('Choose a section in this school.');
      }
      sectionName = matches.first.name;
    }
    if (registeredStaffId != null) {
      final matches = (await people()).where((p) => p.id == registeredStaffId);
      if (matches.isEmpty) {
        throw ArgumentError('Choose a person in this school directory.');
      }
      name = matches.first.name;
    }
    final contact = email.trim().toLowerCase();
    if (name.trim().isEmpty ||
        title.trim().isEmpty ||
        ((registeredStaffId == null || contact.isNotEmpty) &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(contact)) ||
        duties.isEmpty ||
        duties.any((duty) => !assignableDuties.containsKey(duty))) {
      throw ArgumentError(
        'Enter a name, valid email, job title and at least one duty.',
      );
    }
    // Re-saving the same person's job updates it instead of making duplicates.
    final id =
        assignmentId ??
        sha256
            .convert(
              utf8.encode(
                '${registeredStaffId ?? contact}|${title.trim().toLowerCase()}|${sectionId ?? 'school'}',
              ),
            )
            .toString();
    final existing = await database.getLocalRecord(
      tenantId: owner.schoolId,
      entityType: entityType,
      entityId: id,
    );
    if (assignmentId != null && existing == null) {
      throw StateError('Assignment not found in this school.');
    }
    if (_owner().id != owner.id) {
      throw StateError('School changed. Please try again.');
    }
    await _save(owner, id, {
      'name': name.trim(),
      'email': contact,
      'title': title.trim(),
      'recipientType': registeredStaffId == null
          ? 'unregistered'
          : 'registered',
      'registeredStaffId': registeredStaffId,
      'role': role,
      'sectionId': sectionId,
      'sectionName': sectionName,
      'scope': sectionId == null ? 'school' : 'section',
      'duties': duties.toList()..sort(),
      'status': 'pendingActivation',
      'createdAt':
          existing?.payload['createdAt'] ??
          DateTime.now().toUtc().toIso8601String(),
      'assignedByMembershipId': owner.id,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }, existing);
  }

  Future<void> revoke(String id) async {
    final owner = _owner();
    final existing = await database.getLocalRecord(
      tenantId: owner.schoolId,
      entityType: entityType,
      entityId: id,
    );
    if (existing == null) {
      throw StateError('Assignment not found in this school.');
    }
    await _save(owner, id, {
      ...existing.payload,
      'status': 'revoked',
      'revokedByMembershipId': owner.id,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }, existing);
  }

  Future<void> _save(
    SchoolMembership owner,
    String id,
    Map<String, Object?> payload,
    LocalRecord? existing,
  ) async {
    await database.upsertLocalRecord(
      tenantId: owner.schoolId,
      entityType: entityType,
      entityId: id,
      payload: payload,
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await database.queueMutation(
      tenantId: owner.schoolId,
      membershipId: owner.id,
      entityType: entityType,
      entityId: id,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: payload,
      baseVersion: existing?.serverVersion,
    );
  }
}
