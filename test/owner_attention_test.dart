import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_attention_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_overview.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_profile_repository.dart';
import 'package:schoolos_app/features/proprietor/data/payroll_batch_repository.dart';
import 'package:schoolos_app/features/proprietor/data/proprietor_structure_repository.dart';
import 'package:schoolos_app/features/proprietor/data/staff_proposal_repository.dart';
import 'package:schoolos_app/features/proprietor/domain/concession_request.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const owner = SchoolMembership(id: 'm-owner', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.proprietor);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;

  OwnerAttentionRepository attention() {
    final profiles = OwnerStaffProfileRepository(database: db, session: session);
    final structure = ProprietorStructureRepository(localDatabase: db, schoolSession: session);
    return OwnerAttentionRepository(
      database: db,
      session: session,
      proposals: StaffProposalRepository(database: db, session: session),
      concessions: ConcessionRepository(localDatabase: db, schoolSession: session),
      staff: OwnerStaffOverviewRepository(profiles: profiles, structure: structure),
      structure: structure,
    );
  }

  setUp(() async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([owner]);
    await session.selectSchool(owner);
  });

  tearDown(() => db.close());

  test('the queue shows what is really waiting: a pending concession, then nothing once it is decided', () async {
    final concessions = ConcessionRepository(localDatabase: db, schoolSession: session);
    final pending = (await concessions.loadRequests()).where((r) => r.status == ConcessionStatus.pendingApproval).toList();
    expect(pending, isNotEmpty);

    var items = (await attention().load()).items;
    expect(items.where((i) => i.moduleKey == 'finance-approvals').length, pending.length);
    expect(items.firstWhere((i) => i.moduleKey == 'finance-approvals').detail, contains(pending.first.requestedBy));

    for (final r in pending) {
      await concessions.decide(request: r, status: ConcessionStatus.approved, note: 'ok');
    }
    items = (await attention().load()).items;
    expect(items.where((i) => i.moduleKey == 'finance-approvals'), isEmpty);
  });

  test('a prepared payroll batch is waiting for approval, an approved one is not', () async {
    await db.upsertLocalRecord(
      tenantId: owner.schoolId,
      entityType: PayrollBatchRepository.entityType,
      entityId: '2026-09',
      payload: {'period': '2026-09', 'status': 'prepared', 'lines': [{}, {}], 'total': 100},
    );
    await db.upsertLocalRecord(
      tenantId: owner.schoolId,
      entityType: PayrollBatchRepository.entityType,
      entityId: '2026-08',
      payload: {'period': '2026-08', 'status': 'approved', 'lines': [{}], 'total': 50},
    );
    final items = (await attention().load()).items;
    final payroll = items.where((i) => i.moduleKey == 'payroll').toList();
    expect(payroll.length, 1);
    expect(payroll.single.title, contains('2026-09'));
  });
}
