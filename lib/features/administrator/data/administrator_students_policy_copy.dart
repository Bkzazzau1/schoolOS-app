import '../domain/administrator_students_models.dart';

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
