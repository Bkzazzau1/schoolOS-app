import '../domain/parent_school_life_models.dart';

const parentDefaultSchoolLife = ParentSchoolLifeSnapshot(
  familyAccountId: 'FAM-BGA-0042',
  activities: [
    ParentSchoolLifeActivity(
      childName: 'Maryam Abdullahi',
      activity: 'Chess Club',
      schedule: 'Wednesday · 15:30',
      status: 'Active',
    ),
    ParentSchoolLifeActivity(
      childName: 'Maryam Abdullahi',
      activity: 'Debate & Public Speaking',
      schedule: 'Friday · 14:30',
      status: 'Active',
    ),
    ParentSchoolLifeActivity(
      childName: 'Hafsa Abdullahi',
      activity: 'Reading Buddies',
      schedule: 'Tuesday · 13:20',
      status: 'Active',
    ),
    ParentSchoolLifeActivity(
      childName: 'Hafsa Abdullahi',
      activity: 'Creative Arts',
      schedule: 'Thursday · 13:20',
      status: 'Active',
    ),
  ],
  events: [
    ParentSchoolLifeEvent(
      dateLabel: '18 Sep',
      title: 'Inter-house sports briefing',
      scope: 'Whole school',
    ),
    ParentSchoolLifeEvent(
      dateLabel: '24 Sep',
      title: 'Primary family reading afternoon',
      scope: 'Primary',
    ),
    ParentSchoolLifeEvent(
      dateLabel: '03 Oct',
      title: 'Mid-term break begins',
      scope: 'Whole school',
    ),
  ],
  transport: [
    ParentSchoolLifeTransport(
      childName: 'Maryam Abdullahi',
      serviceCode: 'BUS-02',
      status: 'Active',
      guardianSafeSummary:
          'Pickup details restricted to authorized family account',
    ),
    ParentSchoolLifeTransport(
      childName: 'Hafsa Abdullahi',
      serviceCode: 'BUS-01',
      status: 'Active',
      guardianSafeSummary:
          'Pickup details restricted to authorized family account',
    ),
  ],
  mealPlans: [
    ParentSchoolLifeMealPlan(
      childName: 'Maryam Abdullahi',
      planLabel: 'Standard meal plan',
    ),
    ParentSchoolLifeMealPlan(
      childName: 'Hafsa Abdullahi',
      planLabel: 'Standard meal plan',
    ),
  ],
  todayMeal: 'Rice · beans · fruit',
  todayMealService: 'Lunch served',
  recognition: [
    ParentSchoolLifeRecognition(
      childName: 'Maryam Abdullahi',
      title: 'Debate Participation Recognition',
      periodLabel: 'September 2026',
    ),
    ParentSchoolLifeRecognition(
      childName: 'Hafsa Abdullahi',
      title: 'Reading Effort Recognition',
      periodLabel: 'September 2026',
    ),
  ],
);

const parentSchoolLifeTransportBoundary =
    'Detailed route, driver and pickup information should be disclosed only to the child’s authorized guardians—not on a general school-life page.';

const parentSchoolLifeMealsBoundary =
    'Sensitive allergy, diagnosis, religion or medical diet details remain in restricted health workflows and should surface here only as the minimum safe instruction when necessary.';

const parentSchoolLifeRecognitionBoundary =
    'Activities, awards and recognition are family-visible context only. They must not become permanent child rankings or alter academic grades.';
