import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/features/administrator/data/administrator_staff_attendance_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_staff_repository.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_staff_attendance_models.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_staff_models.dart';

/// Writes a real staff directory entry, the same real entity [AdministratorStaffRepository.load]
/// merges into the directory. Tests use this instead of the fabricated directory seed that used to
/// populate a fresh school's staff list automatically.
Future<void> seedRealStaff(
  LocalDatabase db, {
  required String tenantId,
  required String id,
  required String name,
  required String role,
  required String section,
  AdministratorStaffFileStatus fileStatus = AdministratorStaffFileStatus.complete,
}) async {
  await db.upsertLocalRecord(
    tenantId: tenantId,
    entityType: AdministratorStaffRepository.directoryEntityType,
    entityId: id,
    payload: AdministratorStaffRecord(id: id, name: name, role: role, section: section, fileStatus: fileStatus).toJson(),
  );
}

/// Writes a real staff attendance record, the same real entity
/// [AdministratorStaffAttendanceRepository.load] merges into the ledger.
Future<void> seedRealStaffAttendance(
  LocalDatabase db, {
  required String tenantId,
  required String id,
  required String name,
  required String role,
  required String section,
  int expected = 22,
  int present = 22,
  int leave = 0,
  int late = 0,
  int unexplained = 0,
  StaffAttendanceReviewStatus status = StaffAttendanceReviewStatus.ready,
}) async {
  await db.upsertLocalRecord(
    tenantId: tenantId,
    entityType: AdministratorStaffAttendanceRepository.recordEntityType,
    entityId: id,
    payload: StaffAttendanceRecord(
      id: id, name: name, role: role, section: section,
      expected: expected, present: present, leave: leave, late: late, unexplained: unexplained, status: status,
    ).toJson(),
  );
}

/// The same two named Secondary teachers the app's old, now-removed fabricated staff/staff-attendance
/// seeds used to invent - kept here as real directory and attendance entries so tests written against
/// those names keep working without each hand-rolling the same fixtures.
Future<void> seedClassicStaff(LocalDatabase db, {required String tenantId}) async {
  const people = [
    (id: 'STAFF-001', name: 'Mrs. Amina Yusuf', role: 'Teacher', section: 'Secondary'),
    (id: 'STAFF-002', name: 'Mr. Ahmad Sani', role: 'Teacher', section: 'Secondary'),
  ];
  for (final p in people) {
    await seedRealStaff(db, tenantId: tenantId, id: p.id, name: p.name, role: p.role, section: p.section);
    await seedRealStaffAttendance(db, tenantId: tenantId, id: p.id, name: p.name, role: p.role, section: p.section);
  }
}
