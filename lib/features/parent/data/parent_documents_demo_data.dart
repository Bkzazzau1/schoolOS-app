import '../domain/parent_documents_models.dart';

const parentDocumentsVisibilityBoundary =
    'Guardian access never includes teacher private notes, confidential safeguarding records, staff performance data, other families’ documents, or internal administrative documents that have not been approved for family visibility.';

const parentDefaultDocuments = ParentDocumentsSnapshot(
  familyAccountId: 'FAM-BGA-0042',
  documents: [
    ParentFamilyDocument(
      id: 'DOC-MARYAM-REPORT-T1',
      ownerLabel: 'Maryam Abdullahi',
      title: 'Term 1 Report Card',
      typeLabel: 'Academic report',
      status: ParentDocumentStatus.ready,
    ),
    ParentFamilyDocument(
      id: 'DOC-HAFSA-LEARNING-T1',
      ownerLabel: 'Hafsa Abdullahi',
      title: 'Primary Learning Report',
      typeLabel: 'Learning report',
      status: ParentDocumentStatus.ready,
    ),
    ParentFamilyDocument(
      id: 'DOC-FAMILY-SEPT-RECEIPT',
      ownerLabel: 'Family Account',
      title: 'September Payment Receipt',
      typeLabel: 'Finance',
      status: ParentDocumentStatus.ready,
    ),
    ParentFamilyDocument(
      id: 'DOC-MARYAM-EXCURSION-CONSENT',
      ownerLabel: 'Maryam Abdullahi',
      title: 'Excursion Consent Form',
      typeLabel: 'Consent',
      status: ParentDocumentStatus.actionNeeded,
    ),
  ],
  consentRequests: [
    ParentConsentRequest(
      id: 'CONSENT-MARYAM-KADUNA-MUSEUM-20260928',
      childName: 'Maryam Abdullahi',
      contextLabel: 'Excursion',
      title: 'Kaduna Museum Learning Visit',
      dateLabel: '28 September 2026',
      schoolSection: 'Secondary School',
      description:
          'The school requests guardian consent for Maryam to participate in the supervised learning visit. Transport and supervision details are provided by the school.',
      actionNeeded: true,
    ),
  ],
  consentHistory: [
    ParentConsentHistoryItem(
      id: 'CONSENT-HISTORY-001',
      title: 'Inter-house sports participation',
      decision: ParentConsentDecision.approved,
      dateLabel: '02 Sep 2026',
      subjectLabel: 'Maryam Abdullahi',
    ),
    ParentConsentHistoryItem(
      id: 'CONSENT-HISTORY-002',
      title: 'School media / gallery use',
      decision: ParentConsentDecision.declined,
      dateLabel: '20 Aug 2026',
      subjectLabel: 'Hafsa Abdullahi',
    ),
    ParentConsentHistoryItem(
      id: 'CONSENT-HISTORY-003',
      title: 'Emergency contact confirmation',
      decision: ParentConsentDecision.confirmed,
      dateLabel: '18 Aug 2026',
      subjectLabel: 'Family account',
    ),
  ],
);
