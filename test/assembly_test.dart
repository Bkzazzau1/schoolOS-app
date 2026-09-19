import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/assembly/data/assembly_demo_data.dart';
import 'package:schoolos_app/features/assembly/domain/assembly_models.dart';

void main() {
  test('website assembly seed preserves five configured sessions and types', () {
    expect(assemblyWebsiteSeed, hasLength(5));
    expect(AssemblySessionType.values, hasLength(5));
    expect(
      assemblyWebsiteSeed.map((session) => session.type).toSet(),
      containsAll(AssemblySessionType.values),
    );
  });

  test('assembly stats preserve website whole-school and section totals', () {
    final stats = assemblyStats(assemblyWebsiteSeed);

    expect(stats[0].value, '5');
    expect(stats[1].value, '1');
    expect(stats[2].value, '3');
    expect(stats[3].value, '1');
    expect(stats[4].value, 'Config');
  });

  test('faith programme remains explicitly tenant configurable', () {
    final faith = assemblyWebsiteSeed.singleWhere(
      (session) => session.type == AssemblySessionType.faithReligious,
    );

    expect(faith.id, 'ASM-03');
    expect(faith.audience, 'Configured participants');
    expect(faith.venue, 'Configured venue');
    expect(faith.participation, 'School-policy controlled');
    expect(faith.note, contains('alternatives'));
  });

  test('assembly filtering covers query and type without merging audiences', () {
    final primary = assemblyWebsiteSeed[1];
    final faith = assemblyWebsiteSeed[2];

    expect(primary.matches('headmistress', null), isTrue);
    expect(primary.matches('primary', AssemblySessionType.sectionAssembly), isTrue);
    expect(primary.matches('primary', AssemblySessionType.civic), isFalse);
    expect(faith.matches('configured', AssemblySessionType.faithReligious), isTrue);
  });

  test('assembly session serialization preserves participation metadata', () {
    final original = assemblyWebsiteSeed.first;
    final restored = AssemblySession.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.type, original.type);
    expect(restored.audience, original.audience);
    expect(restored.participation, original.participation);
  });

  test('configuration principles prevent a hard-coded faith model', () {
    expect(assemblyConfigurationPrinciples, hasLength(3));
    expect(
      assemblyConfigurationPrinciples.keys,
      contains('No hard-coded faith model'),
    );
    expect(assemblyConfigurationPrinciples.keys, contains('Audience-aware'));
    expect(
      assemblyConfigurationPrinciples.keys,
      contains('Alternatives supported'),
    );
  });
}
