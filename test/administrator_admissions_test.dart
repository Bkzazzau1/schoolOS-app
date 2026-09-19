import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/data/administrator_admissions_demo_data.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_admissions_models.dart';

void main() {
  test('website admissions seed preserves five exact sample applicants', () {
    expect(administratorAdmissionsWebsiteSeed, hasLength(5));
    expect(
      administratorAdmissionsWebsiteSeed.map((item) => item.reference),
      [
        'BGA-ADM-26094',
        'BGA-ADM-26093',
        'BGA-ADM-26091',
        'BGA-ADM-26088',
        'BGA-ADM-26082',
      ],
    );
    expect(
      administratorAdmissionsWebsiteSeed.map((item) => item.name),
      ['Aisha Sani', 'Muhammad Kabir', 'Zainab Aliyu', 'Umar Faruq', 'Fatima Musa'],
    );
  });

  test('admissions headline metrics match the website', () {
    expect(administratorAdmissionsKpis, hasLength(5));
    expect(
      administratorAdmissionsKpis.map((item) => '${item.label}:${item.value}'),
      [
        'Applications:131',
        'Awaiting documents:17',
        'Screening queue:24',
        'Offers issued:100',
        'Accepted:79',
      ],
    );
  });

  test('six controlled stage labels preserve website ordering', () {
    expect(
      AdmissionStage.values.map((stage) => stage.label),
      ['New', 'Documents', 'Screening', 'Offer', 'Accepted', 'Registered'],
    );
  });

  test('Aisha preserves the website document-review state', () {
    final aisha = administratorAdmissionsWebsiteSeed.first;
    expect(aisha.section, 'Primary');
    expect(aisha.className, 'Primary 2');
    expect(aisha.guardian, 'Alhaji Sani Ibrahim');
    expect(aisha.phone, '0803 100 2401');
    expect(aisha.stage, AdmissionStage.documents);
    expect(aisha.submitted, '13 Sep');
    expect(aisha.source, 'School website');
    expect(aisha.birthCertificate, AdmissionDocumentStatus.received);
    expect(aisha.previousSchoolReport, AdmissionDocumentStatus.pending);
    expect(aisha.guardianId, AdmissionDocumentStatus.received);
  });

  test('stage filtering follows the selected stage exactly', () {
    expect(
      administratorAdmissionsWebsiteSeed
          .where((item) => item.matchesStage(AdmissionStage.offer)),
      hasLength(1),
    );
    expect(
      administratorAdmissionsWebsiteSeed
          .where((item) => item.matchesStage(AdmissionStage.newApplication)),
      isEmpty,
    );
    expect(
      administratorAdmissionsWebsiteSeed.where((item) => item.matchesStage(null)),
      hasLength(5),
    );
  });

  test('serialization preserves applicant and document state', () {
    final original = administratorAdmissionsWebsiteSeed.first.copyWith(
      documentRequestQueued: true,
    );
    final restored = AdmissionApplicant.fromJson(original.toJson());
    expect(restored.reference, original.reference);
    expect(restored.stage, AdmissionStage.documents);
    expect(restored.previousSchoolReport, AdmissionDocumentStatus.pending);
    expect(restored.documentRequestQueued, isTrue);
    expect(restored.guardian, original.guardian);
  });

  test('pipeline updates do not silently create a student identity', () {
    final applicant = administratorAdmissionsWebsiteSeed[1];
    final screening = applicant.copyWith(stage: AdmissionStage.screening);
    final offer = screening.copyWith(stage: AdmissionStage.offer);

    expect(offer.reference, applicant.reference);
    expect(offer.guardian, applicant.guardian);
    expect(offer.phone, applicant.phone);
    expect(offer.toJson().containsKey('studentId'), isFalse);
    expect(offer.toJson().containsKey('admissionNumber'), isFalse);
    expect(offer.toJson().containsKey('financeAccount'), isFalse);
  });

  test('admissions boundary requires full registration before activation', () {
    expect(administratorAdmissionsBoundary, contains('applicant record only'));
    expect(administratorAdmissionsBoundary, contains('active student'));
    expect(administratorAdmissionsBoundary, contains('guardian linking'));
    expect(administratorAdmissionsBoundary, contains('class placement'));
    expect(administratorAdmissionsBoundary, contains('finance setup'));
  });
}
