import '../domain/administrator_staff_models.dart';

const administratorStaffWebsiteSeed = <AdministratorStaffRecord>[
  AdministratorStaffRecord(
    id: 'STAFF-001',
    name: 'Mrs. Amina Yusuf',
    role: 'Teacher',
    section: 'Secondary',
    fileStatus: AdministratorStaffFileStatus.complete,
  ),
  AdministratorStaffRecord(
    id: 'STAFF-009',
    name: 'Mrs. Khadija Musa',
    role: 'Class Teacher',
    section: 'Primary',
    fileStatus: AdministratorStaffFileStatus.complete,
  ),
  AdministratorStaffRecord(
    id: 'STAFF-014',
    name: 'Mr. Ahmad Sani',
    role: 'Teacher',
    section: 'Secondary',
    fileStatus: AdministratorStaffFileStatus.missingDocument,
  ),
  AdministratorStaffRecord(
    id: 'STAFF-021',
    name: 'Mrs. Safiya Ahmad',
    role: 'Teacher',
    section: 'Primary',
    fileStatus: AdministratorStaffFileStatus.complete,
  ),
  // Also the Gold House coordinator (see house_demo_data.dart) and the
  // Staff role's own demo login - see StaffSelfServiceRepository.
  AdministratorStaffRecord(
    id: 'STAFF-030',
    name: 'Mr. Peter James',
    role: 'House coordinator',
    section: 'Whole school',
    fileStatus: AdministratorStaffFileStatus.missingDocument,
  ),
];

const administratorStaffOnboardingChecklist = <AdministratorStaffChecklistItem>[
  AdministratorStaffChecklistItem(
    title: 'Identity & contact',
    detail: 'Staff ID, phone, address and emergency contact.',
  ),
  AdministratorStaffChecklistItem(
    title: 'Qualifications',
    detail: 'Certificates and professional registration.',
  ),
  AdministratorStaffChecklistItem(
    title: 'Employment documents',
    detail: 'Offer, contract and assigned section.',
  ),
];

int administratorCompleteStaffFiles() => administratorStaffWebsiteSeed
    .where((item) => item.fileStatus == AdministratorStaffFileStatus.complete)
    .length;

int administratorStaffFilesNeedingAttention() => administratorStaffWebsiteSeed
    .where((item) => item.needsAttention)
    .length;
