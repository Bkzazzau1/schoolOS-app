import '../domain/principal_assignments_models.dart';

const principalAssignmentClasses = <String>['JSS 1A', 'JSS 2A', 'JSS 2B', 'JSS 3A', 'SS 1A', 'SS 2A'];
const principalAssignmentSubjects = <String>[
  'Mathematics',
  'English Language',
  'Basic Science',
  'Social Studies',
  'Civic Education',
  'Computer Studies',
  'Physics',
  'Further Mathematics',
  'Literature',
];

const principalAssignmentTeachers = <PrincipalAssignmentTeacher>[
  PrincipalAssignmentTeacher(id: 'TCH-001', name: 'Mrs. Amina Yusuf', department: 'Mathematics', qualifiedSubjects: ['Mathematics', 'Further Mathematics'], weeklyPeriods: 24),
  PrincipalAssignmentTeacher(id: 'TCH-002', name: 'Mr. Daniel John', department: 'Mathematics', qualifiedSubjects: ['Mathematics'], weeklyPeriods: 19),
  PrincipalAssignmentTeacher(id: 'TCH-003', name: 'Mrs. Fatima Bello', department: 'Languages', qualifiedSubjects: ['English Language', 'Literature'], weeklyPeriods: 26),
  PrincipalAssignmentTeacher(id: 'TCH-004', name: 'Mr. Peter James', department: 'Science', qualifiedSubjects: ['Basic Science', 'Physics'], weeklyPeriods: 21),
  PrincipalAssignmentTeacher(id: 'TCH-005', name: 'Mrs. Grace Musa', department: 'Humanities', qualifiedSubjects: ['Social Studies', 'Civic Education'], weeklyPeriods: 17),
  PrincipalAssignmentTeacher(id: 'TCH-006', name: 'Mr. Samuel Bello', department: 'Computing', qualifiedSubjects: ['Computer Studies'], weeklyPeriods: 18),
];

const principalAssignmentSeed = <PrincipalTeachingAssignment>[
  PrincipalTeachingAssignment(id: 'ASN-001', className: 'JSS 1A', subject: 'Mathematics', teacherId: 'TCH-002', periodsPerWeek: 5),
  PrincipalTeachingAssignment(id: 'ASN-002', className: 'JSS 1A', subject: 'English Language', teacherId: 'TCH-003', periodsPerWeek: 5),
  PrincipalTeachingAssignment(id: 'ASN-003', className: 'JSS 2A', subject: 'Mathematics', teacherId: 'TCH-001', periodsPerWeek: 5),
  PrincipalTeachingAssignment(id: 'ASN-004', className: 'JSS 2A', subject: 'Basic Science', teacherId: 'TCH-004', periodsPerWeek: 4),
  PrincipalTeachingAssignment(id: 'ASN-005', className: 'JSS 2B', subject: 'English Language', teacherId: 'TCH-003', periodsPerWeek: 5),
  PrincipalTeachingAssignment(id: 'ASN-006', className: 'JSS 3A', subject: 'Civic Education', teacherId: 'TCH-005', periodsPerWeek: 3),
  PrincipalTeachingAssignment(id: 'ASN-007', className: 'SS 1A', subject: 'Physics', teacherId: 'TCH-004', periodsPerWeek: 4),
  PrincipalTeachingAssignment(id: 'ASN-008', className: 'SS 2A', subject: 'Computer Studies', teacherId: 'TCH-006', periodsPerWeek: 3),
];

const principalUnassignedSubjects = <PrincipalUnassignedSubject>[
  PrincipalUnassignedSubject(className: 'JSS 2B', subject: 'Mathematics', periods: 5),
  PrincipalUnassignedSubject(className: 'SS 1A', subject: 'Further Mathematics', periods: 4),
  PrincipalUnassignedSubject(className: 'SS 2A', subject: 'Literature', periods: 3),
];

const principalTransferRecordScope = <String>[
  'Lesson plans and submitted teaching work',
  'Syllabus and curriculum-progress history',
  'Assessment setup and score-entry history',
  'Class teaching notes attached to the assignment',
  'Timetable and period context',
  'Assignment history and previous handover records',
];

const principalTransferPrivacyBoundary =
    'Transfer gives the incoming teacher the complete teaching record for this class-subject responsibility, but never the previous teacher’s private leadership notes, payroll, bank, medical or unrelated HR records.';

const principalAssignmentScopeBoundary =
    'The Principal may create, assign and transfer teaching responsibilities only inside the active Secondary School section. Primary and Nursery remain separate leadership scopes.';

const principalAssignmentPermissions = PrincipalAssignmentPermissions(
  canManageSecondaryAssignments: true,
  canCreateProvisionalTargets: true,
  canTransferWork: true,
  canManagePrimary: false,
);
