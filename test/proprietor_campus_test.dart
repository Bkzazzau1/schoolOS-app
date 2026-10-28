import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_staff_models.dart';
import 'package:schoolos_app/features/proprietor/data/owner_campuses.dart';
import 'package:schoolos_app/features/proprietor/domain/proprietor_structure_models.dart';

AcademicSection section(String id, String name, String campusId, int classes, {String leader = ''}) => AcademicSection(
      id: id,
      name: name,
      stage: name,
      campusId: campusId,
      leaderTitle: 'Head',
      leaderName: leader,
      classes: classes,
    );

AdministratorStaffRecord person(String id, String role, String sectionName, {bool missing = false}) => AdministratorStaffRecord(
      id: id,
      name: 'Person $id',
      role: role,
      section: sectionName,
      fileStatus: missing ? AdministratorStaffFileStatus.missingDocument : AdministratorStaffFileStatus.complete,
    );

void main() {
  test('sections are grouped into real campuses and staff are counted by their section', () {
    final result = buildCampuses(
      campuses: const [Campus(id: 'kaduna', name: 'Kaduna Campus'), Campus(id: 'zaria', name: 'Zaria Campus')],
      sections: [
        section('1', 'Primary', 'kaduna', 6, leader: 'Mrs. Sule'),
        section('2', 'Secondary', 'kaduna', 6),
        section('3', 'Primary', 'zaria', 4, leader: 'Mr. Aliyu'),
      ],
      staff: [
        person('a', 'Class Teacher', 'Primary'),
        person('b', 'Subject Teacher', 'Secondary', missing: true),
        person('c', 'Security', 'Primary'),
        person('d', 'Cleaner', 'Unknown section'),
      ],
    );
    expect(result.campuses.map((c) => c.name), ['Kaduna Campus', 'Zaria Campus']);
    final kaduna = result.campuses.first;
    expect(kaduna.sections.length, 2);
    expect(kaduna.classes, 12);
    expect(kaduna.leaders, ['Mrs. Sule, Head (Primary)']);
    expect(kaduna.filesToComplete, 1);
    expect(result.unassignedStaff, 1);
    expect(result.sections, 3);
  });

  test('a real campus with no sections yet still appears, honestly empty', () {
    final result = buildCampuses(
      campuses: const [Campus(id: 'kaduna', name: 'Kaduna Campus')],
      sections: const [],
      staff: const [],
    );
    expect(result.campuses.map((c) => c.name), ['Kaduna Campus']);
    expect(result.campuses.single.sections, isEmpty);
  });

  test('a section with no real campus yet is counted, but groups into none', () {
    final result = buildCampuses(
      campuses: const [],
      sections: [section('1', 'Primary', '', 6)],
      staff: const [],
    );
    expect(result.campuses, isEmpty);
    expect(result.sections, 1);
    expect(result.unassignedSections, 1);
  });

  test('no campuses and no sections means nothing made up', () {
    final result = buildCampuses(campuses: const [], sections: const [], staff: [person('a', 'Teacher', 'Primary')]);
    expect(result.campuses, isEmpty);
    expect(result.unassignedStaff, 1);
  });

  test('the isolation principle and expansion checklist stay as guidance', () {
    expect(campusExpansionChecklist.length, 4);
    expect(campusIsolationPrinciple, contains('scope'));
  });
}
