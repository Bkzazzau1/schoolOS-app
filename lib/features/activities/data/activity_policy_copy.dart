import '../domain/activity_models.dart';

/// Static guidance copy for Activities, Clubs & Sports - not data about this school, so it never
/// needs a real backend source. Real activity (programmes) lives in [ActivityRepository] instead.
const activityTimetable = <String, String>{
  'Assembly': 'Monday · 7:45 AM · Whole school',
  'Club period': 'Friday · 2:30 PM · Primary + Secondary',
  'Sports period': 'Section-specific PE and games slots',
  'Library / Lab / Creative': 'Can appear as structured non-subject periods.',
};

const activityParticipationRule =
    'Activity attendance or club participation may support recognition and engagement, but must not silently become an academic ability score.';

class ActivityStat {
  const ActivityStat(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
}

/// Computed from [activities] - the real, locally-held programmes a school has actually created,
/// never fixed sample counts.
List<ActivityStat> activityStats(List<SchoolActivity> activities) => [
      ActivityStat('Active programmes', '${activities.length}', 'Clubs, sports, creative + enrichment'),
      ActivityStat(
        'Participation entries',
        '${activities.fold<int>(0, (total, a) => total + a.members)}',
        'Not a unique-student count',
      ),
      ActivityStat(
        'Programme types',
        '${activities.map((a) => a.type).toSet().length}',
        'Sport, club, creative, enrichment',
      ),
      const ActivityStat('Dedicated workflows', '2', 'Houses + excursions separate'),
    ];
