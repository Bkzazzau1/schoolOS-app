import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/service/data/service_policy_copy.dart';
import 'package:schoolos_app/features/service/domain/service_models.dart';

List<ServiceProject> _projects() => const [
      ServiceProject(
        id: 'SV-TEST-001',
        title: 'School Environment Clean-Up',
        type: 'Service',
        audience: 'JSS 2 + JSS 3',
        coordinator: 'Environmental Club',
        date: '19 Sep 2026',
        participants: 74,
        hours: 148,
        status: ServiceProjectStatus.planned,
        beneficiary: 'School community',
        note: 'Supervised campus clean-up and waste-sorting activity.',
      ),
      ServiceProject(
        id: 'SV-TEST-002',
        title: 'Primary Reading Buddies',
        type: 'Peer support',
        audience: 'Primary 5–6',
        coordinator: 'Primary Literacy Team',
        date: 'Weekly',
        participants: 28,
        hours: 84,
        status: ServiceProjectStatus.active,
        beneficiary: 'Primary 1–2 readers',
        note: 'Older pupils support younger readers in supervised short sessions.',
      ),
      ServiceProject(
        id: 'SV-TEST-003',
        title: 'Community Food Drive',
        type: 'Community support',
        audience: 'Whole school families',
        coordinator: 'School Community Committee',
        date: '25 Sep 2026',
        participants: 112,
        hours: 0,
        status: ServiceProjectStatus.active,
        beneficiary: 'Local community partners',
        note: 'Voluntary donation campaign coordinated with approved community organizations.',
      ),
      ServiceProject(
        id: 'SV-TEST-004',
        title: 'Tree Planting Day',
        type: 'Environment',
        audience: 'Secondary + clubs',
        coordinator: 'Science Department',
        date: '5 Sep 2026',
        participants: 46,
        hours: 138,
        status: ServiceProjectStatus.completed,
        beneficiary: 'School environment',
        note: 'Students and staff planted and labelled trees around the campus.',
        verified: true,
      ),
    ];

void main() {
  test('service stats are computed entirely from the real projects given, never a fixed sample', () {
    final stats = serviceStats(_projects());
    expect(stats[0].value, '4');
    expect(stats[1].value, '260');
    expect(stats[2].value, '370');
    expect(stats[3].value, '2');
    expect(stats[4].value, '1');

    final empty = serviceStats(const []);
    expect(empty.every((s) => s.value == '0'), isTrue);
  });

  test('Tree Planting Day is initially completed and verified', () {
    final project = _projects().singleWhere((project) => project.id == 'SV-TEST-004');

    expect(project.title, 'Tree Planting Day');
    expect(project.status, ServiceProjectStatus.completed);
    expect(project.verified, isTrue);
    expect(project.hours, 138);
  });

  test('Community Food Drive is contribution based with zero hours', () {
    final project = _projects().singleWhere((project) => project.id == 'SV-TEST-003');

    expect(project.isContributionBased, isTrue);
    expect(project.hours, 0);
    expect(project.participants, 112);
  });

  test('service search covers title audience and coordinator', () {
    final project = _projects()[1];

    expect(project.matches('reading buddies'), isTrue);
    expect(project.matches('primary 5'), isTrue);
    expect(project.matches('literacy team'), isTrue);
    expect(project.matches('environmental club'), isFalse);
  });

  test('copyWith only changes the fields given', () {
    final updated = _projects().first.copyWith(verified: true, hours: 200);
    final json = updated.toJson();
    final restored = ServiceProject.fromJson(json);

    expect(restored.verified, isTrue);
    expect(restored.hours, 200);
    expect(restored.id, 'SV-TEST-001');
    expect(restored.status, ServiceProjectStatus.planned);
  });

  test('service principles keep volunteering separate from academics', () {
    expect(servicePrinciples, hasLength(3));
    expect(servicePrinciples.keys, contains('Voluntary where appropriate'));
    expect(servicePrinciples.keys, contains('Supervised'));
    expect(servicePrinciples.keys, contains('Recognizable, not academic'));
    expect(
      servicePrinciples['Recognizable, not academic'],
      contains('not silently alter grades'),
    );
  });

  test('connected modules require appropriate review', () {
    expect(serviceConnectedModules, contains('Community posts'));
    expect(serviceConnectedModules, contains('Awards & Recognition'));
    expect(serviceConnectedModules, contains('Houses/Teams points'));
    expect(serviceConnectedModules, contains('after appropriate review'));
  });

  test('status labels preserve website wording', () {
    expect(
      ServiceProjectStatus.values.map((status) => status.label),
      ['Planned', 'Active', 'Completed'],
    );
  });
}
