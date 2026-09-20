import '../domain/parent_dashboard_models.dart';

const parentNavigation = <ParentNavItem>[
  ParentNavItem(key: 'dashboard', label: 'Home'),
  ParentNavItem(key: 'children', label: 'My Children'),
  ParentNavItem(key: 'progress', label: 'Learning Progress'),
  ParentNavItem(key: 'weekly-learning', label: 'Weekly Learning'),
  ParentNavItem(key: 'attendance', label: 'Attendance'),
  ParentNavItem(key: 'finance', label: 'Finance & Payments'),
  ParentNavItem(key: 'messages', label: 'Messages'),
  ParentNavItem(key: 'discussions', label: 'School Discussions'),
  ParentNavItem(key: 'school-life', label: 'School Life'),
  ParentNavItem(key: 'documents', label: 'Documents & Consent'),
  ParentNavItem(key: 'ai', label: 'Parent AI'),
];

const parentPrivacyBoundary =
    'Private family access. This guardian account can only access linked children and approved family records. Other families, staff-private notes and restricted safeguarding records are never exposed.';

const parentDefaultDashboard = ParentDashboardSnapshot(
  guardianName: 'Alhaji Abdullahi Yusuf',
  familyAccountId: 'FAM-BGA-0042',
  campusLabel: 'Kaduna Campus',
  academicPeriod: '2026/2027 Term 1',
  children: [
    ParentChildSummary(
      id: 'STU-001',
      name: 'Maryam Abdullahi',
      className: 'JSS 2A',
      section: 'Secondary',
      attendancePercent: 96,
      academicPercent: 86,
      feeBalance: 40000,
      initials: 'MA',
      presentToday: true,
    ),
    ParentChildSummary(
      id: 'PRI-003',
      name: 'Hafsa Abdullahi',
      className: 'Primary 3',
      section: 'Primary',
      attendancePercent: 82,
      academicPercent: 58,
      feeBalance: 25000,
      initials: 'HA',
      presentToday: true,
    ),
  ],
  attentionItems: [
    ParentAttentionItem(
      title: 'Hafsa’s attendance is 82%',
      detail: 'Primary 3 has several absences this term. Review the dates and contact the school if context is missing.',
      area: 'Attendance · Primary',
      destinationKey: 'attendance',
    ),
    ParentAttentionItem(
      title: 'Next monthly payment is scheduled',
      detail: '₦25,000 on 20 September from the family payment plan.',
      area: 'Finance · Parent-authorized',
      destinationKey: 'finance',
    ),
    ParentAttentionItem(
      title: 'Consent required for excursion',
      detail: 'Primary educational visit form is awaiting your response.',
      area: 'Documents & Consent',
      destinationKey: 'documents',
    ),
  ],
  finance: ParentFinanceSnapshot(
    totalBilled: 420000,
    totalPaid: 355000,
    nextScheduledDebit: 25000,
    nextScheduledDebitLabel: '20 Sep · parent-authorized',
    accounts: [
      ParentPaymentAccount(
        childName: 'Maryam Abdullahi',
        accountNumber: '1047263815',
        description: 'Static payment account for 2026/2027 Term 1',
        balance: 40000,
      ),
      ParentPaymentAccount(
        childName: 'Hafsa Abdullahi',
        accountNumber: '1047263821',
        description: 'Static payment account for 2026/2027 Term 1',
        balance: 25000,
      ),
    ],
  ),
  messages: [
    ParentMessagePreview(
      sender: 'Mrs. Khadija Musa · Primary 3',
      message: 'Reading-support materials have been shared for Hafsa.',
      timeLabel: 'Today',
      unread: true,
    ),
    ParentMessagePreview(
      sender: 'School Finance Office',
      message: 'Your monthly payment plan remains active for 20 September.',
      timeLabel: 'Yesterday',
      unread: true,
    ),
    ParentMessagePreview(
      sender: 'Mrs. Amina Yusuf · JSS 2A',
      message: 'Maryam completed the Mathematics assessment.',
      timeLabel: '11 Sep',
      unread: false,
    ),
  ],
  notices: [
    ParentNoticePreview(
      title: 'Inter-house sports · 26 September',
      detail: 'Parents are invited. Maryam is registered with Blue House.',
      category: 'Event',
    ),
    ParentNoticePreview(
      title: 'Primary educational visit',
      detail: 'Guardian consent required by 18 September.',
      category: 'Action',
    ),
    ParentNoticePreview(
      title: 'Term report release',
      detail: 'Reports become available after section approval.',
      category: 'Academic',
    ),
  ],
);
