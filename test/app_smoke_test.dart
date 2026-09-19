import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/attendance/domain/attendance_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

void main() {
  test('school membership preserves tenant-specific role', () {
    const membership = SchoolMembership(
      id: 'membership-1',
      schoolId: 'school-a',
      schoolName: 'School A',
      role: SchoolRole.teacher,
    );

    final restored = SchoolMembership.fromJson(membership.toJson());

    expect(restored.id, membership.id);
    expect(restored.schoolId, 'school-a');
    expect(restored.role, SchoolRole.teacher);
    expect(restored.roleLabel, 'Teacher');
  });

  test('attendance entry changes status without changing student identity', () {
    const student = AttendanceStudent(
      id: 'student-1',
      admissionNumber: 'J1A-001',
      name: 'Aisha Musa',
    );
    const entry = AttendanceEntry(
      student: student,
      status: AttendanceStatus.present,
    );

    final absent = entry.copyWith(status: AttendanceStatus.absent);

    expect(absent.student.id, 'student-1');
    expect(absent.status, AttendanceStatus.absent);
    expect(absent.toJson()['status'], 'absent');
  });
}
