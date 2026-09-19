import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_demo_data.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_students_models.dart';

void main() {
  test('website seed preserves four exact student directory rows', () {
    expect(administratorStudentsWebsiteSeed, hasLength(4));

    final maryam = administratorStudentsWebsiteSeed[0];
    expect(maryam.id, 'STU-001');
    expect(maryam.name, 'Maryam Abdullahi');
    expect(maryam.className, 'JSS 2A');
    expect(maryam.primaryGuardian, 'Alhaji Abdullahi Musa');
    expect(maryam.status, AdministratorStudentStatus.active);

    final hafsa = administratorStudentsWebsiteSeed[3];
    expect(hafsa.id, 'PRI-003');
    expect(hafsa.name, 'Hafsa Abdullahi');
    expect(hafsa.className, 'Primary 3');
    expect(hafsa.isPrimary, isTrue);
  });

  test('directory has three active and one transfer-pending record', () {
    expect(
      administratorStudentsWebsiteSeed
          .where((item) => item.status == AdministratorStudentStatus.active),
      hasLength(3),
    );
    expect(
      administratorStudentsWebsiteSeed.where(
        (item) => item.status == AdministratorStudentStatus.transferPending,
      ),
      hasLength(1),
    );
    expect(
      administratorStudentsWebsiteSeed[2].name,
      'Yusuf Bello',
    );
  });

  test('website family account tasks are preserved exactly', () {
    expect(administratorFamilyTasks, hasLength(2));
    expect(administratorFamilyTasks[0].title, contains('2 guardian links'));
    expect(administratorFamilyTasks[0].detail, contains('access scope'));
    expect(administratorFamilyTasks[1].title, contains('1 sibling link'));
    expect(administratorFamilyTasks[1].detail, contains('without merging'));
  });

  test('website record quality tasks are preserved exactly', () {
    expect(administratorRecordQualityTasks, hasLength(2));
    expect(administratorRecordQualityTasks[0].title, contains('7 profiles'));
    expect(administratorRecordQualityTasks[0].detail, contains('previous-school'));
    expect(administratorRecordQualityTasks[1].title, contains('3 emergency contacts'));
    expect(administratorRecordQualityTasks[1].detail, 'Contact details incomplete.');
  });

  test('student directory serialization preserves operational fields', () {
    final original = administratorStudentsWebsiteSeed[2];
    final restored = AdministratorStudentRecord.fromJson(original.toJson());
    expect(restored.id, 'STU-003');
    expect(restored.name, 'Yusuf Bello');
    expect(restored.className, 'JSS 2B');
    expect(restored.primaryGuardian, 'Alhaji Musa Bello');
    expect(restored.status, AdministratorStudentStatus.transferPending);
  });

  test('Open routing preserves primary versus secondary leadership destination', () {
    expect(
      administratorStudentsWebsiteSeed.first.leadershipDestination,
      'Secondary leadership profile',
    );
    expect(
      administratorStudentsWebsiteSeed.last.leadershipDestination,
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
