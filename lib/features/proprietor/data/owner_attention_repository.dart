import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../domain/concession_request.dart';
import '../domain/proprietor_overview_models.dart';
import 'concession_repository.dart';
import 'owner_staff_overview.dart';
import 'payroll_batch_repository.dart';
import 'proprietor_structure_repository.dart';
import 'staff_proposal_repository.dart';

/// What the owner's overview shows from real records: what is waiting on them, and who leads each section.
class OwnerAttention {
  const OwnerAttention({required this.items, required this.leadership});

  final List<ProprietorAttentionItem> items;
  final List<ProprietorLeadershipItem> leadership;
}

/// What is waiting on the owner right now, worked out from the school's real records: staff proposals to
/// approve, concessions to decide, payroll batches to approve, incomplete staff files, and an empty structure.
class OwnerAttentionRepository {
  OwnerAttentionRepository({
    required this.database,
    required this.session,
    required this.proposals,
    required this.concessions,
    required this.staff,
    required this.structure,
  });

  final LocalDatabase database;
  final SchoolSessionController session;
  final StaffProposalRepository proposals;
  final ConcessionRepository concessions;
  final OwnerStaffOverviewRepository staff;
  final ProprietorStructureRepository structure;

  Future<OwnerAttention> load() async {
    final items = <ProprietorAttentionItem>[];
    final school = session.requireActiveMembership().schoolId;

    final snapshot = await structure.load();
    if (snapshot.needsSetup || snapshot.sections.isEmpty) {
      items.add(const ProprietorAttentionItem(
        title: 'Set up the school structure',
        detail: 'Sections and leadership are not set up yet.',
        owner: 'Proprietor',
        tone: ProprietorAttentionTone.high,
        moduleKey: 'structure',
      ));
    }

    final pendingStaff = [for (final p in await proposals.load()) if (p.status == StaffProposalStatus.pending) p];
    for (final p in pendingStaff) {
      items.add(ProprietorAttentionItem(
        title: 'Approve new staff: ${p.name}',
        detail: '${p.roleTitle}${p.workArea.isEmpty ? '' : ', ${p.workArea}'}. Proposed by ${p.proposedBy}.',
        owner: 'Proprietor',
        tone: ProprietorAttentionTone.high,
        moduleKey: 'staff-profiles',
      ));
    }

    final pendingConcessions = [
      for (final c in await concessions.loadRequests()) if (c.status == ConcessionStatus.pendingApproval) c,
    ];
    for (final c in pendingConcessions) {
      items.add(ProprietorAttentionItem(
        title: '${c.type == ConcessionType.scholarship ? 'Scholarship' : 'Discount'} for ${c.student}',
        detail: '${c.className}. Requested by ${c.requestedBy}. ${c.reason}',
        owner: 'Proprietor',
        tone: ProprietorAttentionTone.high,
        moduleKey: 'finance-approvals',
      ));
    }

    final batches = await database.getLocalRecords(tenantId: school, entityType: PayrollBatchRepository.entityType);
    for (final r in batches) {
      final batch = PayrollBatch.fromPayload(r.payload);
      if (batch.status == PayrollBatchStatus.prepared) {
        items.add(ProprietorAttentionItem(
          title: 'Payroll for ${batch.period} is waiting for approval',
          detail: '${batch.lines.length} people are in this batch.',
          owner: 'Proprietor',
          tone: ProprietorAttentionTone.medium,
          moduleKey: 'payroll',
        ));
      }
    }

    final people = await staff.load();
    for (final a in people.attention.take(3)) {
      items.add(ProprietorAttentionItem(
        title: a.title,
        detail: a.detail,
        owner: a.owner,
        tone: ProprietorAttentionTone.info,
        moduleKey: 'staff',
      ));
    }
    return OwnerAttention(
      items: items,
      leadership: [
        for (final l in people.leaders)
          ProprietorLeadershipItem(
            name: l.name,
            role: l.role,
            scope: l.scope,
            signal: l.needsReview ? ProprietorLeadershipSignal.review : ProprietorLeadershipSignal.onTrack,
          ),
      ],
    );
  }
}
