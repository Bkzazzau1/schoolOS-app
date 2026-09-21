import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/network/api_exceptions.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/proprietor/data/staff_onboarding_repository.dart';
import 'package:schoolos_app/features/proprietor/data/staff_proposal_repository.dart';
import 'package:schoolos_app/features/proprietor/domain/owner_staff_profile_models.dart';
import 'package:schoolos_app/features/proprietor/data/staff_server_api.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const owner = SchoolMembership(
  id: '55555555-5555-5555-5555-555555555555',
  schoolId: '22222222-2222-2222-2222-222222222222',
  schoolName: 'BrightGate',
  role: SchoolRole.proprietor,
);

const principal = SchoolMembership(
  id: '88888888-8888-8888-8888-888888888888',
  schoolId: '22222222-2222-2222-2222-222222222222',
  schoolName: 'BrightGate',
  role: SchoolRole.principal,
);

Map<String, Object?> proposalPayload({String status = 'pending', String proposedBy = 'someone'}) => {
      'name': 'Musa Ibrahim',
      'roleTitle': 'Mathematics Teacher',
      'systemRole': 'teacher',
      'workArea': 'Secondary',
      'email': 'musa@school.ng',
      'phone': '08031234567',
      'nin': '12345678901',
      'gross': 200000,
      'deductions': 20000,
      'status': status,
      'proposedByMembershipId': proposedBy,
      'proposedByRole': 'principal',
    };

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late FakeServer server;
  late StaffServerApi api;
  var synced = 0;

  setUp(() async {
    synced = 0;
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([owner, principal]);
    await session.selectSchool(owner);
  });

  tearDown(() => db.close());

  Future<void> givenProposal(String id, {String status = 'pending'}) => db.upsertLocalRecord(
        tenantId: owner.schoolId, entityType: 'staff_proposal', entityId: id,
        payload: proposalPayload(status: status), serverVersion: 3,
      );

  StaffProposalRepository repo(Future<dynamic> Function(dynamic request) handler) {
    server = FakeServer((r) async => await handler(r));
    api = StaffServerApi(api: apiFor(server), afterChange: () async => synced++);
    return StaffProposalRepository(database: db, session: session, remote: api);
  }

  Future<LocalRecord> stored(String id) async =>
      (await db.getLocalRecord(tenantId: owner.schoolId, entityType: 'staff_proposal', entityId: id))!;

  group('approving with a server', () {
    test('asks the server, sends the owner\'s changes, and shows the decision without queueing anything', () async {
      await givenProposal('P1');
      final proposals = repo((r) async => jsonResponse({'staffId': 'STAFF-9', 'alreadyApproved': false}));
      await proposals.approve('P1', gross: 250000, deductions: 25000, systemRole: 'accountant');

      final request = server.requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, endsWith('/staff/schools/${owner.schoolId}/proposals/P1/approve/'));
      expect(request.url.queryParameters, {'membership': owner.id});
      expect(body(request), {'gross': 250000, 'deductions': 25000, 'systemRole': 'accountant'});
      expect(synced, 1);                                                            // it asked for a download

      final record = await stored('P1');
      expect((record.payload['status'], record.payload['createdStaffId']), ('approved', 'STAFF-9'));
      expect((record.isDirty, record.serverVersion), (false, 3));                   // not an edit to send
      expect(await db.pendingMutations(tenantId: owner.schoolId), isEmpty);
      // The device did not invent the staff records; the server owns them.
      expect(await db.getLocalRecords(tenantId: owner.schoolId, entityType: 'owner_staff_profile'), isEmpty);
      expect(await db.getLocalRecords(tenantId: owner.schoolId, entityType: 'owner_payroll_profile'), isEmpty);
    });

    test('with nothing changed it sends an empty body, so the server uses what was proposed', () async {
      await givenProposal('P1');
      await repo((r) async => jsonResponse({'staffId': 'STAFF-9'})).approve('P1');
      expect(body(server.requests.single), isEmpty);
    });

    test('the server\'s refusal is shown in its words and nothing changes here', () async {
      await givenProposal('P1');
      final proposals = repo((r) async => jsonResponse({
            'code': 'rejected',
            'message': 'That phone number already belongs to Aisha Bello.',
          }, 400));
      await expectLater(
        proposals.approve('P1'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'That phone number already belongs to Aisha Bello.')),
      );
      expect((await stored('P1')).payload['status'], 'pending');
      expect(synced, 0);
    });

    test('someone who may not approve is refused by the server, not by a guess on the device', () async {
      await session.selectSchool(principal);
      await givenProposal('P1');
      final proposals = repo((r) async => jsonResponse({'detail': 'You do not have access to this school.'}, 403));
      await expectLater(proposals.approve('P1'), throwsA(isA<ApiException>().having((e) => e.isForbidden, 'forbidden', true)));
      expect(server.requests.single.url.queryParameters['membership'], principal.id);
    });

    test('offline it fails cleanly and can be tried again', () async {
      await givenProposal('P1');
      final proposals = repo((r) async => throw const ApiOfflineException());
      await expectLater(proposals.approve('P1'), throwsA(isA<ApiOfflineException>()));
      expect((await stored('P1')).payload['status'], 'pending');
    });

    test('an approved proposal is not sent again, and a rejected one cannot be approved', () async {
      await givenProposal('P1', status: 'approved');
      await givenProposal('P2', status: 'rejected');
      final proposals = repo((r) async => jsonResponse({'staffId': 'X'}));
      await proposals.approve('P1');
      await expectLater(proposals.approve('P2'), throwsStateError);
      expect(server.requests, isEmpty);
    });

    test('a proposal this device does not have, or a made-up role, is refused before asking', () async {
      final proposals = repo((r) async => jsonResponse({'staffId': 'X'}));
      await expectLater(proposals.approve('NOPE'), throwsStateError);
      await givenProposal('P1');
      await expectLater(proposals.approve('P1', systemRole: 'astronaut'), throwsArgumentError);
      expect(server.requests, isEmpty);
    });
  });

  group('rejecting with a server', () {
    test('sends the reason and shows the decision', () async {
      await givenProposal('P1');
      await repo((r) async => jsonResponse({'ok': true})).reject('P1', '  Not needed this term  ');
      final request = server.requests.single;
      expect(request.url.path, endsWith('/proposals/P1/reject/'));
      expect(body(request), {'note': 'Not needed this term'});
      final record = await stored('P1');
      expect((record.payload['status'], record.payload['decisionNote'], record.isDirty), ('rejected', 'Not needed this term', false));
      expect(synced, 1);
    });

    test('only a pending proposal can be rejected', () async {
      await givenProposal('P1', status: 'approved');
      await expectLater(repo((r) async => jsonResponse({'ok': true})).reject('P1', ''), throwsStateError);
      expect(server.requests, isEmpty);
    });
  });

  group('proposing with a server', () {
    test('still goes through the queue, so it works offline; the server checks it on arrival', () async {
      final proposals = repo((r) async => jsonResponse({}));
      await proposals.propose(
        name: 'Aisha Bello', roleTitle: 'Teacher', systemRole: 'teacher', workArea: 'Primary',
        phone: '08039990001', nin: '99999999991', gross: 150000, deductions: 10000, email: 'aisha@school.ng',
      );
      final queued = await db.pendingMutations(tenantId: owner.schoolId);
      expect(queued.map((m) => (m.entityType, m.operation.name)), [('staff_proposal', 'create')]);
      expect(server.requests, isEmpty);
    });
  });

  group('the owner adding staff directly, with a server', () {
    Future<void> add(StaffProposalRepository proposals) => proposals.propose(
          name: 'Aisha Bello', roleTitle: 'Teacher', systemRole: 'teacher', workArea: 'Primary',
          phone: '08039990001', nin: '99999999991', gross: 150000, deductions: 10000, email: 'aisha@school.ng',
        );

    /// What a sync round does with the queue, as far as this test needs.
    void serverTakesIt() {
      for (final item in db.syncQueueItems(tenantId: owner.schoolId)) {
        db.markMutationSyncing(item.id);
        db.markMutationSynced(item.id, serverVersion: 1);
      }
    }

    StaffProposalRepository ownerRepo({required void Function() whenSyncing}) {
      server = FakeServer((r) async => jsonResponse({'staffId': 'STAFF-7'}));
      api = StaffServerApi(api: apiFor(server), afterChange: () async => whenSyncing());
      return StaffProposalRepository(database: db, session: session, remote: api);
    }

    test('the proposal is sent first, and only then approved', () async {
      await add(ownerRepo(whenSyncing: serverTakesIt));
      expect(server.requests.single.url.path, endsWith('/approve/'));
      expect(await db.pendingMutations(tenantId: owner.schoolId), isEmpty);
    });

    test('if the server refuses the proposal, the owner is told why and nothing is left stuck', () async {
      final proposals = ownerRepo(whenSyncing: () {
        for (final item in db.syncQueueItems(tenantId: owner.schoolId)) {
          db.markMutationSyncing(item.id);
          db.markMutationFailed(item.id, 'That phone number already belongs to Musa Ibrahim.');
        }
      });
      await expectLater(
        add(proposals),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('already belongs to Musa Ibrahim'))),
      );
      expect(server.requests, isEmpty);                                    // never asked to approve
      expect(db.syncQueueItems(tenantId: owner.schoolId), isEmpty);         // the failed copy was dropped
      expect(await db.getLocalRecords(tenantId: owner.schoolId, entityType: 'staff_proposal'), isEmpty);
    });

    test('offline it stays queued, and is approved later from the list', () async {
      await add(ownerRepo(whenSyncing: () {}));
      expect(server.requests, isEmpty);
      expect((await db.pendingMutations(tenantId: owner.schoolId)).length, 1);
    });
  });

  group('invitations', () {
    StaffServerApi apiWith(Future<dynamic> Function(dynamic) handler) {
      server = FakeServer((r) async => await handler(r));
      return api = StaffServerApi(api: apiFor(server), afterChange: () async => synced++);
    }

    Map<String, Object?> pending({String? sentAt = '2026-09-20T09:00:00Z', String event = 'sent'}) => {
          'status': 'pending', 'linked': false, 'email': 'musa@school.ng', 'sentAt': sentAt,
          'expiresAt': '2026-10-04T09:00:00Z', 'acceptedAt': null,
          'lastEvent': {'event': event, 'at': '2026-09-20T09:00:01Z', 'detail': {}},
        };

    test('reads where an invitation stands', () async {
      final status = await apiWith((r) async => jsonResponse(pending())).invitation(owner, 'STAFF-1');
      expect(server.requests.single.url.path, endsWith('/owner/schools/${owner.schoolId}/staff/STAFF-1/invitation/'));
      expect((status.status, status.email, status.isPending, status.neverSent, status.deliveryFailed, status.linked), ('pending', 'musa@school.ng', true, false, false, false));
      expect(status.expiresAt, DateTime.utc(2026, 10, 4, 9));
    });

    test('an invitation that never left, or failed to be delivered, says so', () async {
      final status = await apiWith((r) async => jsonResponse(pending(sentAt: null, event: 'failed'))).invitation(owner, 'STAFF-1');
      expect((status.neverSent, status.deliveryFailed), (true, true));
      final none = await apiWith((r) async => jsonResponse({'status': 'none', 'linked': true})).invitation(owner, 'STAFF-1');
      expect((none.status, none.linked, none.email), ('none', true, null));
    });

    test('sending again can correct the email, and asks for a download', () async {
      final result = await apiWith((r) async => jsonResponse(pending())).resendInvitation(owner, 'STAFF-1', email: '  musa.fixed@school.ng ');
      expect(server.requests.single.method, 'POST');
      expect(body(server.requests.single), {'email': 'musa.fixed@school.ng'});
      expect(result.isPending, isTrue);
      expect(synced, 1);
      await apiWith((r) async => jsonResponse(pending())).resendInvitation(owner, 'STAFF-1');
      expect(body(server.requests.single), isEmpty);                     // no email: the server uses the one on file
    });

    test('cancelling and unlinking use the owner endpoints; a refusal is in words', () async {
      final calls = apiWith((r) async => r.method == 'DELETE' ? http204() : jsonResponse({'ok': true}));
      await calls.cancelInvitation(owner, 'STAFF-1');
      await calls.unlink(owner, 'STAFF-1');
      expect(server.requests.map((r) => '${r.method} ${r.url.path.split('/staff/').last}'), ['DELETE STAFF-1/invitation/', 'POST STAFF-1/unlink/']);
      expect(synced, 1);                                                  // unlinking changes records the device holds

      final refused = apiWith((r) async => jsonResponse({'code': 'already_linked', 'message': 'This staff member already has a login.'}, 409));
      await expectLater(refused.resendInvitation(owner, 'STAFF-1'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'already_linked')));
    });
  });

  group('registering with a server', () {
    const me = principal;

    Future<StaffOnboardingRepository> asStaff(Future<dynamic> Function(dynamic) handler) async {
      await session.selectSchool(me);
      final profile = StaffProfile(
        staffId: 'STAFF-1',
        onboardingStatus: StaffOnboardingStatus.invitePending,
        onboardingEmail: 'musa@school.ng',
        linkedMembershipId: me.id,
        documents: [const StaffRequiredDocument(name: 'Passport photograph')],
      );
      await db.upsertLocalRecord(
        tenantId: me.schoolId, entityType: 'owner_staff_profile', entityId: 'STAFF-1',
        payload: profile.toJson(), serverVersion: 2,
      );
      server = FakeServer((r) async => await handler(r));
      api = StaffServerApi(api: apiFor(server), afterChange: () async => synced++);
      return StaffOnboardingRepository(database: db, session: session, remote: api);
    }

    Future<void> submit(StaffOnboardingRepository repo) => repo.submit(
          personal: const StaffPersonalInfo(
            phone: '0803 123 4567', nin: '12345678901', address: '12 Market Road', dateOfBirth: '1990-05-14',
            nextOfKinName: 'Aisha Ibrahim', nextOfKinPhone: '08031112222',
          ),
          payment: const StaffPaymentDetails(bankName: 'Access Bank', accountName: 'Musa Ibrahim', accountNumber: '0123456789'),
          documents: const {'Passport photograph': 'Handed to the office', 'Other': '  '},
        );

    Future<LocalRecord> profile() async =>
        (await db.getLocalRecord(tenantId: me.schoolId, entityType: 'owner_staff_profile', entityId: 'STAFF-1'))!;

    test('goes straight to the server with tidied values, and is not queued', () async {
      final repo = await asStaff((r) async => jsonResponse({'staffId': 'STAFF-1', 'status': 'submitted'}));
      await submit(repo);
      final request = server.requests.single;
      expect(request.url.path, endsWith('/staff/me/onboarding/'));
      final sent = body(request);
      expect((sent['personal'] as Map)['phone'], '08031234567');                 // normalised
      expect((sent['personal'] as Map)['nextOfKinPhone'], '08031112222');
      expect((sent['payment'] as Map)['accountNumber'], '0123456789');
      expect(sent['documents'], {'Passport photograph': 'Handed to the office'});   // blanks left out
      expect(await db.pendingMutations(tenantId: me.schoolId), isEmpty);

      final saved = await profile();
      expect(saved.payload['onboardingStatus'], 'submitted');
      expect((saved.isDirty, saved.serverVersion), (false, 2));
      expect(synced, 1);
    });

    test("the server's refusal reaches the person at once and nothing is saved as submitted", () async {
      final repo = await asStaff((r) async => jsonResponse({
            'code': 'duplicate_identity',
            'message': 'That phone number already belongs to Aisha Bello. If this is you, contact the school office.',
          }, 409));
      await expectLater(submit(repo), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'duplicate_identity')));
      expect((await profile()).payload['onboardingStatus'], 'invitePending');
      expect(await db.pendingMutations(tenantId: me.schoolId), isEmpty);
    });

    test('offline it fails cleanly so they can try again', () async {
      final repo = await asStaff((r) async => throw const ApiOfflineException());
      await expectLater(submit(repo), throwsA(isA<ApiOfflineException>()));
      expect((await profile()).payload['onboardingStatus'], 'invitePending');
    });

    test('bad details are caught on the device before anything is sent', () async {
      final repo = await asStaff((r) async => jsonResponse({}));
      await expectLater(
        repo.submit(
          personal: const StaffPersonalInfo(phone: '123', nin: '12345678901'),
          payment: const StaffPaymentDetails(),
        ),
        throwsArgumentError,
      );
      expect(server.requests, isEmpty);
    });
  });

  group('the staff member\'s own registration', () {
    test('reads what is asked of them, and none open is not an error', () async {
      final open = await StaffServerApi(api: apiFor(FakeServer((r) async => jsonResponse({
            'staffId': 'STAFF-1', 'schoolName': 'BrightGate', 'status': 'invitePending', 'email': 'musa@school.ng',
            'personal': {'phone': ''}, 'documents': [{'name': 'Passport photograph', 'status': 'requested'}],
          })))).myOnboarding(principal);
      expect((open!.staffId, open.status, open.documents.single.name), ('STAFF-1', 'invitePending', 'Passport photograph'));

      final none = await StaffServerApi(api: apiFor(FakeServer((r) async =>
              jsonResponse({'code': 'no_open_request', 'message': 'There is no open registration request for you.'}, 404))))
          .myOnboarding(principal);
      expect(none, isNull);
    });

    test('other problems still surface', () async {
      final broken = StaffServerApi(api: apiFor(FakeServer((r) async => jsonResponse({'detail': 'no'}, 403))));
      await expectLater(broken.myOnboarding(principal), throwsA(isA<ApiException>()));
    });

    test('submitting sends personal details, bank details and document notes, and hears back at once', () async {
      final ok = StaffServerApi(api: apiFor(server = FakeServer((r) async => jsonResponse({'staffId': 'STAFF-1', 'status': 'submitted'}))), afterChange: () async => synced++);
      await ok.submitOnboarding(
        principal,
        personal: {'phone': '08031234567', 'nin': '12345678901'},
        payment: {'bankName': 'Access Bank', 'accountName': 'Musa Ibrahim', 'accountNumber': '0123456789'},
        documents: {'Passport photograph': 'Handed to the office'},
      );
      expect(server.requests.single.url.path, endsWith('/staff/me/onboarding/'));
      expect(body(server.requests.single)['payment'], {'bankName': 'Access Bank', 'accountName': 'Musa Ibrahim', 'accountNumber': '0123456789'});
      expect(synced, 1);

      final duplicate = StaffServerApi(api: apiFor(FakeServer((r) async =>
          jsonResponse({'code': 'duplicate_identity', 'message': 'That phone number already belongs to someone else.'}, 409))));
      await expectLater(
        duplicate.submitOnboarding(principal, personal: const {}, payment: const {}),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'duplicate_identity')),
      );
    });
  });
}

// A 204 answer has no body.
dynamic http204() => http.Response('', 204);
