import '../domain/excursion_models.dart';

/// Static guidance copy for Excursions & Trips - not data about this school, so it never needs a
/// real backend source. Real activity (trips) lives in [ExcursionRepository] instead.
const excursionDepartureChecks = <String, String>{
  'Guardian consent': 'Required where school policy says so.',
  'Transport manifest': 'Vehicle, adults and participant list.',
  'Emergency contacts': 'Accessible to authorized supervising staff.',
  'Medical/access needs': 'Handled privately and only where necessary for safe participation.',
};

const excursionPrivacyRule =
    'Share essential trip safety information privately with the authorized supervisor.';

/// Computed entirely from [trips] - the real, locally-held excursions a school has actually
/// created, never fixed sample counts. "Transport plans" was dropped outright: nothing in the app
/// tracks a transport plan separately from a trip's own free-text `transport` field, so there was
/// no honest count to show beyond the trip count itself.
List<ExcursionStat> excursionStats(List<SchoolTrip> trips) => [
      ExcursionStat('Planned trips', '${trips.length}', 'Across the whole term'),
      ExcursionStat(
        'Consent outstanding',
        '${trips.fold<int>(0, (sum, trip) => sum + trip.consentOutstanding)}',
        'Across all real trips',
      ),
      ExcursionStat(
        'Ready to go',
        '${trips.where((trip) => trip.status == TripStatus.ready).length}',
        'Consent + readiness complete',
      ),
      ExcursionStat(
        'Unreviewed readiness',
        '${trips.where((trip) => !trip.readinessReviewed).length}',
        'Offline review state',
      ),
    ];
