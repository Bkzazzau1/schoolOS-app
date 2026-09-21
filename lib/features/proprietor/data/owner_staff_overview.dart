import '../../administrator/domain/administrator_staff_models.dart';
import '../domain/owner_staff_profile_models.dart';
import '../domain/proprietor_staff_models.dart';
import '../domain/proprietor_structure_models.dart';
import 'owner_staff_profile_repository.dart';
import 'proprietor_structure_repository.dart';

/// What the owner's Staff & HR page shows, worked out from the school's real staff records,
/// profiles and leadership structure (nothing here is typed in by hand).
class StaffOverview {
  const StaffOverview({
    required this.kpis,
    required this.leaders,
    required this.attention,
    required this.mix,
    required this.total,
    required this.empty,
  });

  final List<OwnerStaffKpi> kpis;
  final List<OwnerLeaderRow> leaders;
  final List<OwnerPeopleAttentionItem> attention;
  final List<OwnerStaffMixItem> mix;
  final int total;

  /// No staff on record yet.
  final bool empty;
}

/// A person's record with the profile details the overview needs.
class StaffOverviewPerson {
  const StaffOverviewPerson({required this.record, required this.profile, this.attendanceRate});

  final AdministratorStaffRecord record;
  final StaffProfile profile;
  final double? attendanceRate;

  bool get teaches => record.role.toLowerCase().contains('teacher');
}

/// Credentials that run out within this many days are flagged.
const credentialWarningDays = 60;

StaffOverview buildStaffOverview({
  required List<StaffOverviewPerson> people,
  required List<AcademicSection> sections,
  required List<LeadershipAppointment> leaders,
  required DateTime now,
}) {
  final soon = now.add(const Duration(days: credentialWarningDays));
  final missingFiles = [for (final p in people) if (p.record.needsAttention) p];
  final onboarding = [
    for (final p in people)
      if (p.profile.onboardingStatus == StaffOnboardingStatus.invitePending ||
          p.profile.onboardingStatus == StaffOnboardingStatus.submitted)
        p,
  ];
  final expiring = <(StaffOverviewPerson, StaffCredential)>[
    for (final p in people)
      for (final c in p.profile.credentials)
        if (c.expiryDate != null && c.expiryDate!.isBefore(soon)) (p, c),
  ];
  final rates = [for (final p in people) if (p.attendanceRate != null) p.attendanceRate!];
  final teaching = people.where((p) => p.teaches).length;

  final kpis = [
    OwnerStaffKpi(label: 'Staff on record', value: '${people.length}', note: 'Everyone with a staff file'),
    OwnerStaffKpi(label: 'Teaching staff', value: '$teaching', note: '${people.length - teaching} support and other staff'),
    OwnerStaffKpi(
      label: 'Staff attendance',
      value: rates.isEmpty ? 'Not recorded' : '${(rates.reduce((a, b) => a + b) / rates.length).round()}%',
      note: rates.isEmpty ? 'No attendance has been recorded yet' : 'Average across ${rates.length} people',
    ),
    OwnerStaffKpi(
      label: 'Files to complete',
      value: '${missingFiles.length}',
      note: missingFiles.isEmpty ? 'Every file is complete' : 'A document is missing',
    ),
    OwnerStaffKpi(
      label: 'Credentials ending',
      value: '${expiring.length}',
      note: 'Expired or ending within $credentialWarningDays days',
    ),
  ];

  final attention = <OwnerPeopleAttentionItem>[
    for (final p in missingFiles)
      OwnerPeopleAttentionItem(
        title: '${p.record.name}: a document is missing',
        detail: 'Their staff file is not complete (${p.record.role}, ${p.record.section}).',
        owner: 'Administrator',
      ),
    for (final p in onboarding)
      OwnerPeopleAttentionItem(
        title: '${p.record.name}: onboarding is open',
        detail: p.profile.onboardingStatus == StaffOnboardingStatus.submitted
            ? 'They sent their details. Review and confirm them.'
            : 'Waiting for them to fill in their details.',
        owner: p.profile.onboardingStatus == StaffOnboardingStatus.submitted ? 'Proprietor' : 'The staff member',
      ),
    for (final (p, c) in expiring)
      OwnerPeopleAttentionItem(
        title: '${p.record.name}: ${c.title} ${c.isExpired(now) ? 'has expired' : 'is ending'}',
        detail: 'Expiry date ${c.expiry}. Ask for the renewed document.',
        owner: 'HR / Proprietor',
      ),
  ];

  final bySection = <String, int>{};
  for (final p in people) {
    final name = p.record.section.trim().isEmpty ? 'No section' : p.record.section.trim();
    bySection[name] = (bySection[name] ?? 0) + 1;
  }
  final mix = [
    for (final e in bySection.entries)
      OwnerStaffMixItem(
        section: e.key,
        count: e.value,
        note: '${people.where((p) => p.record.section.trim() == e.key && p.teaches).length} teaching',
      ),
  ];

  String sectionName(String id) {
    for (final s in sections) {
      if (s.id == id) return s.name;
    }
    return 'Whole school';
  }

  final leaderRows = [
    for (final l in leaders)
      OwnerLeaderRow(
        name: l.person,
        role: l.title,
        scope: sectionName(l.sectionId),
        team: _teamText(people, sectionName(l.sectionId)),
        signal: people.any((p) => p.record.needsAttention && p.record.section == sectionName(l.sectionId)) ? 'Review' : 'On track',
      ),
  ];

  return StaffOverview(
    kpis: kpis,
    leaders: leaderRows,
    attention: attention,
    mix: mix,
    total: people.length,
    empty: people.isEmpty,
  );
}

String _teamText(List<StaffOverviewPerson> people, String section) {
  final n = people.where((p) => p.record.section == section).length;
  return n == 0 ? 'No staff on record' : '$n staff';
}

class OwnerStaffOverviewRepository {
  OwnerStaffOverviewRepository({required this.profiles, required this.structure, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final OwnerStaffProfileRepository profiles;
  final ProprietorStructureRepository structure;
  final DateTime Function() _clock;

  Future<StaffOverview> load() async {
    final staff = await profiles.people();
    final people = <StaffOverviewPerson>[];
    for (final record in staff) {
      final view = await profiles.view(record);
      people.add(StaffOverviewPerson(record: record, profile: view.profile, attendanceRate: view.attendanceRate));
    }
    final snapshot = await structure.load();
    return buildStaffOverview(people: people, sections: snapshot.sections, leaders: snapshot.leaders, now: _clock());
  }
}
