import '../domain/principal_students_models.dart';

const principalStudentSummaries = <PrincipalStudentSummary>[
  PrincipalStudentSummary(id: 'STU-001', name: 'Maryam Abdullahi', className: 'JSS 2A', average: 86, attendance: 96, trend: 4.2, behaviour: PrincipalStudentBehaviour.excellent, risk: PrincipalStudentRisk.strong, incidents: 0, interventions: 0, guardian: 'Alhaji Abdullahi Musa', concern: 'No current concern'),
  PrincipalStudentSummary(id: 'STU-002', name: 'Ibrahim Sani', className: 'JSS 2A', average: 61, attendance: 88, trend: -3.1, behaviour: PrincipalStudentBehaviour.good, risk: PrincipalStudentRisk.watch, incidents: 1, interventions: 1, guardian: 'Alhaji Sani Ibrahim', concern: 'Mathematics performance has declined across two assessments'),
  PrincipalStudentSummary(id: 'STU-003', name: 'Yusuf Bello', className: 'JSS 2B', average: 48, attendance: 79, trend: -8.4, behaviour: PrincipalStudentBehaviour.needsAttention, risk: PrincipalStudentRisk.atRisk, incidents: 2, interventions: 2, guardian: 'Alhaji Musa Bello', concern: 'Low attendance and academic decline require coordinated follow-up'),
  PrincipalStudentSummary(id: 'STU-004', name: 'Fatima Musa', className: 'JSS 3A', average: 91, attendance: 98, trend: 6.0, behaviour: PrincipalStudentBehaviour.excellent, risk: PrincipalStudentRisk.strong, incidents: 0, interventions: 0, guardian: 'Hajiya Aisha Musa', concern: 'Strong performance across subjects'),
  PrincipalStudentSummary(id: 'STU-005', name: 'Abdullahi Umar', className: 'SS 1A', average: 68, attendance: 91, trend: -1.9, behaviour: PrincipalStudentBehaviour.good, risk: PrincipalStudentRisk.stable, incidents: 0, interventions: 1, guardian: 'Alhaji Umar Abdullahi', concern: 'Physics and Further Mathematics slightly below target'),
  PrincipalStudentSummary(id: 'STU-006', name: 'Zainab Aliyu', className: 'SS 2A', average: 74, attendance: 93, trend: 2.1, behaviour: PrincipalStudentBehaviour.good, risk: PrincipalStudentRisk.stable, incidents: 0, interventions: 0, guardian: 'Alhaji Aliyu Ibrahim', concern: 'No major concern'),
];

const principalStudentClasses = ['All classes', 'JSS 2A', 'JSS 2B', 'JSS 3A', 'SS 1A', 'SS 2A'];
const principalStudentRiskFilters = ['All statuses', 'Strong', 'Stable', 'Watch', 'At risk'];
const principalStudentProfileTabs = ['Overview', 'Academics', 'Attendance', 'Family', 'School Life', 'Services', 'History', 'Status & Promotion', 'Documents', 'Timeline', 'Notes'];
const principalStudentLifecycleActions = ['Promote', 'Move class', 'Transfer out', 'Withdraw', 'Mark alumni'];

const principalStudentsScopeBoundary = 'Principal student oversight is limited to the active Secondary School leadership scope. Primary and Early Years remain under their own leadership memberships.';
const principalStudentNoteBoundary = 'Leadership notes are internal professional records. They must not automatically appear in guardian reports, community posts or student-visible views unless deliberately approved for sharing.';
const principalStudentLifecycleBoundary = 'Lifecycle actions are proposed with actor, date, destination and reason. Historical enrollment is append-only; current class/status is not silently overwritten offline.';
const principalStudentHealthBoundary = 'Medical information is minimum-necessary and separately authorized. Attendance or academic performance must never be used to infer a diagnosis.';
const principalStudentAiBoundary = 'AI can surface combined academic, attendance and behaviour signals for human review. It must not automatically label, punish, suspend, promote or exclude a student.';

const principalStudentPermissions = PrincipalStudentPermissions(
  canViewSecondaryStudents: true,
  canAddLeadershipNote: true,
  canCreateLifecycleProposal: true,
  canManagePrimary: false,
  canViewConfidentialFinance: false,
);

PrincipalStudentProfile principalStudentProfileFor(PrincipalStudentSummary summary) {
  if (summary.id == 'STU-001') return _maryam;
  if (summary.id == 'STU-003') return _yusuf;
  return _generatedProfile(summary);
}

final _maryam = PrincipalStudentProfile(
  summary: principalStudentSummaries[0],
  admissionNo: 'BGA/2023/SEC/001',
  campus: 'Kaduna Campus',
  enrollmentStatus: PrincipalStudentEnrollmentStatus.active,
  classTeacher: 'Mrs. Amina Yusuf',
  guardianPhone: '+234 800 111 0001',
  familyAccountId: 'FAM-ABD-0041',
  admissionDate: '12 Sep 2023',
  dateOfBirth: '14 Feb 2013',
  gender: 'Female',
  house: 'Blue House',
  medicalInstruction: 'No active school-day medical instruction in this mock record.',
  healthRecordLabel: 'Restricted',
  transport: 'BUS-02 · Barnawa / Kakuri Route',
  meals: 'Standard school menu',
  boarding: 'Day student',
  feeVisibility: 'Finance team + authorized guardian only',
  previousSchool: 'Al-Hikmah Primary School, Kaduna',
  activities: const ['Chess Club', 'Debate & Public Speaking'],
  awards: const ['Excellent Attendance · Term 2', 'Debate Team Recognition'],
  subjects: const [
    PrincipalStudentSubject(name: 'Mathematics', score: 88, trend: '+3.0'),
    PrincipalStudentSubject(name: 'English', score: 84, trend: '+2.1'),
    PrincipalStudentSubject(name: 'Basic Science', score: 87, trend: '+5.2'),
    PrincipalStudentSubject(name: 'Social Studies', score: 85, trend: '+4.0'),
  ],
  attendanceSummary: const [
    PrincipalStudentLabelValue(label: 'Present', value: '96%'),
    PrincipalStudentLabelValue(label: 'Late', value: '2'),
    PrincipalStudentLabelValue(label: 'Excused', value: '1'),
    PrincipalStudentLabelValue(label: 'Unexplained', value: '0'),
  ],
  promotionHistory: const [
    PrincipalStudentHistoryRow(session: '2025/2026', className: 'JSS 1A', outcome: 'Promoted to JSS 2', note: 'Normal progression'),
    PrincipalStudentHistoryRow(session: '2024/2025', className: 'Primary 6', outcome: 'Completed', note: 'Admission transition record'),
  ],
  documents: const [
    PrincipalStudentDocument(name: 'Admission form', status: 'Verified', visibility: 'Leadership + Records'),
    PrincipalStudentDocument(name: 'Birth record', status: 'Verified', visibility: 'Leadership + Records'),
    PrincipalStudentDocument(name: 'Guardian consent', status: 'Current', visibility: 'Leadership + Guardian'),
  ],
  timeline: const [
    PrincipalStudentTimelineItem(date: '10 Sep', title: 'Debate recognition', detail: 'Recognized for contribution to inter-house debate preparation.', visibility: 'School + Guardian'),
    PrincipalStudentTimelineItem(date: '6 Sep', title: 'Assessment completed', detail: 'Basic Science assessment recorded at 87%.', visibility: 'Teacher + Leadership + Guardian'),
    PrincipalStudentTimelineItem(date: '2 Sep', title: 'Attendance review', detail: 'Attendance remained above section target.', visibility: 'Leadership + Teacher'),
  ],
);

final _yusuf = PrincipalStudentProfile(
  summary: principalStudentSummaries[2],
  admissionNo: 'BGA/2023/SEC/003',
  campus: 'Kaduna Campus',
  enrollmentStatus: PrincipalStudentEnrollmentStatus.active,
  classTeacher: 'Mr. Sani Bello',
  guardianPhone: '+234 800 111 0003',
  familyAccountId: 'FAM-BEL-0087',
  admissionDate: '9 Sep 2023',
  dateOfBirth: '22 Jun 2012',
  gender: 'Male',
  house: 'Red House',
  medicalInstruction: 'Health details restricted. No diagnosis should be inferred from attendance or performance data.',
  healthRecordLabel: 'Restricted',
  transport: 'No school transport',
  meals: 'Standard school menu',
  boarding: 'Day student',
  feeVisibility: 'Finance team + authorized guardian only',
  previousSchool: 'Darul Ilm Academy, Kaduna',
  activities: const ['Football Academy'],
  awards: const ['House Participation · Term 1'],
  subjects: const [
    PrincipalStudentSubject(name: 'Mathematics', score: 42, trend: '-11.0'),
    PrincipalStudentSubject(name: 'English', score: 51, trend: '-5.0'),
    PrincipalStudentSubject(name: 'Basic Science', score: 46, trend: '-9.0'),
    PrincipalStudentSubject(name: 'Social Studies', score: 53, trend: '-4.0'),
  ],
  attendanceSummary: const [
    PrincipalStudentLabelValue(label: 'Present', value: '79%'),
    PrincipalStudentLabelValue(label: 'Late', value: '5'),
    PrincipalStudentLabelValue(label: 'Excused', value: '3'),
    PrincipalStudentLabelValue(label: 'Unexplained', value: '6'),
  ],
  promotionHistory: const [
    PrincipalStudentHistoryRow(session: '2025/2026', className: 'JSS 1B', outcome: 'Promoted to JSS 2', note: 'Support plan continued'),
    PrincipalStudentHistoryRow(session: '2024/2025', className: 'Primary 6', outcome: 'Completed', note: 'Admission transition record'),
  ],
  documents: const [
    PrincipalStudentDocument(name: 'Admission form', status: 'Verified', visibility: 'Leadership + Records'),
    PrincipalStudentDocument(name: 'Birth record', status: 'Verified', visibility: 'Leadership + Records'),
    PrincipalStudentDocument(name: 'Guardian contact record', status: 'Current', visibility: 'Leadership + Guardian'),
  ],
  timeline: const [
    PrincipalStudentTimelineItem(date: '12 Sep', title: 'Guardian follow-up requested', detail: 'Leadership requested coordinated attendance and learning follow-up.', visibility: 'Leadership + Guardian'),
    PrincipalStudentTimelineItem(date: '8 Sep', title: 'Teacher intervention', detail: 'Short Mathematics revision support plan started.', visibility: 'Teacher + Leadership'),
    PrincipalStudentTimelineItem(date: '4 Sep', title: 'Attendance pattern reviewed', detail: 'Repeated absences flagged for human follow-up; no family cause inferred.', visibility: 'Leadership only'),
  ],
);

PrincipalStudentProfile _generatedProfile(PrincipalStudentSummary summary) {
  final score = summary.average.clamp(35, 96).toInt();
  final digits = summary.id.replaceAll(RegExp(r'\D'), '').padLeft(3, '0');
  return PrincipalStudentProfile(
    summary: summary,
    admissionNo: 'BGA/2026/SEC/${digits.substring(digits.length - 3)}',
    campus: 'Kaduna Campus',
    enrollmentStatus: PrincipalStudentEnrollmentStatus.active,
    classTeacher: switch (summary.id) {
      'STU-002' => 'Mrs. Amina Yusuf',
      'STU-004' => 'Mrs. Zainab Lawal',
      'STU-005' => 'Mr. Umar Faruq',
      'STU-006' => 'Mrs. Hauwa Sani',
      _ => 'Secondary class teacher',
    },
    guardianPhone: '+234 800 111 0000',
    familyAccountId: 'FAM-${summary.id.replaceAll('-', '')}',
    admissionDate: 'Current school record',
    dateOfBirth: 'Restricted operational record',
    gender: 'Recorded in authorized student record',
    house: 'Green House',
    medicalInstruction: 'No general medical detail exposed in this generated profile.',
    healthRecordLabel: 'Restricted',
    transport: 'Service relationship not configured in this sample',
    meals: 'Standard school menu',
    boarding: 'Day student',
    feeVisibility: 'Finance team + authorized guardian only',
    previousSchool: 'Previous-school record available to authorized admissions staff',
    activities: const ['School activity participation'],
    awards: summary.risk == PrincipalStudentRisk.strong ? const ['Positive contribution recognition'] : const [],
    subjects: [
      PrincipalStudentSubject(name: 'Mathematics', score: score - 4, trend: '${summary.trend}'),
      PrincipalStudentSubject(name: 'English', score: score + 2, trend: '${summary.trend / 2}'),
    ],
    attendanceSummary: [
      PrincipalStudentLabelValue(label: 'Present', value: '${summary.attendance}%'),
      const PrincipalStudentLabelValue(label: 'Late', value: '—'),
      const PrincipalStudentLabelValue(label: 'Excused', value: '—'),
      const PrincipalStudentLabelValue(label: 'Unexplained', value: '—'),
    ],
    promotionHistory: [PrincipalStudentHistoryRow(session: '2025/2026', className: 'Previous class', outcome: 'Progressed to ${summary.className}', note: 'Representative mock progression record')],
    documents: const [
      PrincipalStudentDocument(name: 'Admission form', status: 'Verified', visibility: 'Leadership + Records'),
      PrincipalStudentDocument(name: 'Guardian record', status: 'Current', visibility: 'Leadership + Guardian'),
    ],
    timeline: const [PrincipalStudentTimelineItem(date: 'Current term', title: 'Profile summary', detail: 'Representative student record generated from the directory mock for consistent profile navigation.', visibility: 'Teacher + Leadership')],
  );
}
