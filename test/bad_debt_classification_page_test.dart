import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_students_models.dart';
import 'package:schoolos_app/features/transferverify/data/bad_debt_classification_repository.dart';
import 'package:schoolos_app/features/transferverify/domain/bad_debt_classification_models.dart';
import 'package:schoolos_app/features/transferverify/presentation/bad_debt_classification_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const owner = SchoolMembership(id: 'owner', schoolId: 'a', schoolName: 'A', role: SchoolRole.proprietor);

  Future<BadDebtClassificationRepository> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FlutterSecureStorage.setMockInitialValues({});
    final database = _Database();
    final session = SchoolSessionController(store: SchoolSessionStore());
    await session.setMemberships([owner]);
    await session.selectSchool(owner);
    addTearDown(session.dispose);
    final repository = BadDebtClassificationRepository(localDatabase: database, schoolSession: session);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BadDebtClassificationPage(repository: repository, membership: owner))));
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('classify, advance to bad debt, then publish and withdraw from the workspace', (tester) async {
    final repository = await pump(tester);

    await tester.tap(find.text('Classify a bad debt'));
    await tester.pumpAndSettle();

    final firstStudent = (await repository.students()).first;
    await tester.tap(find.byType(DropdownButtonFormField<AdministratorStudentRecord>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${firstStudent.name} · ${firstStudent.className}').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Outstanding amount (₦)'), '245000');
    await tester.enterText(find.widgetWithText(TextFormField, 'Your name'), 'Mrs Bello');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Outstanding'), findsOneWidget);
    expect(find.text('₦245,000'), findsOneWidget);

    await tester.tap(find.text('Classify as bad debt'));
    await tester.pumpAndSettle();
    expect(find.text('Bad debt / unresolved obligation'), findsOneWidget);

    await tester.tap(find.text('Publish to TransferVerify'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<TransferVerifyPublicationReason>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Withdrew without financial clearance').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await tester.pumpAndSettle();

    expect(find.text('Published to TransferVerify'), findsOneWidget);

    await tester.tap(find.text('Withdraw publication'));
    await tester.pumpAndSettle();

    expect(find.text('Published to TransferVerify'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
