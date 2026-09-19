import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/data/administrator_registration_demo_data.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_registration_models.dart';

void main() {
  test('website registration seed preserves exact student identity and placement', () {
    final record = administratorRegistrationWebsiteSeed;
    expect(record.firstName, 'Aisha');
    expect(record.surname, 'Sani');
    expect(record.otherName, 'Maryam');
    expect(record.dateOfBirth, '2018-04-12');
    expect(record.gender, 'Female');
    expect(record.academicSection, 'Primary');
    expect(record.proposedClass, 'Primary 2');
    expect(record.previousSchool, 'Al-Hikmah Academy');
    expect(record.address, 'Kaduna, Kaduna State');
  });

  test('generated website admission identity and status are preserved', () {
    final record = administratorRegistrationWebsiteSeed;
    expect(record.admissionNumber, 'BGA/KD/PRI/26/014');
    expect(record.studentId, 'STU-NEW-014');
    expect(record.status, StudentRegistrationStatus.inProgress);
    expect(record.isActive, isFalse);
    expect(admissionNumberForSection('Primary'), 'BGA/KD/PRI/26/014');
    expect(admissionNumberForSection('Secondary'), 'BGA/KD/SEC/26/009');
    expect(admissionNumberForSection('Early Years'), 'BGA/KD/EYR/26/009');
  });

  test('guardian family and document handoff defaults match website', () {
    final record = administratorRegistrationWebsiteSeed;
    expect(record.primaryGuardian, 'Alhaji Sani Ibrahim');
    expect(record.relationship, 'Father');
    expect(record.familyAccount, 'Create new family account');
    expect(record.siblingLink, 'No existing sibling');
    expect(record.birthCertificateStatus, 'Received · pending verification');
    expect(record.previousSchoolRecordStatus, 'Received');
    expect(record.guardianIdentificationStatus, 'Received');
    expect(record.financeSetupStatus, 'Prepare after student activation');
    expect(record.transportMealStatus, 'Optional service setup');
  });

  test('website registration choices are preserved', () {
    expect(registrationSections, ['Early Years', 'Primary', 'Secondary']);
    expect(
      registrationClasses,
      ['Primary 2', 'Primary 3', 'JSS 1A', 'Nursery 2'],
    );
    expect(registrationRelationships, ['Father', 'Mother', 'Guardian']);
    expect(registrationFamilyAccounts, hasLength(2));
    expect(registrationSiblingLinks, hasLength(2));
  });

  test('serialization preserves identity guardian status and source handoff', () {
    final original = administratorRegistrationWebsiteSeed.copyWith(
      sourceApplicantReference: 'BGA-ADM-26094',
    );
    final restored = StudentRegistrationRecord.fromJson(original.toJson());
    expect(restored.fullName, 'Aisha Maryam Sani');
    expect(restored.admissionNumber, 'BGA/KD/PRI/26/014');
    expect(restored.studentId, 'STU-NEW-014');
    expect(restored.primaryGuardian, 'Alhaji Sani Ibrahim');
    expect(restored.sourceApplicantReference, 'BGA-ADM-26094');
    expect(restored.status, StudentRegistrationStatus.inProgress);
  });

  test('completion changes status only and does not silently set up services', () {
    final original = administratorRegistrationWebsiteSeed;
    final completed = original.copyWith(status: StudentRegistrationStatus.active);
    expect(completed.isActive, isTrue);
    expect(completed.financeSetupStatus, original.financeSetupStatus);
    expect(completed.transportMealStatus, original.transportMealStatus);
    expect(completed.primaryGuardian, original.primaryGuardian);
    expect(completed.proposedClass, original.proposedClass);
  });

  test('QR and activation boundaries exclude sensitive payloads and silent setup', () {
    expect(registrationQrSafetyBoundary, contains('safe opaque identifier'));
    expect(registrationQrSafetyBoundary, contains('date of birth'));
    expect(registrationQrSafetyBoundary, contains('guardian phone'));
    expect(registrationQrSafetyBoundary, contains('health information'));
    expect(registrationQrSafetyBoundary, contains('fee balance'));
    expect(registrationActivationBoundary, contains('Admission in progress'));
    expect(registrationActivationBoundary, contains('Finance account setup'));
    expect(registrationActivationBoundary, contains('transport and meal'));

    final json = administratorRegistrationWebsiteSeed.toJson();
    expect(json.containsKey('qrPayload'), isFalse);
    expect(json.containsKey('feeBalance'), isFalse);
    expect(json.containsKey('healthInformation'), isFalse);
  });
}
