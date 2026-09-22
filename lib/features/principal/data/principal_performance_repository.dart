import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/domain/administrator_staff_models.dart';
import '../../proprietor/data/owner_staff_profile_repository.dart';
import '../domain/principal_academics_models.dart';
import '../domain/principal_incidents_models.dart' show PrincipalIncidentStatus;
import '../domain/principal_performance_models.dart';
import 'principal_academics_demo_data.dart' show principalAssessmentAverage, principalSchoolAverage, principalSyllabusAverage;
import 'principal_academics_repository.dart';
import 'principal_attendance_repository.dart';
import 'principal_incidents_repository.dart';
import 'principal_performance_demo_data.dart';

bool _teaches(AdministratorStaffRecord record) => record.role.toLowerCase().contains('teacher');

/// A school-wide performance scorecard, rolled up live from the same real sources the
/// Academics, Attendance, Teachers and Incidents screens already use. Nothing here is
/// computed or stored independently, so it can never drift from what those screens show.
class PrincipalPerformanceRepository {
  /// [localDatabase] is accepted for constructor consistency with every other Principal
  /// repository, even though this one is a pure read-side roll-up of other repositories and
  /// never touches the local database directly.
  PrincipalPerformanceRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required PrincipalAcademicsRepository academics,
    required PrincipalAttendanceRepository attendance,
    required PrincipalIncidentsRepository incidents,
    required OwnerStaffProfileRepository staff,
  })  : _schoolSession = schoolSession,
        _academics = academics,
        _attendance = attendance,
        _incidents = incidents,
        _staff = staff;

  final SchoolSessionController _schoolSession;
  final PrincipalAcademicsRepository _academics;
  final PrincipalAttendanceRepository _attendance;
  final PrincipalIncidentsRepository _incidents;
  final OwnerStaffProfileRepository _staff;

  bool canView(SchoolMembership membership) => membership.role == SchoolRole.principal;

  Future<int?> _studentAttendance() async {
    final classes = (await _attendance.load()).classes;
    final total = classes.fold<int>(0, (sum, row) => sum + row.total);
    if (total == 0) return null;
    final present = classes.fold<int>(0, (sum, row) => sum + row.present);
    return (present * 100 / total).round();
  }

  Future<int?> _teacherAttendance() async {
    final all = await _staff.people();
    final rates = <double>[];
    for (final record in all) {
      if (record.section != 'Secondary' || !_teaches(record)) continue;
      final rate = (await _staff.view(record)).attendanceRate;
      if (rate != null) rates.add(rate);
    }
    if (rates.isEmpty) return null;
    return (rates.reduce((a, b) => a + b) / rates.length).round();
  }

  Future<int?> _resolvedIncidents() async {
    final cases = (await _incidents.load()).cases;
    if (cases.isEmpty) return null;
    final resolved = cases.where((c) => c.status == PrincipalIncidentStatus.resolved).length;
    return (resolved * 100 / cases.length).round();
  }

  Future<PrincipalPerformanceSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    if (!canView(membership)) {
      return const PrincipalPerformanceSnapshot(metrics: [], classHealth: [], priorities: []);
    }

    final academicsSnapshot = await _academics.load();
    final studentAttendance = await _studentAttendance();
    final teacherAttendance = await _teacherAttendance();
    final resolvedIncidents = await _resolvedIncidents();

    final metrics = [
      PrincipalPerformanceMetric(
        label: 'Academic average',
        current: principalSchoolAverage(academicsSnapshot.classes),
        target: principalPerformanceTargets['Academic average']!,
        suffix: '%',
        routeKey: 'academics',
      ),
      PrincipalPerformanceMetric(
        label: 'Student attendance',
        current: studentAttendance,
        target: principalPerformanceTargets['Student attendance']!,
        suffix: '%',
        routeKey: 'attendance',
      ),
      PrincipalPerformanceMetric(
        label: 'Teacher attendance',
        current: teacherAttendance,
        target: principalPerformanceTargets['Teacher attendance']!,
        suffix: '%',
        routeKey: 'teachers',
      ),
      PrincipalPerformanceMetric(
        label: 'Syllabus coverage',
        current: principalSyllabusAverage(academicsSnapshot.classes),
        target: principalPerformanceTargets['Syllabus coverage']!,
        suffix: '%',
        routeKey: 'academics',
      ),
      PrincipalPerformanceMetric(
        label: 'Assessment completion',
        current: principalAssessmentAverage(academicsSnapshot.classes),
        target: principalPerformanceTargets['Assessment completion']!,
        suffix: '%',
        routeKey: 'academics',
      ),
      PrincipalPerformanceMetric(
        label: 'Resolved incidents',
        current: resolvedIncidents,
        target: principalPerformanceTargets['Resolved incidents']!,
        suffix: '%',
        routeKey: 'incidents',
      ),
    ];

    final classHealth = [
      for (final row in academicsSnapshot.classes)
        PrincipalClassHealth(
          className: row.name,
          average: row.status == PrincipalAcademicStatus.notEvaluated ? null : row.average,
          attendance: row.attendance,
        ),
    ]..sort((a, b) {
        if (a.average == null && b.average == null) return a.className.compareTo(b.className);
        if (a.average == null) return 1;
        if (b.average == null) return -1;
        return b.average!.compareTo(a.average!);
      });

    return PrincipalPerformanceSnapshot(
      metrics: metrics,
      classHealth: classHealth,
      priorities: const [],
    );
  }
}
