import '../../administrator/domain/administrator_staff_models.dart';
import '../domain/proprietor_structure_models.dart';
import 'owner_staff_profile_repository.dart';
import 'proprietor_structure_repository.dart';

/// One real campus, worked out from the school's sections and staff records.
class CampusView {
  const CampusView({
    required this.id,
    required this.name,
    required this.sections,
    required this.classes,
    required this.staff,
    required this.teachers,
    required this.leaders,
    required this.filesToComplete,
  });

  final String id;
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
  const OwnerCampuses({
    required this.campuses,
    required this.allSections,
    required this.unassignedStaff,
  });

  final List<CampusView> campuses;

  /// Every real section, whatever campus (if any) it is assigned to - so a section can be
  /// assigned or reassigned even before or after a campus has any others.
  final List<AcademicSection> allSections;

  /// Staff whose section is not one of the school's sections, so they belong to no campus yet.
  final int unassignedStaff;

  int get sections => allSections.length;
  int get classes => campuses.fold(0, (n, c) => n + c.classes);
  int get staff => campuses.fold(0, (n, c) => n + c.staff);
  int get unassignedSections => allSections.where((s) => s.campusId.isEmpty).length;
}

OwnerCampuses buildCampuses({
  required List<Campus> campuses,
  required List<AcademicSection> sections,
  required List<AdministratorStaffRecord> staff,
}) {
  final byCampusId = <String, List<AcademicSection>>{};
  for (final s in sections) {
    if (s.campusId.isEmpty) continue;
    byCampusId.putIfAbsent(s.campusId, () => []).add(s);
  }
  final sectionNames = {for (final s in sections) s.name.trim().toLowerCase()};

  final views = [
    for (final campus in campuses)
      () {
        final value = byCampusId[campus.id] ?? const <AcademicSection>[];
        final names = {for (final s in value) s.name.trim().toLowerCase()};
        final people = [for (final p in staff) if (names.contains(p.section.trim().toLowerCase())) p];
        return CampusView(
          id: campus.id,
          name: campus.name,
          sections: value,
          classes: value.fold(0, (n, s) => n + s.classes),
          staff: people.length,
          teachers: people.where((p) => p.role.toLowerCase().contains('teacher')).length,
          leaders: [
            for (final s in value)
              if (s.leaderName.trim().isNotEmpty) '${s.leaderName}, ${s.leaderTitle} (${s.name})',
          ],
          filesToComplete: people.where((p) => p.needsAttention).length,
        );
      }(),
  ]..sort((a, b) => a.name.compareTo(b.name));

  return OwnerCampuses(
    campuses: views,
    allSections: sections,
    unassignedStaff: staff.where((p) => !sectionNames.contains(p.section.trim().toLowerCase())).length,
  );
}

class OwnerCampusesRepository {
  OwnerCampusesRepository({required this.structure, required this.profiles});

  final ProprietorStructureRepository structure;
  final OwnerStaffProfileRepository profiles;

  Future<OwnerCampuses> load() async {
    final snapshot = await structure.load();
    return buildCampuses(
      campuses: snapshot.campuses,
      sections: snapshot.sections,
      staff: await profiles.people(),
    );
  }

  Future<StructureChangeResult> addCampus(String name) => structure.saveCampus(name: name);

  Future<StructureChangeResult> renameCampus(CampusView campus, String name) =>
      structure.saveCampus(id: campus.id, name: name);

  Future<StructureChangeResult> assignCampus(AcademicSection section, String campusId) =>
      structure.assignCampus(section, campusId);
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
