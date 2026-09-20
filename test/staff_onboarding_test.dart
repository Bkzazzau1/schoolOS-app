import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/proprietor/data/owner_payroll_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_profile_repository.dart';
import 'package:schoolos_app/features/proprietor/data/staff_onboarding_repository.dart';
import 'package:schoolos_app/features/proprietor/data/staff_proposal_repository.dart';
import 'package:schoolos_app/features/proprietor/domain/owner_staff_profile_models.dart';
import 'package:schoolos_app/features/proprietor/presentation/staff_onboarding_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

class _Database implements LocalDatabase {
  final records = <String, LocalRecord>{};
  final mutations = <Map<Symbol, dynamic>>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final a = invocation.namedArguments;
    final key = '${a[#tenantId]}/${a[#entityType]}/${a[#entityId]}';
    switch (invocation.memberName) {
      case #getLocalRecord:
        return Future<LocalRecord?>.value(records[key]);
      case #getLocalRecords:
        return Future<List<LocalRecord>>.value(
          records.values
              .where((r) =>
                  r.tenantId == a[#tenantId] && r.entityType == a[#entityType])
              .toList(),
        );
      case #upsertLocalRecord:
        records[key] = LocalRecord(
          tenantId: a[#tenantId],
          entityType: a[#entityType],
          entityId: a[#entityId],
          payload: Map<String, Object?>.from(a[#payload]),
          updatedAt: DateTime.now(),
          isDirty: a[#isDirty] ?? false,
        );
        return Future<void>.value();
      case #queueMutation:
        mutations.add(a);
        return Future<String>.value('mutation-${mutations.length}');
    }
    return super.noSuchMethod(invocation);
  }
}

SchoolMembership _m(String id, SchoolRole role) =>
    SchoolMembership(id: id, schoolId: 'a', schoolName: 'A', role: role);

final _owner = _m('owner', SchoolRole.proprietor);
final _principal = _m('principal', SchoolRole.principal);
final _newStaff = _m('new-staff', SchoolRole.staff);
final _otherStaff = _m('other-staff', SchoolRole.staff);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sessions = <SchoolSessionController>[];
  tearDown(() {
    for (final s in sessions) {
      s.dispose();
    }
    sessions.clear();
  });

  Future<SchoolSessionController> session(SchoolMembership who) async {
    FlutterSecureStorage.setMockInitialValues({});
    final s = SchoolSessionController(store: SchoolSessionStore());
    await s.setMemberships([_owner, _principal, _newStaff, _otherStaff]);
    await s.selectSchool(who);
    sessions.add(s);
    return s;
  }

  /// Principal proposes, owner approves. Returns the new staff id.
  Future<String> approvedStaff(_Database db) async {
    final principal = StaffProposalRepository(
      database: db,
      session: await session(_principal),
    );
    await principal.propose(
      name: 'Musa Ibrahim',
      roleTitle: 'Driver', systemRole: 'teacher',
      workArea: 'Bus 1',
      phone: '08031234567',
      nin: '12345678901',
      email: 'musa@school.ng',
      gross: 120000,
      deductions: 10000,
    );
    final owner = StaffProposalRepository(
      database: db,
      session: await session(_owner),
    );
    final id = (await owner.load()).single.id;
    await owner.approve(id);
    return (await owner.load()).single.createdStaffId;
  }

  /// Simulates account activation from the invitation, which links the staff
  /// record to the new login.
  void activate(_Database db, String staffId, String membershipId) {
    final key = 'a/${OwnerStaffProfileRepository.entityType}/$staffId';
    final r = db.records[key]!;
    db.records[key] = LocalRecord(
      tenantId: r.tenantId,
      entityType: r.entityType,
      entityId: r.entityId,
      payload: {...r.payload, 'linkedMembershipId': membershipId},
      updatedAt: r.updatedAt,
      isDirty: r.isDirty,
    );
  }

  const personal = StaffPersonalInfo(
    phone: '0803 987 6543',
    nin: '98765432109',
    email: 'musa@school.ng',
    address: '5 Ahmadu Bello Way, Kaduna',
    dateOfBirth: '1990-05-14',
    gender: 'Male',
    stateOfOrigin: 'Kaduna',
    nextOfKinName: 'Hauwa Ibrahim',
    nextOfKinPhone: '08055556666',
  );
  const payment = StaffPaymentDetails(
    bankName: 'GTBank',
    accountName: 'Musa Ibrahim',
    accountNumber: '0123456789',
  );

  test('approval queues the registration invitation for the staff email', () async {
    final db = _Database();
    final staffId = await approvedStaff(db);
    final record = db.records['a/${OwnerStaffProfileRepository.entityType}/$staffId']!;
    expect(record.payload['onboardingStatus'], 'invitePending');
    expect(record.payload['onboardingEmail'], 'musa@school.ng');
    expect((record.payload['documents'] as List).length, defaultRequiredDocuments.length);
    // Queued for the backend to email; the app never claims it was sent.
    expect(
      db.mutations.any((m) =>
          m[#entityType] == OwnerStaffProfileRepository.entityType &&
          (m[#payload] as Map)['onboardingStatus'] == 'invitePending'),
      isTrue,
    );
  });

  test('the staff member fills in their registration and it goes for review', () async {
    final db = _Database();
    final staffId = await approvedStaff(db);
    activate(db, staffId, 'new-staff');

    final repo = StaffOnboardingRepository(database: db, session: await session(_newStaff));
    expect((await repo.openRequest())!.onboardingEmail, 'musa@school.ng');
    final before = db.mutations.length;
    await repo.submit(
      personal: personal,
      payment: payment,
      documents: {
        'Passport photograph': 'passport.jpg emailed to admin',
        'Curriculum vitae': 'Handed to school office',
      },
    );
    expect(db.mutations.length, before + 1);
    expect(await repo.openRequest(), isNull);

    // The owner and the principal can see everything the staff member entered.
    for (final who in [_owner, _principal]) {
      final profiles = OwnerStaffProfileRepository(database: db, session: await session(who));
      final person = (await profiles.people()).firstWhere((p) => p.id == staffId);
      final view = await profiles.view(person);
      final p = view.profile;
      expect(p.onboardingStatus, StaffOnboardingStatus.submitted, reason: who.id);
      expect(p.personal.phone, '08039876543');
      expect(p.personal.nin, '98765432109');
      expect(p.personal.address, contains('Kaduna'));
      expect(p.personal.nextOfKinPhone, '08055556666');
      expect(p.payment.accountNumber, '0123456789');
      final byName = {for (final d in p.documents) d.name: d};
      expect(byName['Passport photograph']!.status, StaffDocumentStatus.received);
      expect(byName['Passport photograph']!.reference, 'passport.jpg emailed to admin');
      expect(byName['Curriculum vitae']!.status, StaffDocumentStatus.received);
      // Documents not provided stay requested.
      expect(byName['Guarantor form']!.status, StaffDocumentStatus.requested);
    }

    // The owner or principal then marks it reviewed.
    final principalProfiles = OwnerStaffProfileRepository(database: db, session: await session(_principal));
    await principalProfiles.markOnboardingReviewed(staffId);
    final person = (await principalProfiles.people()).firstWhere((p) => p.id == staffId);
    expect((await principalProfiles.view(person)).profile.onboardingStatus, StaffOnboardingStatus.reviewed);
  });

  test('submitting cannot change salary, reviews, credentials or the link', () async {
    final db = _Database();
    final staffId = await approvedStaff(db);
    final profiles = OwnerStaffProfileRepository(database: db, session: await session(_owner));
    await profiles.addReview(staffId, 'Term 1', 4, 'Good');
    await profiles.addCredential(staffId, const StaffCredential(title: 'Licence', issuer: 'FRSC'));
    activate(db, staffId, 'new-staff');
    final salaryBefore = (await OwnerPayrollRepository(database: db, session: await session(_owner)).load())
        .profiles[staffId]!;

    await StaffOnboardingRepository(database: db, session: await session(_newStaff))
        .submit(personal: personal, payment: payment);

    final person = (await profiles.people()).firstWhere((p) => p.id == staffId);
    final p = (await profiles.view(person)).profile;
    expect(p.reviews.single.rating, 4);
    expect(p.credentials.single.title, 'Licence');
    final salaryAfter = (await OwnerPayrollRepository(database: db, session: await session(_owner)).load())
        .profiles[staffId]!;
    expect(salaryAfter.gross, salaryBefore.gross);
    expect(salaryAfter.onPayroll, isTrue);
    expect(
      db.records['a/${OwnerStaffProfileRepository.entityType}/$staffId']!.payload['linkedMembershipId'],
      'new-staff',
    );
  });

  test('only the linked staff member can submit, and only once', () async {
    final db = _Database();
    final staffId = await approvedStaff(db);
    // Before activation nobody is linked, so nobody can submit.
    for (final who in [_newStaff, _otherStaff, _owner, _principal]) {
      final repo = StaffOnboardingRepository(database: db, session: await session(who));
      expect(await repo.openRequest(), isNull, reason: who.id);
      expect(repo.submit(personal: personal, payment: payment), throwsStateError, reason: who.id);
    }
    activate(db, staffId, 'new-staff');
    for (final who in [_otherStaff, _owner, _principal]) {
      final repo = StaffOnboardingRepository(database: db, session: await session(who));
      expect(repo.submit(personal: personal, payment: payment), throwsStateError, reason: who.id);
    }
    final repo = StaffOnboardingRepository(database: db, session: await session(_newStaff));
    await repo.submit(personal: personal, payment: payment);
    // The request is closed once submitted.
    expect(repo.submit(personal: personal, payment: payment), throwsStateError);
  });

  test('registration details are validated and nothing is saved when they are wrong', () async {
    final db = _Database();
    final staffId = await approvedStaff(db);
    activate(db, staffId, 'new-staff');
    final repo = StaffOnboardingRepository(database: db, session: await session(_newStaff));
    final mutations = db.mutations.length;

    Future<void> go({StaffPersonalInfo? p, StaffPaymentDetails? pay}) =>
        repo.submit(personal: p ?? personal, payment: pay ?? payment);
    StaffPersonalInfo with_({String? phone, String? nin, String? address, String? dob, String? kin, String? kinPhone}) =>
        StaffPersonalInfo(
          phone: phone ?? personal.phone,
          nin: nin ?? personal.nin,
          email: personal.email,
          address: address ?? personal.address,
          dateOfBirth: dob ?? personal.dateOfBirth,
          nextOfKinName: kin ?? personal.nextOfKinName,
          nextOfKinPhone: kinPhone ?? personal.nextOfKinPhone,
        );
    expect(go(p: with_(phone: '12345')), throwsArgumentError);
    expect(go(p: with_(nin: '123')), throwsArgumentError);
    expect(go(p: with_(address: ' ')), throwsArgumentError);
    expect(go(p: with_(dob: 'not a date')), throwsArgumentError);
    expect(go(p: with_(kin: '')), throwsArgumentError);
    expect(go(p: with_(kinPhone: '12')), throwsArgumentError);
    for (final number in ['123', '12345678901', 'abcdefghij', '']) {
      expect(
        go(pay: StaffPaymentDetails(bankName: 'GTBank', accountName: 'A', accountNumber: number)),
        throwsArgumentError,
        reason: number,
      );
    }
    expect(go(pay: const StaffPaymentDetails(bankName: '', accountName: 'A', accountNumber: '0123456789')), throwsArgumentError);
    expect(db.mutations.length, mutations);
    expect(await repo.openRequest(), isNotNull);
  });

  test('a phone number or NIN already used by another staff member is refused', () async {
    final db = _Database();
    final staffId = await approvedStaff(db);
    activate(db, staffId, 'new-staff');
    db.records['a/${OwnerStaffProfileRepository.entityType}/STAFF-001'] = LocalRecord(
      tenantId: 'a',
      entityType: OwnerStaffProfileRepository.entityType,
      entityId: 'STAFF-001',
      payload: {'staffId': 'STAFF-001', 'personal': {'phone': '08039876543', 'nin': '55555555555'}},
      updatedAt: DateTime.now(),
      isDirty: false,
    );
    final repo = StaffOnboardingRepository(database: db, session: await session(_newStaff));
    expect(repo.submit(personal: personal, payment: payment), throwsA(isA<DuplicateIdentityError>()));
    // Their own numbers from approval are fine to resubmit.
    await repo.submit(
      personal: StaffPersonalInfo(
        phone: '08031234567', nin: '12345678901', email: 'musa@school.ng',
        address: 'Kaduna', dateOfBirth: '1990-01-01',
        nextOfKinName: 'Hauwa', nextOfKinPhone: '08055556666',
      ),
      payment: payment,
    );
  });

  testWidgets('a new staff member sees the registration banner and completes the form', (tester) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = _Database();
    final staffId = await approvedStaff(db);
    activate(db, staffId, 'new-staff');
    final repo = StaffOnboardingRepository(database: db, session: await session(_newStaff));
    var submitted = 0;
    await tester.pumpWidget(MaterialApp(
      home: StaffOnboardingBanner(
        repository: repo,
        onSubmitted: () => submitted++,
        child: const Scaffold(body: Center(child: Text('dashboard'))),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('dashboard'), findsOneWidget);
    expect(find.text('Complete registration'), findsOneWidget);

    await tester.tap(find.text('Complete registration'));
    await tester.pumpAndSettle();
    expect(find.text('Complete your registration'), findsOneWidget);
    // Required fields are checked before anything is sent.
    await tester.tap(find.text('Submit registration'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsWidgets);
    expect(submitted, 0);

    Future<void> fill(String label, String value) async {
      await tester.enterText(find.widgetWithText(TextFormField, label), value);
    }

    await fill('Phone number', '0803 987 6543');
    await fill('NIN (11 digits)', '98765432109');
    await fill('Home address', '5 Ahmadu Bello Way');
    await fill('Date of birth (yyyy-mm-dd)', '1990-05-14');
    await fill('Next of kin name', 'Hauwa Ibrahim');
    await fill('Next of kin phone', '08055556666');
    await fill('Bank', 'GTBank');
    await fill('Account name', 'Musa Ibrahim');
    await fill('Account number (10 digits)', '0123456789');
    await tester.ensureVisible(find.text('Submit registration'));
    await tester.tap(find.text('Submit registration'));
    await tester.pumpAndSettle();

    expect(submitted, 1);
    expect(find.text('Complete registration'), findsNothing);
    expect(await repo.openRequest(), isNull);
  });

  testWidgets('people with no open request see no banner', (tester) async {
    final db = _Database();
    final staffId = await approvedStaff(db);
    activate(db, staffId, 'new-staff');
    for (final who in [_otherStaff, _owner]) {
      final repo = StaffOnboardingRepository(database: db, session: await session(who));
      await tester.pumpWidget(MaterialApp(
        home: StaffOnboardingBanner(
          repository: repo,
          child: const Scaffold(body: Text('dashboard')),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('dashboard'), findsOneWidget, reason: who.id);
      expect(find.text('Complete registration'), findsNothing, reason: who.id);
    }
  });
}
