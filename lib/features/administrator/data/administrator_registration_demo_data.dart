import '../domain/administrator_registration_models.dart';

// Synthetic prototype values copied from the website UI; not production identity data.
const administratorRegistrationWebsiteSeed = StudentRegistrationRecord(
  registrationId: 'REG-DRAFT-014',
  firstName: 'Aisha',
  surname: 'Sani',
  otherName: 'Maryam',
  dateOfBirth: '2018-04-12',
  gender: 'Female',
  academicSection: 'Primary',
  proposedClass: 'Primary 2',
  previousSchool: 'Al-Hikmah Academy',
  address: 'Kaduna, Kaduna State',
  admissionNumber: 'BGA/KD/PRI/26/014',
  studentId: 'STU-NEW-014',
  status: StudentRegistrationStatus.inProgress,
  primaryGuardian: 'Alhaji Sani Ibrahim',
  relationship: 'Father',
  guardianPhone: '0800 000 0011',
  guardianEmail: 'sani@example.com',
  familyAccount: 'Create new family account',
  siblingLink: 'No existing sibling',
  birthCertificateStatus: 'Received · pending verification',
  previousSchoolRecordStatus: 'Received',
  guardianIdentificationStatus: 'Received',
  financeSetupStatus: 'Prepare after student activation',
  transportMealStatus: 'Optional service setup',
);

const registrationSections = <String>['Early Years', 'Primary', 'Secondary'];
const registrationClasses = <String>['Primary 2', 'Primary 3', 'JSS 1A', 'Nursery 2'];
const registrationRelationships = <String>['Father', 'Mother', 'Guardian'];
const registrationFamilyAccounts = <String>[
  'Create new family account',
  'FAM-BGA-0042 · Abdullahi Yusuf',
];
const registrationSiblingLinks = <String>[
  'No existing sibling',
  'Maryam Abdullahi · JSS 2A',
];
