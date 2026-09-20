import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/core/identity/identity_normalizer.dart';
import 'package:schoolos_app/features/administrator/data/administrator_staff_repository.dart';
import 'package:schoolos_app/features/proprietor/data/staff_identity.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_payroll_models.dart';
import 'package:schoolos_app/features/proprietor/data/job_assignment_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_payroll_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_profile_repository.dart';
import 'package:schoolos_app/features/proprietor/data/payroll_batch_repository.dart';
import 'package:schoolos_app/features/proprietor/data/staff_proposal_repository.dart';
import 'package:schoolos_app/features/proprietor/presentation/owner_staff_profiles_page.dart';
import 'package:schoolos_app/features/proprietor/domain/owner_staff_profile_models.dart';
import 'package:schoolos_app/features/proprietor/presentation/staff_proposals_ui.dart';
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

SchoolMembership _m(String id, SchoolRole role) => SchoolMembership(
  id: id, schoolId: 'a', schoolName: 'A', role: role,
);

final _owner = _m('owner', SchoolRole.proprietor);
final _principal = _m('principal', SchoolRole.principal);
final _admin = _m('admin', SchoolRole.administrator);
final _finance = _m('finance', SchoolRole.accountant);
final _teacher = _m('teacher', SchoolRole.teacher);
final _sectionHead = _m('head', SchoolRole.teacher);

Future<SchoolSessionController> _session(SchoolMembership active) async {
  FlutterSecureStorage.setMockInitialValues({});
  final session = SchoolSessionController(store: SchoolSessionStore());
  await session.setMemberships([
    _owner, _principal, _admin, _finance, _teacher, _sectionHead,
  ]);
  await session.selectSchool(active);
  return session;
}

Future<StaffProposalRepository> _repo(
  _Database db,
  SchoolMembership who,
  List<SchoolSessionController> sessions,
) async {
  final session = await _session(who);
  sessions.add(session);
  return StaffProposalRepository(database: db, session: session);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sessions = <SchoolSessionController>[];
  tearDown(() {
    for (final s in sessions) {
      s.dispose();
    }
    sessions.clear();
  });

  Future<int> directoryCount(_Database db) async {
    final session = await _session(_owner);
    sessions.add(session);
    return (await AdministratorStaffRepository(
      localDatabase: db,
      schoolSession: session,
    ).load()).staff.length;
  }

  Future<void> propose(StaffProposalRepository repo, {String email = 'musa@school.ng'}) =>
      repo.propose(
        name: 'Musa Ibrahim',
        roleTitle: 'Mathematics Teacher',
        workArea: 'Secondary',
        phone: '0803 123 4567',
        nin: '12345678901',
        gross: 200000,
        deductions: 20000,
        email: email,
      );

  test('principal, administrator and finance can only propose, never create staff', () async {
    for (final who in [_principal, _admin, _finance]) {
      final db = _Database();
      final before = await directoryCount(db);
      final repo = await _repo(db, who, sessions);
      await propose(repo, email: 'musa@school.ng');

      final proposals = await repo.load();
      expect(proposals, hasLength(1), reason: who.id);
      expect(proposals.single.status, StaffProposalStatus.pending);
      expect(proposals.single.createdStaffId, isEmpty);
      expect(proposals.single.proposedBy, who.id);

      // Not staff yet: no directory entry, no salary, no onboarding request.
      expect(await directoryCount(db), before, reason: who.id);
      expect(
        db.records.values.where((r) =>
            r.entityType == OwnerPayrollRepository.profileType ||
            r.entityType == OwnerStaffProfileRepository.entityType),
        isEmpty,
        reason: who.id,
      );
    }
  });

  test('roles with no staffing responsibility cannot propose', () async {
    final db = _Database();
    final repo = await _repo(db, _teacher, sessions);
    expect(repo.canPropose(), completion(isFalse));
    expect(propose(repo), throwsStateError);
    expect(repo.load(), throwsStateError);
  });

  test('a head of section can propose once their login is linked to the assignment', () async {
    final db = _Database();
    db.records['a/${JobAssignmentRepository.entityType}/j1'] = LocalRecord(
      tenantId: 'a',
      entityType: JobAssignmentRepository.entityType,
      entityId: 'j1',
      payload: {'role': 'sectionHead', 'status': 'pendingActivation'},
      updatedAt: DateTime.now(),
      isDirty: false,
    );
    final repo = await _repo(db, _sectionHead, sessions);
    expect(repo.canPropose(), completion(isFalse));

    db.records['a/${JobAssignmentRepository.entityType}/j1'] = LocalRecord(
      tenantId: 'a',
      entityType: JobAssignmentRepository.entityType,
      entityId: 'j1',
      payload: {'role': 'sectionHead', 'status': 'active', 'membershipId': 'head'},
      updatedAt: DateTime.now(),
      isDirty: false,
    );
    expect(repo.canPropose(), completion(isTrue));
    await propose(repo);

    // A revoked assignment ends the right to propose.
    db.records['a/${JobAssignmentRepository.entityType}/j1'] = LocalRecord(
      tenantId: 'a',
      entityType: JobAssignmentRepository.entityType,
      entityId: 'j1',
      payload: {'role': 'sectionHead', 'status': 'revoked', 'membershipId': 'head'},
      updatedAt: DateTime.now(),
      isDirty: false,
    );
    expect(repo.canPropose(), completion(isFalse));
  });

  test('only the owner can approve or reject, including the proposer', () async {
    final db = _Database();
    final principal = await _repo(db, _principal, sessions);
    await propose(principal);
    final id = (await principal.load()).single.id;
    expect(principal.approve(id), throwsStateError);
    expect(principal.reject(id, 'x'), throwsStateError);
    for (final who in [_admin, _finance]) {
      final other = await _repo(db, who, sessions);
      expect(other.approve(id), throwsStateError, reason: who.id);
    }
    expect((await principal.load()).single.status, StaffProposalStatus.pending);
  });

  test('owner approval makes the person staff, puts them on payroll and queues onboarding', () async {
    final db = _Database();
    final finance = await _repo(db, _finance, sessions);
    await propose(finance, email: 'Musa@School.ng');
    final id = (await finance.load()).single.id;
    final before = await directoryCount(db);

    final owner = await _repo(db, _owner, sessions);
    expect((await owner.load()).single.status, StaffProposalStatus.pending);
    await owner.approve(id, gross: 250000, deductions: 25000);

    final approved = (await owner.load()).single;
    expect(approved.status, StaffProposalStatus.approved);
    expect(approved.createdStaffId, startsWith('STAFF-'));
    expect(await directoryCount(db), before + 1);

    final session = await _session(_owner);
    sessions.add(session);
    final staff = (await AdministratorStaffRepository(localDatabase: db, schoolSession: session)
            .load())
        .staff
        .firstWhere((s) => s.id == approved.createdStaffId);
    expect(staff.name, 'Musa Ibrahim');
    expect(staff.role, 'Mathematics Teacher');
    expect(staff.section, 'Secondary');

    final payroll = await OwnerPayrollRepository(database: db, session: session).load();
    final profile = payroll.profiles[approved.createdStaffId]!;
    expect(profile.onPayroll, isTrue);
    expect(profile.gross, 250000);
    expect(profile.net, 225000);

    final onboarding = (await OwnerStaffProfileRepository(database: db, session: session)
            .view(staff))
        .profile;
    expect(onboarding.onboardingStatus, StaffOnboardingStatus.invitePending);
    expect(onboarding.onboardingEmail, 'musa@school.ng');
    expect(onboarding.personal.phone, '08031234567');
    expect(onboarding.personal.nin, '12345678901');

    // The proposer sees the outcome.
    expect((await finance.load()).single.status, StaffProposalStatus.approved);
  });

  test('approving twice does not create a duplicate staff member', () async {
    final db = _Database();
    final admin = await _repo(db, _admin, sessions);
    await propose(admin);
    final id = (await admin.load()).single.id;
    final owner = await _repo(db, _owner, sessions);
    final before = await directoryCount(db);
    await owner.approve(id);
    await owner.approve(id);
    expect(await directoryCount(db), before + 1);
    expect(
      db.records.values.where((r) => r.entityType == OwnerPayrollRepository.profileType),
      hasLength(1),
    );
  });

  test('a rejected proposal never becomes staff', () async {
    final db = _Database();
    final principal = await _repo(db, _principal, sessions);
    await propose(principal);
    final id = (await principal.load()).single.id;
    final before = await directoryCount(db);
    final owner = await _repo(db, _owner, sessions);
    await owner.reject(id, 'No vacancy');
    expect(await directoryCount(db), before);
    final proposal = (await principal.load()).single;
    expect(proposal.status, StaffProposalStatus.rejected);
    expect(proposal.decisionNote, 'No vacancy');
    expect(owner.approve(id), throwsStateError);
    expect(owner.reject(id, 'again'), throwsStateError);
    expect(
      db.records.values.where((r) => r.entityType == OwnerPayrollRepository.profileType),
      isEmpty,
    );
  });

  test('people only see their own proposals; the owner sees all', () async {
    final db = _Database();
    final principal = await _repo(db, _principal, sessions);
    final finance = await _repo(db, _finance, sessions);
    await propose(principal);
    await finance.propose(
      name: 'Aisha', roleTitle: 'Bursar Assistant', workArea: 'Finance office',
      phone: '08055550000', nin: '99999999999', email: 'aisha@school.ng',
      gross: 100000, deductions: 0,
    );
    expect(await principal.load(), hasLength(1));
    expect((await principal.load()).single.proposedBy, 'principal');
    expect((await finance.load()).single.name, 'Aisha');
    final owner = await _repo(db, _owner, sessions);
    expect(await owner.load(), hasLength(2));
  });

  test('when the owner adds staff it is recorded as an immediate approval', () async {
    final db = _Database();
    final owner = await _repo(db, _owner, sessions);
    final before = await directoryCount(db);
    await propose(owner);
    expect(await directoryCount(db), before + 1);
    final proposal = (await owner.load()).single;
    expect(proposal.status, StaffProposalStatus.approved);
    expect(proposal.proposedBy, 'owner');
  });

  test('proposal details are validated', () async {
    final db = _Database();
    final repo = await _repo(db, _principal, sessions);
    Future<void> go({
      String name = 'A', String role = 'R', String area = 'S',
      String phone = '08031234567', String nin = '12345678901',
      int gross = 100, int ded = 0, String email = 'a@b.com',
    }) => repo.propose(
      name: name, roleTitle: role, workArea: area, phone: phone, nin: nin,
      gross: gross, deductions: ded, email: email,
    );
    expect(go(name: ' '), throwsArgumentError);
    expect(go(role: ''), throwsArgumentError);
    expect(go(area: ''), throwsArgumentError);
    expect(go(gross: 0), throwsArgumentError);
    expect(go(gross: 100, ded: 200), throwsArgumentError);
    expect(go(ded: -1), throwsArgumentError);
    expect(go(email: 'nope'), throwsArgumentError);
    expect(go(email: ''), throwsArgumentError);
    expect(go(phone: ''), throwsArgumentError);
    expect(go(phone: '12345'), throwsArgumentError);
    expect(go(nin: '123'), throwsArgumentError);
    expect(go(nin: 'abcdefghijk'), throwsArgumentError);
    expect(await repo.load(), isEmpty);
    final owner = await _repo(db, _owner, sessions);
    await go();
    final id = (await repo.load()).single.id;
    expect(owner.approve(id, gross: 100, deductions: 500), throwsArgumentError);
    expect((await repo.load()).single.status, StaffProposalStatus.pending);
  });

  test('administrators can no longer add staff directly', () async {
    final db = _Database();
    final session = await _session(_admin);
    sessions.add(session);
    final staffRepo = AdministratorStaffRepository(localDatabase: db, schoolSession: session);
    expect(
      staffRepo.registerSupportStaff(name: 'X', role: 'driver', workArea: 'Y'),
      throwsStateError,
    );
  });

  testWidgets('owner sees the proposal and approves it from the panel', (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = _Database();
    final principal = await _repo(db, _principal, sessions);
    await propose(principal);
    final owner = await _repo(db, _owner, sessions);
    var added = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: StaffProposalsPanel(repository: owner, onChanged: () {}, onStaffAdded: () => added++),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Musa Ibrahim'), findsOneWidget);
    expect(find.textContaining('Awaiting owner approval'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Approve').last);
    await tester.pumpAndSettle();
    expect(added, 1);
    expect((await owner.load()).single.status, StaffProposalStatus.approved);
    expect(find.text('No proposals are waiting.'), findsOneWidget);
  });

  testWidgets('a proposer sees status but no approve buttons', (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = _Database();
    final finance = await _repo(db, _finance, sessions);
    await propose(finance);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: StaffProposalsPanel(repository: finance, onChanged: () {}),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Your staff proposals'), findsOneWidget);
    expect(find.text('Propose new staff'), findsOneWidget);
    expect(find.textContaining('Awaiting owner approval'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
  });

  testWidgets('proposal form warns that nothing happens until the owner approves', (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = _Database();
    final principal = await _repo(db, _principal, sessions);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showStaffProposalDialog(context, principal),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not a staff member'), findsOneWidget);
    expect(find.text('Submit for owner approval'), findsOneWidget);
    await tester.tap(find.text('Submit for owner approval'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the full name.'), findsOneWidget);
    expect(await principal.load(), isEmpty);
  });

  test('a phone number or NIN can belong to only one staff member, however it is typed', () async {
    final db = _Database();
    final owner = await _repo(db, _owner, sessions);
    await propose(owner); // phone 0803 123 4567, NIN 12345678901

    final principal = await _repo(db, _principal, sessions);
    Future<void> again({String phone = '08099990000', String nin = '55555555555'}) =>
        principal.propose(
          name: 'Other', roleTitle: 'Teacher', workArea: 'Primary',
          phone: phone, nin: nin, email: 'other@school.ng', gross: 100000, deductions: 0,
        );
    for (final phone in ['08031234567', '+234 803 123 4567', '234-803-123-4567', '(0803) 123 4567']) {
      expect(again(phone: phone), throwsA(isA<DuplicateIdentityError>()), reason: phone);
    }
    expect(again(nin: '123 4567 8901'), throwsA(isA<DuplicateIdentityError>()));
    // The message names who already has it.
    try {
      await again(phone: '08031234567');
      fail('expected a duplicate');
    } on DuplicateIdentityError catch (e) {
      expect(e.message, contains('Musa Ibrahim'));
      expect(e.message, contains('phone'));
    }
    await again(); // unique numbers are fine
  });

  test('a pending proposal reserves its phone and NIN, and a rejected one releases them', () async {
    final db = _Database();
    final principal = await _repo(db, _principal, sessions);
    final finance = await _repo(db, _finance, sessions);
    await propose(principal);
    expect(propose(finance), throwsA(isA<DuplicateIdentityError>()));
    final owner = await _repo(db, _owner, sessions);
    await owner.reject((await principal.load()).single.id, 'no');
    await propose(finance); // free again
    expect(await finance.load(), hasLength(1));
  });

  test('approval is refused if the phone or NIN was taken in the meantime', () async {
    final db = _Database();
    final principal = await _repo(db, _principal, sessions);
    await propose(principal);
    final id = (await principal.load()).single.id;
    final owner = await _repo(db, _owner, sessions);
    final before = await directoryCount(db);

    // Someone else's staff profile now uses the same phone.
    db.records['a/${OwnerStaffProfileRepository.entityType}/STAFF-001'] = LocalRecord(
      tenantId: 'a',
      entityType: OwnerStaffProfileRepository.entityType,
      entityId: 'STAFF-001',
      payload: {'staffId': 'STAFF-001', 'personal': {'phone': '08031234567'}},
      updatedAt: DateTime.now(),
      isDirty: false,
    );
    expect(owner.approve(id), throwsA(isA<DuplicateIdentityError>()));
    // Nothing was created.
    expect(await directoryCount(db), before);
    expect(
      db.records.values.where((r) => r.entityType == OwnerPayrollRepository.profileType),
      isEmpty,
    );
    expect((await principal.load()).single.status, StaffProposalStatus.pending);
  });

  test('editing personal details also enforces unique phone and NIN', () async {
    final db = _Database();
    final session = await _session(_owner);
    sessions.add(session);
    final repo = OwnerStaffProfileRepository(database: db, session: session);
    final people = await repo.people();
    final a = people[0].id;
    final b = people[1].id;
    await repo.savePersonal(a, const StaffPersonalInfo(phone: '0803 123 4567', nin: '12345678901'));
    final saved = (await repo.view(people[0])).profile.personal;
    expect(saved.phone, '08031234567'); // stored normalized
    expect(saved.nin, '12345678901');

    expect(repo.savePersonal(b, const StaffPersonalInfo(phone: '+2348031234567')), throwsA(isA<DuplicateIdentityError>()));
    expect(repo.savePersonal(b, const StaffPersonalInfo(nin: '12345678901')), throwsA(isA<DuplicateIdentityError>()));
    expect(repo.savePersonal(b, const StaffPersonalInfo(phone: '123')), throwsArgumentError);
    expect(repo.savePersonal(b, const StaffPersonalInfo(nin: '123')), throwsArgumentError);
    // The same person may re-save their own numbers.
    await repo.savePersonal(a, const StaffPersonalInfo(phone: '08031234567', nin: '12345678901', address: 'Kaduna'));
    // A different person with different numbers is fine.
    await repo.savePersonal(b, const StaffPersonalInfo(phone: '08055556666', nin: '22222222222'));
  });

  test('existing duplicates are found and reported', () async {
    final db = _Database();
    LocalRecord profile(String id, String phone, String nin) => LocalRecord(
      tenantId: 'a',
      entityType: OwnerStaffProfileRepository.entityType,
      entityId: id,
      payload: {'staffId': id, 'personal': {'phone': phone, 'nin': nin}},
      updatedAt: DateTime.now(),
      isDirty: false,
    );
    for (final r in [
      profile('STAFF-001', '08031234567', '11111111111'),
      profile('STAFF-009', '+234 803 123 4567', '22222222222'),
      profile('STAFF-014', '08077778888', '11111111111'),
      profile('STAFF-021', '08099990000', '33333333333'),
    ]) {
      db.records['a/${r.entityType}/${r.entityId}'] = r;
    }
    final groups = await findStaffDuplicateGroups(db, 'a');
    expect(groups, hasLength(2));
    final phone = groups.firstWhere((g) => g.field == 'phone');
    expect(phone.value, '08031234567');
    expect(phone.people.map((p) => p.staffId), unorderedEquals(['STAFF-001', 'STAFF-009']));
    final nin = groups.firstWhere((g) => g.field == 'NIN');
    expect(nin.people.map((p) => p.staffId), unorderedEquals(['STAFF-001', 'STAFF-014']));
  });

  test('phone and NIN normalizing', () {
    for (final v in ['08031234567', '0803 123 4567', '+234 803 123 4567', '2348031234567', '0803-123-4567']) {
      expect(normalizeNigerianPhone(v), '08031234567', reason: v);
    }
    for (final v in ['', '123', '0803123456', '080312345678', '0603 123 4567', 'abc', '+44 7911 123456']) {
      expect(normalizeNigerianPhone(v), isNull, reason: v);
    }
    expect(normalizeNin('123 4567 8901'), '12345678901');
    expect(normalizeNin('1234567890'), isNull);
    expect(normalizeNin('123456789012'), isNull);
    expect(normalizeNin('1234567890a'), isNull);
    expect(normalizeName('  Mrs.  Amina   YUSUF '), 'mrs amina yusuf');
  });

  /// The owner's assignment, linked to a login when the person's account is
  /// activated.
  void assign(_Database db, SchoolMembership who, Set<String> authorities,
      {String status = 'active', String? linkTo}) {
    db.records['a/${OwnerPayrollRepository.authorizerType}/${who.id}'] = LocalRecord(
      tenantId: 'a',
      entityType: OwnerPayrollRepository.authorizerType,
      entityId: who.id,
      payload: {
        'name': who.id,
        'authorities': authorities.toList(),
        'status': status,
        'membershipId': linkTo ?? who.id,
      },
      updatedAt: DateTime.now(),
      isDirty: false,
    );
  }

  test('someone the owner assigned can approve staff; everyone else still cannot', () async {
    final db = _Database();
    final principal = await _repo(db, _principal, sessions);
    await propose(principal);
    final id = (await principal.load()).single.id;

    final finance = await _repo(db, _finance, sessions);
    // No assignment yet, or one that is not active and linked to them.
    expect(finance.canApprove(), completion(isFalse));
    expect(finance.approve(id), throwsStateError);
    assign(db, _finance, {'approveStaff'}, status: 'pendingActivation');
    expect(finance.canApprove(), completion(isFalse));
    assign(db, _finance, {'approveStaff'}, linkTo: 'someone-else');
    expect(finance.canApprove(), completion(isFalse));
    assign(db, _finance, {'approveStaff'}, status: 'revoked');
    expect(finance.canApprove(), completion(isFalse));
    // Payroll authority alone does not let someone approve staff.
    assign(db, _finance, {'approve', 'pay'});
    expect(finance.canApprove(), completion(isFalse));
    expect(finance.approve(id), throwsStateError);

    assign(db, _finance, {'approveStaff'});
    expect(finance.canApprove(), completion(isTrue));
    final before = await directoryCount(db);
    expect((await finance.load()).single.id, id); // sees others' proposals
    await finance.approve(id);

    final approved = (await finance.load(), ).$1.single;
    expect(approved.status, StaffProposalStatus.approved);
    expect(await directoryCount(db), before + 1);
    final record = db.records['a/staff_proposal/$id']!;
    expect(record.payload['decidedByMembershipId'], 'finance');
    expect(record.payload['decidedByRole'], 'accountant');
    // Same result as an owner approval: on payroll, invitation queued.
    final staffId = approved.createdStaffId;
    expect(db.records['a/${OwnerPayrollRepository.profileType}/$staffId']!.payload['onPayroll'], isTrue);
    expect(db.records['a/${OwnerPayrollRepository.profileType}/$staffId']!.payload['gross'], 200000);
    final profile = db.records['a/${OwnerStaffProfileRepository.entityType}/$staffId']!.payload;
    expect(profile['onboardingStatus'], 'invitePending');
    expect(profile['onboardingEmail'], 'musa@school.ng');
  });

  test('an assigned approver need not be a role that can propose staff', () async {
    final db = _Database();
    final principal = await _repo(db, _principal, sessions);
    await propose(principal);
    final id = (await principal.load()).single.id;
    assign(db, _teacher, {'approveStaff'});
    final teacher = await _repo(db, _teacher, sessions);
    expect(teacher.canPropose(), completion(isFalse));
    expect((await teacher.load()).single.id, id);
    await teacher.approve(id);
    expect((await teacher.load()).single.status, StaffProposalStatus.approved);
  });

  test('an assigned approver cannot change the salary or decide their own proposal', () async {
    final db = _Database();
    assign(db, _finance, {'approveStaff'});
    assign(db, _principal, {'approveStaff'});
    final principal = await _repo(db, _principal, sessions);
    final finance = await _repo(db, _finance, sessions);
    await propose(principal);
    await finance.propose(
      name: 'Aisha', roleTitle: 'Clerk', workArea: 'Office',
      phone: '08055550000', nin: '99999999999', email: 'a@school.ng',
      gross: 100000, deductions: 0,
    );
    final all = await finance.load();
    final byPrincipal = all.firstWhere((p) => p.proposedBy == 'principal');
    final byFinance = all.firstWhere((p) => p.proposedBy == 'finance');

    // Own proposals are decided by someone else.
    expect(finance.approve(byFinance.id), throwsStateError);
    expect(finance.reject(byFinance.id, 'x'), throwsStateError);
    // Salary changes are the owner's alone.
    expect(finance.approve(byPrincipal.id, gross: 999999), throwsStateError);
    expect(finance.approve(byPrincipal.id, deductions: 1), throwsStateError);
    expect((await finance.load()).where((p) => p.status == StaffProposalStatus.pending), hasLength(2));

    await principal.approve(byFinance.id); // the other assigned approver
    await finance.approve(byPrincipal.id, gross: 200000, deductions: 20000); // unchanged amounts are fine
    expect((await finance.load()).every((p) => p.status == StaffProposalStatus.approved), isTrue);

    // The owner may still change a salary.
    final another = await _repo(db, _admin, sessions);
    await another.propose(
      name: 'Bala', roleTitle: 'Guard', workArea: 'Gate',
      phone: '08011112222', nin: '11122233344', email: 'b@school.ng',
      gross: 50000, deductions: 0,
    );
    final owner = await _repo(db, _owner, sessions);
    final bala = (await owner.load()).firstWhere((p) => p.name == 'Bala');
    await owner.approve(bala.id, gross: 60000, deductions: 5000);
    expect(
      db.records['a/${OwnerPayrollRepository.profileType}/${(await owner.load()).firstWhere((p) => p.name == 'Bala').createdStaffId}']!.payload['gross'],
      60000,
    );
  });

  test('an assigned approver can reject a proposal', () async {
    final db = _Database();
    final principal = await _repo(db, _principal, sessions);
    await propose(principal);
    assign(db, _finance, {'approveStaff'});
    final finance = await _repo(db, _finance, sessions);
    final before = await directoryCount(db);
    await finance.reject((await finance.load()).single.id, 'Budget');
    expect((await principal.load()).single.status, StaffProposalStatus.rejected);
    expect((await principal.load()).single.decisionNote, 'Budget');
    expect(await directoryCount(db), before);
  });

  test('approving or releasing payroll implies seeing it', () {
    PayrollAuthorizer a(Set<String> x) => PayrollAuthorizer(
      id: 'p', name: 'P', authorities: x, status: 'active', membershipId: 'principal',
    );
    expect(payrollAuthoritiesFor(_principal, [a({'approve'})]), {'approve', 'view'});
    expect(payrollAuthoritiesFor(_principal, [a({'pay'})]), {'pay', 'view'});
    expect(payrollAuthoritiesFor(_principal, [a({'approveStaff'})]), {'approveStaff'});
    expect(payrollAuthorityLabels.keys, containsAll(['approveStaff', 'approve', 'pay', 'prepare', 'view']));
  });

  test('people the owner assigned approve and release a payroll batch, one step each', () async {
    final db = _Database();
    final period = PayrollBatchRepository.periodFor(DateTime.now());
    final finance = PayrollBatchRepository(database: db, session: await session0(_finance, sessions));
    await finance.prepare(period, [
      FinancePayrollRowHelper.ready('A', 100000, 10000),
    ]);

    final principalBatches = PayrollBatchRepository(database: db, session: await session0(_principal, sessions));
    final adminBatches = PayrollBatchRepository(database: db, session: await session0(_admin, sessions));
    // Before they are assigned nobody but the owner can act.
    expect(principalBatches.approve(period), throwsStateError);
    expect(adminBatches.instructDisbursement(period), throwsStateError);

    assign(db, _principal, {'approve'});
    assign(db, _admin, {'pay'});
    // Paying is refused until the batch is approved.
    expect(adminBatches.instructDisbursement(period), throwsStateError);
    // The payer cannot approve, and the approver cannot pay.
    expect(adminBatches.approve(period), throwsStateError);
    await principalBatches.approve(period);
    expect(principalBatches.instructDisbursement(period), throwsStateError);
    await adminBatches.instructDisbursement(period);
    expect((await adminBatches.load(period))!.status, PayrollBatchStatus.disbursementInstructed);
  });

  testWidgets('an assigned approver sees the payment approval step on Staff Profiles; others do not', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = _Database();

    Future<void> open(SchoolMembership who) async {
      final session = await session0(who, sessions);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: OwnerStaffProfilesPage(
            key: UniqueKey(),
            repository: OwnerStaffProfileRepository(database: db, session: session),
            proposals: StaffProposalRepository(database: db, session: session),
            payrollBatches: PayrollBatchRepository(database: db, session: session),
            onChanged: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    await open(_principal);
    expect(find.textContaining('Payment approval'), findsNothing);
    assign(db, _principal, {'approve'});
    await open(_principal);
    expect(find.textContaining('Payment approval'), findsOneWidget);
    // The owner has their own payroll page, so it is not repeated here.
    await open(_owner);
    expect(find.textContaining('Payment approval'), findsNothing);
  });

  testWidgets('an assigned approver approves at the proposed salary from the panel', (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = _Database();
    final principal = await _repo(db, _principal, sessions);
    await propose(principal);
    assign(db, _finance, {'approveStaff'});
    final finance = await _repo(db, _finance, sessions);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: StaffProposalsPanel(repository: finance, onChanged: () {}),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Staff awaiting approval'), findsOneWidget);
    // Finance can also propose, so the button is there too.
    expect(find.text('Propose new staff'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Only the owner can change the salary'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Gross salary (₦)'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Approve').last);
    await tester.pumpAndSettle();
    expect((await finance.load()).single.status, StaffProposalStatus.approved);
  });

  testWidgets('a proposer who is not an approver still sees only their own proposals and no decision buttons', (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = _Database();
    final finance = await _repo(db, _finance, sessions);
    await propose(finance);
    assign(db, _principal, {'approve'}); // payroll only, not staff approval
    final principal = await _repo(db, _principal, sessions);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: StaffProposalsPanel(repository: principal, onChanged: () {}),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Your staff proposals'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.textContaining('Musa Ibrahim'), findsNothing); // not theirs
  });
}

Future<SchoolSessionController> session0(
  SchoolMembership who,
  List<SchoolSessionController> sessions,
) async {
  final s = await _session(who);
  sessions.add(s);
  return s;
}

class FinancePayrollRowHelper {
  static FinancePayrollRow ready(String id, int gross, int deductions) =>
      FinancePayrollRow(
        staffId: id, name: id, expectedDays: 22, presentDays: 22, leaveDays: 0,
        unexplainedDays: 0, gross: gross, deductions: deductions,
        net: gross - deductions, status: FinancePayrollStatus.ready,
      );
}
