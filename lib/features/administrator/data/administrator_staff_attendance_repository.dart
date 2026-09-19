import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/administrator_staff_attendance_models.dart';
import 'administrator_staff_attendance_demo_data.dart';

class AdministratorStaffAttendanceSnapshot {
  const AdministratorStaffAttendanceSnapshot({
    required this.records,
    required this.devices,
    required this.summary,
    required this.permissions,
  });

  final List<StaffAttendanceRecord> records;
  final List<StaffAttendanceDevice> devices;
  final PayrollAttendanceSummary summary;
  final StaffAttendancePermissions permissions;
}

class AdministratorStaffAttendanceActionResult {
  const AdministratorStaffAttendanceActionResult({
    required this.success,
    required this.message,
    this.summary,
  });

  final bool success;
  final String message;
  final PayrollAttendanceSummary? summary;
}

class AdministratorStaffAttendanceRepository {
  AdministratorStaffAttendanceRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _recordEntityType = 'administrator_staff_attendance';
  static const _summaryEntityType = 'payroll_attendance_summary';
  static const _summaryId = 'PAYROLL-ATT-2026-09';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  StaffAttendancePermissions permissionsFor(SchoolMembership membership) {
    final allowed = membership.role == SchoolRole.administrator;
    return StaffAttendancePermissions(
      canViewAttendance: allowed,
      canSendPayrollSummary: allowed,
    );
  }

  Future<AdministratorStaffAttendanceSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var storedRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _recordEntityType,
    );

    if (storedRecords.isEmpty) {
      for (final record in administratorStaffAttendanceWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _recordEntityType,
          entityId: record.id,
          payload: record.toJson(),
        );
      }
      storedRecords = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _recordEntityType,
      );
    }

    final records = storedRecords
        .map((item) => StaffAttendanceRecord.fromJson(item.payload))
        .toList();
    final order = <String, int>{
      for (var i = 0; i < administratorStaffAttendanceWebsiteSeed.length; i++)
        administratorStaffAttendanceWebsiteSeed[i].id: i,
    };
    records.sort((a, b) =>
        (order[a.id] ?? 999).compareTo(order[b.id] ?? 999));

    final storedSummary = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _summaryEntityType,
      entityId: _summaryId,
    );
    final summary = storedSummary == null
        ? PayrollAttendanceSummary(
            id: _summaryId,
            sent: false,
            records: records,
          )
        : PayrollAttendanceSummary.fromJson(storedSummary.payload);

    return AdministratorStaffAttendanceSnapshot(
      records: records,
      devices: administratorStaffAttendanceDevices,
      summary: PayrollAttendanceSummary(
        id: summary.id,
        sent: summary.sent,
        records: records,
      ),
      permissions: permissionsFor(membership),
    );
  }

  Future<AdministratorStaffAttendanceActionResult> sendPayrollSummary(
    List<StaffAttendanceRecord> records,
  ) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canSendPayrollSummary) {
      return const AdministratorStaffAttendanceActionResult(
        success: false,
        message: 'This membership cannot send the payroll attendance summary.',
      );
    }

    final summary = PayrollAttendanceSummary(
      id: _summaryId,
      sent: true,
      records: records,
    );
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _summaryEntityType,
      entityId: _summaryId,
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _summaryEntityType,
      entityId: _summaryId,
      payload: summary.toJson(),
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _summaryEntityType,
      entityId: _summaryId,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: summary.toJson(),
      baseVersion: existing?.serverVersion,
    );

    return AdministratorStaffAttendanceActionResult(
      success: true,
      message:
          'Attendance summary sent offline and queued for sync. Review holds remain holds; no salary deduction or employment action was created.',
      summary: summary,
    );
  }

  String buildExportPreview(List<StaffAttendanceRecord> records) {
    final buffer = StringBuffer(
      'Staff ID,Name,Role,Section,Expected,Present,Leave,Late,Unexplained,Payroll State\n',
    );
    for (final record in records) {
      buffer.writeln([
        record.id,
        record.name,
        record.role,
        record.section,
        record.expected,
        record.present,
        record.leave,
        record.late,
        record.unexplained,
        record.payrollState,
      ].join(','));
    }
    return buffer.toString().trimRight();
  }
}
