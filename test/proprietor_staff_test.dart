import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_staff_models.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_overview.dart';
import 'package:schoolos_app/features/proprietor/domain/owner_staff_profile_models.dart';
import 'package:schoolos_app/features/proprietor/domain/proprietor_structure_models.dart';

StaffOverviewPerson person(
  String id,
  String name,
  String role,
  String section, {
  bool missing = false,
  StaffOnboardingStatus onboarding = StaffOnboardingStatus.none,
  List<StaffCredential> credentials = const [],
  double? rate,
}) => StaffOverviewPerson(
  record: AdministratorStaffRecord(
    id: id,
    name: name,
    role: role,
    section: section,
    fileStatus: missing ? AdministratorStaffFileStatus.missingDocument : AdministratorStaffFileStatus.complete,
  ),
  profile: StaffProfile(staffId: id, onboardingStatus: onboarding, credentials: credentials),
  attendanceRate: rate,
);

void main() {
  final now = DateTime(2026, 9, 21);

  test('an empty school says so instead of showing made-up numbers', () {
    final o = buildStaffOverview(people: const [], sections: const [], leaders: const [], now: now);
    expect(o.empty, isTrue);
    expect(o.kpis.first.value, '0');
    expect(o.attention, isEmpty);
    expect(o.kpis.firstWhere((k) => k.label == 'Staff attendance').value, 'Not recorded');
  });

  test('counts, attendance and the section mix come from the staff records', () {
    final o = buildStaffOverview(
      people: [
        person('1', 'Grace', 'Class Teacher', 'Primary', rate: 90),
        person('2', 'Daniel', 'Subject Teacher', 'Secondary', rate: 100),
        person('3', 'Peter', 'Security', 'Primary'),
      ],
      sections: const [],
      leaders: const [],
      now: now,
    );
    String kpi(String label) => o.kpis.firstWhere((k) => k.label == label).value;
    expect(kpi('Staff on record'), '3');
    expect(kpi('Teaching staff'), '2');
    expect(kpi('Staff attendance'), '95%');
    expect(o.mix.firstWhere((m) => m.section == 'Primary').count, 2);
    expect(o.total, 3);
  });

  test('missing documents, open onboarding and ending credentials each raise something to act on', () {
    final o = buildStaffOverview(
      people: [
        person('1', 'Grace', 'Teacher', 'Primary', missing: true),
        person('2', 'Daniel', 'Teacher', 'Secondary', onboarding: StaffOnboardingStatus.submitted),
        person('3', 'Amina', 'Teacher', 'Secondary', credentials: const [
          StaffCredential(title: 'TRCN licence', issuer: 'TRCN', expiry: '2026-10-05'),
          StaffCredential(title: 'First aid', issuer: 'Red Cross', expiry: '2028-01-01'),
        ]),
      ],
      sections: const [],
      leaders: const [],
      now: now,
    );
    final titles = [for (final a in o.attention) a.title];
    expect(titles, contains('Grace: a document is missing'));
    expect(titles, contains('Daniel: onboarding is open'));
    expect(titles, contains('Amina: TRCN licence is ending'));
    expect(titles.length, 3);
    expect(o.kpis.firstWhere((k) => k.label == 'Credentials ending').value, '1');
  });

  test('a leader is marked for review when someone in their section has an incomplete file', () {
    final o = buildStaffOverview(
      people: [person('1', 'Grace', 'Teacher', 'Primary', missing: true), person('2', 'Daniel', 'Teacher', 'Secondary')],
      sections: const [
        AcademicSection(id: 's1', name: 'Primary', stage: 'Primary', campus: 'Main', leaderTitle: 'Headmistress', leaderName: 'Mrs. Hauwa Sule', classes: 6),
        AcademicSection(id: 's2', name: 'Secondary', stage: 'Secondary', campus: 'Main', leaderTitle: 'Principal', leaderName: 'Mr. Ibrahim Danladi', classes: 6),
      ],
      leaders: const [
        LeadershipAppointment(id: 'l1', person: 'Mrs. Hauwa Sule', title: 'Headmistress', level: LeadershipLevel.sectionHead, sectionId: 's1'),
        LeadershipAppointment(id: 'l2', person: 'Mr. Ibrahim Danladi', title: 'Principal', level: LeadershipLevel.sectionHead, sectionId: 's2'),
      ],
      now: now,
    );
    expect(o.leaders.firstWhere((l) => l.name == 'Mrs. Hauwa Sule').needsReview, isTrue);
    expect(o.leaders.firstWhere((l) => l.name == 'Mr. Ibrahim Danladi').needsReview, isFalse);
    expect(o.leaders.first.team, '1 staff');
  });
}
