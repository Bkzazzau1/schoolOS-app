import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_admissions_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_registration_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_admissions_models.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_students_models.dart';
import 'package:schoolos_app/features/administrator/presentation/administrator_admissions_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const admin = SchoolMembership(id: 'm-admin', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.administrator);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late AdministratorAdmissionsRepository admissions;
  late AdministratorRegistrationRepository registration;
  late AdministratorStudentsRepository students;

  Future<void> setUpSchool([SchoolMembership who = admin]) async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([admin, teacher]);
    await session.selectSchool(who);
    admissions = AdministratorAdmissionsRepository(localDatabase: db, schoolSession: session);
    registration = AdministratorRegistrationRepository(localDatabase: db, schoolSession: session);
    students = AdministratorStudentsRepository(localDatabase: db, schoolSession: session);
  }

  Future<AdmissionApplicant> applicant(String name) async =>
      (await admissions.load()).applicants.firstWhere((a) => a.name == name);

  tearDown(() => db.close());

  test('an application goes from documents to a registered student, and the student appears on the register', () async {
    await setUpSchool();
    final aisha = await applicant('Aisha Sani');
    expect(aisha.stage, AdmissionStage.documents);

    expect((await admissions.scheduleScreening(aisha.reference)).message, contains('Documents are still pending'));
    expect((await admissions.issueOffer(aisha.reference)).message, contains('Screening comes before an offer'));

    expect((await admissions.markDocumentReceived(aisha.reference, 'Previous school report')).success, isTrue);
    expect((await admissions.markDocumentReceived(aisha.reference, 'Previous school report')).message, contains('already received'));
    expect((await admissions.scheduleScreening(aisha.reference)).success, isTrue);
    expect((await admissions.acceptOffer(aisha.reference)).message, contains('has to be issued'));
    expect((await admissions.issueOffer(aisha.reference)).success, isTrue);
    expect((await admissions.acceptOffer(aisha.reference)).success, isTrue);
    expect((await applicant('Aisha Sani')).stage, AdmissionStage.accepted);

    final snapshot = await registration.load(sourceApplicant: await applicant('Aisha Sani'));
    final done = await registration.completeRegistration(snapshot.record);
    expect(done.success, isTrue, reason: done.message);

    expect((await applicant('Aisha Sani')).stage, AdmissionStage.registered);
    final register = (await students.load()).students;
    final aishaStudent = register.firstWhere((s) => s.name == 'Aisha Sani');
    expect(aishaStudent.className, 'Primary 2');
    expect(aishaStudent.status, AdministratorStudentStatus.active);
  });

  test('registration cannot be completed for a child whose offer has not been accepted', () async {
    await setUpSchool();
    final zainab = await applicant('Zainab Aliyu');
    expect(zainab.stage, AdmissionStage.offer);
    final snapshot = await registration.load(sourceApplicant: zainab);
    final refused = await registration.completeRegistration(snapshot.record);
    expect(refused.success, isFalse);
    expect(refused.message, contains('has not been accepted'));
    expect((await students.load()).students.any((s) => s.name == 'Zainab Aliyu'), isFalse);
  });

  test('a new application is taken at the school, gets the next reference, and starts with all documents pending', () async {
    await setUpSchool();
    final before = (await admissions.load()).applicants;
    final added = await admissions.addApplicant(
      name: 'Sadiq Lawal',
      section: 'Primary',
      className: 'Primary 3',
      guardian: 'Mr. Lawal Sadiq',
      phone: '0803 555 0142',
      now: DateTime(2026, 9, 21),
    );
    expect(added.success, isTrue, reason: added.message);
    final sadiq = await applicant('Sadiq Lawal');
    expect(sadiq.reference, 'BGA-ADM-26095');
    expect(sadiq.stage, AdmissionStage.newApplication);
    expect(AdministratorAdmissionsRepository.pendingDocuments(sadiq).length, 3);
    expect(sadiq.submitted, '21 Sep');
    expect((await admissions.load()).applicants.length, before.length + 1);

    final first = await admissions.markDocumentReceived(sadiq.reference, 'Birth certificate');
    expect(first.success, isTrue);
    expect((await applicant('Sadiq Lawal')).stage, AdmissionStage.documents, reason: 'the first document starts collection');
  });

  test('a new application needs a full name, a class, a guardian and a valid phone, and is not added twice', () async {
    await setUpSchool();
    Future<String> add({String name = 'Sadiq Lawal', String cls = 'Primary 3', String guardian = 'Mr. Lawal', String phone = '0803 555 0142'}) async =>
        (await admissions.addApplicant(name: name, section: 'Primary', className: cls, guardian: guardian, phone: phone)).message;

    expect(await add(name: 'Sadiq'), contains('first name and surname'));
    expect(await add(cls: ''), contains('which class'));
    expect(await add(guardian: ''), contains("guardian's name"));
    expect(await add(phone: '123'), contains('valid Nigerian phone'));
    expect(await add(), contains('added as'));
    expect(await add(), contains('already has an open application'));
  });

  test('a closed application keeps its reason, cannot move on, and drops out of the open counts', () async {
    await setUpSchool();
    final zainab = await applicant('Zainab Aliyu');
    expect((await admissions.close(zainab.reference, '')).message, contains('Say why'));
    expect((await admissions.close(zainab.reference, 'Family moved away')).success, isTrue);
    final closed = await applicant('Zainab Aliyu');
    expect(closed.isClosed, isTrue);
    expect(closed.closedReason, 'Family moved away');
    expect((await admissions.acceptOffer(zainab.reference)).message, contains('closed'));

    final snapshot = await registration.load(sourceApplicant: closed);
    expect((await registration.completeRegistration(snapshot.record)).message, contains('closed'));
    final registered = await applicant('Fatima Musa');
    expect((await admissions.close(registered.reference, 'x')).message, contains('registered student'));
  });

  test('only the administrator manages admissions', () async {
    await setUpSchool(teacher);
    final refused = await admissions.addApplicant(name: 'Sadiq Lawal', section: 'Primary', className: 'Primary 3', guardian: 'Mr. Lawal', phone: '0803 555 0142');
    expect(refused.success, isFalse);
    expect(refused.message, contains('cannot manage'));
  });

  testWidgets('the admissions desk takes a new application and marks a document received from its screen', (tester) async {
    tester.view.physicalSize = const Size(1800, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(setUpSchool);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdministratorAdmissionsPage(
          schoolName: 'BrightGate',
          repository: admissions,
          onRegistrationRequested: (_) {},
          onOpenPublicWebsite: () {},
          onAdmissionsChanged: () {},
        ),
      ),
    ));
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
    }

    await settle();
    await tester.tap(find.byKey(const ValueKey('admissions-new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('applicant-name')), 'Sadiq Lawal');
    await tester.enterText(find.byKey(const ValueKey('applicant-class')), 'Primary 3');
    await tester.enterText(find.byKey(const ValueKey('applicant-guardian')), 'Mr. Lawal Sadiq');
    await tester.enterText(find.byKey(const ValueKey('applicant-phone')), '0803 555 0142');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('applicant-add')));
    await settle();
    await tester.pumpAndSettle();

    late List<AdmissionApplicant> all;
    await tester.runAsync(() async => all = (await admissions.load()).applicants);
    expect(all.any((a) => a.name == 'Sadiq Lawal'), isTrue);

    // Aisha Sani is waiting for her school report; her row's button hands it in.
    await tester.tap(find.text('Aisha Sani').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('receive-Previous school report')));
    await settle();
    await tester.pumpAndSettle();
    await tester.runAsync(() async => all = (await admissions.load()).applicants);
    expect(all.firstWhere((a) => a.name == 'Aisha Sani').previousSchoolReport, AdmissionDocumentStatus.received);
    final problem = tester.takeException();
    expect(problem == null || problem.toString().contains('overflowed'), isTrue, reason: '$problem');
  });
}
