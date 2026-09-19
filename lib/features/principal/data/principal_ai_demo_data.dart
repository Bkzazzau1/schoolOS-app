import '../domain/principal_ai_models.dart';

const principalAISuggestedQuestions = <String>[
  'What needs my attention today?',
  'Why is JSS 2B declining?',
  'Which teachers need support?',
  'Which students are at risk?',
  'Compare this term with the previous term',
  'Which classes are behind on syllabus coverage?',
];

const principalAIPrioritySignals = <PrincipalAIPrioritySignal>[
  PrincipalAIPrioritySignal(rank: 1, title: 'JSS 2B combined risk', detail: 'Academic decline + attendance weakness + syllabus lag.', priority: 'High', target: 'academics'),
  PrincipalAIPrioritySignal(rank: 2, title: 'Science coverage', detail: 'Staff absence may affect lesson coverage and pace.', priority: 'High', target: 'timetable'),
  PrincipalAIPrioritySignal(rank: 3, title: 'Report approval', detail: 'JSS 2B report cards are still awaiting principal review.', priority: 'Medium', target: 'approvals'),
  PrincipalAIPrioritySignal(rank: 4, title: 'Student Gamma', detail: 'Highest combined student risk in the prototype dataset.', priority: 'Medium', target: 'students'),
];

const principalAIResponses = <String, PrincipalAIInsight>{
  'What needs my attention today?': PrincipalAIInsight(
    title: 'Today’s principal priorities',
    answer: 'Three issues deserve attention first: JSS 2B is showing combined academic and attendance decline; one staff absence is affecting Science coverage; and the JSS 2B report-card batch is still awaiting approval. These issues are operationally connected, so the most useful sequence is attendance follow-up, teacher coverage confirmation, then report release review.',
    evidence: [
      'JSS 2B average: 61%, trend: -6.8%',
      'JSS 2B attendance: 85%, below other monitored classes',
      'Mr. Peter James: second absence this month',
      'JSS 2B report batch: awaiting principal approval',
    ],
    actions: [
      PrincipalAIAction(label: 'Open JSS 2B academics', target: 'academics'),
      PrincipalAIAction(label: 'Review attendance', target: 'attendance'),
      PrincipalAIAction(label: 'Open approvals', target: 'approvals'),
    ],
    confidence: PrincipalAIConfidence.high,
    scope: 'Academics · Attendance · Teachers · Approvals',
  ),
  'Why is JSS 2B declining?': PrincipalAIInsight(
    title: 'JSS 2B decline analysis',
    answer: 'The strongest prototype explanation is not a single subject issue. JSS 2B combines lower attendance, slower syllabus progress and incomplete assessment activity. Mathematics is specifically behind target, but the broader pattern suggests that attendance and instructional pace are reinforcing each other. A class-level intervention is more appropriate than treating Mathematics alone.',
    evidence: [
      'Class average: 61%, down 6.8%',
      'Attendance: 85%',
      'Syllabus coverage: 63%',
      'Assessment completion: 72%',
      'Mathematics identified as a pacing concern',
    ],
    actions: [
      PrincipalAIAction(label: 'Open Academics', target: 'academics'),
      PrincipalAIAction(label: 'View Students', target: 'students'),
      PrincipalAIAction(label: 'Message class team', target: 'communication'),
    ],
    confidence: PrincipalAIConfidence.high,
    scope: 'Academics · Students · Attendance',
  ),
  'Which teachers need support?': PrincipalAIInsight(
    title: 'Teacher support priorities',
    answer: 'Mr. Peter James is the clearest support priority in the current prototype data. His attendance, punctuality, lesson-plan completion, syllabus pace and assessment completion are all below the stronger teacher cohort. Mrs. Amina Yusuf and Mrs. Fatima Bello have high workloads, but their compliance indicators remain comparatively strong, so workload monitoring is more appropriate than performance escalation.',
    evidence: [
      'Mr. Peter James attendance: 89%',
      'Punctuality: 84%',
      'Lesson plans: 72%',
      'Syllabus: 62%',
      'Assessment completion: 69%',
      'Amina Yusuf and Fatima Bello both carry heavy workloads',
    ],
    actions: [
      PrincipalAIAction(label: 'Open Teachers', target: 'teachers'),
      PrincipalAIAction(label: 'Review Timetable', target: 'timetable'),
      PrincipalAIAction(label: 'Send support message', target: 'communication'),
    ],
    confidence: PrincipalAIConfidence.high,
    scope: 'Teachers · Attendance · Timetable',
  ),
  'Which students are at risk?': PrincipalAIInsight(
    title: 'Student risk summary',
    answer: 'Student Gamma is the highest combined prototype risk because academic decline and attendance weakness are occurring together, alongside two recorded incidents. Student Beta is on a watch list due to declining performance despite more acceptable attendance. Student Epsilon is currently stable but should be monitored in Physics and Further Mathematics.',
    evidence: [
      'Student Gamma: average 48%, attendance 79%, trend -8.4%',
      'Student Gamma: two incidents and two interventions',
      'Student Beta: average 61%, trend -3.1%',
      'Student Epsilon: stable overall with subject-specific weakness',
    ],
    actions: [
      PrincipalAIAction(label: 'Open Students', target: 'students'),
      PrincipalAIAction(label: 'Review Incidents', target: 'incidents'),
      PrincipalAIAction(label: 'Contact guardians', target: 'communication'),
    ],
    confidence: PrincipalAIConfidence.high,
    scope: 'Students · Attendance · Incidents · Results',
  ),
  'Compare this term with the previous term': PrincipalAIInsight(
    title: 'Term-on-term comparison',
    answer: 'The current prototype shows stronger performance in JSS 2A and JSS 3A, while JSS 2B and SS 1A are below their recent direction. Attendance is broadly stable school-wide, but the classes with declining academic results also show weaker syllabus or assessment completion. This means the school-wide average can look healthy while a small number of classes still need targeted intervention.',
    evidence: [
      'JSS 2A trend: +4.7%',
      'JSS 3A trend: +6.4%',
      'JSS 2B trend: -6.8%',
      'SS 1A trend: -1.9%',
      'School-wide monitored results remain mostly above 68%',
    ],
    actions: [
      PrincipalAIAction(label: 'Open Results', target: 'results'),
      PrincipalAIAction(label: 'Open Academics', target: 'academics'),
    ],
    confidence: PrincipalAIConfidence.medium,
    scope: 'Results · Academics',
  ),
  'Which classes are behind on syllabus coverage?': PrincipalAIInsight(
    title: 'Syllabus coverage exceptions',
    answer: 'JSS 2B is the clearest syllabus concern at 63% coverage, followed by SS 1A at 69%. JSS 2A is stronger at 74%, while JSS 3A is currently the healthiest monitored class at 84%. The priority should be to confirm whether the lag comes from missed lessons, teacher workload, attendance disruption or topic difficulty before changing the timetable.',
    evidence: [
      'JSS 2B syllabus: 63%',
      'SS 1A syllabus: 69%',
      'JSS 2A syllabus: 74%',
      'JSS 3A syllabus: 84%',
    ],
    actions: [
      PrincipalAIAction(label: 'Open Academics', target: 'academics'),
      PrincipalAIAction(label: 'Review Teachers', target: 'teachers'),
      PrincipalAIAction(label: 'Review Timetable', target: 'timetable'),
    ],
    confidence: PrincipalAIConfidence.high,
    scope: 'Academics · Teachers · Timetable',
  ),
};

const principalAIDefaultQuestion = 'What needs my attention today?';

PrincipalAIInsight resolvePrincipalAIInsight(String question) {
  final direct = principalAIResponses[question];
  if (direct != null) return direct;
  final normalized = question.toLowerCase();
  if (normalized.contains('jss 2b') || normalized.contains('declin')) return principalAIResponses['Why is JSS 2B declining?']!;
  if (normalized.contains('teacher') || normalized.contains('staff')) return principalAIResponses['Which teachers need support?']!;
  if (normalized.contains('student') || normalized.contains('risk')) return principalAIResponses['Which students are at risk?']!;
  if (normalized.contains('syllabus') || normalized.contains('coverage')) return principalAIResponses['Which classes are behind on syllabus coverage?']!;
  if (normalized.contains('term') || normalized.contains('compare')) return principalAIResponses['Compare this term with the previous term']!;
  final base = principalAIResponses[principalAIDefaultQuestion]!;
  return PrincipalAIInsight(
    title: 'School-wide prototype analysis',
    answer: 'This prototype AI workspace is not connected to the production data layer yet. It can currently demonstrate school-wide reasoning using the portal’s mock data. In production, the same question must be answered only from records the active principal is permitted to access, with tenant and role filters applied before any context is sent to the model.',
    evidence: base.evidence,
    actions: base.actions,
    confidence: PrincipalAIConfidence.medium,
    scope: base.scope,
  );
}

const principalAIGuardrail = 'Principal AI must resolve the active school, membership and principal permissions before retrieving data. It must never search another school, expose finance or staff-confidential records outside the principal’s permission set, or make automatic safeguarding/disciplinary decisions.';

const principalAIProductionPrinciple = 'The model should never receive an unrestricted database dump. SchoolOS should retrieve the smallest authorized context first, then ask the model to reason over that context. That keeps tenant isolation and role permissions outside the model rather than trusting the model to enforce them.';

const principalAIDataPath = <String>['Principal', 'Active school', 'Role & permissions', 'Allowed records', 'Context builder', 'AI answer'];
