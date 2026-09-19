import '../domain/principal_teachers_models.dart';

const principalTeacherDepartments = <String>[
  'All departments',
  'Mathematics',
  'Languages',
  'Science',
  'Humanities',
];

const principalTeacherStatuses = <String>[
  'All statuses',
  'Strong',
  'On track',
  'Needs support',
];

const principalTeacherKpis = <String, String>{
  'Secondary teaching staff': '24',
  'Staff attendance': '96%',
  'Needs support': '1',
  'Pending teacher work': '10',
  'Lesson-plan compliance': '89%',
  'Assessment completion': '85%',
};

const principalTeacherGuidance = <String, String>{
  'SECTION SCOPE': 'This Principal manages Secondary teachers only. Primary and Nursery remain separate.',
  'HR VIEW': 'Full staff profile shows employment, qualifications, workload, leave and documents — not confidential payroll amounts.',
  'SUPPORT FIRST': 'Use indicators for coaching and workload review rather than reducing quality to one score.',
};

const principalTeacherPayrollBoundary =
    'Salary amount, bank account, deductions, staff-loan balances and payslip detail remain restricted to the staff member and authorized HR/finance roles.';

const principalTeacherDecisionBoundary =
    'Do not use AI or a single metric to make firing, promotion, pay or disciplinary decisions automatically.';

const principalTeachersWebsiteSeed = <PrincipalTeacher>[
  PrincipalTeacher(
    id: 'TCH-001',
    name: 'Mrs. Amina Yusuf',
    initials: 'AY',
    department: 'Mathematics',
    subjects: 'Mathematics · Further Mathematics',
    classes: 4,
    students: 150,
    attendance: 98,
    punctuality: 96,
    lessonPlans: 92,
    syllabus: 71,
    assessments: 84,
    workload: 'Heavy',
    status: 'On track',
    pending: 2,
    note: 'Strong attendance and lesson planning. JSS 2B syllabus pace needs follow-up.',
  ),
  PrincipalTeacher(
    id: 'TCH-002',
    name: 'Mr. Ahmad Sani',
    initials: 'AS',
    department: 'Mathematics',
    subjects: 'Mathematics',
    classes: 3,
    students: 118,
    attendance: 97,
    punctuality: 94,
    lessonPlans: 96,
    syllabus: 83,
    assessments: 93,
    workload: 'Balanced',
    status: 'Strong',
    pending: 1,
    note: 'Consistent assessment completion and good syllabus pace.',
  ),
  PrincipalTeacher(
    id: 'TCH-003',
    name: 'Mrs. Fatima Bello',
    initials: 'FB',
    department: 'Languages',
    subjects: 'English Language',
    classes: 5,
    students: 182,
    attendance: 95,
    punctuality: 91,
    lessonPlans: 88,
    syllabus: 76,
    assessments: 86,
    workload: 'Heavy',
    status: 'On track',
    pending: 3,
    note: 'High workload. Monitor marking volume and report-card preparation.',
  ),
  PrincipalTeacher(
    id: 'TCH-004',
    name: 'Mr. Bashir Musa',
    initials: 'BM',
    department: 'Science',
    subjects: 'Basic Science · Physics',
    classes: 4,
    students: 143,
    attendance: 89,
    punctuality: 84,
    lessonPlans: 72,
    syllabus: 62,
    assessments: 69,
    workload: 'Balanced',
    status: 'Needs support',
    pending: 4,
    note: 'Repeated lateness and lower assessment completion. Schedule a support conversation.',
  ),
  PrincipalTeacher(
    id: 'TCH-005',
    name: 'Mrs. Hauwa Sani',
    initials: 'HS',
    department: 'Humanities',
    subjects: 'Social Studies · Civic Education',
    classes: 3,
    students: 105,
    attendance: 99,
    punctuality: 98,
    lessonPlans: 97,
    syllabus: 89,
    assessments: 95,
    workload: 'Light',
    status: 'Strong',
    pending: 0,
    note: 'Very strong compliance and curriculum pace.',
  ),
];

const principalTeacherProfilesWebsiteSeed = <PrincipalTeacherProfile>[
  PrincipalTeacherProfile(
    directoryId: 'TCH-001', staffId: 'TCH-2048', payrollId: 'PAY-BGA-2048', name: 'Mrs. Amina Yusuf', section: 'Secondary', campus: 'Kaduna Campus', jobTitle: 'Mathematics Teacher', department: 'Mathematics', employmentType: 'Full-time · Permanent', employmentStatus: 'Active', hireDate: '15 January 2022', qualification: 'B.Ed Mathematics', professionalId: 'TRCN-MOCK-2048', phone: '+234 800 000 0000', email: 'amina.yusuf@example.edu', nextOfKin: 'Alhaji Yusuf Ibrahim', emergencyPhone: '+234 800 000 0101', attendance: 98, punctuality: 96, weeklyPeriods: 28, workload: 'Heavy', classResponsibility: 'Subject teacher', subjects: ['Mathematics', 'Further Mathematics'],
    assignments: [PrincipalTeacherAssignment(className: 'JSS 2A', subject: 'Mathematics', periods: 7, role: 'Subject teacher'), PrincipalTeacherAssignment(className: 'JSS 2B', subject: 'Mathematics', periods: 7, role: 'Subject teacher'), PrincipalTeacherAssignment(className: 'JSS 3A', subject: 'Mathematics', periods: 7, role: 'Subject teacher'), PrincipalTeacherAssignment(className: 'SS 1A', subject: 'Further Mathematics', periods: 7, role: 'Subject teacher')],
    leave: [PrincipalTeacherLeave(type: 'Annual leave', dates: '12–13 Aug 2026', days: 2, status: 'Approved'), PrincipalTeacherLeave(type: 'Personal leave', dates: '3 Jun 2026', days: 1, status: 'Approved')],
    documents: [PrincipalTeacherDocument(name: 'B.Ed certificate', status: 'Verified', visibility: 'HR + authorized leadership'), PrincipalTeacherDocument(name: 'TRCN record', status: 'Verified', visibility: 'HR + authorized leadership'), PrincipalTeacherDocument(name: 'Employment letter', status: 'Current', visibility: 'HR + authorized leadership')],
    timeline: [PrincipalTeacherTimelineItem(date: 'Sep 2026', title: 'Teaching load reviewed', detail: 'JSS 2B syllabus pace flagged for support follow-up.'), PrincipalTeacherTimelineItem(date: 'Aug 2026', title: 'Annual leave', detail: 'Two days approved and recorded.'), PrincipalTeacherTimelineItem(date: 'May 2026', title: 'Professional development', detail: 'Completed classroom assessment workshop.')],
    supportNote: 'Strong attendance and lesson planning. JSS 2B syllabus pace needs supportive follow-up.',
  ),
  PrincipalTeacherProfile(
    directoryId: 'TCH-002', staffId: 'TCH-2051', payrollId: 'PAY-BGA-2051', name: 'Mr. Ahmad Sani', section: 'Secondary', campus: 'Kaduna Campus', jobTitle: 'Mathematics Teacher', department: 'Mathematics', employmentType: 'Full-time · Permanent', employmentStatus: 'Active', hireDate: '3 September 2021', qualification: 'B.Sc Ed Mathematics', professionalId: 'TRCN-MOCK-2051', phone: '+234 800 000 0051', email: 'ahmad.sani@example.edu', nextOfKin: 'Hajiya Maryam Sani', emergencyPhone: '+234 800 000 0151', attendance: 97, punctuality: 94, weeklyPeriods: 22, workload: 'Balanced', classResponsibility: 'Subject teacher', subjects: ['Mathematics'],
    assignments: [PrincipalTeacherAssignment(className: 'JSS 1A', subject: 'Mathematics', periods: 7, role: 'Subject teacher'), PrincipalTeacherAssignment(className: 'JSS 1B', subject: 'Mathematics', periods: 7, role: 'Subject teacher'), PrincipalTeacherAssignment(className: 'SS 2A', subject: 'Mathematics', periods: 8, role: 'Subject teacher')],
    leave: [PrincipalTeacherLeave(type: 'Annual leave', dates: '21 Aug 2026', days: 1, status: 'Approved')],
    documents: [PrincipalTeacherDocument(name: 'Degree certificate', status: 'Verified', visibility: 'HR + authorized leadership'), PrincipalTeacherDocument(name: 'Employment letter', status: 'Current', visibility: 'HR + authorized leadership')],
    timeline: [PrincipalTeacherTimelineItem(date: 'Sep 2026', title: 'Assessment review', detail: 'Assessment completion remains strong.')],
    supportNote: 'Consistent assessment completion and syllabus progress.',
  ),
  PrincipalTeacherProfile(
    directoryId: 'TCH-003', staffId: 'TCH-2057', payrollId: 'PAY-BGA-2057', name: 'Mrs. Fatima Bello', section: 'Secondary', campus: 'Kaduna Campus', jobTitle: 'English Language Teacher', department: 'Languages', employmentType: 'Full-time · Permanent', employmentStatus: 'Active', hireDate: '8 February 2023', qualification: 'B.A Ed English', professionalId: 'TRCN-MOCK-2057', phone: '+234 800 000 0057', email: 'fatima.bello@example.edu', nextOfKin: 'Alhaji Bello Musa', emergencyPhone: '+234 800 000 0157', attendance: 95, punctuality: 91, weeklyPeriods: 30, workload: 'Heavy', classResponsibility: 'Subject teacher', subjects: ['English Language'],
    assignments: [PrincipalTeacherAssignment(className: 'JSS 1A', subject: 'English Language', periods: 6, role: 'Subject teacher'), PrincipalTeacherAssignment(className: 'JSS 2A', subject: 'English Language', periods: 6, role: 'Subject teacher'), PrincipalTeacherAssignment(className: 'JSS 3A', subject: 'English Language', periods: 6, role: 'Subject teacher'), PrincipalTeacherAssignment(className: 'SS 1A', subject: 'English Language', periods: 6, role: 'Subject teacher'), PrincipalTeacherAssignment(className: 'SS 2A', subject: 'English Language', periods: 6, role: 'Subject teacher')],
    leave: [],
    documents: [PrincipalTeacherDocument(name: 'Degree certificate', status: 'Verified', visibility: 'HR + authorized leadership'), PrincipalTeacherDocument(name: 'TRCN record', status: 'Verified', visibility: 'HR + authorized leadership')],
    timeline: [PrincipalTeacherTimelineItem(date: 'Sep 2026', title: 'Workload review', detail: 'Marking volume and report preparation reviewed.')],
    supportNote: 'High workload. Monitor marking volume and report-card preparation.',
  ),
  PrincipalTeacherProfile(
    directoryId: 'TCH-004', staffId: 'TCH-2064', payrollId: 'PAY-BGA-2064', name: 'Mr. Bashir Musa', section: 'Secondary', campus: 'Kaduna Campus', jobTitle: 'Science Teacher', department: 'Science', employmentType: 'Full-time · Permanent', employmentStatus: 'Active', hireDate: '10 October 2020', qualification: 'B.Sc Ed Physics', professionalId: 'TRCN-MOCK-2064', phone: '+234 800 000 0064', email: 'bashir.musa@example.edu', nextOfKin: 'Hajiya Aisha Musa', emergencyPhone: '+234 800 000 0164', attendance: 89, punctuality: 84, weeklyPeriods: 24, workload: 'Balanced', classResponsibility: 'Subject teacher', subjects: ['Basic Science', 'Physics'],
    assignments: [PrincipalTeacherAssignment(className: 'JSS 2B', subject: 'Basic Science', periods: 8, role: 'Subject teacher'), PrincipalTeacherAssignment(className: 'SS 1A', subject: 'Physics', periods: 8, role: 'Subject teacher'), PrincipalTeacherAssignment(className: 'SS 2A', subject: 'Physics', periods: 8, role: 'Subject teacher')],
    leave: [PrincipalTeacherLeave(type: 'Medical leave', dates: '4 Jul 2026', days: 1, status: 'Approved')],
    documents: [PrincipalTeacherDocument(name: 'Degree certificate', status: 'Verified', visibility: 'HR + authorized leadership')],
    timeline: [PrincipalTeacherTimelineItem(date: 'Sep 2026', title: 'Support conversation requested', detail: 'Punctuality and assessment completion need contextual review.')],
    supportNote: 'Repeated lateness and lower assessment completion. Schedule a supportive conversation before drawing conclusions.',
  ),
  PrincipalTeacherProfile(
    directoryId: 'TCH-005', staffId: 'TCH-2070', payrollId: 'PAY-BGA-2070', name: 'Mrs. Hauwa Sani', section: 'Secondary', campus: 'Kaduna Campus', jobTitle: 'Humanities Teacher', department: 'Humanities', employmentType: 'Full-time · Permanent', employmentStatus: 'Active', hireDate: '17 April 2021', qualification: 'B.Ed Social Studies', professionalId: 'TRCN-MOCK-2070', phone: '+234 800 000 0070', email: 'hauwa.sani@example.edu', nextOfKin: 'Alhaji Sani Umar', emergencyPhone: '+234 800 000 0170', attendance: 99, punctuality: 98, weeklyPeriods: 18, workload: 'Light', classResponsibility: 'Subject teacher', subjects: ['Social Studies', 'Civic Education'],
    assignments: [PrincipalTeacherAssignment(className: 'JSS 1A', subject: 'Social Studies', periods: 6, role: 'Subject teacher'), PrincipalTeacherAssignment(className: 'JSS 2A', subject: 'Civic Education', periods: 6, role: 'Subject teacher'), PrincipalTeacherAssignment(className: 'JSS 3A', subject: 'Social Studies', periods: 6, role: 'Subject teacher')],
    leave: [],
    documents: [PrincipalTeacherDocument(name: 'Degree certificate', status: 'Verified', visibility: 'HR + authorized leadership')],
    timeline: [PrincipalTeacherTimelineItem(date: 'Sep 2026', title: 'Mentoring capacity noted', detail: 'Strong current operational indicators; possible peer-support role.')],
    supportNote: 'Strong current teaching indicators. Consider optional mentoring support, not extra workload by default.',
  ),
];

const principalTeacherPermissions = PrincipalTeacherPermissions(
  canReviewSecondaryTeachers: true,
  canSavePrivateNotes: true,
  canViewConfidentialPayroll: false,
);

const principalStaffProfileTabs = <String>[
  'Overview',
  'Employment',
  'Qualifications',
  'Teaching Load',
  'Attendance',
  'Leave',
  'Documents',
  'Timeline',
  'Leadership Notes',
  'Payroll Access',
];
