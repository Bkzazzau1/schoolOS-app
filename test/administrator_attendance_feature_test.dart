import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_demo_data.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_attendance_models.dart';

void main() {
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

  test('an event entityId is always a safe sync id, even with a space in the student name', () {
    // The sync push endpoint only accepts entityId matching ^[A-Za-z0-9._:\-]{1,128}$ - a
    // raw "$time-$student" would be rejected the moment this reached a real backend.
    const event = AdministratorAttendanceEvent(
      time: '07:45',
      student: 'Maryam Abdullahi',
      className: 'JSS 2A',
      device: 'Front desk',
      method: 'Manual',
      status: AdministratorAttendanceEventStatus.checkedIn,
      parentState: 'Queued',
    );
    expect(event.entityId, isNot(contains(' ')));
    expect(RegExp(r'^[A-Za-z0-9._:-]{1,128}$').hasMatch(event.entityId), isTrue);
  });

  test('device serialization preserves operational fields', () {
    final device = AdministratorAttendanceDevice.fromJson(
      administratorAttendanceWebsiteDevices[3].toJson(),
    );
    expect(device.status, AdministratorAttendanceDeviceStatus.syncing);
    expect(device.events, '42 queued');
  });

  test('correction serialization preserves operational fields', () {
    const original = AdministratorAttendanceCorrection(
      id: 'ATT-083',
      student: 'Hafsa Abdullahi',
      className: 'Primary 3',
      requestedChange: 'Present → Excused',
      evidence: 'Leadership review required',
    );
    final correction = AdministratorAttendanceCorrection.fromJson(original.toJson());
    expect(correction.id, 'ATT-083');
    expect(correction.requestedChange, 'Present → Excused');
    expect(correction.isPending, isTrue);
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

  test('website architecture flow stays complete', () {
    expect(administratorAttendanceFlow, hasLength(6));
    expect(administratorAttendanceFlow.first, contains('Device scan'));
    expect(administratorAttendanceFlow.last, contains('Parent update'));
  });
}
