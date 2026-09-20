import '../domain/teacher_students_models.dart';

const teacherStudentKpis = <(String, String, String)>[
  ('Assigned students', '150', 'Across 4 classes'),
  ('Strong / stable', '128', 'Within expected range'),
  ('Watch list', '14', 'Needs closer monitoring'),
  ('At risk', '8', 'Academic or attendance concern'),
];

const teacherStudents = <TeacherStudentSummary>[
  TeacherStudentSummary(
    id: 'STU-J2A-001',
    name: 'Maryam Abdullahi',
    className: 'JSS 2A',
    average: 86,
    attendance: 96,
    trend: 4.2,
    risk: TeacherStudentRisk.strong,
    intervention: 'None',
    attention: 'No current major concern. Continue normal academic and co-curricular support.',
  ),
  TeacherStudentSummary(
    id: 'STU-J2A-002',
    name: 'Ibrahim Sani',
    className: 'JSS 2A',
    average: 61,
    attendance: 88,
    trend: -3.1,
    risk: TeacherStudentRisk.watch,
    intervention: 'Revision support',
    attention: 'Recent Mathematics decline needs review across more than one assessment before changing support.',
  ),
  TeacherStudentSummary(
    id: 'STU-J2B-001',
    name: 'Yusuf Bello',
    className: 'JSS 2B',
    average: 48,
    attendance: 79,
    trend: -8.4,
    risk: TeacherStudentRisk.atRisk,
    intervention: 'Guardian + academic follow-up',
    attention: 'Attendance weakness and academic decline are appearing together. Review context with teacher and guardian before deciding next support action.',
  ),
  TeacherStudentSummary(
    id: 'STU-J3A-001',
    name: 'Fatima Musa',
    className: 'JSS 3A',
    average: 91,
    attendance: 98,
    trend: 6.0,
    risk: TeacherStudentRisk.strong,
    intervention: 'None',
    attention: 'Strong current academic and attendance evidence. Continue normal support and enrichment.',
  ),
  TeacherStudentSummary(
    id: 'STU-S1A-001',
    name: 'Abdullahi Umar',
    className: 'SS 1A',
    average: 68,
    attendance: 91,
    trend: -1.9,
    risk: TeacherStudentRisk.stable,
    intervention: 'Subject-level review',
    attention: 'Overall stable; Physics and Further Mathematics need routine subject-level review.',
  ),
];

const teacherStudentProfiles = <TeacherStudentProfile>[
  TeacherStudentProfile(
    id: 'STU-J2A-001',
    admissionNo: 'BGA/2023/SEC/001',
    name: 'Maryam Abdullahi',
    className: 'JSS 2A',
    status: 'Strong',
    average: 86,
    attendance: 96,
    trend: 4.2,
    classTeacher: 'Mrs. Amina Yusuf',
    attention: 'No current major concern. Continue normal academic and co-curricular support.',
    subjects: [
      TeacherStudentSubjectEvidence(name: 'Mathematics', score: 88, trend: 3.0),
      TeacherStudentSubjectEvidence(name: 'English', score: 84, trend: 2.1),
      TeacherStudentSubjectEvidence(name: 'Basic Science', score: 87, trend: 5.2),
      TeacherStudentSubjectEvidence(name: 'Social Studies', score: 85, trend: 4.0),
    ],
    attendanceSummary: [
      TeacherStudentAttendanceEvidence(label: 'Present', value: '96%'),
      TeacherStudentAttendanceEvidence(label: 'Late', value: '2'),
      TeacherStudentAttendanceEvidence(label: 'Excused', value: '1'),
      TeacherStudentAttendanceEvidence(label: 'Unexplained', value: '0'),
    ],
    timeline: [
      TeacherStudentTimelineItem(
        date: '10 Sep',
        title: 'Debate recognition',
        detail: 'Recognized for contribution to inter-house debate preparation.',
        visibility: 'School + Guardian',
      ),
      TeacherStudentTimelineItem(
        date: '6 Sep',
        title: 'Assessment completed',
        detail: 'Basic Science assessment recorded at 87%.',
        visibility: 'Teacher + Leadership + Guardian',
      ),
      TeacherStudentTimelineItem(
        date: '2 Sep',
        title: 'Attendance review',
        detail: 'Attendance remained above section target.',
        visibility: 'Leadership + Teacher',
      ),
    ],
  ),
  TeacherStudentProfile(
    id: 'STU-J2A-002',
    admissionNo: '',
    name: 'Ibrahim Sani',
    className: 'JSS 2A',
    status: 'Watch',
    average: 61,
    attendance: 88,
    trend: -3.1,
    classTeacher: 'Mrs. Amina Yusuf',
    attention: 'Recent Mathematics decline needs review across more than one assessment before changing support.',
    subjects: [],
    attendanceSummary: [],
    timeline: [],
  ),
  TeacherStudentProfile(
    id: 'STU-J2B-001',
    admissionNo: 'BGA/2023/SEC/003',
    name: 'Yusuf Bello',
    className: 'JSS 2B',
    status: 'At risk',
    average: 48,
    attendance: 79,
    trend: -8.4,
    classTeacher: 'Mr. Sani Bello',
    attention: 'Attendance weakness and academic decline are appearing together. Review context with teacher and guardian before deciding next support action.',
    subjects: [
      TeacherStudentSubjectEvidence(name: 'Mathematics', score: 42, trend: -11.0),
      TeacherStudentSubjectEvidence(name: 'English', score: 51, trend: -5.0),
      TeacherStudentSubjectEvidence(name: 'Basic Science', score: 46, trend: -9.0),
      TeacherStudentSubjectEvidence(name: 'Social Studies', score: 53, trend: -4.0),
    ],
    attendanceSummary: [
      TeacherStudentAttendanceEvidence(label: 'Present', value: '79%'),
      TeacherStudentAttendanceEvidence(label: 'Late', value: '5'),
      TeacherStudentAttendanceEvidence(label: 'Excused', value: '3'),
      TeacherStudentAttendanceEvidence(label: 'Unexplained', value: '6'),
    ],
    timeline: [
      TeacherStudentTimelineItem(
        date: '8 Sep',
        title: 'Teacher intervention',
        detail: 'Short Mathematics revision support plan started.',
        visibility: 'Teacher + Leadership',
      ),
    ],
  ),
  TeacherStudentProfile(
    id: 'STU-J3A-001',
    admissionNo: '',
    name: 'Fatima Musa',
    className: 'JSS 3A',
    status: 'Strong',
    average: 91,
    attendance: 98,
    trend: 6.0,
    classTeacher: 'Mrs. Zainab Lawal',
    attention: 'Strong current academic and attendance evidence. Continue normal support and enrichment.',
    subjects: [],
    attendanceSummary: [],
    timeline: [],
  ),
  TeacherStudentProfile(
    id: 'STU-S1A-001',
    admissionNo: '',
    name: 'Abdullahi Umar',
    className: 'SS 1A',
    status: 'Stable',
    average: 68,
    attendance: 91,
    trend: -1.9,
    classTeacher: 'Mr. Umar Faruq',
    attention: 'Overall stable; Physics and Further Mathematics need routine subject-level review.',
    subjects: [],
    attendanceSummary: [],
    timeline: [],
  ),
];

const teacherStudentAiInsight =
    'Yusuf Bello shows the strongest combined review signal in this demo: attendance is below 80% and recent assessment performance is declining. Suggested action: short diagnostic revision, then controlled guardian follow-up through SchoolOS messaging.';

const teacherStudentsPrivacyBoundary =
    'Teachers can only access students assigned to their authorized classes. Finance, family-account details, medical/genotype/blood data, unrelated classes, confidential administrative records, leadership-only timeline items and other schools remain outside this Teacher cache.';

const teacherStudentsEvidenceBoundary =
    'Risk and attention labels describe current evidence for human review. They must not become automatic punishment, promotion/failure, diagnosis, permanent ability labels or safeguarding decisions.';

const teacherStudentNoteBoundary =
    'A teacher note is a professional teaching/intervention note. Saving it locally does not change marks, attendance, student status, guardian delivery or leadership records.';
