import '../domain/principal_academics_models.dart';

const principalAcademicsScopeBoundary =
    'Academic monitoring and intervention authority on this page is limited to the Secondary School section. Primary and Early Years remain under their own leadership memberships.';

const principalAcademicLevels = <String>['All levels', 'JSS 1', 'JSS 2', 'JSS 3', 'SS 1', 'SS 2', 'SS 3'];
const principalAcademicStatuses = <String>['All statuses', 'Strong', 'On track', 'Watch', 'Behind', 'Not evaluated'];

/// The school average across classes that have at least one real recorded assessment. Returns `null` when no
/// class has any real assessment evidence yet, rather than a misleading 0%.
int? principalSchoolAverage(List<PrincipalAcademicClass> rows) {
  final evaluated = rows.where((row) => row.status != PrincipalAcademicStatus.notEvaluated).toList();
  if (evaluated.isEmpty) return null;
  return (evaluated.fold<int>(0, (sum, row) => sum + row.average) / evaluated.length).round();
}

/// The average syllabus coverage across classes that have an approved scheme of work uploaded at all. Returns
/// `null` when no Secondary class has one yet.
int? principalSyllabusAverage(List<PrincipalAcademicClass> rows) {
  final withScheme = rows.where((row) => row.hasSyllabusScheme).toList();
  if (withScheme.isEmpty) return null;
  return (withScheme.fold<int>(0, (sum, row) => sum + row.syllabus) / withScheme.length).round();
}

/// The average assessment score-entry completion across classes that have at least one real assessment.
/// Returns `null` when none exist yet.
int? principalAssessmentAverage(List<PrincipalAcademicClass> rows) {
  final evaluated = rows.where((row) => row.status != PrincipalAcademicStatus.notEvaluated).toList();
  if (evaluated.isEmpty) return null;
  return (evaluated.fold<int>(0, (sum, row) => sum + row.assessments) / evaluated.length).round();
}
