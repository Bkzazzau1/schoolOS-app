import '../domain/administrator_lifecycle_models.dart';

const administratorLifecycleWebsiteSeed = <AdministratorLifecycleRecord>[
  AdministratorLifecycleRecord(
    id: 'STU-003',
    studentName: 'Yusuf Bello',
    workflow: 'Transfer out',
    change: 'Awaiting records pack',
    status: AdministratorLifecycleStatus.pending,
  ),
  AdministratorLifecycleRecord(
    id: 'PRI-006',
    studentName: 'Ahmad Musa',
    workflow: 'Promotion',
    change: 'Primary 6 → JSS 1',
    status: AdministratorLifecycleStatus.pending,
    fromClass: 'Primary 6',
    toClass: 'JSS 1',
  ),
  AdministratorLifecycleRecord(
    id: 'STU-005',
    studentName: 'Abdullahi Umar',
    workflow: 'Class change',
    change: 'SS1A → SS1B',
    status: AdministratorLifecycleStatus.pending,
    fromClass: 'SS1A',
    toClass: 'SS1B',
  ),
  AdministratorLifecycleRecord(
    id: 'ALM-001',
    studentName: 'Fatima Musa',
    workflow: 'Alumni',
    change: 'Completed',
    status: AdministratorLifecycleStatus.completed,
  ),
];
