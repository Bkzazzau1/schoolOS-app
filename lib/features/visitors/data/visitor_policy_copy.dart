import '../domain/visitor_models.dart';

/// Static guidance copy for Visitor Management - not data about this school, so it never needs a
/// real backend source. Real activity (visitor records) lives in [VisitorRepository] instead.
const visitorAccessRules = <String, String>{
  'Host required':
      'Visitor access should be tied to an accountable staff office/person.',
  'Minimum data':
      'Collect only what the school needs for safety and operational accountability.',
  'Restricted log':
      'Visitor history should not be visible to ordinary students or general community users.',
};

const visitorPickupBoundary =
    'A visitor pass does not authorize child pickup. Confirm pickup authorization with school staff.';

/// Computed entirely from [visits] - the real, locally-held visitor records a school has actually
/// logged, never fixed sample counts. "Unescorted exceptions" was dropped outright: nothing in the
/// app tracks whether a visitor was ever left unescorted, so there was no honest number to show.
List<VisitorStat> visitorStats(List<VisitorRecord> visits) => [
      VisitorStat(
        'Visits today',
        '${visits.length}',
        'Across every real logged visit',
      ),
      VisitorStat(
        'On campus',
        '${visits.where((visit) => visit.status == VisitStatus.onCampus).length}',
        'Currently signed in',
      ),
      VisitorStat(
        'Expected',
        '${visits.where((visit) => visit.status == VisitStatus.expected).length}',
        'Pre-registered',
      ),
      VisitorStat(
        'Checked out',
        '${visits.where((visit) => visit.status == VisitStatus.checkedOut).length}',
        'Completed visits',
      ),
    ];
