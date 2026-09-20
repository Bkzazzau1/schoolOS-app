import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_staff_repository.dart';
import '../../../core/identity/identity_normalizer.dart';
import '../domain/owner_staff_profile_models.dart';
import 'job_assignment_repository.dart';
import 'owner_payroll_repository.dart';
import 'owner_staff_profile_repository.dart';
import 'staff_identity.dart';

enum StaffProposalStatus { pending, approved, rejected }

class StaffProposal {
  const StaffProposal({
    required this.id,
    required this.name,
    required this.roleTitle,
    required this.workArea,
    required this.email,
    required this.phone,
    required this.nin,
    required this.gross,
    required this.deductions,
    required this.proposedBy,
    required this.proposedByRole,
    required this.status,
    this.decisionNote = '',
    this.createdStaffId = '',
  });

  final String id;
  final String name;
  final String roleTitle;
  final String workArea;
  final String email;
  final String phone;
  final String nin;
  final int gross;
  final int deductions;
  final String proposedBy;
  final String proposedByRole;
  final StaffProposalStatus status;
  final String decisionNote;

  /// Set only once the owner has approved and the person is on the staff list.
  final String createdStaffId;

  int get net => gross - deductions;

  factory StaffProposal.fromPayload(String id, Map<String, Object?> json) =>
      StaffProposal(
        id: id,
        name: json['name'] as String? ?? '',
        roleTitle: json['roleTitle'] as String? ?? '',
        workArea: json['workArea'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        nin: json['nin'] as String? ?? '',
        gross: json['gross'] as int? ?? 0,
        deductions: json['deductions'] as int? ?? 0,
        proposedBy: json['proposedByMembershipId'] as String? ?? '',
        proposedByRole: json['proposedByRole'] as String? ?? '',
        status: StaffProposalStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => StaffProposalStatus.pending,
        ),
        decisionNote: json['decisionNote'] as String? ?? '',
        createdStaffId: json['createdStaffId'] as String? ?? '',
      );
}

/// Adding staff and proposing their salary.
///
/// The principal, administrator and finance officer (and a section head once
/// their login is linked) can only propose a new staff member. A proposal is
/// not a staff record: the person is not on the staff list or payroll until
/// the owner approves it. The owner adds staff directly, which is recorded as
/// an immediate approval.
class StaffProposalRepository {
  StaffProposalRepository({required this.database, required this.session});

  final LocalDatabase database;
  final SchoolSessionController session;

  static const entityType = 'staff_proposal';

  SchoolMembership get _member => session.requireActiveMembership();
  bool get isOwner => _member.role == SchoolRole.proprietor;

  Future<bool> canPropose() async {
    final member = _member;
    if (const {
      SchoolRole.proprietor,
      SchoolRole.principal,
      SchoolRole.administrator,
      SchoolRole.accountant,
    }.contains(member.role)) {
      return true;
    }
    // A head of section, once their login is linked to the job assignment.
    final jobs = await database.getLocalRecords(
      tenantId: member.schoolId,
      entityType: JobAssignmentRepository.entityType,
    );
    return jobs.any(
      (j) =>
          j.payload['role'] == 'sectionHead' &&
          j.payload['status'] != 'revoked' &&
          j.payload['membershipId'] == member.id,
    );
  }

  /// The owner sees every proposal. Anyone else sees only their own.
  Future<List<StaffProposal>> load() async {
    final member = _member;
    if (!await canPropose()) {
      throw StateError('You are not allowed to propose staff.');
    }
    final records = await database.getLocalRecords(
      tenantId: member.schoolId,
      entityType: entityType,
    );
    return [
      for (final r in records)
        if (isOwner || r.payload['proposedByMembershipId'] == member.id)
          StaffProposal.fromPayload(r.entityId, r.payload),
    ]..sort((a, b) => b.id.compareTo(a.id));
  }

  Future<void> propose({
    required String name,
    required String roleTitle,
    required String workArea,
    required String phone,
    required String nin,
    required int gross,
    required int deductions,
    String email = '',
  }) async {
    final member = _member;
    if (!await canPropose()) {
      throw StateError('You are not allowed to propose staff.');
    }
    final contact = email.trim().toLowerCase();
    if (name.trim().isEmpty ||
        roleTitle.trim().isEmpty ||
        workArea.trim().isEmpty) {
      throw ArgumentError('Enter the name, role and campus or work area.');
    }
    if (gross <= 0 || deductions < 0 || deductions > gross) {
      throw ArgumentError(
        'Enter a gross salary above zero and deductions that do not exceed it.',
      );
    }
    // Phone and NIN identify the person, so both are required and must not
    // already belong to another staff member or pending proposal.
    final cleanPhone = normalizeNigerianPhone(phone);
    if (cleanPhone == null) {
      throw ArgumentError('Enter a valid Nigerian phone number, for example 0803 123 4567.');
    }
    final cleanNin = normalizeNin(nin);
    if (cleanNin == null) throw ArgumentError('A NIN is exactly 11 digits.');
    final matches = await findStaffIdentityMatches(
      database,
      member.schoolId,
      phone: cleanPhone,
      nin: cleanNin,
    );
    if (matches.isNotEmpty) {
      throw DuplicateIdentityError(matches.map((m) => m.message).toSet().join(' '));
    }
    if (contact.isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(contact)) {
      throw ArgumentError('Enter a valid email address.');
    }
    final id =
        'PROP-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    await _save(member, id, null, {
      'name': name.trim(),
      'roleTitle': roleTitle.trim(),
      'workArea': workArea.trim(),
      'email': contact,
      'phone': cleanPhone,
      'nin': cleanNin,
      'gross': gross,
      'deductions': deductions,
      'status': StaffProposalStatus.pending.name,
      'proposedByMembershipId': member.id,
      'proposedByRole': member.role.name,
      'proposedAt': DateTime.now().toUtc().toIso8601String(),
    });
    // The owner's own additions need no one else's approval.
    if (member.role == SchoolRole.proprietor) await approve(id);
  }

  SchoolMembership _requireOwner() {
    final member = _member;
    if (member.role != SchoolRole.proprietor) {
      throw StateError('Only the owner can approve or reject staff.');
    }
    return member;
  }

  /// Approves a proposal, optionally adjusting the salary. Only now does the
  /// person become a staff member, with their salary on payroll and an
  /// onboarding request queued if an email was given.
  ///
  /// The staff id is derived from the proposal id, so retrying after a partial
  /// failure fills in the same records instead of creating a duplicate.
  Future<void> approve(String id, {int? gross, int? deductions}) async {
    final owner = _requireOwner();
    final record = await database.getLocalRecord(
      tenantId: owner.schoolId,
      entityType: entityType,
      entityId: id,
    );
    if (record == null) throw StateError('Proposal not found.');
    final proposal = StaffProposal.fromPayload(id, record.payload);
    if (proposal.status == StaffProposalStatus.approved) return;
    if (proposal.status == StaffProposalStatus.rejected) {
      throw StateError('This proposal was rejected.');
    }
    final approvedGross = gross ?? proposal.gross;
    final approvedDeductions = deductions ?? proposal.deductions;
    if (approvedGross <= 0 ||
        approvedDeductions < 0 ||
        approvedDeductions > approvedGross) {
      throw ArgumentError(
        'Enter a gross salary above zero and deductions that do not exceed it.',
      );
    }
    final staffId =
        'STAFF-${sha256.convert(utf8.encode(id)).toString().substring(0, 16)}';
    // Re-check before creating anything: someone else may have taken this
    // phone or NIN since it was proposed.
    final clashes = await findStaffIdentityMatches(
      database,
      owner.schoolId,
      phone: proposal.phone.isEmpty ? null : proposal.phone,
      nin: proposal.nin.isEmpty ? null : proposal.nin,
      excludeStaffId: staffId,
      excludeProposalId: id,
    );
    if (clashes.isNotEmpty) {
      throw DuplicateIdentityError(
        '${clashes.map((m) => m.message).toSet().join(' ')} Reject this proposal or correct the details.',
      );
    }
    final person = await AdministratorStaffRepository(
      localDatabase: database,
      schoolSession: session,
    ).createStaffRecord(
      id: staffId,
      name: proposal.name,
      role: proposal.roleTitle,
      section: proposal.workArea,
      proposalId: id,
    );
    await OwnerPayrollRepository(database: database, session: session)
        .saveSalary(
          person: person,
          gross: approvedGross,
          deductions: approvedDeductions,
          onPayroll: true,
        );
    final profiles = OwnerStaffProfileRepository(database: database, session: session);
    await profiles.savePersonal(
      staffId,
      StaffPersonalInfo(phone: proposal.phone, nin: proposal.nin, email: proposal.email),
      excludeProposalId: id,
    );
    if (proposal.email.isNotEmpty) {
      await profiles.requestOnboarding(staffId, proposal.email);
    }
    await _save(owner, id, record, {
      ...record.payload,
      'status': StaffProposalStatus.approved.name,
      'createdStaffId': staffId,
      'approvedGross': approvedGross,
      'approvedDeductions': approvedDeductions,
      'decidedByMembershipId': owner.id,
      'decidedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> reject(String id, String note) async {
    final owner = _requireOwner();
    final record = await database.getLocalRecord(
      tenantId: owner.schoolId,
      entityType: entityType,
      entityId: id,
    );
    if (record == null) throw StateError('Proposal not found.');
    final proposal = StaffProposal.fromPayload(id, record.payload);
    if (proposal.status != StaffProposalStatus.pending) {
      throw StateError('This proposal has already been decided.');
    }
    await _save(owner, id, record, {
      ...record.payload,
      'status': StaffProposalStatus.rejected.name,
      'decisionNote': note.trim(),
      'decidedByMembershipId': owner.id,
      'decidedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _save(
    SchoolMembership member,
    String id,
    LocalRecord? existing,
    Map<String, Object?> payload,
  ) async {
    await database.upsertLocalRecord(
      tenantId: member.schoolId,
      entityType: entityType,
      entityId: id,
      payload: payload,
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await database.queueMutation(
      tenantId: member.schoolId,
      membershipId: member.id,
      entityType: entityType,
      entityId: id,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: payload,
      baseVersion: existing?.serverVersion,
    );
  }
}
