import '../domain/parent_weekly_learning_models.dart';

const parentWeeklyLearningBoundary =
    'Weekly updates describe classroom learning and current evidence. They are not permanent ability labels, class rankings, diagnoses or predictions about a child’s future performance.';

const parentDefaultWeeklyLearning = ParentWeeklyLearningSnapshot(
  familyAccountId: 'FAM-BGA-0042',
  updates: [
    ParentWeeklyLearningUpdate(
      id: 'STU-001-week-6-2026-09-13',
      weekLabel: 'Week 6',
      dateLabel: '13 Sep 2026',
      childId: 'STU-001',
      childName: 'Maryam Abdullahi',
      className: 'JSS 2A',
      teacher: 'Mrs. Amina Yusuf',
      teacherNote:
          'The class completed the major planned topics this week. Mathematics practice will continue before the next topic begins.',
      subjects: [
        ParentWeeklySubjectUpdate(
          subject: 'Mathematics',
          thisWeek:
              'Linear equations completed with worked examples and short class assessment',
          learningEvidence: 'Classwork 82% · Assignment 79%',
          nextTopic: 'Simultaneous equations',
          practiceNote:
              'Fractions remain the main practice area for a small group',
        ),
        ParentWeeklySubjectUpdate(
          subject: 'English',
          thisWeek: 'Narrative writing and comprehension completed',
          learningEvidence: 'Writing task completed · comprehension check 84%',
          nextTopic: 'Formal letter writing',
          practiceNote: 'Sentence structure practice continues',
        ),
        ParentWeeklySubjectUpdate(
          subject: 'Basic Science',
          thisWeek:
              'Digestive system introduced and labelled diagram completed',
          learningEvidence: 'Class diagram + 10-question check',
          nextTopic: 'Nutrition and balanced diet',
          practiceNote: 'Key vocabulary will be reinforced',
        ),
      ],
    ),
    ParentWeeklyLearningUpdate(
      id: 'STU-001-week-5-2026-09-06',
      weekLabel: 'Week 5',
      dateLabel: '6 Sep 2026',
      childId: 'STU-001',
      childName: 'Maryam Abdullahi',
      className: 'JSS 2A',
      teacher: 'Mrs. Amina Yusuf',
      teacherNote:
          'Good participation across the week. Continue routine home reading and Mathematics practice.',
      subjects: [
        ParentWeeklySubjectUpdate(
          subject: 'Mathematics',
          thisWeek: 'Simplifying algebraic expressions completed',
          learningEvidence: 'Classwork 86%',
          nextTopic: 'Linear equations',
          practiceNote: 'Continue practice with negative signs',
        ),
        ParentWeeklySubjectUpdate(
          subject: 'English',
          thisWeek: 'Reading comprehension and summary writing',
          learningEvidence: 'Summary task completed',
          nextTopic: 'Narrative writing',
          practiceNote: 'Use complete sentences in written answers',
        ),
        ParentWeeklySubjectUpdate(
          subject: 'Basic Science',
          thisWeek: 'Classes of food and digestion overview',
          learningEvidence: 'Short quiz 85%',
          nextTopic: 'Human digestive system',
          practiceNote: 'Revise key food groups',
        ),
      ],
    ),
    ParentWeeklyLearningUpdate(
      id: 'PRI-003-week-6-2026-09-13',
      weekLabel: 'Week 6',
      dateLabel: '13 Sep 2026',
      childId: 'PRI-003',
      childName: 'Hafsa Abdullahi',
      className: 'Primary 3',
      teacher: 'Mrs. Khadija Musa',
      teacherNote:
          'Hafsa’s class completed the planned literacy and numeracy work. Guided reading will continue next week.',
      subjects: [
        ParentWeeklySubjectUpdate(
          subject: 'Literacy',
          thisWeek: 'Reading comprehension and sentence building',
          learningEvidence: 'Reading activity completed',
          nextTopic: 'Paragraph writing',
          practiceNote: 'Continue guided reading practice',
        ),
        ParentWeeklySubjectUpdate(
          subject: 'Numeracy',
          thisWeek: 'Multiplication using groups and arrays',
          learningEvidence: 'Classwork 74%',
          nextTopic: 'Division as sharing',
          practiceNote: 'Times-table practice will help',
        ),
        ParentWeeklySubjectUpdate(
          subject: 'Basic Science',
          thisWeek: 'Living and non-living things review',
          learningEvidence: 'Workbook activity completed',
          nextTopic: 'Simple habitats',
          practiceNote: 'Review examples from home and school',
        ),
      ],
    ),
  ],
);
