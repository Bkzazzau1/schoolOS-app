import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/media/media_api.dart';
import 'package:schoolos_app/core/media/media_queue_models.dart';
import 'package:schoolos_app/core/media/media_upload_queue.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_profile_repository.dart';
import 'package:schoolos_app/features/proprietor/presentation/owner_staff_profiles_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';

/// The same shape as owner_staff_profiles_test.dart's own `_Database` - a person's staff record lives in the
/// repository's own demo data, not the database, so an empty mock is enough - extended with the two
/// MediaUploadQueue reads its widgets make on every build.
class _Database implements LocalDatabase {
  final records = <String, LocalRecord>{};
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final a = invocation.namedArguments;
    switch (invocation.memberName) {
      case #getLocalRecord:
        final key = '${a[#tenantId]}/${a[#entityType]}/${a[#entityId]}';
        return Future<LocalRecord?>.value(records[key]);
      case #getLocalRecords:
        return Future<List<LocalRecord>>.value(
          records.values.where((r) => r.tenantId == a[#tenantId] && r.entityType == a[#entityType]).toList(),
        );
      case #upsertLocalRecord:
        final key = '${a[#tenantId]}/${a[#entityType]}/${a[#entityId]}';
        records[key] = LocalRecord(
          tenantId: a[#tenantId], entityType: a[#entityType], entityId: a[#entityId],
          payload: Map<String, Object?>.from(a[#payload]), updatedAt: DateTime.now(), isDirty: a[#isDirty] ?? false,
        );
        return Future<void>.value();
      case #queueMutation:
        return Future<String>.value('mutation');
      case #mediaUploadsForOwner:
        return const <QueuedMediaUpload>[];
      case #pendingMediaUploadCount:
        return 0;
    }
    return super.noSuchMethod(invocation);
  }
}

const _owner = SchoolMembership(id: 'owner', schoolId: 'a', schoolName: 'A', role: SchoolRole.proprietor);
const _finance = SchoolMembership(id: 'finance', schoolId: 'a', schoolName: 'A', role: SchoolRole.accountant);

Future<SchoolSessionController> _session(SchoolMembership active) async {
  FlutterSecureStorage.setMockInitialValues({});
  final session = SchoolSessionController(store: SchoolSessionStore());
  await session.setMemberships([_owner, _finance]);
  await session.selectSchool(active);
  return session;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, {MediaApi? api}) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = _Database();
    final session = await _session(_owner);
    addTearDown(session.dispose);
    final repo = OwnerStaffProfileRepository(database: db, session: session);
    final person = (await repo.people()).first;

    Widget home = OwnerStaffProfileDetailPage(repository: repo, person: person, onChanged: () {});
    if (api != null) {
      final queue = MediaUploadQueue(database: db, schoolSession: session, observeLifecycle: false)..api = api;
      addTearDown(queue.dispose);
      home = MediaScope(api: api, queue: queue, child: home);
    }
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('without a school server, staff documents offer no way to attach a real file', (tester) async {
    await pump(tester);
    expect(find.textContaining('needs your school\'s server'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-staff_document')), findsNothing);
  });

  testWidgets('with a school server, the owner can attach a real file to a staff members record', (tester) async {
    final server = FakeServer((r) async {
      if (r.method == 'GET' && r.url.path.endsWith('/assets/')) return jsonResponse({'assets': <Object?>[]});
      return jsonResponse({}, 404);
    });
    await pump(tester, api: MediaApi(api: apiFor(server)));
    expect(find.byKey(const ValueKey('add-staff_document')), findsOneWidget);
    expect(server.requests.any((r) => r.url.queryParameters['ownerType'] == 'staff_profile_document'), isTrue);
  });
}
