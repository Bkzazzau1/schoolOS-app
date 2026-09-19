import '../domain/assembly_models.dart';

const assemblyWebsiteSeed = <AssemblySession>[
  AssemblySession(
    id: 'ASM-01',
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
    id: 'ASM-02',
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
    id: 'ASM-03',
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
  AssemblySession(
    id: 'ASM-04',
    title: 'Civic & Leadership Talk',
    type: AssemblySessionType.civic,
    audience: 'Secondary',
    day: 'Thursday',
    time: '10:30 AM',
    venue: 'Assembly hall',
    lead: 'Principal Office',
    participation: 'Secondary students',
    note: 'Citizenship, leadership and school-community responsibilities.',
  ),
  AssemblySession(
    id: 'ASM-05',
    title: 'Early Years Circle Gathering',
    type: AssemblySessionType.wellbeing,
    audience: 'Early Years',
    day: 'Daily',
    time: '8:10 AM',
    venue: 'Early Years rooms',
    lead: 'Group educators',
    participation: 'Nursery / Reception',
    note: 'Songs, routine, belonging and age-appropriate group participation.',
  ),
];

const assemblyConfigurationPrinciples = <String, String>{
  'No hard-coded faith model':
      'Each school configures programmes that match its identity and obligations.',
  'Audience-aware': 'Whole-school and section gatherings remain distinct.',
  'Alternatives supported':
      'Participation rules and alternatives can be configured later where needed.',
};

List<AssemblyStat> assemblyStats(List<AssemblySession> sessions) => [
      AssemblyStat(
        'Configured sessions',
        '${sessions.length}',
        'Representative weekly pattern',
      ),
      AssemblyStat(
        'Whole-school',
        '${sessions.where((s) => s.audience == 'Whole school').length}',
        'Monday assembly',
      ),
      AssemblyStat(
        'Section sessions',
        '${sessions.where((s) => const {'Primary', 'Secondary', 'Early Years'}.contains(s.audience)).length}',
        'Primary, Secondary, Early Years',
      ),
      AssemblyStat(
        'Faith programmes',
        '${sessions.where((s) => s.type == AssemblySessionType.faithReligious).length}',
        'Tenant-configurable',
      ),
      const AssemblyStat(
        'Participation policy',
        'Config',
        'School-defined',
      ),
    ];
