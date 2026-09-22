import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_demo_data.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_desk.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_attendance_models.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_students_models.dart';

const _students = <AdministratorStudentRecord>[
  AdministratorStudentRecord(id: 'STU-001', name: 'Maryam Abdullahi', className: 'JSS 2A', primaryGuardian: 'Alhaji Abdullahi Musa', status: AdministratorStudentStatus.active),
  AdministratorStudentRecord(id: 'STU-002', name: 'Ibrahim Sani', className: 'JSS 2A', primaryGuardian: 'Alhaji Sani Ibrahim', status: AdministratorStudentStatus.active),
  AdministratorStudentRecord(id: 'STU-003', name: 'Yusuf Bello', className: 'JSS 2B', primaryGuardian: 'Alhaji Musa Bello', status: AdministratorStudentStatus.transferPending),
  AdministratorStudentRecord(id: 'PRI-003', name: 'Hafsa Abdullahi', className: 'Primary 3', primaryGuardian: 'Alhaji Abdullahi Sani', status: AdministratorStudentStatus.active),
];

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

  test('device serialization preserves operational fields', () {
    final device = AdministratorAttendanceDevice.fromJson(
      administratorAttendanceWebsiteDevices[3].toJson(),
    );
    expect(device.status, AdministratorAttendanceDeviceStatus.syncing);
    expect(device.events, '42 queued');
  });

  test('sample correction requests are drawn from the real register, not fixed names', () {
    // Every sample correction must name a student who is really on the passed-in register, so a demo school
    // never shows a fabricated request attributed to a real, identifiable student who never submitted one.
    final corrections = demoCorrectionsFor(_students);
    expect(corrections, hasLength(3));
    final realNames = _students.map((s) => s.name).toSet();
    for (final c in corrections) {
      expect(realNames, contains(c.student));
    }
    expect(corrections.map((c) => c.id), ['ATT-081', 'ATT-082', 'ATT-083']);
    expect(corrections.every((c) => c.isPending), isTrue);
  });

  test('sample correction requests are deterministic: the same register gives the same requests', () {
    final first = demoCorrectionsFor(_students);
    final second = demoCorrectionsFor(_students);
    expect(first.map((c) => '${c.id}-${c.student}-${c.requestedChange}'), second.map((c) => '${c.id}-${c.student}-${c.requestedChange}'));
  });

  test('an empty register produces no sample correction requests', () {
    expect(demoCorrectionsFor(const []), isEmpty);
  });

  test('correction serialization preserves operational fields', () {
    final correction = AdministratorAttendanceCorrection.fromJson(
      demoCorrectionsFor(_students).last.toJson(),
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

  test('website architecture flow stays complete', () {
    expect(administratorAttendanceFlow, hasLength(6));
    expect(administratorAttendanceFlow.first, contains('Device scan'));
    expect(administratorAttendanceFlow.last, contains('Parent update'));
  });
}
