import '../domain/parent_learning_progress_models.dart';

const parentDefaultLearningProgress = ParentLearningProgressSnapshot(
  familyAccountId: 'FAM-BGA-0042',
  children: [
    ParentLearningChild(
      id: 'STU-001',
      name: 'Maryam Abdullahi',
      className: 'JSS 2A',
      section: 'Secondary',
      averagePercent: 86,
      attendancePercent: 96,
      trendPercent: 4.2,
      status: ParentLearningStatus.strong,
      history: [72, 76, 74, 81, 79, 84, 86],
      subjects: [
        ParentLearningSubjectEvidence(
          subject: 'Mathematics',
          examPercent: 88,
          classworkPercent: 84,
          assignmentPercent: 91,
          trendLabel: '+3.0',
        ),
        ParentLearningSubjectEvidence(
          subject: 'English',
          examPercent: 84,
          classworkPercent: 86,
          assignmentPercent: 88,
          trendLabel: '+2.1',
        ),
        ParentLearningSubjectEvidence(
          subject: 'Basic Science',
          examPercent: 87,
          classworkPercent: 82,
          assignmentPercent: 89,
          trendLabel: '+5.2',
        ),
        ParentLearningSubjectEvidence(
          subject: 'Social Studies',
          examPercent: 85,
          classworkPercent: 83,
          assignmentPercent: 86,
          trendLabel: '+4.0',
        ),
      ],
      topics: [
        ParentLearningTopic(
          name: 'Fractions',
          scorePercent: 62,
          note: 'Needs another guided practice cycle',
        ),
        ParentLearningTopic(
          name: 'Algebra',
          scorePercent: 91,
          note: 'Current strength',
        ),
        ParentLearningTopic(
          name: 'Geometry',
          scorePercent: 69,
          note: 'Improving but inconsistent',
        ),
        ParentLearningTopic(
          name: 'Comprehension',
          scorePercent: 87,
          note: 'Strong recent evidence',
        ),
      ],
      evidence: [
        ParentLearningEvidenceItem(
          label: 'Exams',
          value: '86%',
          note: 'Current term average',
        ),
        ParentLearningEvidenceItem(
          label: 'Classwork',
          value: '84%',
          note: '14 activities',
        ),
        ParentLearningEvidenceItem(
          label: 'Assignments',
          value: '89%',
          note: '92% completion',
        ),
        ParentLearningEvidenceItem(
          label: 'Attendance',
          value: '96%',
          note: '2 late arrivals',
        ),
      ],
      timeline: [
        ParentLearningTimelineEvent(
          dateLabel: '12 Sep',
          title: 'Mathematics topic review',
          detail:
              "Fractions remained below Maryam's other Mathematics topics.",
        ),
        ParentLearningTimelineEvent(
          dateLabel: '8 Sep',
          title: 'Basic Science improvement',
          detail: 'Assessment evidence rose after guided revision.',
        ),
        ParentLearningTimelineEvent(
          dateLabel: '2 Sep',
          title: 'Assignment consistency',
          detail: 'All scheduled assignments submitted this week.',
        ),
      ],
      insight:
          "Maryam's overall learning trend is improving. Algebra and comprehension are current strengths; fractions still need reinforcement before more difficult ratio work.",
      actions: [
        'Give one additional fractions practice set',
        'Check geometry again after two more class activities',
        'Continue normal enrichment in English and Basic Science',
      ],
    ),
    ParentLearningChild(
      id: 'PRI-003',
      name: 'Hafsa Abdullahi',
      className: 'Primary 3',
      section: 'Primary',
      averagePercent: 58,
      attendancePercent: 82,
      trendPercent: -6.8,
      status: ParentLearningStatus.needsSupport,
      history: [69, 68, 66, 64, 62, 60, 58],
      subjects: [
        ParentLearningSubjectEvidence(
          subject: 'Literacy',
          examPercent: 54,
          classworkPercent: 58,
          assignmentPercent: 61,
          trendLabel: '-8.0',
        ),
        ParentLearningSubjectEvidence(
          subject: 'Numeracy',
          examPercent: 61,
          classworkPercent: 63,
          assignmentPercent: 66,
          trendLabel: '-3.0',
        ),
        ParentLearningSubjectEvidence(
          subject: 'Basic Science',
          examPercent: 60,
          classworkPercent: 62,
          assignmentPercent: 64,
          trendLabel: '-4.0',
        ),
        ParentLearningSubjectEvidence(
          subject: 'Creative Arts',
          examPercent: 78,
          classworkPercent: 82,
          assignmentPercent: 80,
          trendLabel: '+2.0',
        ),
      ],
      topics: [
        ParentLearningTopic(
          name: 'Reading fluency',
          scorePercent: 52,
          note: 'Needs guided reading practice',
        ),
        ParentLearningTopic(
          name: 'Spelling patterns',
          scorePercent: 57,
          note: 'Still inconsistent',
        ),
        ParentLearningTopic(
          name: 'Number bonds',
          scorePercent: 68,
          note: 'More secure',
        ),
        ParentLearningTopic(
          name: 'Creative expression',
          scorePercent: 82,
          note: 'Current strength',
        ),
      ],
      evidence: [
        ParentLearningEvidenceItem(
          label: 'Assessments',
          value: '58%',
          note: 'Current term evidence',
        ),
        ParentLearningEvidenceItem(
          label: 'Classwork',
          value: '63%',
          note: '16 activities',
        ),
        ParentLearningEvidenceItem(
          label: 'Assignments',
          value: '66%',
          note: '88% completion',
        ),
        ParentLearningEvidenceItem(
          label: 'Attendance',
          value: '82%',
          note: '4 late arrivals',
        ),
      ],
      timeline: [
        ParentLearningTimelineEvent(
          dateLabel: '11 Sep',
          title: 'Reading support review',
          detail: 'Teacher recommended continued guided reading practice.',
        ),
        ParentLearningTimelineEvent(
          dateLabel: '7 Sep',
          title: 'Attendance follow-up',
          detail:
              'Headmistress requested a guardian conversation about the attendance pattern.',
        ),
        ParentLearningTimelineEvent(
          dateLabel: '3 Sep',
          title: 'Creative activity',
          detail: 'Strong participation recorded during creative work.',
        ),
      ],
      insight:
          'Hafsa shows stronger evidence in creative work and numeracy than in reading fluency. Reading support should continue, while attendance context should be monitored over the next learning cycle.',
      actions: [
        'Continue guided reading in short sessions',
        'Use spelling practice tied to current class texts',
        'Review progress after the next two literacy activities',
      ],
    ),
  ],
);

const parentLearningProgressBoundary =
    'This view explains current learning evidence and suggested practice areas. It is not a permanent ability label, diagnosis or class ranking.';
