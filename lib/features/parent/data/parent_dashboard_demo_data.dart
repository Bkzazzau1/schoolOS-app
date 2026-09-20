import '../domain/parent_dashboard_models.dart';

const parentFamilyId = 'FAM-BGA-0042';
const parentGuardianName = 'Alhaji Abdullahi Yusuf';
const parentCampusLabel = 'Kaduna Campus';

final parentDashboardDemoData = ParentDashboardSnapshot(
  family: ParentFamilyAccount(
    familyId: parentFamilyId,
    guardianName: parentGuardianName,
    linkedChildren: 2,
    currentTermBalanceNaira: 65000,
    nextScheduledDebitNaira: 25000,
    nextScheduledDebitDate: DateTime(2026, 9, 20),
    unreadMessages: 2,
  ),
  children: const [
    ParentLinkedChild(
      id: 'STU-001',
      name: 'Maryam Abdullahi',
      className: 'JSS 2A',
      section: 'Secondary',
      attendancePercent: 96,
      academicPercent: 86,
      ledgerBalanceNaira: 40000,
      initials: 'MA',
      presentToday: true,
      allocationReference: '1047263815',
    ),
    ParentLinkedChild(
      id: 'PRI-003',
      name: 'Hafsa Abdullahi',
      className: 'Primary 3',
      section: 'Primary',
      attendancePercent: 82,
      academicPercent: 58,
      ledgerBalanceNaira: 25000,
      initials: 'HA',
      presentToday: true,
      allocationReference: '1047263821',
    ),
  ],
  attentionItems: const [
    ParentAttentionItem(
      kind: ParentAttentionKind.attendance,
      title: 'Hafsa’s attendance is 82%',
      description: 'Primary 3 has several absences this term. Review the dates and contact the school if context is missing.',
      meta: 'Attendance · Primary',
    ),
    ParentAttentionItem(
      kind: ParentAttentionKind.finance,
      title: 'Next monthly payment is scheduled',
      description: '₦25,000 on 20 September from the family payment plan.',
      meta: 'Finance · Parent-authorized',
    ),
    ParentAttentionItem(
      kind: ParentAttentionKind.consent,
      title: 'Consent required for excursion',
      description: 'Primary educational visit form is awaiting your response.',
      meta: 'Documents & Consent',
    ),
  ],
  finance: const ParentFinanceSnapshot(
    totalBilledNaira: 420000,
    totalPaidNaira: 355000,
    balanceNaira: 65000,
  ),
  messages: const [
    ParentMessagePreview(
      sender: 'Mrs. Khadija Musa · Primary 3',
      message: 'Reading-support materials have been shared for Hafsa.',
      whenLabel: 'Today',
    ),
    ParentMessagePreview(
      sender: 'School Finance Office',
      message: 'Your monthly payment plan remains active for 20 September.',
      whenLabel: 'Yesterday',
    ),
    ParentMessagePreview(
      sender: 'Mrs. Amina Yusuf · JSS 2A',
      message: 'Maryam completed the Mathematics assessment.',
      whenLabel: '11 Sep',
    ),
  ],
  notices: const [
    ParentNoticePreview(
      title: 'Inter-house sports · 26 September',
      description: 'Parents are invited. Maryam is registered with Blue House.',
      category: 'Event',
    ),
    ParentNoticePreview(
      title: 'Primary educational visit',
      description: 'Guardian consent required by 18 September.',
      category: 'Action',
    ),
    ParentNoticePreview(
      title: 'Term report release',
      description: 'Reports become available after section approval.',
      category: 'Academic',
    ),
  ],
  aiPrompts: const [
    'Why is Hafsa’s attendance lower this term?',
    'What fees are still outstanding?',
    'Summarize Maryam’s latest academic report.',
  ],
)..validate();
