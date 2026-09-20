import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/parent_attendance_models.dart';
import 'parent_attendance_demo_data.dart';

class ParentAttendanceRepository {
  ParentAttendanceRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'parent_attendance_snapshot';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  Future<ParentAttendanceSnapshot> load() async {
    final membership = _requireParentMembership();
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: membership.id,
    );

    if (record != null) {
      final snapshot = ParentAttendanceSnapshot.fromJson(record.payload);
      _validateSnapshot(snapshot);
      return snapshot;
    }

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: membership.id,
      payload: parentDefaultAttendance.toJson(),
    );
    return parentDefaultAttendance;
  }

  Future<void> replaceFromServer({
    required ParentAttendanceSnapshot snapshot,
    required int serverVersion,
  }) async {
    final membership = _requireParentMembership();
    _validateSnapshot(snapshot);

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: membership.id,
      payload: snapshot.toJson(),
      serverVersion: serverVersion,
      isDirty: false,
    );
  }

  void _validateSnapshot(ParentAttendanceSnapshot snapshot) {
    if (snapshot.familyAccountId.trim().isEmpty) {
      throw StateError('Family attendance is missing its family account id.');
    }

    final childIds = <String>{};
    for (final child in snapshot.children) {
      if (child.childId.trim().isEmpty || !childIds.add(child.childId)) {
        throw StateError('Family attendance contains an invalid child id.');
      }
      if (child.attendancePercent < 0 || child.attendancePercent > 100) {
        throw StateError('A child attendance percentage is outside the valid range.');
      }
      if (child.presentDays < 0 || child.totalSchoolDays < 0 || child.presentDays > child.totalSchoolDays) {
        throw StateError('A child attendance day count is invalid.');
      }
      if (child.lateArrivals < 0) {
        throw StateError('A child late-arrival count cannot be negative.');
      }
    }

    for (final event in snapshot.events) {
      if (!childIds.contains(event.childId)) {
        throw StateError(
          'Attendance history contains a child not linked to the active family snapshot.',
        );
      }
      if (event.dateLabel.trim().isEmpty ||
          event.checkIn.trim().isEmpty ||
          event.status.trim().isEmpty) {
        throw StateError('Attendance history contains an incomplete event.');
      }
    }
  }

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError('Family attendance requires an active Parent membership.');
    }
    return membership;
  }
}
