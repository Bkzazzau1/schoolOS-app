import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/administrator/data/administrator_staff_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_profile_repository.dart';
import 'package:schoolos_app/features/proprietor/domain/owner_staff_profile_models.dart';
import 'package:schoolos_app/features/proprietor/presentation/owner_staff_profiles_page.dart';
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

const _owner = SchoolMembership(
  id: 'owner', schoolId: 'a', schoolName: 'A', role: SchoolRole.proprietor);
const _finance = SchoolMembership(
  id: 'finance', schoolId: 'a', schoolName: 'A', role: SchoolRole.accountant);

const _principal = SchoolMembership(
  id: 'principal', schoolId: 'a', schoolName: 'A', role: SchoolRole.principal);
const _admin = SchoolMembership(
  id: 'admin', schoolId: 'a', schoolName: 'A', role: SchoolRole.administrator);
const _staffMember = SchoolMembership(
  id: 'staff-1', schoolId: 'a', schoolName: 'A', role: SchoolRole.staff);
const _otherStaff = SchoolMembership(
  id: 'staff-2', schoolId: 'a', schoolName: 'A', role: SchoolRole.staff);

Future<SchoolSessionController> _session(SchoolMembership active) async {
  FlutterSecureStorage.setMockInitialValues({});
  final session = SchoolSessionController(store: SchoolSessionStore());
  await session.setMemberships([_owner, _finance, _principal, _admin, _staffMember, _otherStaff]);
  await session.selectSchool(active);
  return session;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('highest level of study is derived from academic records', () async {
    final db = _Database();
    final session = await _session(_owner);
    addTearDown(session.dispose);
    final repo = OwnerStaffProfileRepository(database: db, session: session);
    final person = (await repo.people()).first;
    expect((await repo.view(person)).profile.highestLevel, isNull);
    await repo.addAcademic(
      person.id,
      const StaffAcademicRecord(
        level: 'Bachelor degree', institution: 'ABU', course: 'Education', year: 2015,
      ),
    );
    await repo.addAcademic(
      person.id,
      const StaffAcademicRecord(
        level: 'Master degree', institution: 'BUK', course: 'Mathematics', year: 2019,
      ),
    );
    await repo.addAcademic(
      person.id,
      const StaffAcademicRecord(
        level: 'HND', institution: 'Poly', course: 'Stats', year: 2010,
      ),
    );
    var view = await repo.view(person);
    expect(view.profile.highestLevel, 'Master degree');
    await repo.removeAcademic(person.id, 1);
    view = await repo.view(person);
    expect(view.profile.highestLevel, 'Bachelor degree');
    expect(db.mutations, hasLength(4));
  });

  test('attendance rate comes from recorded attendance', () async {
    final session = await _session(_owner);
    addTearDown(session.dispose);
    final repo = OwnerStaffProfileRepository(database: _Database(), session: session);
    final view = await repo.view((await repo.people()).first);
    final a = view.attendance!;
    expect(view.attendanceRate, closeTo(a.present / a.expected * 100, 0.001));
  });

  test('credentials, personal info and reviews are validated and stored', () async {
    final db = _Database();
    final session = await _session(_owner);
    addTearDown(session.dispose);
    final repo = OwnerStaffProfileRepository(database: db, session: session);
    final id = (await repo.people()).first.id;
    await repo.savePersonal(id, const StaffPersonalInfo(phone: '0801', email: 'a@b.com'));
    await repo.addCredential(
      id,
      const StaffCredential(title: 'TRCN', issuer: 'TRCN', expiry: '2020-01-01'),
    );
    await repo.setCredentialVerified(id, 0, true);
    await repo.addReview(id, 'Term 1', 4, 'Strong');
    await repo.addReview(id, 'Term 2', 5, '');
    final profile = (await repo.view((await repo.people()).first)).profile;
    expect(profile.personal.phone, '0801');
    expect(profile.credentials.single.verified, isTrue);
    expect(profile.credentials.single.isExpired(DateTime(2026, 9, 20)), isTrue);
    expect(profile.averageRating, 4.5);
    expect(profile.latestReview!.period, 'Term 2');
    expect(
      () => repo.savePersonal(id, const StaffPersonalInfo(email: 'bad')),
      throwsArgumentError,
    );
    expect(() => repo.addReview(id, 'T', 6, ''), throwsArgumentError);
    expect(
      () => repo.addCredential(id, const StaffCredential(title: '', issuer: 'x')),
      throwsArgumentError,
    );
    expect(
      () => repo.addCredential(
        id,
        const StaffCredential(title: 'x', issuer: 'y', expiry: 'soon'),
      ),
      throwsArgumentError,
    );
    expect(
      () => repo.addAcademic(
        id,
        const StaffAcademicRecord(level: 'HND', institution: 'x', course: 'y', year: 2999),
      ),
      throwsArgumentError,
    );
  });

  test('only the owner can read or change staff profiles', () async {
    final session = await _session(_finance);
    addTearDown(session.dispose);
    final repo = OwnerStaffProfileRepository(database: _Database(), session: session);
    expect(repo.people(), throwsStateError);
    expect(
      repo.addReview('STAFF-001', 'T', 3, ''),
      throwsStateError,
    );
  });

  testWidgets('profile page shows personal details, level, attendance and performance', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = _Database();
    final session = await _session(_owner);
    addTearDown(session.dispose);
    final repo = OwnerStaffProfileRepository(database: db, session: session);
    final person = (await repo.people()).first;
    await repo.savePersonal(person.id, const StaffPersonalInfo(phone: '08012345678'));
    await repo.addAcademic(
      person.id,
      const StaffAcademicRecord(
        level: 'Master degree', institution: 'BUK', course: 'Physics', year: 2018,
      ),
    );
    await repo.addReview(person.id, 'Term 1', 4, '');

    await tester.pumpWidget(
      MaterialApp(
        home: OwnerStaffProfileDetailPage(
          repository: repo, person: person, onChanged: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('08012345678'), findsOneWidget);
    expect(find.text('Master degree'), findsOneWidget);
    expect(find.text('Attendance rate'), findsOneWidget);
    expect(find.text('4.0 / 5'), findsOneWidget);
    expect(find.textContaining('Term 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  /// Simulates account activation, which links a staff record to a login.
  Future<void> linkStaff(_Database db, String id) async {
    final key = 'a/${OwnerStaffProfileRepository.entityType}/$id';
    final r = db.records[key]!;
    db.records[key] = LocalRecord(
      tenantId: r.tenantId,
      entityType: r.entityType,
      entityId: r.entityId,
      payload: {...r.payload, 'linkedMembershipId': 'staff-1'},
      updatedAt: r.updatedAt,
      isDirty: r.isDirty,
    );
  }

  Future<(_Database, String)> seeded() async {
    final db = _Database();
    final session = await _session(_owner);
    final repo = OwnerStaffProfileRepository(database: db, session: session);
    final id = (await repo.people()).first.id;
    await repo.savePersonal(id, const StaffPersonalInfo(phone: '0801'));
    await repo.addAcademic(
      id,
      const StaffAcademicRecord(
        level: 'HND', institution: 'Poly', course: 'Stats', year: 2010,
      ),
    );
    await repo.addCredential(id, const StaffCredential(title: 'TRCN', issuer: 'TRCN'));
    await repo.addReview(id, 'Term 1', 4, 'Strong');
    session.dispose();
    await linkStaff(db, id);
    final staff = await _session(_staffMember);
    await OwnerStaffProfileRepository(database: db, session: staff).saveOwnPayment(
      id,
      const StaffPaymentDetails(bankName: 'GTBank', accountName: 'A Yusuf', accountNumber: '0123456789'),
    );
    staff.dispose();
    return (db, id);
  }

  test('principal has the same full access and edit rights as the owner', () async {
    final (db, id) = await seeded();
    final session = await _session(_principal);
    addTearDown(session.dispose);
    final repo = OwnerStaffProfileRepository(database: db, session: session);
    final person = (await repo.people()).firstWhere((p) => p.id == id);
    final view = await repo.view(person);
    expect(view.profile.personal.phone, '0801');
    expect(view.profile.credentials, hasLength(1));
    expect(view.profile.payment.accountNumber, '0123456789');
    expect(view.profile.reviews, hasLength(1));
    expect(view.attendance, isNotNull);
    expect(view.access.canEdit, isTrue);
    await repo.savePersonal(id, const StaffPersonalInfo(phone: '0999'));
    await repo.addReview(id, 'Term 2', 3, '');
    final after = await repo.view(person);
    expect(after.profile.personal.phone, '0999');
    expect(after.profile.payment.bankName, 'GTBank');
    expect(after.profile.payment.accountNumber, '0123456789');
    expect(after.profile.reviews.last.reviewerRole, 'principal');
    expect(after.profile.reviews.first.rating, 4);
  });

  test('administrator sees the HR file but not bank details or performance', () async {
    final (db, id) = await seeded();
    final session = await _session(_admin);
    addTearDown(session.dispose);
    final repo = OwnerStaffProfileRepository(database: db, session: session);
    final view = await repo.view((await repo.people()).firstWhere((p) => p.id == id));
    expect(view.profile.personal.phone, '0801');
    expect(view.profile.credentials, hasLength(1));
    expect(view.attendance, isNotNull);
    expect(view.profile.payment.isEmpty, isTrue);
    expect(view.profile.reviews, isEmpty);
    expect(view.access.canEdit, isFalse);
    expect(view.access.canInvite, isTrue);
    expect(() => repo.savePersonal(id, const StaffPersonalInfo()), throwsStateError);
    expect(() => repo.addReview(id, 'T', 3, ''), throwsStateError);
  });

  test('only the linked staff member can change their bank details', () async {
    final (db, id) = await seeded();
    const changed = StaffPaymentDetails(bankName: 'Zenith', accountName: 'A Yusuf', accountNumber: '1111111111');
    for (final role in [_owner, _principal, _admin, _finance, _otherStaff]) {
      final session = await _session(role);
      final repo = OwnerStaffProfileRepository(database: db, session: session);
      expect(repo.saveOwnPayment(id, changed), throwsStateError, reason: role.id);
      session.dispose();
    }
    // The staff member can.
    final staff = await _session(_staffMember);
    addTearDown(staff.dispose);
    final staffRepo = OwnerStaffProfileRepository(database: db, session: staff);
    await staffRepo.saveOwnPayment(id, changed);
    final owner = await _session(_owner);
    addTearDown(owner.dispose);
    final ownerRepo = OwnerStaffProfileRepository(database: db, session: owner);
    final person = (await ownerRepo.people()).firstWhere((p) => p.id == id);
    expect((await ownerRepo.view(person)).profile.payment.accountNumber, '1111111111');
  });

  test('other edits never change bank details or the linked login', () async {
    final (db, id) = await seeded();
    final owner = await _session(_owner);
    addTearDown(owner.dispose);
    final repo = OwnerStaffProfileRepository(database: db, session: owner);
    final person = (await repo.people()).firstWhere((p) => p.id == id);
    await repo.savePersonal(id, const StaffPersonalInfo(phone: '0777'));
    await repo.addAcademic(id, const StaffAcademicRecord(level: 'HND', institution: 'x', course: 'y', year: 2011));
    await repo.requestOnboarding(id, 'a@b.com');
    await repo.markOnboardingReviewed(id);
    final view = await repo.view(person);
    expect(view.profile.payment.accountNumber, '0123456789');
    expect(view.profile.payment.bankName, 'GTBank');
    expect(
      db.records['a/${OwnerStaffProfileRepository.entityType}/$id']!.payload['linkedMembershipId'],
      'staff-1',
    );
  });

  test('staff bank details are validated', () async {
    final (db, id) = await seeded();
    final staff = await _session(_staffMember);
    addTearDown(staff.dispose);
    final repo = OwnerStaffProfileRepository(database: db, session: staff);
    for (final number in ['123', '12345678901', 'abcdefghij', '']) {
      expect(
        repo.saveOwnPayment(id, StaffPaymentDetails(bankName: 'GTBank', accountName: 'A', accountNumber: number)),
        throwsArgumentError,
        reason: number,
      );
    }
    expect(
      repo.saveOwnPayment(id, const StaffPaymentDetails(bankName: '', accountName: 'A', accountNumber: '0123456789')),
      throwsArgumentError,
    );
  });

  test('onboarding request queues required documents and never claims delivery', () async {
    final db = _Database();
    final session = await _session(_owner);
    addTearDown(session.dispose);
    final repo = OwnerStaffProfileRepository(database: db, session: session);
    final person = (await repo.people()).first;
    expect(repo.requestOnboarding(person.id, 'not-an-email'), throwsArgumentError);
    await repo.requestOnboarding(person.id, ' Staff@School.NG ');
    var profile = (await repo.view(person)).profile;
    expect(profile.onboardingStatus, StaffOnboardingStatus.invitePending);
    expect(profile.onboardingEmail, 'staff@school.ng');
    expect(profile.documents.map((d) => d.name), defaultRequiredDocuments);
    expect(profile.documents.every((d) => d.status == StaffDocumentStatus.requested), isTrue);
    expect(db.mutations, hasLength(1));

    await repo.updateDocument(person.id, 0, StaffDocumentStatus.verified, 'Folder 4');
    await repo.requestOnboarding(person.id, 'staff@school.ng');
    profile = (await repo.view(person)).profile;
    expect(profile.documents, hasLength(defaultRequiredDocuments.length));
    expect(profile.documents.first.status, StaffDocumentStatus.verified);
    expect(profile.documents.first.reference, 'Folder 4');

    await repo.markOnboardingReviewed(person.id);
    expect((await repo.view(person)).profile.onboardingStatus, StaffOnboardingStatus.reviewed);
  });

  test('administrator can send an onboarding request but finance cannot', () async {
    final db = _Database();
    final admin = await _session(_admin);
    addTearDown(admin.dispose);
    final adminRepo = OwnerStaffProfileRepository(database: db, session: admin);
    final id = (await adminRepo.people()).first.id;
    await adminRepo.requestOnboarding(id, 'a@b.com');
    expect(db.mutations, hasLength(1));
    final finance = await _session(_finance);
    addTearDown(finance.dispose);
    final financeRepo = OwnerStaffProfileRepository(database: db, session: finance);
    expect(financeRepo.requestOnboarding(id, 'a@b.com'), throwsStateError);
  });

  test('registering staff with an email queues an onboarding request', () async {
    final db = _Database();
    final session = await _session(_admin);
    addTearDown(session.dispose);
    final staffRepo = AdministratorStaffRepository(localDatabase: db, schoolSession: session);
    await staffRepo.registerSupportStaff(name: 'Musa Driver', role: 'driver', workArea: 'Bus 1', email: 'musa@school.ng');
    final profile = db.records.values
        .where((r) => r.entityType == OwnerStaffProfileRepository.entityType)
        .single;
    expect(profile.payload['onboardingStatus'], 'invitePending');
    expect(profile.payload['onboardingEmail'], 'musa@school.ng');
    expect((profile.payload['documents'] as List), hasLength(defaultRequiredDocuments.length));
    expect(
      staffRepo.registerSupportStaff(name: 'X', role: 'driver', workArea: 'Y', email: 'bad'),
      throwsArgumentError,
    );
    // No email means no onboarding request, only the staff record itself.
    final before = db.mutations.length;
    await staffRepo.registerSupportStaff(name: 'No Email', role: 'driver', workArea: 'Y');
    expect(db.mutations.length, before + 1);
  });

  testWidgets('principal page shows payment details and can send onboarding', (tester) async {
    tester.view.physicalSize = const Size(1400, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (db, id) = await seeded();
    final session = await _session(_principal);
    addTearDown(session.dispose);
    final repo = OwnerStaffProfileRepository(database: db, session: session);
    final person = (await repo.people()).firstWhere((p) => p.id == id);
    await tester.pumpWidget(MaterialApp(
      home: OwnerStaffProfileDetailPage(repository: repo, person: person, onChanged: () {}),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Payment details'), findsOneWidget);
    expect(find.text('0123456789'), findsOneWidget);
    expect(find.textContaining('Only the staff member can add or change'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Edit'), findsOneWidget); // personal info only
    expect(find.text('Personal information'), findsOneWidget);
    expect(find.text('Send onboarding request'), findsOneWidget);
    expect(find.text('Add review'), findsOneWidget);
  });

  testWidgets('administrator page hides payment details and performance', (tester) async {
    tester.view.physicalSize = const Size(1400, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (db, id) = await seeded();
    final session = await _session(_admin);
    addTearDown(session.dispose);
    final repo = OwnerStaffProfileRepository(database: db, session: session);
    final person = (await repo.people()).firstWhere((p) => p.id == id);
    await tester.pumpWidget(MaterialApp(
      home: OwnerStaffProfileDetailPage(repository: repo, person: person, onChanged: () {}),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Payment details'), findsNothing);
    expect(find.text('0123456789'), findsNothing);
    expect(find.text('Add review'), findsNothing);
    expect(find.text('Send onboarding request'), findsOneWidget);
  });
}
