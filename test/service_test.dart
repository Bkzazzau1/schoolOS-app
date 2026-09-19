import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/service/data/service_demo_data.dart';
import 'package:schoolos_app/features/service/domain/service_models.dart';

void main() {
  test('website service seed preserves project and KPI totals', () {
    expect(serviceWebsiteSeed, hasLength(4));

    final participants = serviceWebsiteSeed.fold<int>(
      0,
      (sum, project) => sum + project.participants,
    );
    final hours = serviceWebsiteSeed.fold<int>(
      0,
      (sum, project) => sum + project.hours,
    );
    final active = serviceWebsiteSeed
        .where((project) => project.status == ServiceProjectStatus.active)
        .length;
    final verified = serviceWebsiteSeed.where((project) => project.verified).length;

    expect(participants, 260);
    expect(hours, 370);
    expect(active, 2);
    expect(verified, 1);
  });

  test('Tree Planting Day is initially completed and verified', () {
    final project = serviceWebsiteSeed.singleWhere(
      (project) => project.id == 'SV-004',
    );

    expect(project.title, 'Tree Planting Day');
    expect(project.status, ServiceProjectStatus.completed);
    expect(project.verified, isTrue);
    expect(project.hours, 138);
  });

  test('Community Food Drive is contribution based with zero hours', () {
    final project = serviceWebsiteSeed.singleWhere(
      (project) => project.id == 'SV-003',
    );

    expect(project.isContributionBased, isTrue);
    expect(project.hours, 0);
    expect(project.participants, 112);
  });

  test('service search covers title audience and coordinator', () {
    final project = serviceWebsiteSeed[1];

    expect(project.matches('reading buddies'), isTrue);
    expect(project.matches('primary 5'), isTrue);
    expect(project.matches('literacy team'), isTrue);
    expect(project.matches('environmental club'), isFalse);
  });

  test('verification survives serialization', () {
    final updated = serviceWebsiteSeed.first.copyWith(verified: true);
    final json = updated.toJson();
    final restored = ServiceProject.fromJson(json);

    expect(restored.verified, isTrue);
    expect(restored.id, 'SV-001');
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
