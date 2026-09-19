class ProprietorSchoolLifeCapability {
  const ProprietorSchoolLifeCapability({
    required this.key,
    required this.module,
    required this.tag,
    required this.description,
    required this.level,
    required this.detail,
    required this.webPath,
  });

  final String key;
  final String module;
  final String tag;
  final String description;
  final String level;
  final String detail;
  final String webPath;
}

const proprietorSchoolLifeCapabilities = <ProprietorSchoolLifeCapability>[
  ProprietorSchoolLifeCapability(
    key: 'community',
    module: 'Community',
    tag: 'Social',
    description:
        'Private school discussion feed with posts, comments, reactions, scoped audiences, moderation and approved public showcase content.',
    level: 'Manage school-wide',
    detail:
        'Post, moderate, pin and approve selected public-showcase content across the school.',
    webPath: '/community',
  ),
  ProprietorSchoolLifeCapability(
    key: 'noticeboard',
    module: 'Noticeboard',
    tag: 'Official',
    description:
        'Authoritative announcements with publishing authority, urgency, audience scope, expiry, read receipts and acknowledgement.',
    level: 'Publish school-wide',
    detail:
        'Publish whole-school, campus, section or audience-specific official notices and emergencies.',
    webPath: '/noticeboard',
  ),
  ProprietorSchoolLifeCapability(
    key: 'activities',
    module: 'Activities & Clubs',
    tag: 'Co-curricular',
    description:
        'Sports, clubs, creative programmes and enrichment activities with coordinators, schedules, attendance and participation.',
    level: 'Manage all',
    detail:
        'Create programmes, clubs, sports and enrichment activities and appoint coordinators.',
    webPath: '/activities',
  ),
  ProprietorSchoolLifeCapability(
    key: 'events',
    module: 'Events & Calendar',
    tag: 'Calendar',
    description:
        'One school calendar for parent meetings, sports days, section events, club showcases, academic events and holidays.',
    level: 'Manage all',
    detail:
        'Create school-wide and section events and resolve school-level scheduling conflicts.',
    webPath: '/events',
  ),
  ProprietorSchoolLifeCapability(
    key: 'houses',
    module: 'Houses & Teams',
    tag: 'Belonging',
    description:
        'School houses, captains, coordinators, points, competitions and service activity without affecting academic grades.',
    level: 'Manage all',
    detail:
        'Configure houses, coordinators, captains, competitions and school-life points.',
    webPath: '/houses',
  ),
  ProprietorSchoolLifeCapability(
    key: 'gallery',
    module: 'Media Gallery',
    tag: 'Media',
    description:
        'Audience-scoped photo and video albums with internal, parent and separately approved public-showcase visibility.',
    level: 'Approve visibility',
    detail:
        'Manage albums and approve parent/public showcase visibility subject to consent rules.',
    webPath: '/gallery',
  ),
  ProprietorSchoolLifeCapability(
    key: 'excursions',
    module: 'Excursions & Consent',
    tag: 'Trips',
    description:
        'Trip planning, destinations, transport, guardian consent, manifests, emergency-readiness checks and supervision.',
    level: 'Manage all',
    detail:
        'Approve trips, consent, transport/readiness workflows and excursion policy.',
    webPath: '/excursions',
  ),
  ProprietorSchoolLifeCapability(
    key: 'transport',
    module: 'School Transport',
    tag: 'Operations',
    description:
        'Routes, vehicles, drivers, assistants, stops, rider checks and maintenance readiness with private route details.',
    level: 'Manage fleet & routes',
    detail:
        'Configure vehicles, routes, transport staff, service availability and school-wide transport policy.',
    webPath: '/transport',
  ),
  ProprietorSchoolLifeCapability(
    key: 'meals',
    module: 'Meals & Cafeteria',
    tag: 'Operations',
    description:
        'Weekly menus, service counts and safe meal exceptions while keeping dietary and health details restricted.',
    level: 'Manage service',
    detail:
        'Configure meal service, menus and operational policy while sensitive exceptions remain need-to-know.',
    webPath: '/meals',
  ),
  ProprietorSchoolLifeCapability(
    key: 'boarding',
    module: 'Boarding & Hostel',
    tag: 'Optional',
    description:
        'Optional dorm occupancy, approved leave, duty handover, welfare coordination and facilities follow-up for boarding schools.',
    level: 'Configure / disable',
    detail:
        'Enable or disable boarding and manage dorm structure, capacity and delegated boarding leadership.',
    webPath: '/boarding',
  ),
  ProprietorSchoolLifeCapability(
    key: 'assembly',
    module: 'Assembly & Faith Activities',
    tag: 'School culture',
    description:
        'Whole-school and section assemblies, civic programmes, wellbeing gatherings and configurable faith activities.',
    level: 'Configure school-wide',
    detail:
        'Set assembly, civic, wellbeing and optional faith-programme structures and participation policy.',
    webPath: '/assembly',
  ),
  ProprietorSchoolLifeCapability(
    key: 'visitors',
    module: 'Visitor Management',
    tag: 'Front office',
    description:
        'Expected visitors, host, purpose, permitted area, pass and checkout records with restricted visibility.',
    level: 'Govern front office',
    detail:
        'Set visitor-access policy and review operational visitor controls without making logs public.',
    webPath: '/visitors',
  ),
  ProprietorSchoolLifeCapability(
    key: 'lost-found',
    module: 'Lost & Found',
    tag: 'Front office',
    description:
        'Found-item logging, storage, claim verification and return status without exposing identifying details publicly.',
    level: 'Manage policy',
    detail:
        'Configure retention/claim policy and front-office ownership of found-item records.',
    webPath: '/lost-found',
  ),
  ProprietorSchoolLifeCapability(
    key: 'service',
    module: 'Service & Volunteering',
    tag: 'Community',
    description:
        'Supervised school and community projects, participants, service hours and contribution records separate from academic marks.',
    level: 'Manage all',
    detail:
        'Create or approve school/community service programmes and recognition policy.',
    webPath: '/service',
  ),
  ProprietorSchoolLifeCapability(
    key: 'awards',
    module: 'Awards & Recognition',
    tag: 'Recognition',
    description:
        'Celebrate students, teachers, teams, houses, clubs and service without turning recognition into permanent ranking.',
    level: 'Issue & publish',
    detail:
        'Approve school-wide awards and decide internal, parent or public visibility.',
    webPath: '/awards',
  ),
  ProprietorSchoolLifeCapability(
    key: 'teaching-models',
    module: 'Teaching Models',
    tag: 'Academic structure',
    description:
        'Configure Class Teacher, Subject Teacher or Hybrid models by section and class—including one-class-one-teacher Primary structures.',
    level: 'Configure all sections',
    detail:
        'Set Class Teacher, Subject Teacher or Hybrid structures across Nursery, Primary and Secondary.',
    webPath: '/teaching-models',
  ),
];

const proprietorSchoolLifeScope = 'Whole school';
const proprietorSchoolLifeNote =
    'Owner-level access across the complete School Life and school operations layer.';

const proprietorSchoolLifeAccessPrinciple =
    'One module, different authority: membership, campus, section, class and delegated duties determine what each person can see or do.';

const proprietorSchoolLifeProductionRule =
    'UI permissions are not security. Transport, meals, boarding, visitor, consent and publishing access must also be authorized by the backend.';
