import '../domain/administrator_lifecycle_models.dart';
import '../domain/administrator_records_models.dart';
import '../domain/administrator_students_models.dart';

// The demo school: enough students, in enough classes, to show the desk working. They sit beside the four students of the
// website sample, and the lifecycle records below refer only to students that exist.

AdministratorStudentRecord _student(String id, String name, String className, String guardian) => AdministratorStudentRecord(
      id: id,
      name: name,
      className: className,
      primaryGuardian: guardian,
      status: AdministratorStudentStatus.active,
    );

final administratorStudentsDemoExtras = <AdministratorStudentRecord>[
  _student('NUR-001', 'Zainab Yusuf', 'Nursery 2', 'Mrs. Amina Yusuf'),
  _student('NUR-002', 'Bilal Kabir', 'Nursery 1', 'Mr. Sani Kabir'),
  _student('PRI-001', 'Aisha Danladi', 'Primary 1', 'Mr. Ibrahim Danladi'),
  _student('PRI-002', 'Hassan Faruq', 'Primary 2', 'Mrs. Hauwa Faruq'),
  _student('PRI-004', 'Khadija Sule', 'Primary 4', 'Mrs. Hauwa Sule'),
  _student('PRI-005', 'Musa Abubakar', 'Primary 5', 'Mr. Musa Abubakar'),
  _student('PRI-006', 'Ahmad Musa', 'Primary 6', 'Mrs. Grace Musa'),
  _student('PRI-007', 'Fatima Aliyu', 'Primary 6', 'Mr. Aliyu Garba'),
  _student('STU-004', 'Halima Sani', 'JSS 1', 'Alhaji Sani Halima'),
  _student('STU-005', 'Abdullahi Umar', 'SS1A', 'Mr. Umar Abdullahi'),
  _student('STU-006', 'Ruth John', 'SS1A', 'Mr. Daniel John'),
  _student('STU-007', 'Samuel Peter', 'SS2A', 'Mr. Peter James'),
  _student('STU-008', 'Maimuna Bello', 'SS2B', 'Alhaji Musa Bello'),
  _student('STU-009', 'Yakubu Garba', 'SS3A', 'Mr. Aliyu Garba'),
  _student('STU-010', 'Rahma Ibrahim', 'JSS 3A', 'Alhaji Ibrahim Bashir'),
  _student('STU-011', 'Ahmed Yusuf', 'JSS 2B', 'Mrs. Amina Yusuf'),
  // Registered through admissions (the applicant BGA-ADM-26082).
  _student('STU-012', 'Fatima Musa', 'JSS 2', 'Alhaji Musa Bello'),
];

/// Changes that are already part of the school's history, and one waiting to be processed.
const administratorLifecycleDemoExtras = <AdministratorLifecycleRecord>[
  AdministratorLifecycleRecord(
    id: 'LC-DEMO-001',
    studentName: 'Halima Sani',
    workflow: 'Promotion',
    change: 'Primary 6 → JSS 1',
    status: AdministratorLifecycleStatus.completed,
    studentId: 'STU-004',
    fromClass: 'Primary 6',
    toClass: 'JSS 1',
    requestedAt: '2026-08-20T09:00:00Z',
    completedAt: '2026-09-01T10:00:00Z',
    approvedBy: 'Mr. Ibrahim Danladi (Principal)',
  ),
  AdministratorLifecycleRecord(
    id: 'LC-DEMO-002',
    studentName: 'Ruth John',
    workflow: 'Class change',
    change: 'SS1B → SS1A',
    status: AdministratorLifecycleStatus.completed,
    studentId: 'STU-006',
    fromClass: 'SS1B',
    toClass: 'SS1A',
    requestedAt: '2026-09-02T09:00:00Z',
    completedAt: '2026-09-03T11:00:00Z',
  ),
  AdministratorLifecycleRecord(
    id: 'LC-DEMO-003',
    studentName: 'Maimuna Bello',
    workflow: 'Class change',
    change: 'SS2B → SS2A',
    status: AdministratorLifecycleStatus.pending,
    studentId: 'STU-008',
    fromClass: 'SS2B',
    toClass: 'SS2A',
    requestedAt: '2026-09-15T09:00:00Z',
    note: 'Guardian asked for the science class',
  ),
];

AdministratorDocumentRecord _doc(String n, String document, String owner, AdministratorRecordStatus status, {String kind = 'Student', String received = 'Sep 2026'}) =>
    AdministratorDocumentRecord(
      id: 'REC-DEMO-$n',
      document: document,
      recordOwner: owner,
      status: status,
      received: status == AdministratorRecordStatus.missing || status == AdministratorRecordStatus.draft ? '—' : received,
      visibility: 'Restricted',
      kind: kind,
    );

/// Documents for the demo students and staff: some verified, some waiting, some still to arrive.
final administratorRecordsDemoExtras = <AdministratorDocumentRecord>[
  _doc('01', 'Birth certificate', 'Ahmed Yusuf', AdministratorRecordStatus.missing),
  _doc('02', 'Birth certificate', 'Zainab Yusuf', AdministratorRecordStatus.verified),
  _doc('03', 'Previous school report', 'Halima Sani', AdministratorRecordStatus.verified),
  _doc('04', 'Guardian ID', 'Mrs. Amina Yusuf family', AdministratorRecordStatus.pending, kind: 'Family'),
  _doc('05', 'Immunisation record', 'Bilal Kabir', AdministratorRecordStatus.pending),
  _doc('06', 'Passport photograph', 'Ruth John', AdministratorRecordStatus.missing),
  _doc('07', 'Transfer letter', 'Maimuna Bello', AdministratorRecordStatus.draft),
  _doc('08', 'Staff qualification', 'Mrs. Grace Musa', AdministratorRecordStatus.verified, kind: 'Staff'),
  _doc('09', 'Staff ID', 'Mr. Daniel John', AdministratorRecordStatus.pending, kind: 'Staff'),
  _doc('10', 'Staff qualification', 'Mr. Peter James', AdministratorRecordStatus.missing, kind: 'Staff'),
];
