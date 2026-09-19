import '../domain/proprietor_overview_models.dart';

abstract final class ProprietorOverviewDemoData {
  static const sections = <ProprietorSectionPerformance>[
    ProprietorSectionPerformance(
      name: 'Nursery / Early Years',
      leader: 'Mrs. Maryam Abdullahi',
      leaderRole: 'Head Teacher',
      students: 84,
      attendancePercent: 93,
      academicPercent: 89,
      feeCollectionPercent: 96,
      staff: 12,
      status: ProprietorHealthStatus.healthy,
    ),
    ProprietorSectionPerformance(
      name: 'Primary School',
      leader: 'Mrs. Hauwa Sule',
      leaderRole: 'Headmistress',
      students: 286,
      attendancePercent: 94,
      academicPercent: 82,
      feeCollectionPercent: 91,
      staff: 28,
      status: ProprietorHealthStatus.healthy,
    ),
    ProprietorSectionPerformance(
      name: 'Secondary School',
      leader: 'Mr. Ibrahim Danladi',
      leaderRole: 'Principal',
      students: 278,
      attendancePercent: 90,
      academicPercent: 76,
      feeCollectionPercent: 86,
      staff: 24,
      status: ProprietorHealthStatus.watch,
    ),
  ];

  static const attention = <ProprietorAttentionItem>[
    ProprietorAttentionItem(
      title: 'Secondary attendance below target',
      detail: '90% versus the 94% school target. JSS 2B has the widest current gap.',
      owner: 'Principal',
      tone: ProprietorAttentionTone.high,
    ),
    ProprietorAttentionItem(
      title: '₦3.7m remains outstanding',
      detail: '73 family accounts still have current-term balances.',
      owner: 'Finance',
      tone: ProprietorAttentionTone.medium,
    ),
    ProprietorAttentionItem(
      title: 'Two curriculum pacing gaps',
      detail: 'Secondary Mathematics and Basic Science require follow-up.',
      owner: 'VP Academics',
      tone: ProprietorAttentionTone.medium,
    ),
    ProprietorAttentionItem(
      title: 'Primary 6 class-teacher gap',
      detail: 'The responsibility remains operationally unassigned.',
      owner: 'Headmistress',
      tone: ProprietorAttentionTone.info,
    ),
  ];

  static const leadership = <ProprietorLeadershipItem>[
    ProprietorLeadershipItem(
      name: 'Mrs. Maryam Abdullahi',
      role: 'Head Teacher',
      scope: 'Nursery / Early Years',
      signal: ProprietorLeadershipSignal.onTrack,
    ),
    ProprietorLeadershipItem(
      name: 'Mrs. Hauwa Sule',
      role: 'Headmistress',
      scope: 'Primary School',
      signal: ProprietorLeadershipSignal.onTrack,
    ),
    ProprietorLeadershipItem(
      name: 'Mr. Ibrahim Danladi',
      role: 'Principal',
      scope: 'Secondary School',
      signal: ProprietorLeadershipSignal.review,
    ),
    ProprietorLeadershipItem(
      name: 'Mrs. Zainab Musa',
      role: 'Vice Principal Academics',
      scope: 'Secondary School',
      signal: ProprietorLeadershipSignal.onTrack,
    ),
  ];

  static const collectionTrend = <int>[72, 78, 81, 84, 88, 91, 94];

  static const quickAccess = <ProprietorQuickAccessItem>[
    ProprietorQuickAccessItem(
      title: 'Owner Finance',
      description: 'Collections, outstanding balances and financing exposure',
      moduleKey: 'finance',
    ),
    ProprietorQuickAccessItem(
      title: 'Enrollment',
      description: 'Admissions, retention and section distribution',
      moduleKey: 'enrollment',
    ),
    ProprietorQuickAccessItem(
      title: 'Staff & HR',
      description: 'Staffing, workload, contracts and vacancies',
      moduleKey: 'staff',
    ),
    ProprietorQuickAccessItem(
      title: 'Reports',
      description: 'Executive reporting and section comparisons',
      moduleKey: 'reports',
    ),
    ProprietorQuickAccessItem(
      title: 'Campuses',
      description: 'Branch comparison and expansion readiness',
      moduleKey: 'campuses',
    ),
    ProprietorQuickAccessItem(
      title: 'Proprietor AI',
      description: 'Ask whole-school management questions',
      moduleKey: 'ai',
    ),
  ];

  static int get totalStudents =>
      sections.fold<int>(0, (sum, section) => sum + section.students);

  static int get totalStaff =>
      sections.fold<int>(0, (sum, section) => sum + section.staff);

  static int get weightedAttendance {
    final weighted = sections.fold<int>(
      0,
      (sum, section) => sum + section.attendancePercent * section.students,
    );
    return (weighted / totalStudents).round();
  }

  static int get weightedAcademic {
    final weighted = sections.fold<int>(
      0,
      (sum, section) => sum + section.academicPercent * section.students,
    );
    return (weighted / totalStudents).round();
  }

  static List<ProprietorKpi> get kpis => [
        ProprietorKpi(
          label: 'Active students',
          value: '$totalStudents',
          note: 'Across three sections',
          trend: '+4.8% YoY',
          tone: ProprietorKpiTone.green,
        ),
        const ProprietorKpi(
          label: 'Fee collection',
          value: '94.1%',
          note: '₦59.1m of ₦62.8m billed',
          trend: '+6.2%',
          tone: ProprietorKpiTone.green,
        ),
        const ProprietorKpi(
          label: 'Outstanding fees',
          value: '₦3.7m',
          note: '73 family accounts',
          trend: 'Review',
          tone: ProprietorKpiTone.amber,
        ),
        ProprietorKpi(
          label: 'Teaching staff',
          value: '$totalStaff',
          note: 'Current section sample',
          trend: '96% attendance',
          tone: ProprietorKpiTone.blue,
        ),
        ProprietorKpi(
          label: 'Student attendance',
          value: '$weightedAttendance%',
          note: 'Weighted school average',
          trend: '+1.9%',
          tone: ProprietorKpiTone.green,
        ),
        ProprietorKpi(
          label: 'Academic health',
          value: '$weightedAcademic%',
          note: 'Cross-section indicator',
          trend: '3 watch items',
          tone: ProprietorKpiTone.purple,
        ),
      ];
}
