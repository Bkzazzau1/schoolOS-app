import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/assembly/data/assembly_policy_copy.dart';
import 'package:schoolos_app/features/assembly/domain/assembly_models.dart';

List<AssemblySession> _sessions() => const [
      AssemblySession(
        id: 'ASM-TEST-01',
        title: 'Monday Whole-School Assembly',
        type: AssemblySessionType.generalAssembly,
        audience: 'Whole school',
        day: 'Monday',
        time: '7:45 AM',
        venue: 'Main assembly ground',
        lead: 'School Leadership',
        participation: 'Whole school',
        note: 'Announcements, recognition, safety reminders and weekly priorities.',
      ),
      AssemblySession(
        id: 'ASM-TEST-02',
        title: 'Primary Values Assembly',
        type: AssemblySessionType.sectionAssembly,
        audience: 'Primary',
        day: 'Wednesday',
        time: '8:00 AM',
        venue: 'Primary courtyard',
        lead: 'Headmistress Office',
        participation: 'Primary pupils + staff',
        note: 'Age-appropriate school values, reading, songs and pupil presentations.',
      ),
      AssemblySession(
        id: 'ASM-TEST-03',
        title: 'Friday Faith Programme',
        type: AssemblySessionType.faithReligious,
        audience: 'Configured participants',
        day: 'Friday',
        time: '12:30 PM',
        venue: 'Configured venue',
        lead: 'Approved school coordinator',
        participation: 'School-policy controlled',
        note: 'Example faith activity. Schools configure programme type, audience, alternatives and participation rules to fit their own context.',
      ),
    ];

void main() {
  test('assembly stats are computed from the real sessions given, never a fixed sample', () {
    final stats = assemblyStats(_sessions());
    expect(stats[0].value, '3');
    expect(stats[1].value, '1');
    expect(stats[2].value, '1');
    expect(stats[3].value, '1');
    expect(stats[4].value, 'Config');

    expect(assemblyStats(const []).every((stat) => stat.value == '0' || stat.value == 'Config'), isTrue);
  });

  test('faith programme remains explicitly tenant configurable', () {
    final faith = _sessions().singleWhere(
      (session) => session.type == AssemblySessionType.faithReligious,
    );

    expect(faith.audience, 'Configured participants');
    expect(faith.venue, 'Configured venue');
    expect(faith.participation, 'School-policy controlled');
    expect(faith.note, contains('alternatives'));
  });

  test('assembly filtering covers query and type without merging audiences', () {
    final sessions = _sessions();
    final primary = sessions[1];
    final faith = sessions[2];

    expect(primary.matches('headmistress', null), isTrue);
    expect(primary.matches('primary', AssemblySessionType.sectionAssembly), isTrue);
    expect(primary.matches('primary', AssemblySessionType.civic), isFalse);
    expect(faith.matches('configured', AssemblySessionType.faithReligious), isTrue);
  });

  test('assembly session serialization preserves participation metadata', () {
    final original = _sessions().first;
    final restored = AssemblySession.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.type, original.type);
    expect(restored.audience, original.audience);
    expect(restored.participation, original.participation);
  });

  test('copyWith only changes the fields given', () {
    final original = _sessions().first;
    final updated = original.copyWith(venue: 'New venue', time: '9:00 AM');
    expect(updated.venue, 'New venue');
    expect(updated.time, '9:00 AM');
    expect(updated.title, original.title);
    expect(updated.type, original.type);
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
