import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_students_models.dart';

const _fixtureStudents = <AdministratorStudentRecord>[
  AdministratorStudentRecord(
    id: 'STU-FIX-001',
    name: 'Maryam Abdullahi',
    className: 'JSS 2A',
    primaryGuardian: 'Alhaji Abdullahi Musa',
    status: AdministratorStudentStatus.active,
  ),
  AdministratorStudentRecord(
    id: 'STU-FIX-002',
    name: 'Ibrahim Sani',
    className: 'JSS 2A',
    primaryGuardian: 'Alhaji Sani Ibrahim',
    status: AdministratorStudentStatus.active,
  ),
  AdministratorStudentRecord(
    id: 'STU-FIX-003',
    name: 'Yusuf Bello',
    className: 'JSS 2B',
    primaryGuardian: 'Alhaji Musa Bello',
    status: AdministratorStudentStatus.transferPending,
  ),
  AdministratorStudentRecord(
    id: 'PRI-FIX-003',
    name: 'Hafsa Abdullahi',
    className: 'Primary 3',
    primaryGuardian: 'Alhaji Abdullahi Sani',
    status: AdministratorStudentStatus.active,
  ),
];

void main() {
  test('a fixture directory row carries exact name, class, guardian and status fields', () {
    expect(_fixtureStudents, hasLength(4));

    final maryam = _fixtureStudents[0];
    expect(maryam.name, 'Maryam Abdullahi');
    expect(maryam.className, 'JSS 2A');
    expect(maryam.primaryGuardian, 'Alhaji Abdullahi Musa');
    expect(maryam.status, AdministratorStudentStatus.active);

    final hafsa = _fixtureStudents[3];
    expect(hafsa.name, 'Hafsa Abdullahi');
    expect(hafsa.className, 'Primary 3');
    expect(hafsa.isPrimary, isTrue);
  });

  test('a fixture register has three active and one transfer-pending record', () {
    expect(
      _fixtureStudents
          .where((item) => item.status == AdministratorStudentStatus.active),
      hasLength(3),
    );
    expect(
      _fixtureStudents.where(
        (item) => item.status == AdministratorStudentStatus.transferPending,
      ),
      hasLength(1),
    );
    expect(
      _fixtureStudents[2].name,
      'Yusuf Bello',
    );
  });

  test('student directory serialization preserves operational fields', () {
    final original = _fixtureStudents[2];
    final restored = AdministratorStudentRecord.fromJson(original.toJson());
    expect(restored.id, 'STU-FIX-003');
    expect(restored.name, 'Yusuf Bello');
    expect(restored.className, 'JSS 2B');
    expect(restored.primaryGuardian, 'Alhaji Musa Bello');
    expect(restored.status, AdministratorStudentStatus.transferPending);
  });

  test('Open routing preserves primary versus secondary leadership destination', () {
    expect(
      _fixtureStudents.first.leadershipDestination,
      'Secondary leadership profile',
    );
    expect(
      _fixtureStudents.last.leadershipDestination,
      'Primary leadership profile',
    );
  });

  test('administrator profile boundary blocks leadership privilege leakage', () {
    expect(administratorStudentProfileBoundary, contains('leadership profiles'));
    expect(administratorStudentProfileBoundary, contains('restricted health data'));
    expect(administratorStudentProfileBoundary, contains('promotion decisions'));
    expect(administratorFamilyBoundary, contains('without merging'));
    expect(administratorFamilyBoundary, contains('separate academic'));
  });
}
