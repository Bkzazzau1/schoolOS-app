import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/administrator_attendance_models.dart';
import 'administrator_attendance_demo_data.dart';

class AdministratorAttendanceSnapshot {
  const AdministratorAttendanceSnapshot({
    required this.events,
    required this.devices,
    required this.corrections,
    required this.permissions,
  });

  final List<AdministratorAttendanceEvent> events;
  final List<AdministratorAttendanceDevice> devices;
  final List<AdministratorAttendanceCorrection> corrections;
  final AdministratorAttendancePermissions permissions;
}

class AdministratorAttendanceRepository {
  AdministratorAttendanceRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _eventEntityType = 'administrator_attendance_event';
  static const _deviceEntityType = 'administrator_attendance_device';
  static const _correctionEntityType = 'administrator_attendance_correction';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  AdministratorAttendancePermissions permissionsFor(SchoolMembership membership) {
    final allowed = membership.role == SchoolRole.administrator;
    return AdministratorAttendancePermissions(
      canViewControlCenter: allowed,
      canReviewCorrections: allowed,
    );
  }

  Future<AdministratorAttendanceSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();

    var eventRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _eventEntityType,
    );
    if (eventRecords.isEmpty) {
      for (final item in administratorAttendanceWebsiteEvents) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _eventEntityType,
          entityId: item.entityId,
          payload: item.toJson(),
        );
      }
      eventRecords = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _eventEntityType,
      );
    }

    var deviceRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _deviceEntityType,
    );
    if (deviceRecords.isEmpty) {
      for (final item in administratorAttendanceWebsiteDevices) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _deviceEntityType,
          entityId: item.name,
          payload: item.toJson(),
        );
      }
      deviceRecords = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _deviceEntityType,
      );
    }

    var correctionRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _correctionEntityType,
    );
    if (correctionRecords.isEmpty) {
      for (final item in administratorAttendanceCorrections) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _correctionEntityType,
          entityId: item.id,
          payload: item.toJson(),
        );
      }
      correctionRecords = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _correctionEntityType,
      );
    }

    final events = eventRecords
        .map((record) => AdministratorAttendanceEvent.fromJson(record.payload))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    final devices = deviceRecords
        .map((record) => AdministratorAttendanceDevice.fromJson(record.payload))
        .toList();
    final corrections = correctionRecords
        .map((record) => AdministratorAttendanceCorrection.fromJson(record.payload))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    final deviceOrder = <String, int>{
      for (var i = 0; i < administratorAttendanceWebsiteDevices.length; i++)
        administratorAttendanceWebsiteDevices[i].name: i,
    };
    devices.sort((a, b) =>
        (deviceOrder[a.name] ?? 9999).compareTo(deviceOrder[b.name] ?? 9999));

    return AdministratorAttendanceSnapshot(
      events: events,
      devices: devices,
      corrections: corrections,
      permissions: permissionsFor(membership),
    );
  }

  String exportTodayPreview(List<AdministratorAttendanceEvent> events) {
    final buffer = StringBuffer('time,student,class,device,method,status,parent\n');
    for (final item in events) {
      buffer.writeln([
        item.time,
        item.student,
        item.className,
        item.device,
        item.method,
        item.status.label,
        item.parentState,
      ].map(_csv).join(','));
    }
    return buffer.toString().trimRight();
  }

  static String _csv(String value) => '"${value.replaceAll('"', '""')}"';
}
