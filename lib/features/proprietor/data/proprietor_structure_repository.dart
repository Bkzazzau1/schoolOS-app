import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../domain/proprietor_structure_models.dart';
import 'proprietor_structure_demo_data.dart';

class ProprietorStructureSnapshot {
  const ProprietorStructureSnapshot({
    required this.sections,
    required this.leaders,
  });

  final List<AcademicSection> sections;
  final List<LeadershipAppointment> leaders;
}

class StructureChangeResult {
  const StructureChangeResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class ProprietorStructureRepository {
  ProprietorStructureRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  static const _sectionEntity = 'academic_section';
  static const _leaderEntity = 'leadership_appointment';

  Future<ProprietorStructureSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final sectionRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _sectionEntity,
    );
    final leaderRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _leaderEntity,
    );

    if (sectionRecords.isEmpty && leaderRecords.isEmpty) {
      await _seed(membership.schoolId);
      return const ProprietorStructureSnapshot(
        sections: initialAcademicSections,
        leaders: initialLeadershipAppointments,
      );
    }

    final sections = sectionRecords
        .map((record) => AcademicSection.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    final leaders = leaderRecords
        .map((record) => LeadershipAppointment.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));

    return ProprietorStructureSnapshot(
      sections: sections.isEmpty ? initialAcademicSections : sections,
      leaders: leaders.isEmpty ? initialLeadershipAppointments : leaders,
    );
  }

  Future<StructureChangeResult> appoint({
    required AcademicSection section,
    required String person,
    required LeadershipLevel level,
    required String title,
    String? department,
    String? reportsTo,
  }) async {
    final normalizedTitle = title.trim();
    if (person.trim().isEmpty || normalizedTitle.isEmpty) {
      return const StructureChangeResult(
        success: false,
        message: 'Choose a staff member and enter an official title.',
      );
    }

    final snapshot = await load();
    final sectionLeaders = snapshot.leaders
        .where((leader) => leader.sectionId == section.id)
        .toList(growable: false);

    if (level == LeadershipLevel.sectionHead &&
        sectionLeaders.any((leader) => leader.level == LeadershipLevel.sectionHead)) {
      return StructureChangeResult(
        success: false,
        message:
            '${section.name} already has a Section Head. Replace the existing appointment instead of creating a second active Section Head.',
      );
    }

    if (level != LeadershipLevel.sectionHead) {
      final manager = _leaderById(snapshot.leaders, reportsTo);
      if (manager == null ||
          manager.sectionId != section.id ||
          (manager.level != LeadershipLevel.sectionHead &&
              manager.level != LeadershipLevel.deputy)) {
        return const StructureChangeResult(
          success: false,
          message: 'Choose a reporting manager from the same academic section.',
        );
      }
    }

    if (level == LeadershipLevel.hod && (department?.trim().isEmpty ?? true)) {
      return const StructureChangeResult(
        success: false,
        message: 'Enter a department for an HOD appointment.',
      );
    }

    final nextId = _nextLeaderId(snapshot.leaders);
    final appointment = LeadershipAppointment(
      id: nextId,
      person: person,
      title: normalizedTitle,
      level: level,
      sectionId: section.id,
      department: level == LeadershipLevel.hod ? department!.trim() : null,
      reportsTo: level == LeadershipLevel.sectionHead ? null : reportsTo,
    );

    final membership = _schoolSession.requireActiveMembership();
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _leaderEntity,
      entityId: appointment.id,
      payload: appointment.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _leaderEntity,
      entityId: appointment.id,
      operation: SyncOperation.create,
      payload: appointment.toJson(),
    );

    return StructureChangeResult(
      success: true,
      message:
          '${appointment.person} appointed as ${appointment.title} for ${section.name}. Saved offline and queued for sync.',
    );
  }

  Future<StructureChangeResult> replaceSectionHead({
    required AcademicSection section,
    required String person,
  }) async {
    final snapshot = await load();
    LeadershipAppointment? currentHead;
    for (final leader in snapshot.leaders) {
      if (leader.sectionId == section.id &&
          leader.level == LeadershipLevel.sectionHead) {
        currentHead = leader;
        break;
      }
    }
    if (currentHead == null) {
      return const StructureChangeResult(
        success: false,
        message: 'This section has no active Section Head to replace.',
      );
    }

    final title = switch (section.stage) {
      'Primary' => 'Headmaster / Headmistress',
      'Secondary' => 'Principal',
      _ => 'Head Teacher',
    };
    final updatedHead = currentHead.copyWith(person: person, title: title);
    final updatedSection = section.copyWith(
      leaderName: person,
      leaderTitle: title,
    );
    final membership = _schoolSession.requireActiveMembership();

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _leaderEntity,
      entityId: updatedHead.id,
      payload: updatedHead.toJson(),
      isDirty: true,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _sectionEntity,
      entityId: updatedSection.id,
      payload: updatedSection.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _leaderEntity,
      entityId: updatedHead.id,
      operation: SyncOperation.update,
      payload: updatedHead.toJson(),
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _sectionEntity,
      entityId: updatedSection.id,
      operation: SyncOperation.update,
      payload: updatedSection.toJson(),
    );

    return StructureChangeResult(
      success: true,
      message: '$person is now the active $title for ${section.name}.',
    );
  }

  List<LeadershipAppointment> possibleManagers(
    List<LeadershipAppointment> leaders,
    String sectionId,
  ) {
    return leaders
        .where(
          (leader) =>
              leader.sectionId == sectionId &&
              (leader.level == LeadershipLevel.sectionHead ||
                  leader.level == LeadershipLevel.deputy),
        )
        .toList(growable: false);
  }

  Future<void> _seed(String tenantId) async {
    for (final section in initialAcademicSections) {
      await _localDatabase.upsertLocalRecord(
        tenantId: tenantId,
        entityType: _sectionEntity,
        entityId: section.id,
        payload: section.toJson(),
      );
    }
    for (final leader in initialLeadershipAppointments) {
      await _localDatabase.upsertLocalRecord(
        tenantId: tenantId,
        entityType: _leaderEntity,
        entityId: leader.id,
        payload: leader.toJson(),
      );
    }
  }

  LeadershipAppointment? _leaderById(
    List<LeadershipAppointment> leaders,
    String? id,
  ) {
    if (id == null || id.isEmpty) return null;
    for (final leader in leaders) {
      if (leader.id == id) return leader;
    }
    return null;
  }

  String _nextLeaderId(List<LeadershipAppointment> leaders) {
    var maxNumber = 0;
    for (final leader in leaders) {
      final parsed = int.tryParse(leader.id.replaceFirst('L-', '')) ?? 0;
      if (parsed > maxNumber) maxNumber = parsed;
    }
    return 'L-${(maxNumber + 1).toString().padLeft(3, '0')}';
  }
}
