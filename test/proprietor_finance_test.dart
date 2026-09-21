import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_finance_overview.dart';
import 'package:schoolos_app/features/proprietor/data/owner_payroll_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;
import 'package:schoolos_app/features/proprietor/presentation/proprietor_finance_page.dart';
import 'package:schoolos_app/features/proprietor/domain/concession_request.dart';

void main() {
  for (final width in [390.0, 1600.0]) {
    testWidgets('owner finance renders collection table at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const owner = SchoolMembership(id: 'm-owner', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.proprietor);
      late OwnerFinanceOverviewRepository repository;
      await tester.runAsync(() async {
        final db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
        await db.initialize();
        addTearDown(db.close);
        final session = SchoolSessionController(store: FakeSessionStore());
        await session.setMemberships([owner]);
        await session.selectSchool(owner);
        repository = OwnerFinanceOverviewRepository(
          concessions: ConcessionRepository(localDatabase: db, schoolSession: session),
          payroll: OwnerPayrollRepository(database: db, session: session),
          database: db,
          session: session,
        );
        await repository.load();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProprietorFinancePage(
              schoolName: 'BrightGate Academy',
              onActionRequested: (_) {},
              repository: repository,
            ),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
      expect(find.text('Waiting on you'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Collection by school section'));
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
  test('concession calculates net obligation and round-trips safely', () {
    const request = ConcessionRequest(
      id: 'CNC-TEST-001',
      student: 'Hafsa Abdullahi',
      className: 'Primary 3',
      type: ConcessionType.discount,
      grossFee: 145000,
      amount: 10000,
      reason: 'Sibling Discount',
      requestedBy: 'Finance Office',
      requestedByRole: 'Finance Office',
      requestedAt: '10 Sep 2026',
      status: ConcessionStatus.pendingApproval,
    );

    expect(request.netObligation, 135000);
    expect(formatNaira(request.netObligation), '₦135,000');

    final approved = request.copyWith(
      status: ConcessionStatus.approved,
      decidedBy: 'Proprietor',
      decidedAt: '19 Sep 2026',
      decisionNote: 'Approved within policy.',
    );
    final restored = ConcessionRequest.fromJson(approved.toJson());

    expect(restored.status, ConcessionStatus.approved);
    expect(restored.netObligation, 135000);
    expect(restored.decidedBy, 'Proprietor');
    expect(restored.decisionNote, 'Approved within policy.');
  });
}
