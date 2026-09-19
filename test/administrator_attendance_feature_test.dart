import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_demo_data.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_attendance_models.dart';

void main() {
  test('website attendance KPIs are preserved exactly', () {
    expect(administratorAttendancePresentToday, 623);
    expect(administratorAttendancePresentRate, 96.1);
    expect(administratorAttendanceLateArrivals, 27);
    expect(administratorAttendanceAbsentNotCheckedIn, 25);
    expect(administratorAttendanceActiveDevices, '4 / 5');
    expect(administratorAttendanceQueuedEvents, 42);
  });

  test('website seed preserves five exact live events', () {
    expect(administratorAttendanceWebsiteEvents, hasLength(5));
    expect(administratorAttendanceWebsiteEvents.first.student, 'Maryam Abdullahi');
    expect(administratorAttendanceWebsiteEvents.first.time, '07:41');
    expect(administratorAttendanceWebsiteEvents[2].status, AdministratorAttendanceEventStatus.late);
    expect(administratorAttendanceWebsiteEvents[3].status, AdministratorAttendanceEventStatus.offlineSynced);
    expect(administratorAttendanceWebsiteEvents[3].parentState, 'Queued');
    expect(administratorAttendanceWebsiteEvents.last.student, 'Unknown credential');
    expect(administratorAttendanceWebsiteEvents.last.status, AdministratorAttendanceEventStatus.unknownScan);
    expect(administratorAttendanceWebsiteEvents.last.parentState, 'Not sent');
  });

  test('website seed preserves five device states including syncing and offline', () {
    expect(administratorAttendanceWebsiteDevices, hasLength(5));
    expect(
      administratorAttendanceWebsiteDevices
          .where((item) => item.status == AdministratorAttendanceDeviceStatus.online),
      hasLength(3),
    );
    expect(administratorAttendanceWebsiteDevices[3].name, 'Rear Gate Terminal');
    expect(administratorAttendanceWebsiteDevices[3].status, AdministratorAttendanceDeviceStatus.syncing);
    expect(administratorAttendanceWebsiteDevices[3].events, '42 queued');
    expect(administratorAttendanceWebsiteDevices.last.name, 'Sports Exit Reader');
    expect(administratorAttendanceWebsiteDevices.last.status, AdministratorAttendanceDeviceStatus.offline);
  });

  test('section summaries preserve exact rates and counts', () {
    expect(administratorAttendanceSections, hasLength(3));
    expect(administratorAttendanceSections[0].name, 'Early Years');
    expect(administratorAttendanceSections[0].rate, 96);
    expect(administratorAttendanceSections[0].present, 83);
    expect(administratorAttendanceSections[1].present, 312);
    expect(administratorAttendanceSections[1].late, 11);
    expect(administratorAttendanceSections[2].absent, 9);
  });

  test('three correction requests preserve website evidence', () {
    expect(administratorAttendanceCorrections, hasLength(3));
    expect(administratorAttendanceCorrections[0].id, 'ATT-081');
    expect(administratorAttendanceCorrections[0].requestedChange, 'Absent → Present');
    expect(administratorAttendanceCorrections[1].evidence, 'Arrival log attached');
    expect(administratorAttendanceCorrections[2].evidence, 'Leadership review required');
  });

  test('event, device and correction serialization preserve operational fields', () {
    final event = AdministratorAttendanceEvent.fromJson(
      administratorAttendanceWebsiteEvents[3].toJson(),
    );
    expect(event.student, 'Muhammad Kabir');
    expect(event.status, AdministratorAttendanceEventStatus.offlineSynced);

    final device = AdministratorAttendanceDevice.fromJson(
      administratorAttendanceWebsiteDevices[3].toJson(),
    );
    expect(device.status, AdministratorAttendanceDeviceStatus.syncing);
    expect(device.events, '42 queued');

    final correction = AdministratorAttendanceCorrection.fromJson(
      administratorAttendanceCorrections[2].toJson(),
    );
    expect(correction.id, 'ATT-083');
    expect(correction.requestedChange, 'Present → Excused');
  });

  test('attendance integrity boundaries block unsafe automatic conclusions', () {
    expect(administratorAttendanceIntegrityRule, contains('operational evidence, not accusations'));
    expect(administratorAttendanceIntegrityRule, contains('synchronize before absence is finalized'));
    expect(administratorAttendanceIntegrityRule, contains('unknown scans require human review'));
    expect(administratorAttendanceIntegrityRule, contains('requester, approver, reason and timestamp'));
    expect(administratorAttendanceIntegrityRule, contains('without inferring why'));
    expect(administratorAttendanceDeviceBoundary, contains('must not invent credentials'));
    expect(administratorAttendanceCorrectionBoundary, contains('authoritative audit workflow'));
  });

  test('website architecture and exception groups stay complete', () {
    expect(administratorAttendanceFlow, hasLength(6));
    expect(administratorAttendanceFlow.first, contains('Device scan'));
    expect(administratorAttendanceFlow.last, contains('Parent update'));
    expect(administratorAttendanceExceptions, hasLength(3));
    expect(administratorAttendanceExceptions.first, contains('42 offline events'));
    expect(administratorAttendanceExceptions[1], contains('never guess the student identity'));
    expect(administratorAttendanceExceptions.last, contains('audit trail'));
  });
}
