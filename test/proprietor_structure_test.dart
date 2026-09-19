import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/proprietor/data/proprietor_structure_demo_data.dart';
import 'package:schoolos_app/features/proprietor/domain/proprietor_structure_models.dart';

void main() {
  test('each seeded academic section has exactly one active section head', () {
    for (final section in initialAcademicSections) {
      final heads = initialLeadershipAppointments.where(
        (leader) =>
            leader.sectionId == section.id &&
            leader.level == LeadershipLevel.sectionHead,
      );
      expect(heads.length, 1, reason: section.name);
    }
  });

  test('delegated seeded leaders report within their own academic section', () {
    for (final leader in initialLeadershipAppointments) {
      if (leader.level == LeadershipLevel.sectionHead) continue;
      final manager = initialLeadershipAppointments.firstWhere(
        (candidate) => candidate.id == leader.reportsTo,
      );
      expect(manager.sectionId, leader.sectionId);
      expect(
        manager.level == LeadershipLevel.sectionHead ||
            manager.level == LeadershipLevel.deputy,
        isTrue,
      );
    }
  });

  test('seeded structure matches website section and class counts', () {
    expect(initialAcademicSections.length, 3);
    expect(
      initialAcademicSections.fold<int>(0, (sum, section) => sum + section.classes),
      14,
    );
    expect(initialLeadershipAppointments.length, 5);
  });

  test('authority matrix keeps school identity under proprietor control', () {
    final owner = proprietorAuthorityMatrix.first;
    expect(owner.schoolIdentity, 'Manage');
    for (final row in proprietorAuthorityMatrix.skip(1)) {
      expect(row.schoolIdentity, 'No');
    }
  });

  test('access resolution preserves tenant and scope ordering', () {
    expect(
      proprietorAccessResolution,
      const [
        'User',
        'School',
        'Campus',
        'Academic Section',
        'Role + Permissions',
        'Allowed records',
      ],
    );
  });

  test('leadership appointment serializes without losing scope', () {
    const appointment = LeadershipAppointment(
      id: 'L-006',
      person: 'Mrs. Amina Yusuf',
      title: 'HOD Science',
      level: LeadershipLevel.hod,
      sectionId: 'secondary',
      department: 'Science',
      reportsTo: 'L-004',
    );
    final restored = LeadershipAppointment.fromJson(appointment.toJson());
    expect(restored.id, appointment.id);
    expect(restored.sectionId, 'secondary');
    expect(restored.level, LeadershipLevel.hod);
    expect(restored.department, 'Science');
    expect(restored.reportsTo, 'L-004');
  });
}
