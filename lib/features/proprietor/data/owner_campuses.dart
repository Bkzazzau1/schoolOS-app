import '../../administrator/domain/administrator_staff_models.dart';
import '../domain/proprietor_structure_models.dart';
import 'owner_staff_profile_repository.dart';
import 'proprietor_structure_repository.dart';

/// One campus, worked out from the school's sections and staff records.
class CampusView {
  const CampusView({
    required this.name,
    required this.sections,
    required this.classes,
    required this.staff,
    required this.teachers,
    required this.leaders,
    required this.filesToComplete,
  });

  final String name;
  final List<AcademicSection> sections;
  final int classes;
  final int staff;
  final int teachers;

  /// Section leaders, as "Name, Title (Section)".
  final List<String> leaders;
  final int filesToComplete;
}

class OwnerCampuses {
  const OwnerCampuses({required this.campuses, required this.unassignedStaff});

  final List<CampusView> campuses;

  /// Staff whose section is not one of the school's sections, so they belong to no campus yet.
  final int unassignedStaff;

  int get sections => campuses.fold(0, (n, c) => n + c.sections.length);
  int get classes => campuses.fold(0, (n, c) => n + c.classes);
  int get staff => campuses.fold(0, (n, c) => n + c.staff);
}

OwnerCampuses buildCampuses({
  required List<AcademicSection> sections,
  required List<AdministratorStaffRecord> staff,
}) {
  final byCampus = <String, List<AcademicSection>>{};
  for (final s in sections) {
    byCampus.putIfAbsent(s.campus.trim().isEmpty ? 'Main campus' : s.campus.trim(), () => []).add(s);
  }
  final sectionNames = {for (final s in sections) s.name.trim().toLowerCase()};

  final campuses = [
    for (final e in byCampus.entries)
      () {
        final names = {for (final s in e.value) s.name.trim().toLowerCase()};
        final people = [for (final p in staff) if (names.contains(p.section.trim().toLowerCase())) p];
        return CampusView(
          name: e.key,
          sections: e.value,
          classes: e.value.fold(0, (n, s) => n + s.classes),
          staff: people.length,
          teachers: people.where((p) => p.role.toLowerCase().contains('teacher')).length,
          leaders: [
            for (final s in e.value)
              if (s.leaderName.trim().isNotEmpty) '${s.leaderName}, ${s.leaderTitle} (${s.name})',
          ],
          filesToComplete: people.where((p) => p.needsAttention).length,
        );
      }(),
  ];
  return OwnerCampuses(
    campuses: campuses,
    unassignedStaff: staff.where((p) => !sectionNames.contains(p.section.trim().toLowerCase())).length,
  );
}

class OwnerCampusesRepository {
  OwnerCampusesRepository({required this.structure, required this.profiles});

  final ProprietorStructureRepository structure;
  final OwnerStaffProfileRepository profiles;

  Future<OwnerCampuses> load() async => buildCampuses(
        sections: (await structure.load()).sections,
        staff: await profiles.people(),
      );
}

/// What a new campus needs before it should be counted. Guidance for the owner, not data.
const campusExpansionChecklist = <(String, String)>[
  ('Governance & leadership', 'Campus head, section leaders and delegated authority defined.'),
  ('Capacity & staffing', 'Classrooms, teachers, support staff and timetable readiness reviewed.'),
  ('Finance configuration', 'Fee structure, accounts, collection channels and reporting scope configured.'),
  ('Safety & operations', 'Transport, visitor controls, health, safeguarding and emergency procedures configured.'),
];

const campusIsolationPrinciple =
    'Someone appointed to one campus should not automatically see or manage another. Campus scope must be enforced before '
    'records reach the user or the AI.';
