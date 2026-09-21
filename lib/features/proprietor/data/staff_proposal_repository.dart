import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_staff_repository.dart';
import '../../administrator/domain/administrator_staff_models.dart';
import '../../../core/identity/identity_normalizer.dart';
import '../domain/owner_staff_profile_models.dart';
import 'job_assignment_repository.dart';
import 'owner_payroll_repository.dart';
import 'owner_staff_profile_repository.dart';
import 'staff_identity.dart';
import 'staff_server_api.dart';

enum StaffProposalStatus { pending, approved, rejected }

class StaffProposal {
  const StaffProposal({
    required this.id,
    required this.name,
    required this.roleTitle,
    required this.systemRole,
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

  /// The access role proposed for them (a key of [staffSystemRoles]).
  final String systemRole;
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
        systemRole: json['systemRole'] as String? ?? '',
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
///
/// Approving queues the staff member's registration invitation, which the
/// school backend emails to them. This app does not send email itself.
class StaffProposalRepository {
  StaffProposalRepository({required this.database, required this.session, this.remote});

  final LocalDatabase database;
  final SchoolSessionController session;

  /// Set when there is a server: it then decides proposals (approving creates the staff
  /// member, salary, profile and invitation together, or nothing), and this device only
  /// asks. Null on demo data, where the device does it all itself.
  final StaffServerApi? remote;

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

  String get memberId => _member.id;

  Future<Set<String>> _authorities() async {
    final member = _member;
    final authorizers = (await database.getLocalRecords(
      tenantId: member.schoolId,
      entityType: OwnerPayrollRepository.authorizerType,
    )).map(PayrollAuthorizer.fromRecord);
    return payrollAuthoritiesFor(member, authorizers);
  }

  /// The owner, or someone the owner has assigned to approve new staff.
  Future<bool> canApprove() async =>
      isOwner || (await _authorities()).contains('approveStaff');

  /// The owner and assigned approvers see every proposal. Anyone else who can
  /// propose sees only their own.
  Future<List<StaffProposal>> load() async {
    final member = _member;
    final approver = await canApprove();
    if (!approver && !await canPropose()) {
      throw StateError('You are not allowed to propose or approve staff.');
    }
    final records = await database.getLocalRecords(
      tenantId: member.schoolId,
      entityType: entityType,
    );
    return [
      for (final r in records)
        if (approver || r.payload['proposedByMembershipId'] == member.id)
          StaffProposal.fromPayload(r.entityId, r.payload),
    ]..sort((a, b) => b.id.compareTo(a.id));
  }

  Future<void> propose({
    required String name,
    required String roleTitle,
    required String systemRole,
    required String workArea,
    required String phone,
    required String nin,
    required int gross,
    required int deductions,
    required String email,
  }) async {
    final member = _member;
    if (!await canPropose()) {
      throw StateError('You are not allowed to propose staff.');
    }
    final contact = email.trim().toLowerCase();
    if (name.trim().isEmpty ||
        roleTitle.trim().isEmpty ||
        workArea.trim().isEmpty) {
      throw ArgumentError('Enter the name, job title and campus or work area.');
    }
    if (!staffSystemRoles.containsKey(systemRole)) {
      throw ArgumentError('Choose the role this person is proposed for.');
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
    // The registration invitation is emailed here once the owner approves.
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(contact)) {
      throw ArgumentError('Enter the staff member\'s email address. Their registration link is sent there once approved.');
    }
    final id =
        'PROP-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    await _save(member, id, null, {
      'name': name.trim(),
      'roleTitle': roleTitle.trim(),
      'systemRole': systemRole,
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
    if (member.role == SchoolRole.proprietor) {
      if (remote != null) {
        await _approveOwnersOwnOnServer(member, id);
      } else {
        await approve(id);
      }
    }
  }

  /// With a server the proposal must get there before it can be approved, and the
  /// server may refuse it (a phone number or NIN that belongs to someone else). So:
  /// send it, and if the server refused it say why and take the stuck copy off this
  /// device; if it could not be sent yet (offline) it stays queued, and the owner
  /// approves it from the list once it has arrived.
  Future<void> _approveOwnersOwnOnServer(SchoolMembership member, String id) async {
    await remote!.afterChange?.call();
    final items = database
        .syncQueueItems(tenantId: member.schoolId)
        .where((item) => item.entityType == entityType && item.entityId == id)
        .toList();
    for (final item in items) {
      if (item.status == SyncMutationStatus.failed) {
        database.discardMutation(tenantId: member.schoolId, mutationId: item.id);
        throw StateError(item.lastError ?? 'The school refused this proposal.');
      }
    }
    if (items.isNotEmpty) return; // still waiting to be sent
    await approve(id);
  }

  Future<SchoolMembership> _requireApprover() async {
    if (!await canApprove()) {
      throw StateError(
        'Only the owner, or someone the owner has authorized, can approve or reject staff.',
      );
    }
    return _member;
  }

  Future<void> _put(
    SchoolMembership member,
    String type,
    String id,
    Map<String, Object?> payload,
  ) async {
    final existing = await database.getLocalRecord(
      tenantId: member.schoolId,
      entityType: type,
      entityId: id,
    );
    await database.upsertLocalRecord(
      tenantId: member.schoolId,
      entityType: type,
      entityId: id,
      payload: payload,
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await database.queueMutation(
      tenantId: member.schoolId,
      membershipId: member.id,
      entityType: type,
      entityId: id,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: payload,
      baseVersion: existing?.serverVersion,
    );
  }

  /// Approves a proposal. Only now does the person become a staff member, with
  /// their salary on payroll and their registration invitation queued for the
  /// email given.
  ///
  /// The owner may adjust the salary. Someone the owner has authorized can
  /// approve only the salary as proposed, and cannot approve a proposal they
  /// made themselves.
  ///
  /// The staff id is derived from the proposal id, so retrying after a partial
  /// failure fills in the same records instead of creating a duplicate.
  Future<void> approve(
    String id, {
    int? gross,
    int? deductions,
    String? systemRole,
  }) async {
    if (remote != null) {
      return _approveOnServer(id, gross: gross, deductions: deductions, systemRole: systemRole);
    }
    final approver = await _requireApprover();
    final record = await database.getLocalRecord(
      tenantId: approver.schoolId,
      entityType: entityType,
      entityId: id,
    );
    if (record == null) throw StateError('Proposal not found.');
    final proposal = StaffProposal.fromPayload(id, record.payload);
    if (proposal.status == StaffProposalStatus.approved) return;
    if (proposal.status == StaffProposalStatus.rejected) {
      throw StateError('This proposal was rejected.');
    }
    if (!isOwner) {
      if (proposal.proposedBy == approver.id) {
        throw StateError(
          'You proposed this staff member, so someone else must approve it.',
        );
      }
      if ((gross != null && gross != proposal.gross) ||
          (deductions != null && deductions != proposal.deductions)) {
        throw StateError('Only the owner can change the proposed salary.');
      }
    }
    // The role is the one proposed. Only the owner may change it, and an
    // assigned approver may approve only the roles that do not reach money or
    // student records.
    final role = systemRole ?? proposal.systemRole;
    if (!staffSystemRoles.containsKey(role)) {
      throw ArgumentError('Choose the role for this staff member first.');
    }
    if (!isOwner) {
      if (role != proposal.systemRole) {
        throw StateError('Only the owner can change the proposed role.');
      }
      if (!delegateApprovableRoles.contains(role)) {
        throw StateError(
          'Only the owner can approve a ${staffSystemRoleLabel(role)}.',
        );
      }
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
      approver.schoolId,
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

    final now = DateTime.now().toUtc().toIso8601String();
    // 1. The staff directory entry.
    await _put(approver, AdministratorStaffRepository.directoryEntityType, staffId, {
      ...AdministratorStaffRecord(
        id: staffId,
        name: proposal.name,
        role: proposal.roleTitle,
        section: proposal.workArea,
        fileStatus: AdministratorStaffFileStatus.missingDocument,
      ).toJson(),
      'staffCategory': 'approved',
      'systemRole': role,
      'approvedFromProposal': id,
      'createdByMembershipId': approver.id,
      'createdAt': now,
    });
    // 2. Their salary, on payroll.
    final existingSalary = await database.getLocalRecord(
      tenantId: approver.schoolId,
      entityType: OwnerPayrollRepository.profileType,
      entityId: staffId,
    );
    final history = [
      ...((existingSalary?.payload['history'] as List?) ?? const []),
    ];
    final last = history.isEmpty ? null : history.last as Map;
    if (last == null ||
        last['gross'] != approvedGross ||
        last['deductions'] != approvedDeductions) {
      history.add({
        'at': now,
        'gross': approvedGross,
        'deductions': approvedDeductions,
        'onPayroll': true,
        'byMembershipId': approver.id,
      });
    }
    await _put(approver, OwnerPayrollRepository.profileType, staffId, {
      'staffId': staffId,
      'name': proposal.name,
      'role': proposal.roleTitle,
      'gross': approvedGross,
      'deductions': approvedDeductions,
      'onPayroll': true,
      'history': history,
      'updatedAt': now,
    });
    // 3. Their profile, with the registration invitation queued for the
    // backend to email.
    await _put(approver, OwnerStaffProfileRepository.entityType, staffId, {
      ...StaffProfile(
        staffId: staffId,
        personal: StaffPersonalInfo(
          phone: proposal.phone,
          nin: proposal.nin,
          email: proposal.email,
        ),
        documents: [
          for (final name in defaultRequiredDocuments)
            StaffRequiredDocument(name: name),
        ],
        onboardingStatus: StaffOnboardingStatus.invitePending,
        onboardingEmail: proposal.email,
        systemRole: role,
      ).toJson(),
      'updatedAt': now,
      'updatedByMembershipId': approver.id,
    });
    await _save(approver, id, record, {
      ...record.payload,
      'status': StaffProposalStatus.approved.name,
      'createdStaffId': staffId,
      'approvedSystemRole': role,
      'approvedGross': approvedGross,
      'approvedDeductions': approvedDeductions,
      'decidedByMembershipId': approver.id,
      'decidedByRole': approver.role.name,
      'decidedAt': now,
    });
  }

  Future<void> reject(String id, String note) async {
    if (remote != null) return _rejectOnServer(id, note);
    final approver = await _requireApprover();
    final record = await database.getLocalRecord(
      tenantId: approver.schoolId,
      entityType: entityType,
      entityId: id,
    );
    if (record == null) throw StateError('Proposal not found.');
    final proposal = StaffProposal.fromPayload(id, record.payload);
    if (proposal.status != StaffProposalStatus.pending) {
      throw StateError('This proposal has already been decided.');
    }
    if (!isOwner && proposal.proposedBy == approver.id) {
      throw StateError(
        'You proposed this staff member, so someone else must decide it.',
      );
    }
    await _save(approver, id, record, {
      ...record.payload,
      'status': StaffProposalStatus.rejected.name,
      'decisionNote': note.trim(),
      'decidedByMembershipId': approver.id,
      'decidedByRole': approver.role.name,
      'decidedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// The server decides who may approve, whether the numbers are still free, and what
  /// changes; it either creates everything or nothing. Its refusals are shown as they are.
  Future<void> _approveOnServer(String id, {int? gross, int? deductions, String? systemRole}) async {
    final member = _member;
    final record = await database.getLocalRecord(tenantId: member.schoolId, entityType: entityType, entityId: id);
    if (record == null) throw StateError('Proposal not found.');
    final proposal = StaffProposal.fromPayload(id, record.payload);
    if (proposal.status == StaffProposalStatus.approved) return;
    if (proposal.status == StaffProposalStatus.rejected) throw StateError('This proposal was rejected.');
    if (systemRole != null && !staffSystemRoles.containsKey(systemRole)) {
      throw ArgumentError('Choose the role for this staff member first.');
    }
    final staffId = await remote!.approveProposal(member, id, gross: gross, deductions: deductions, systemRole: systemRole);
    await _showDecision(member, id, record, {
      'status': StaffProposalStatus.approved.name,
      'createdStaffId': staffId,
      'decidedByMembershipId': member.id,
      'decidedByRole': member.role.name,
      'decidedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _rejectOnServer(String id, String note) async {
    final member = _member;
    final record = await database.getLocalRecord(tenantId: member.schoolId, entityType: entityType, entityId: id);
    if (record == null) throw StateError('Proposal not found.');
    if (StaffProposal.fromPayload(id, record.payload).status != StaffProposalStatus.pending) {
      throw StateError('This proposal has already been decided.');
    }
    await remote!.rejectProposal(member, id, note);
    await _showDecision(member, id, record, {
      'status': StaffProposalStatus.rejected.name,
      'decisionNote': note.trim(),
      'decidedByMembershipId': member.id,
      'decidedByRole': member.role.name,
      'decidedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Shows the decision on this device straight away. It is not an edit to send: the server
  /// already has it, and the next download replaces this copy with its own.
  Future<void> _showDecision(SchoolMembership member, String id, LocalRecord record, Map<String, Object?> decision) async {
    await database.upsertLocalRecord(
      tenantId: member.schoolId,
      entityType: entityType,
      entityId: id,
      payload: {...record.payload, ...decision},
      serverVersion: record.serverVersion,
      isDirty: false,
    );
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
