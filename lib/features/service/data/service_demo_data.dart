import '../domain/service_models.dart';

const serviceWebsiteSeed = <ServiceProject>[
  ServiceProject(
    id: 'SV-001',
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
    id: 'SV-002',
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
    id: 'SV-003',
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
    id: 'SV-004',
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

List<ServiceStat> serviceStats(List<ServiceProject> projects) {
  final participants = projects.fold<int>(0, (sum, project) => sum + project.participants);
  final hours = projects.fold<int>(0, (sum, project) => sum + project.hours);
  final active = projects.where((project) => project.status == ServiceProjectStatus.active).length;
  final verified = projects.where((project) => project.verified).length;

  return <ServiceStat>[
    ServiceStat('Projects', '${projects.length}', 'Representative term activities'),
    ServiceStat('Participants', '$participants', 'Across current mock projects'),
    ServiceStat('Recorded hours', '$hours', 'Project participation hours'),
    ServiceStat('Active projects', '$active', 'Currently running'),
    ServiceStat('Verified records', '$verified', 'Local review status'),
  ];
}

const servicePrinciples = <String, String>{
  'Voluntary where appropriate':
      'Community-service programmes should follow school policy and age-appropriate participation.',
  'Supervised':
      'Named staff or coordinators own safety and attendance.',
  'Recognizable, not academic':
      'Service can support awards or certificates but should not silently alter grades.',
};

const serviceConnectedModules =
    'Completed projects can feed Community posts, Awards & Recognition, Houses/Teams points and the Media Gallery after appropriate review.';
