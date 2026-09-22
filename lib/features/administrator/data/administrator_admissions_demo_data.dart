import '../domain/administrator_admissions_models.dart';

const administratorAdmissionsWebsiteSeed = <AdmissionApplicant>[
  AdmissionApplicant(
    reference: 'BGA-ADM-26094',
    name: 'Aisha Sani',
    section: 'Primary',
    className: 'Primary 2',
    guardian: 'Alhaji Sani Ibrahim',
    phone: '0803 100 2401',
    stage: AdmissionStage.documents,
    submitted: '13 Sep',
    previousSchoolReport: AdmissionDocumentStatus.pending,
  ),
  AdmissionApplicant(
    reference: 'BGA-ADM-26093',
    name: 'Muhammad Kabir',
    section: 'Secondary',
    className: 'JSS 1',
    guardian: 'Hajiya Amina Kabir',
    phone: '0806 221 1480',
    stage: AdmissionStage.screening,
    submitted: '13 Sep',
  ),
  AdmissionApplicant(
    reference: 'BGA-ADM-26091',
    name: 'Zainab Aliyu',
    section: 'Nursery',
    className: 'Nursery 2',
    guardian: 'Alhaji Aliyu Sani',
    phone: '0812 334 0192',
    stage: AdmissionStage.offer,
    submitted: '12 Sep',
  ),
  AdmissionApplicant(
    reference: 'BGA-ADM-26088',
    name: 'Umar Faruq',
    section: 'Primary',
    className: 'Primary 4',
    guardian: 'Hajiya Maryam Umar',
    phone: '0703 518 9941',
    stage: AdmissionStage.accepted,
    submitted: '11 Sep',
  ),
  AdmissionApplicant(
    reference: 'BGA-ADM-26082',
    name: 'Fatima Musa',
    section: 'Secondary',
    className: 'JSS 2',
    guardian: 'Alhaji Musa Bello',
    phone: '0805 292 4118',
    stage: AdmissionStage.registered,
    submitted: '09 Sep',
  ),
];

const administratorAdmissionsBoundary =
    'Online application creates an applicant record only. A child becomes an active student after the school completes registration, guardian linking, class placement and finance setup.';

const administratorAdmissionsJourney =
    'Each online application moves through a controlled admissions journey from New to Documents, Screening, Offer, Accepted and Registered.';

const administratorAdmissionsPublicWebsiteBoundary =
    'The public admissions website is an online surface. Native Administrator operations may continue offline, but opening the public website itself requires web connectivity.';
