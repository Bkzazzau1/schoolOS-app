import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/data/administrator_staff_attendance_demo_data.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_staff_attendance_models.dart';

void main() {
  test('website seed preserves four exact staff attendance rows', () {
    expect(administratorStaffAttendanceWebsiteSeed, hasLength(4));

    final amina = administratorStaffAttendanceWebsiteSeed[0];
    expect(amina.id, 'STAFF-001');
    expect(amina.name, 'Mrs. Amina Yusuf');
    expect(amina.expected, 22);
    expect(amina.present, 21);
    expect(amina.leave, 1);
    expect(amina.late, 2);
    expect(amina.unexplained, 0);
    expect(amina.status, StaffAttendanceReviewStatus.ready);

    final safiya = administratorStaffAttendanceWebsiteSeed[3];
    expect(safiya.id, 'STAFF-021');
    expect(safiya.present, 19);
    expect(safiya.leave, 2);
    expect(safiya.unexplained, 1);
    expect(safiya.status, StaffAttendanceReviewStatus.review);
  });

  test('ledger has two ready and two review records', () {
    expect(
      administratorStaffAttendanceWebsiteSeed
          .where((item) => item.status == StaffAttendanceReviewStatus.ready),
      hasLength(2),
    );
    expect(
      administratorStaffAttendanceWebsiteSeed
          .where((item) => item.status == StaffAttendanceReviewStatus.review),
      hasLength(2),
    );
    expect(
      administratorStaffAttendanceWebsiteSeed
          .where((item) => item.unexplained > 0),
      hasLength(2),
    );
  });

  test('three exact attendance hardware devices are preserved', () {
    expect(administratorStaffAttendanceDevices, hasLength(3));
    expect(
      administratorStaffAttendanceDevices[0].name,
      'Staff Main Gate Face Terminal',
    );
    expect(administratorStaffAttendanceDevices[0].state, 'Online · 63 scans today');
    expect(administratorStaffAttendanceDevices[1].method, 'NFC / RFID');
    expect(administratorStaffAttendanceDevices[2].state, 'Syncing · 7 queued');
  });

  test('controlled attendance-to-payroll flow has five exact steps', () {
    expect(administratorStaffAttendanceFlow, hasLength(5));
    expect(administratorStaffAttendanceFlow.first[0], '1. Staff scan');
    expect(administratorStaffAttendanceFlow.last[0], '5. Finance handoff');
    expect(administratorStaffAttendanceFlow.last[1], contains('human review'));
  });

  test('attendance serialization preserves payroll review fields', () {
    final original = administratorStaffAttendanceWebsiteSeed[1];
    final restored = StaffAttendanceRecord.fromJson(original.toJson());
    expect(restored.id, 'STAFF-009');
    expect(restored.expected, 22);
    expect(restored.present, 20);
    expect(restored.leave, 1);
    expect(restored.late, 1);
    expect(restored.unexplained, 1);
    expect(restored.status, StaffAttendanceReviewStatus.review);
    expect(restored.payrollState, 'Hold for review');
  });

  test('payroll summary serialization keeps holds and sent state', () {
    final summary = PayrollAttendanceSummary(
      id: 'PAYROLL-ATT-2026-09',
      sent: true,
      records: administratorStaffAttendanceWebsiteSeed,
    );
    final restored = PayrollAttendanceSummary.fromJson(summary.toJson());
    expect(restored.sent, isTrue);
    expect(restored.records, hasLength(4));
    expect(restored.records[1].payrollReady, isFalse);
    expect(restored.records[3].payrollState, 'Hold for review');
  });

  test('governance prevents automatic payroll or employment action', () {
    expect(staffAttendanceGovernanceRule, contains('must not automatically'));
    expect(staffAttendanceGovernanceRule, contains('salary deductions'));
    expect(staffAttendanceGovernanceRule, contains('disciplinary action'));
    expect(staffAttendanceGovernanceRule, contains('employment decisions'));
    expect(staffAttendanceSyncRule, contains('sync before an absence is finalized'));
    expect(staffAttendanceSyncRule, contains('human review'));
  });
}
