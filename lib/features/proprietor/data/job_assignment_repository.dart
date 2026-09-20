import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';

/// Duties requested by an owner. These are not authenticated access grants.
const assignableDuties = <String, String>{
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
  }) async {
    final owner = _owner();
    final contact = email.trim().toLowerCase();
    if (name.trim().isEmpty ||
        title.trim().isEmpty ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(contact) ||
        duties.isEmpty ||
        duties.any((duty) => !assignableDuties.containsKey(duty))) {
      throw ArgumentError(
        'Enter a name, valid email, job title and at least one duty.',
      );
    }
    // Re-saving the same person's job updates it instead of making duplicates.
    final id = sha256
        .convert(utf8.encode('$contact|${title.trim().toLowerCase()}'))
        .toString();
    final existing = await database.getLocalRecord(
      tenantId: owner.schoolId,
      entityType: entityType,
      entityId: id,
    );
    await _save(owner, id, {
      'name': name.trim(),
      'email': contact,
      'title': title.trim(),
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
