import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_attendance_repository.dart';
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_attendance_models.dart';
import '../domain/parent_attendance_models.dart';
import 'parent_children_repository.dart';

const _notRecorded = 'Not recorded yet';

class ParentAttendanceRepository {
  /// [localDatabase] is accepted for constructor consistency with every other Parent
  /// repository, even though this one is a pure read-side roll-up of real attendance data and
  /// never touches the local database directly.
  ParentAttendanceRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required ParentChildrenRepository children,
    required AdministratorStudentsRepository students,
    required AdministratorAttendanceRepository attendance,
  })  : _schoolSession = schoolSession,
        _children = children,
        _students = students,
        _attendance = attendance;

  final SchoolSessionController _schoolSession;
  final ParentChildrenRepository _children;
  final AdministratorStudentsRepository _students;
  final AdministratorAttendanceRepository _attendance;

  static String _key(String name) => name.trim().toLowerCase();

  /// Real, from the same gate-scan source every other role reads. The real source only keeps
  /// today's record — there is no real day-by-day history yet — so [ParentAttendanceChildSummary]
  /// reports a single-day window (today) rather than a fabricated running percentage, and
  /// [ParentAttendanceSnapshot.events] holds only today's real event per child.
  Future<ParentAttendanceSnapshot> load() async {
    final membership = _requireParentMembership();
    final linked = (await _children.load()).children;
    final register = (await _students.load()).students;
    final events = (await _attendance.load(students: register)).events;

    final childSummaries = <ParentAttendanceChildSummary>[];
    final todayEvents = <ParentAttendanceEvent>[];
    for (final child in linked) {
      AdministratorAttendanceEvent? event;
      for (final e in events) {
        if (!e.isUnknown && _key(e.student) == _key(child.name)) {
          event = e;
          break;
        }
      }
      final present = event?.countsAsPresent ?? false;
      childSummaries.add(ParentAttendanceChildSummary(
        childId: child.id,
        name: child.name,
        className: child.className,
        attendancePercent: present ? 100 : 0,
        presentDays: present ? 1 : 0,
        totalSchoolDays: 1,
        lateArrivals: event?.status == AdministratorAttendanceEventStatus.late ? 1 : 0,
        latestCheckInLabel: event == null ? _notRecorded : 'Today · ${event.time}',
        captureDevice: event?.device ?? _notRecorded,
        checkedInToday: present,
      ));
      if (event != null) {
        todayEvents.add(ParentAttendanceEvent(
          dateLabel: 'Today',
          childId: child.id,
          childName: child.name,
          checkIn: event.time,
          checkOut: '—',
          gate: event.device,
          captureMethod: event.method,
          status: event.status.label,
        ));
      }
    }

    return ParentAttendanceSnapshot(
      familyAccountId: membership.id,
      children: childSummaries,
      events: todayEvents,
      // No real push-notification system exists for attendance check-ins.
      notifications: const [],
    );
  }

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError('Family attendance requires an active Parent membership.');
    }
    return membership;
  }
}
