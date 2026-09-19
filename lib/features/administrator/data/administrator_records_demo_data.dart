import '../domain/administrator_records_models.dart';

const administratorRecordsWebsiteSeed = <AdministratorDocumentRecord>[
  AdministratorDocumentRecord(
    id: 'REC-001',
    document: 'Birth certificate',
    recordOwner: 'Maryam Abdullahi',
    status: AdministratorRecordStatus.verified,
    received: 'Sep 2026',
    visibility: 'Restricted',
  ),
  AdministratorDocumentRecord(
    id: 'REC-002',
    document: 'Previous school report',
    recordOwner: 'Aisha Sani',
    status: AdministratorRecordStatus.pending,
    received: 'Sep 2026',
    visibility: 'Restricted',
  ),
  AdministratorDocumentRecord(
    id: 'REC-003',
    document: 'Guardian ID',
    recordOwner: 'Umar Faruq family',
    status: AdministratorRecordStatus.verified,
    received: 'Sep 2026',
    visibility: 'Restricted',
  ),
  AdministratorDocumentRecord(
    id: 'REC-004',
    document: 'Staff qualification',
    recordOwner: 'Mr. Ahmad Sani',
    status: AdministratorRecordStatus.missing,
    received: '—',
    visibility: 'Restricted',
  ),
  AdministratorDocumentRecord(
    id: 'REC-005',
    document: 'Transfer letter',
    recordOwner: 'Yusuf Bello',
    status: AdministratorRecordStatus.draft,
    received: '—',
    visibility: 'Restricted',
  ),
];
