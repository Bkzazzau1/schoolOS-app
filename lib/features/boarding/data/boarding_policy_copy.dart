import '../domain/boarding_models.dart';

/// Static guidance copy for Boarding & Hostel - not data about this school, so it never needs a
/// real backend source. Real activity (dorms) lives in [BoardingRepository] instead.
const boardingBoundaryRules = <String, String>{
  'Welfare, not surveillance':
      'Use roll checks, duty handover and approved leave—not intrusive monitoring.',
  'Restricted records':
      'Private welfare or health details belong in authorized workflows.',
  'Optional by tenant':
      'Day schools should not carry unused hostel navigation once tenant configuration is implemented.',
};

const boardingDisabledPreviewNote =
    'Preview only. Your school settings have not changed.';

/// Computed entirely from [dorms] - the real, locally-held dormitories a school has actually
/// created, never fixed sample counts.
List<BoardingStat> boardingStats(
  List<BoardingDorm> dorms, {
  required bool previewEnabled,
}) {
  final occupied = dorms.fold<int>(0, (sum, dorm) => sum + dorm.occupied);
  final capacity = dorms.fold<int>(0, (sum, dorm) => sum + dorm.capacity);
  final onCampus = dorms.fold<int>(0, (sum, dorm) => sum + dorm.onCampus);
  final approvedLeave =
      dorms.fold<int>(0, (sum, dorm) => sum + dorm.approvedLeave);
  final maintenance =
      dorms.fold<int>(0, (sum, dorm) => sum + dorm.maintenance);

  return [
    BoardingStat(
      'Preview state',
      previewEnabled ? 'Enabled' : 'Off',
      'Preview only',
    ),
    BoardingStat('Dorm occupancy', '$occupied/$capacity', 'Across all real dorms'),
    BoardingStat('On campus', '$onCampus', 'Derived from dorm records'),
    BoardingStat(
      'Approved leave',
      '$approvedLeave',
      'Expected return tracked separately',
    ),
    BoardingStat('Maintenance items', '$maintenance', 'Facilities follow-up'),
  ];
}
