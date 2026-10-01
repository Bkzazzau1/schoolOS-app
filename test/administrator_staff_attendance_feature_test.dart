import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/data/administrator_staff_attendance_policy_copy.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_staff_attendance_models.dart';

const _fixtureRecords = <StaffAttendanceRecord>[
  StaffAttendanceRecord(
    id: 'STAFF-FIX-001',
    name: 'Mrs. Amina Yusuf',
    role: 'Teacher',
    section: 'Secondary',
    expected: 22,
    present: 21,
    leave: 1,
    late: 2,
    unexplained: 0,
    status: StaffAttendanceReviewStatus.ready,
  ),
  StaffAttendanceRecord(
    id: 'STAFF-FIX-009',
    name: 'Mrs. Khadija Musa',
    role: 'Class Teacher',
    section: 'Primary',
    expected: 22,
    present: 20,
    leave: 1,
    late: 1,
    unexplained: 1,
    status: StaffAttendanceReviewStatus.review,
  ),
  StaffAttendanceRecord(
    id: 'STAFF-FIX-014',
    name: 'Mr. Ahmad Sani',
    role: 'Teacher',
    section: 'Secondary',
    expected: 22,
    present: 22,
    leave: 0,
    late: 3,
    unexplained: 0,
    status: StaffAttendanceReviewStatus.ready,
  ),
  StaffAttendanceRecord(
    id: 'STAFF-FIX-021',
    name: 'Mrs. Safiya Ahmad',
    role: 'Teacher',
    section: 'Primary',
    expected: 22,
    present: 19,
    leave: 2,
    late: 0,
    unexplained: 1,
    status: StaffAttendanceReviewStatus.review,
  ),
];

void main() {
  test('a fixture record carries exact expected/present/leave/late/unexplained fields', () {
    expect(_fixtureRecords, hasLength(4));

    final amina = _fixtureRecords[0];
    expect(amina.name, 'Mrs. Amina Yusuf');
    expect(amina.expected, 22);
    expect(amina.present, 21);
    expect(amina.leave, 1);
    expect(amina.late, 2);
    expect(amina.unexplained, 0);
    expect(amina.status, StaffAttendanceReviewStatus.ready);

    final safiya = _fixtureRecords[3];
    expect(safiya.present, 19);
    expect(safiya.leave, 2);
    expect(safiya.unexplained, 1);
    expect(safiya.status, StaffAttendanceReviewStatus.review);
  });

  test('a fixture ledger has two ready and two review records', () {
    expect(
      _fixtureRecords
          .where((item) => item.status == StaffAttendanceReviewStatus.ready),
      hasLength(2),
    );
    expect(
      _fixtureRecords
          .where((item) => item.status == StaffAttendanceReviewStatus.review),
      hasLength(2),
    );
    expect(
      _fixtureRecords
          .where((item) => item.unexplained > 0),
      hasLength(2),
    );
  });

  test('controlled attendance-to-payroll flow has five exact steps', () {
    expect(administratorStaffAttendanceFlow, hasLength(5));
    expect(administratorStaffAttendanceFlow.first[0], '1. Staff scan');
    expect(administratorStaffAttendanceFlow.last[0], '5. Finance handoff');
    expect(administratorStaffAttendanceFlow.last[1], contains('human review'));
  });

  test('attendance serialization preserves payroll review fields', () {
    final original = _fixtureRecords[1];
    final restored = StaffAttendanceRecord.fromJson(original.toJson());
    expect(restored.id, 'STAFF-FIX-009');
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
      records: _fixtureRecords,
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
