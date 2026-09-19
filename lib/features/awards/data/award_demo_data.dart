import '../domain/award_models.dart';

const awardsWebsiteSeed = <AwardRecognition>[
  AwardRecognition(
    id: 'AW-001',
    title: 'Teacher of the Term',
    recipient: 'Mrs. Fatima Bello',
    recipientType: AwardRecipientType.teacher,
    section: 'Secondary',
    category: 'Teaching Excellence',
    citation:
        'Recognized for consistent lesson preparation, strong learner engagement and support for colleagues during the term.',
    issuer: 'School Leadership',
    date: '13 Sep 2026',
    visibility: AwardVisibility.schoolAndParents,
    badge: '★',
  ),
  AwardRecognition(
    id: 'AW-002',
    title: 'Kindness & Community Award',
    recipient: 'Child Amina',
    recipientType: AwardRecipientType.student,
    section: 'Early Years',
    category: 'Positive Contribution',
    citation:
        'Celebrated for helping classmates during routines and participating warmly in collaborative play.',
    issuer: 'Early Years Team',
    date: '12 Sep 2026',
    visibility: AwardVisibility.schoolAndParents,
    badge: '♥',
  ),
  AwardRecognition(
    id: 'AW-003',
    title: 'Inter-House Sports Champion',
    recipient: 'Blue House',
    recipientType: AwardRecipientType.house,
    section: 'Whole school',
    category: 'Sports',
    citation:
        'Highest combined points after athletics, relay and field events, with excellent sportsmanship across age groups.',
    issuer: 'Sports Committee',
    date: '10 Sep 2026',
    visibility: AwardVisibility.publicShowcase,
    badge: '◆',
  ),
  AwardRecognition(
    id: 'AW-004',
    title: 'Most Improved Reader',
    recipient: 'Hauwa Musa',
    recipientType: AwardRecipientType.student,
    section: 'Primary 6',
    category: 'Growth & Progress',
    citation:
        'Recognized for sustained improvement in reading fluency and consistent participation in reading-week activities.',
    issuer: 'Primary School',
    date: '9 Sep 2026',
    visibility: AwardVisibility.schoolAndParents,
    badge: '↑',
  ),
  AwardRecognition(
    id: 'AW-005',
    title: 'Innovation Showcase Award',
    recipient: 'Coding & Robotics Club',
    recipientType: AwardRecipientType.club,
    section: 'Primary + Secondary',
    category: 'Innovation',
    citation:
        'Awarded for designing a simple school-environment monitoring prototype during the term showcase.',
    issuer: 'ICT Department',
    date: '8 Sep 2026',
    visibility: AwardVisibility.publicShowcase,
    badge: '✦',
  ),
];

const awardsTermRecognitionCount = 37;
const awardsTeacherCount = 6;
const awardsStudentRecognitionCount = 21;
const awardsTeamHouseCount = 7;

List<AwardStat> awardStats(List<AwardRecognition> awards) => [
      const AwardStat(
        'Recognitions this term',
        '$awardsTermRecognitionCount',
        'Students, teachers, teams and clubs',
      ),
      const AwardStat(
        'Teacher awards',
        '$awardsTeacherCount',
        'Supportive recognition',
      ),
      const AwardStat(
        'Student recognitions',
        '$awardsStudentRecognitionCount',
        'Achievement + growth + contribution',
      ),
      const AwardStat(
        'Team / house awards',
        '$awardsTeamHouseCount',
        'Sports, clubs and service',
      ),
      AwardStat(
        'Public showcase',
        '${awards.where((award) => award.isPublic).length}',
        'Approved public-facing items',
      ),
    ];

const awardRecognitionCategories = <String, String>{
  'Academic growth':
      'Improvement, effort, research or project work—not only highest marks.',
  'Teaching excellence':
      'Recognition for preparation, support, innovation and contribution.',
  'Sports & activities':
      'Individual, team, club and house achievement.',
  'Character & service':
      'Kindness, leadership, attendance, community service and school contribution.',
  'Creative & innovation':
      'Music, drama, art, coding, science, design and other creative work.',
};

const awardVisibilityDestinations = <String, String>{
  'School dashboards':
      'Current community recognitions and recent achievements.',
  'Parent portal':
      'Recognition involving their child plus approved school-wide highlights.',
  'Community feed':
      'Authorized award posts can generate celebration threads.',
  'Public showcase':
      'Only approved recognition with appropriate privacy/media consent.',
};

const earlyYearsRecognitionGuardrail =
    'Recognition should celebrate participation, kindness, creativity, confidence and developmental milestones without creating a public “best child” league table or fixed ability label.';

const recognitionRankingBoundary =
    'Recognition should celebrate meaningful achievements without creating permanent high-stakes rankings.';
