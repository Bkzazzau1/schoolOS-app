import '../domain/administrator_students_models.dart';

const administratorStudentsWebsiteSeed = <AdministratorStudentRecord>[
  AdministratorStudentRecord(
    id: 'STU-001',
    name: 'Maryam Abdullahi',
    className: 'JSS 2A',
    primaryGuardian: 'Alhaji Abdullahi Musa',
    status: AdministratorStudentStatus.active,
  ),
  AdministratorStudentRecord(
    id: 'STU-002',
    name: 'Ibrahim Sani',
    className: 'JSS 2A',
    primaryGuardian: 'Alhaji Sani Ibrahim',
    status: AdministratorStudentStatus.active,
  ),
  AdministratorStudentRecord(
    id: 'STU-003',
    name: 'Yusuf Bello',
    className: 'JSS 2B',
    primaryGuardian: 'Alhaji Musa Bello',
    status: AdministratorStudentStatus.transferPending,
  ),
  AdministratorStudentRecord(
    id: 'PRI-003',
    name: 'Hafsa Abdullahi',
    className: 'Primary 3',
    primaryGuardian: 'Alhaji Abdullahi Sani',
    status: AdministratorStudentStatus.active,
  ),
];

const administratorFamilyTasks = <AdministratorStudentTask>[
  AdministratorStudentTask(
    title: '2 guardian links awaiting verification',
    detail: 'Confirm relationship and access scope before activation.',
  ),
  AdministratorStudentTask(
    title: '1 sibling link requested',
    detail: 'Family account can link children without merging individual records.',
  ),
];

const administratorRecordQualityTasks = <AdministratorStudentTask>[
  AdministratorStudentTask(
    title: '7 profiles missing one document',
    detail: 'Mostly previous-school records.',
  ),
  AdministratorStudentTask(
    title: '3 emergency contacts need review',
    detail: 'Contact details incomplete.',
  ),
];
