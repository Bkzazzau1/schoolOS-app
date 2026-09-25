import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/transferverify/data/bad_debt_classification_repository.dart';
import 'package:schoolos_app/features/transferverify/data/transfer_verify_associations_api.dart';
import 'package:schoolos_app/features/transferverify/domain/bad_debt_classification_models.dart';
import 'package:schoolos_app/features/transferverify/presentation/publish_transfer_verify_dialog.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';

class _Database implements LocalDatabase {
  final records = <String, LocalRecord>{};
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final a = invocation.namedArguments;
    final key = '${a[#tenantId]}/${a[#entityType]}/${a[#entityId]}';
    switch (invocation.memberName) {
      case #getLocalRecord:
        return Future<LocalRecord?>.value(records[key]);
      case #getLocalRecords:
        return Future<List<LocalRecord>>.value(
          records.values.where((r) => r.tenantId == a[#tenantId] && r.entityType == a[#entityType]).toList(),
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
        return Future<String>.value('mutation');
    }
    return super.noSuchMethod(invocation);
  }
}

const owner = SchoolMembership(id: 'owner', schoolId: 'a', schoolName: 'A', role: SchoolRole.proprietor);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('picks a real active association and it lands in the stored publication', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final database = _Database();
    final session = SchoolSessionController(store: SchoolSessionStore());
    await session.setMemberships([owner]);
    await session.selectSchool(owner);
    addTearDown(session.dispose);
    final repository = BadDebtClassificationRepository(localDatabase: database, schoolSession: session);

    final classified = await repository.classify(
      studentId: 'STU-1',
      studentName: 'A Student',
      outstandingAmountMinor: 100000,
      classifiedByName: 'Mrs Bello',
    );
    var item = classified.item!;
    item = (await repository.advanceStatus(item, BadDebtStatus.badDebt)).item!;

    final server = FakeServer((request) async {
      if (request.url.path.contains('/schools/')) {
        return jsonResponse({
          'memberships': [
            {
              'id': 'row-1',
              'associationId': 'assoc-1',
              'associationName': 'Kaduna Private Schools Association',
              'schoolId': owner.schoolId,
              'status': 'active',
              'requestedByMembershipId': owner.id,
              'requestedAt': DateTime.now().toUtc().toIso8601String(),
              'decisionNote': '',
            },
          ],
        });
      }
      return jsonResponse({}, 404);
    });
    final associationsApi = TransferVerifyAssociationsApi(api: apiFor(server));

    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => PublishTransferVerifyDialog(
                  repository: repository,
                  item: item,
                  membership: owner,
                  associationsApi: associationsApi,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Kaduna Private Schools Association'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<TransferVerifyPublicationReason>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Withdrew without financial clearance').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Kaduna Private Schools Association'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'I have reviewed this case and confirm it should be published.'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await tester.pumpAndSettle();

    final stored = (await repository.load()).items.single;
    expect(stored.associationScope, ['assoc-1']);
    expect(tester.takeException(), isNull);
  });
}
