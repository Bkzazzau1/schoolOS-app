import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/domain/administrator_staff_models.dart';
import '../../proprietor/data/owner_staff_profile_repository.dart';
import '../domain/principal_academics_models.dart';
import '../domain/principal_approvals_models.dart' show PrincipalApprovalStatus, PrincipalApprovalStatusLabel, PrincipalApprovalPriorityLabel;
import '../domain/principal_dashboard_models.dart';
import '../domain/principal_profile_models.dart' show PrincipalProfileActivity;
import 'principal_academics_repository.dart';
import 'principal_approvals_repository.dart';
import 'principal_attendance_repository.dart';
import 'principal_incidents_repository.dart';
import 'principal_teachers_repository.dart';

class PrincipalDashboardSnapshot {
  const PrincipalDashboardSnapshot({
    required this.kpis,
    required this.approvals,
    required this.alerts,
    required this.teachers,
    required this.classes,
    required this.activity,
    required this.pendingApprovals,
    required this.openIncidents,
    required this.permissions,
  });

  final List<PrincipalKpi> kpis;
  final List<PrincipalDashboardApprovalItem> approvals;

  /// Always empty: no real source produces a leadership "alert" automatically (see
  /// [PrincipalAlert]'s doc comment).
  final List<PrincipalAlert> alerts;
  final List<PrincipalTeacherIndicator> teachers;
  final List<PrincipalClassIndicator> classes;
  final List<PrincipalProfileActivity> activity;
  final int pendingApprovals;
  final int openIncidents;
  final PrincipalPermissions permissions;
}

bool _teaches(AdministratorStaffRecord record) => record.role.toLowerCase().contains('teacher');

String _ageOf(String iso) {
  final time = DateTime.tryParse(iso);
  if (time == null) return iso;
  final diff = DateTime.now().toUtc().difference(time.toUtc());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} hr';
  return '${diff.inDays} d';
}

class PrincipalDashboardRepository {
  PrincipalDashboardRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required PrincipalAcademicsRepository academics,
    required PrincipalAttendanceRepository attendance,
    required PrincipalTeachersRepository teachers,
    required PrincipalApprovalsRepository approvals,
    required PrincipalIncidentsRepository incidents,
    required OwnerStaffProfileRepository staff,
  })  : _schoolSession = schoolSession,
        _academics = academics,
        _attendance = attendance,
        _teachers = teachers,
        _approvals = approvals,
        _incidents = incidents,
        _staff = staff;

  final SchoolSessionController _schoolSession;
  final PrincipalAcademicsRepository _academics;
  final PrincipalAttendanceRepository _attendance;
  final PrincipalTeachersRepository _teachers;
  final PrincipalApprovalsRepository _approvals;
  final PrincipalIncidentsRepository _incidents;
  final OwnerStaffProfileRepository _staff;

  PrincipalPermissions permissionsFor(SchoolMembership membership) => PrincipalPermissions(
        canLeadSecondary: membership.role == SchoolRole.principal,
        canApproveAcademicWork: membership.role == SchoolRole.principal,
        canGovernWholeSchool: false,
        canLeadPrimary: false,
      );

  Future<(String, String)> _studentAttendanceKpi() async {
    final classes = (await _attendance.load()).classes;
    final total = classes.fold<int>(0, (sum, row) => sum + row.total);
    if (total == 0) return ('Not recorded', 'No Secondary students on record');
    final present = classes.fold<int>(0, (sum, row) => sum + row.present);
    return ('${(present * 100 / total).round()}%', '$present of $total');
  }

  Future<(String, String)> _teacherAttendanceKpi() async {
    final all = await _staff.people();
    final secondaryTeachers = [for (final s in all) if (s.section == 'Secondary' && _teaches(s)) s];
    final rates = <double>[];
    for (final record in secondaryTeachers) {
      final rate = (await _staff.view(record)).attendanceRate;
      if (rate != null) rates.add(rate);
    }
    if (rates.isEmpty) return ('Not recorded', '0 of ${secondaryTeachers.length} recorded');
    final average = (rates.reduce((a, b) => a + b) / rates.length).round();
    return ('$average%', '${rates.length} of ${secondaryTeachers.length} recorded');
  }

  Future<PrincipalDashboardSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canLeadSecondary) {
      return PrincipalDashboardSnapshot(
        kpis: const [],
        approvals: const [],
        alerts: const [],
        teachers: const [],
        classes: const [],
        activity: const [],
        pendingApprovals: 0,
        openIncidents: 0,
        permissions: permissions,
      );
    }

    final academicsSnapshot = await _academics.load();
    final teachersSnapshot = await _teachers.load();
    final approvalsSnapshot = await _approvals.load();
    final incidentsSnapshot = await _incidents.load();
    final (studentAttendanceValue, studentAttendanceHint) = await _studentAttendanceKpi();
    final (teacherAttendanceValue, teacherAttendanceHint) = await _teacherAttendanceKpi();

    final onTrack = academicsSnapshot.classes.where((c) => c.status == PrincipalAcademicStatus.strong || c.status == PrincipalAcademicStatus.onTrack).length;

    final kpis = <PrincipalKpi>[
      PrincipalKpi(label: 'Secondary students present', value: studentAttendanceValue, hint: studentAttendanceHint),
      PrincipalKpi(label: 'Secondary teachers present', value: teacherAttendanceValue, hint: teacherAttendanceHint),
      PrincipalKpi(label: 'Pending approvals', value: '${approvalsSnapshot.pendingCount}', hint: '${approvalsSnapshot.highPriorityPendingCount} high priority'),
      PrincipalKpi(
        label: 'Classes on track',
        value: academicsSnapshot.classes.isEmpty ? 'Not recorded' : '${(onTrack * 100 / academicsSnapshot.classes.length).round()}%',
        hint: '$onTrack of ${academicsSnapshot.classes.length} classes',
      ),
      PrincipalKpi(label: 'Open incidents', value: '${incidentsSnapshot.openCases}', hint: '${incidentsSnapshot.highPriority} high priority'),
    ];

    final approvals = [
      for (final item in approvalsSnapshot.items.where((i) => i.status == PrincipalApprovalStatus.pending))
        PrincipalDashboardApprovalItem(type: item.type, title: item.title, teacher: item.teacher, age: _ageOf(item.submitted), priority: item.priority.label),
    ]..sort((a, b) => a.age.compareTo(b.age));

    final teachers = [
      for (final t in teachersSnapshot.teachers)
        PrincipalTeacherIndicator(name: t.name, subject: t.subjects, compliance: t.lessonPlans, syllabus: t.syllabus, status: t.status),
    ];

    final classes = [
      for (final c in academicsSnapshot.classes)
        PrincipalClassIndicator(name: c.name, average: c.average, attendance: c.attendance, syllabus: c.syllabus, status: c.status.label),
    ];

    final activity = <PrincipalProfileActivity>[
      for (final item in approvalsSnapshot.items)
        PrincipalProfileActivity(time: item.submitted, action: '${item.teacher} submitted ${item.type.toLowerCase()}: ${item.title}'),
      for (final decision in approvalsSnapshot.decisions)
        PrincipalProfileActivity(time: decision.reviewedAt, action: '${decision.newStatus.label} · ${decision.reviewerMembershipId}'),
      for (final event in incidentsSnapshot.audit)
        PrincipalProfileActivity(
          time: event.createdAt,
          action: event.action == 'status_change' ? 'Incident status updated by ${event.actorMembershipId}' : 'Incident note added by ${event.actorMembershipId}',
        ),
    ]..sort((a, b) => b.time.compareTo(a.time));

    return PrincipalDashboardSnapshot(
      kpis: kpis,
      approvals: approvals,
      alerts: const [],
      teachers: teachers,
      classes: classes,
      activity: activity.take(8).toList(growable: false),
      pendingApprovals: approvalsSnapshot.pendingCount,
      openIncidents: incidentsSnapshot.openCases,
      permissions: permissions,
    );
  }
}
