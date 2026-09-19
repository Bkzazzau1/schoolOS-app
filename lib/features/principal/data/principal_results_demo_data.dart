import '../domain/principal_results_models.dart';

const principalClassResults = <PrincipalClassResult>[
  PrincipalClassResult(className: 'JSS 1A', students: 44, average: 72, passRate: 91, highest: 94, lowest: 46, complete: 100, reportsReady: 44, release: PrincipalResultReleaseState.approved, trend: 3.2),
  PrincipalClassResult(className: 'JSS 2A', students: 42, average: 76, passRate: 95, highest: 96, lowest: 52, complete: 100, reportsReady: 42, release: PrincipalResultReleaseState.released, trend: 4.7),
  PrincipalClassResult(className: 'JSS 2B', students: 39, average: 61, passRate: 74, highest: 89, lowest: 38, complete: 92, reportsReady: 35, release: PrincipalResultReleaseState.awaitingApproval, trend: -6.8),
  PrincipalClassResult(className: 'JSS 3A', students: 41, average: 79, passRate: 97, highest: 98, lowest: 55, complete: 100, reportsReady: 41, release: PrincipalResultReleaseState.approved, trend: 6.4),
  PrincipalClassResult(className: 'SS 1A', students: 37, average: 68, passRate: 86, highest: 92, lowest: 44, complete: 94, reportsReady: 34, release: PrincipalResultReleaseState.draft, trend: -1.9),
  PrincipalClassResult(className: 'SS 2A', students: 35, average: 74, passRate: 93, highest: 95, lowest: 51, complete: 100, reportsReady: 35, release: PrincipalResultReleaseState.approved, trend: 2.1),
];

const principalStudentResults = <PrincipalStudentResult>[
  PrincipalStudentResult(id: 'STU-001', name: 'Student Alpha', className: 'JSS 2A', average: 86, position: '4th of 42', attendance: 96, reportStatus: PrincipalResultReleaseState.released, teacherComment: 'Strong progress. Keep practising multi-step problems.'),
  PrincipalStudentResult(id: 'STU-002', name: 'Student Beta', className: 'JSS 2A', average: 61, position: '21st of 42', attendance: 88, reportStatus: PrincipalResultReleaseState.released, teacherComment: 'Improving steadily. Needs more revision in algebra.'),
  PrincipalStudentResult(id: 'STU-003', name: 'Student Gamma', className: 'JSS 2B', average: 48, position: '31st of 39', attendance: 79, reportStatus: PrincipalResultReleaseState.awaitingApproval, teacherComment: 'Requires targeted revision and better attendance consistency.'),
  PrincipalStudentResult(id: 'STU-004', name: 'Student Delta', className: 'JSS 3A', average: 91, position: '2nd of 41', attendance: 98, reportStatus: PrincipalResultReleaseState.approved, teacherComment: 'Excellent academic performance and class participation.'),
  PrincipalStudentResult(id: 'STU-005', name: 'Student Epsilon', className: 'SS 1A', average: 68, position: '14th of 37', attendance: 91, reportStatus: PrincipalResultReleaseState.draft, teacherComment: 'Stable overall performance. More practice is needed in Physics.'),
];

const principalReportSubjects = <PrincipalSubjectResult>[
  PrincipalSubjectResult(subject: 'Mathematics', ca: 18, exam: 64, total: 82, grade: 'A', remark: 'Excellent'),
  PrincipalSubjectResult(subject: 'English Language', ca: 16, exam: 58, total: 74, grade: 'B', remark: 'Very Good'),
  PrincipalSubjectResult(subject: 'Basic Science', ca: 17, exam: 61, total: 78, grade: 'B', remark: 'Very Good'),
  PrincipalSubjectResult(subject: 'Social Studies', ca: 15, exam: 55, total: 70, grade: 'B', remark: 'Good'),
  PrincipalSubjectResult(subject: 'Computer Studies', ca: 19, exam: 67, total: 86, grade: 'A', remark: 'Excellent'),
];

const principalResultsClassFilters = ['All classes', 'JSS 1A', 'JSS 2A', 'JSS 2B', 'JSS 3A', 'SS 1A', 'SS 2A'];
const principalResultsReleaseFilters = ['All states', 'Draft', 'Awaiting approval', 'Approved', 'Released'];

const principalDefaultComment = 'Good effort. Improve consistency in attendance and revision.';
const principalReturnComment = 'Please review the comments and score entries before resubmitting this report.';

const principalReportSchoolName = 'BrightGate Academy';
const principalReportMotto = 'Knowledge · Character · Excellence';
const principalReportLogoText = 'BGA';
const principalReportAddress = '12 Learning Avenue, Kaduna, Kaduna State, Nigeria';
const principalReportPhone = '+234 800 000 0000';
const principalReportEmail = 'info@brightgate.example';
const principalReportWebsite = 'www.brightgate.example';
const principalReportBranches = ['Kaduna Campus', 'Zaria Campus'];
const principalReportRegistration = 'School Reg. No: BGA/EDU/2026/001';
const principalReportTerm = 'First Term · 2026/2027 Academic Session';
const principalReportPrincipalName = 'Mr. Ibrahim Danladi';
const principalReportDateIssued = '13 September 2026';

int get principalResultsSchoolAverage =>
    (principalClassResults.fold<int>(0, (sum, row) => sum + row.average) / principalClassResults.length).round();
int get principalResultsPassRate =>
    (principalClassResults.fold<int>(0, (sum, row) => sum + row.passRate) / principalClassResults.length).round();
int get principalReportsReady => principalClassResults.fold<int>(0, (sum, row) => sum + row.reportsReady);
int get principalResultsPendingApproval => principalClassResults.where((row) => row.release == PrincipalResultReleaseState.awaitingApproval).length;
int get principalResultsReleasedClasses => principalClassResults.where((row) => row.release == PrincipalResultReleaseState.released).length;
