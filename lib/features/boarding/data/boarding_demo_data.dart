import '../domain/boarding_models.dart';

const boardingWebsiteSeed = <BoardingDorm>[
  BoardingDorm(
    name: 'Amina Hall',
    houseParent: 'Mrs. Grace Daniel',
    capacity: 48,
    occupied: 44,
    onCampus: 42,
    approvedLeave: 2,
    maintenance: 0,
    status: DormStatus.normal,
    note: 'Girls senior dormitory; evening roll and welfare handover complete.',
  ),
  BoardingDorm(
    name: 'Unity Hall',
    houseParent: 'Mr. Samuel Peter',
    capacity: 52,
    occupied: 49,
    onCampus: 47,
    approvedLeave: 2,
    maintenance: 0,
    status: DormStatus.normal,
    note: 'Boys senior dormitory; normal operations.',
  ),
  BoardingDorm(
    name: 'Peace Hall',
    houseParent: 'Mrs. Ruth Musa',
    capacity: 36,
    occupied: 32,
    onCampus: 31,
    approvedLeave: 1,
    maintenance: 2,
    status: DormStatus.review,
    note: 'Two maintenance items awaiting facilities follow-up.',
  ),
];

const boardingBoundaryRules = <String, String>{
  'Welfare, not surveillance':
      'Use roll checks, duty handover and approved leave—not intrusive monitoring.',
  'Restricted records':
      'Private welfare or health details belong in authorized workflows.',
  'Optional by tenant':
      'Day schools should not carry unused hostel navigation once tenant configuration is implemented.',
};

const boardingDisabledPreviewNote =
    'In production, a day school would disable Boarding in tenant settings and the module would disappear from shared navigation. This local preview does not persist or alter access.';

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
      'Local UI only',
    ),
    BoardingStat('Dorm occupancy', '$occupied/$capacity', 'Current mock residents'),
    BoardingStat('On campus', '$onCampus', 'Derived from dorm records'),
    BoardingStat(
      'Approved leave',
      '$approvedLeave',
      'Expected return tracked separately',
    ),
    BoardingStat('Maintenance items', '$maintenance', 'Facilities follow-up'),
  ];
}
