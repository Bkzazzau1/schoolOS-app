import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/data/administrator_admissions_policy_copy.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_admissions_models.dart';

const _fixtureApplicants = <AdmissionApplicant>[
  AdmissionApplicant(
    reference: 'BGA-ADM-26094',
    name: 'Aisha Sani',
    section: 'Primary',
    className: 'Primary 2',
    guardian: 'Alhaji Sani Ibrahim',
    phone: '0803 100 2401',
    stage: AdmissionStage.documents,
    submitted: '13 Sep',
    previousSchoolReport: AdmissionDocumentStatus.pending,
  ),
  AdmissionApplicant(
    reference: 'BGA-ADM-26093',
    name: 'Muhammad Kabir',
    section: 'Secondary',
    className: 'JSS 1',
    guardian: 'Hajiya Amina Kabir',
    phone: '0806 221 1480',
    stage: AdmissionStage.screening,
    submitted: '13 Sep',
  ),
  AdmissionApplicant(
    reference: 'BGA-ADM-26091',
    name: 'Zainab Aliyu',
    section: 'Nursery',
    className: 'Nursery 2',
    guardian: 'Alhaji Aliyu Sani',
    phone: '0812 334 0192',
    stage: AdmissionStage.offer,
    submitted: '12 Sep',
  ),
  AdmissionApplicant(
    reference: 'BGA-ADM-26088',
    name: 'Umar Faruq',
    section: 'Primary',
    className: 'Primary 4',
    guardian: 'Hajiya Maryam Umar',
    phone: '0703 518 9941',
    stage: AdmissionStage.accepted,
    submitted: '11 Sep',
  ),
  AdmissionApplicant(
    reference: 'BGA-ADM-26082',
    name: 'Fatima Musa',
    section: 'Secondary',
    className: 'JSS 2',
    guardian: 'Alhaji Musa Bello',
    phone: '0805 292 4118',
    stage: AdmissionStage.registered,
    submitted: '09 Sep',
  ),
];

void main() {
  test('applicant fixture carries five distinct sample applicants', () {
    expect(_fixtureApplicants, hasLength(5));
    expect(
      _fixtureApplicants.map((item) => item.reference),
      [
        'BGA-ADM-26094',
        'BGA-ADM-26093',
        'BGA-ADM-26091',
        'BGA-ADM-26088',
        'BGA-ADM-26082',
      ],
    );
    expect(
      _fixtureApplicants.map((item) => item.name),
      ['Aisha Sani', 'Muhammad Kabir', 'Zainab Aliyu', 'Umar Faruq', 'Fatima Musa'],
    );
  });

  test('six controlled stage labels preserve website ordering', () {
    expect(
      AdmissionStage.values.map((stage) => stage.label),
      ['New', 'Documents', 'Screening', 'Offer', 'Accepted', 'Registered'],
    );
  });

  test('Aisha preserves the website document-review state', () {
    final aisha = _fixtureApplicants.first;
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
      _fixtureApplicants
          .where((item) => item.matchesStage(AdmissionStage.offer)),
      hasLength(1),
    );
    expect(
      _fixtureApplicants
          .where((item) => item.matchesStage(AdmissionStage.newApplication)),
      isEmpty,
    );
    expect(
      _fixtureApplicants.where((item) => item.matchesStage(null)),
      hasLength(5),
    );
  });

  test('serialization preserves applicant and document state', () {
    final original = _fixtureApplicants.first.copyWith(
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
    final applicant = _fixtureApplicants[1];
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
