import '../domain/proprietor_overview_models.dart';

/// Describes what each module does, for the Overview's quick-access menu - never a live figure, so
/// it needs no real data source behind it.
abstract final class ProprietorOverviewDemoData {
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
}
