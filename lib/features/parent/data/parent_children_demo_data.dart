import '../domain/parent_children_models.dart';

const parentDefaultChildren = ParentChildrenSnapshot(
  familyAccountId: 'FAM-BGA-0042',
  academicPeriod: '2026/2027 · Term 1',
  children: [
    ParentLinkedChild(
      id: 'STU-001',
      name: 'Maryam Abdullahi',
      initials: 'MA',
      className: 'JSS 2A',
      section: 'Secondary',
      admissionNumber: 'BGA/2023/SEC/001',
      classTeacher: 'Mrs. Amina Yusuf',
      attendanceLabel: '96%',
      learningLabel: '86%',
      house: 'Blue House',
      currentBalance: 40000,
      transport: 'BUS-02',
      paymentAccount: '1047263815',
      paymentPlan: 'Monthly · Active',
      activities: 'Chess Club · Debate',
      subjects: [
        ParentChildSubjectProgress(subject: 'Mathematics', progress: '88%'),
        ParentChildSubjectProgress(subject: 'English', progress: '84%'),
        ParentChildSubjectProgress(subject: 'Basic Science', progress: '86%'),
        ParentChildSubjectProgress(subject: 'Social Studies', progress: '85%'),
      ],
      timeline: [
        ParentChildTimelineEvent(dateLabel: 'Today', description: 'Present in school'),
        ParentChildTimelineEvent(
          dateLabel: '12 Sep',
          description: 'Mathematics assessment posted · 88%',
        ),
        ParentChildTimelineEvent(
          dateLabel: '10 Sep',
          description: 'Chess Club attendance recorded',
        ),
        ParentChildTimelineEvent(
          dateLabel: '06 Sep',
          description: 'Term fee payment received · ₦60,000',
        ),
      ],
    ),
    ParentLinkedChild(
      id: 'PRI-003',
      name: 'Hafsa Abdullahi',
      initials: 'HA',
      className: 'Primary 3',
      section: 'Primary',
      admissionNumber: 'BGA/2024/PRI/003',
      classTeacher: 'Mrs. Khadija Musa',
      attendanceLabel: '82%',
      learningLabel: 'Developing',
      house: 'Green House',
      currentBalance: 25000,
      transport: 'BUS-01',
      paymentAccount: '1047263823',
      paymentPlan: 'Manual transfer',
      activities: 'Reading Buddies · Creative Arts',
      subjects: [
        ParentChildSubjectProgress(subject: 'Literacy', progress: 'Developing'),
        ParentChildSubjectProgress(subject: 'Numeracy', progress: 'On track'),
        ParentChildSubjectProgress(subject: 'Basic Science', progress: 'On track'),
        ParentChildSubjectProgress(
          subject: 'Creative Arts',
          progress: 'Strong engagement',
        ),
      ],
      timeline: [
        ParentChildTimelineEvent(dateLabel: 'Today', description: 'Present in school'),
        ParentChildTimelineEvent(
          dateLabel: '12 Sep',
          description: 'Reading-support activity completed',
        ),
        ParentChildTimelineEvent(
          dateLabel: '09 Sep',
          description: 'Creative Arts work shared',
        ),
        ParentChildTimelineEvent(
          dateLabel: '03 Sep',
          description: 'Term fee payment received · ₦50,000',
        ),
      ],
    ),
  ],
);

const parentChildrenPrivacyBoundary =
    'Family access is relationship-based. A guardian sees only children explicitly linked to their family account. Linking a sibling does not merge the children’s academic, welfare or attendance histories.';

const parentChildFinanceBoundary =
    'Finance information is visible only to authorized guardians and finance staff. It does not affect the child’s grades, awards, classroom treatment or learning-support decisions.';
