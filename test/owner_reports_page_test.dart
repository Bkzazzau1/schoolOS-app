import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_attention_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_finance_overview.dart';
import 'package:schoolos_app/features/proprietor/data/owner_payroll_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_reports.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_overview.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_profile_repository.dart';
import 'package:schoolos_app/features/proprietor/data/proprietor_structure_repository.dart';
import 'package:schoolos_app/features/proprietor/data/staff_proposal_repository.dart';
import 'package:schoolos_app/features/proprietor/presentation/proprietor_reports_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

void main() {
  testWidgets('the reports page lists real reports, opens one, and marks the rest not available', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const owner = SchoolMembership(id: 'm-owner', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.proprietor);
    late OwnerReportsRepository repository;
    await tester.runAsync(() async {
      final db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
      await db.initialize();
      addTearDown(db.close);
      final session = SchoolSessionController(store: FakeSessionStore());
      await session.setMemberships([owner]);
      await session.selectSchool(owner);
      final profiles = OwnerStaffProfileRepository(database: db, session: session);
      final structure = ProprietorStructureRepository(localDatabase: db, schoolSession: session);
      final concessions = ConcessionRepository(localDatabase: db, schoolSession: session);
      final staff = OwnerStaffOverviewRepository(profiles: profiles, structure: structure);
      final finance = OwnerFinanceOverviewRepository(
        concessions: concessions,
        payroll: OwnerPayrollRepository(database: db, session: session),
        database: db,
        session: session,
      );
      repository = OwnerReportsRepository(
        staff: staff,
        finance: finance,
        attention: OwnerAttentionRepository(
          database: db,
          session: session,
          proposals: StaffProposalRepository(database: db, session: session),
          concessions: concessions,
          staff: staff,
          structure: structure,
        ),
      );
      await repository.load();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ProprietorReportsPage(schoolName: 'BrightGate', onActionRequested: (_) {}, repository: repository)),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();

    expect(find.text('Executive summary'), findsOneWidget);
    expect(find.textContaining('Not available yet · The Finance role'), findsOneWidget);

    await tester.tap(find.text('Open').first);
    await tester.pumpAndSettle();
    expect(find.text('Waiting on the owner'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
