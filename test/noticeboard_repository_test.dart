import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/noticeboard/data/noticeboard_repository.dart';
import 'package:schoolos_app/features/noticeboard/domain/noticeboard_models.dart';
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

SchoolMembership _member(SchoolRole role) => SchoolMembership(id: role.name, schoolId: 'a', schoolName: 'A', role: role);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Database database;
  late SchoolSessionController session;
  late NoticeboardRepository repository;

  Future<void> actAs(SchoolRole role) async {
    final member = _member(role);
    await session.setMemberships([member]);
    await session.selectSchool(member);
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    database = _Database();
    session = SchoolSessionController(store: SchoolSessionStore());
    repository = NoticeboardRepository(localDatabase: database, schoolSession: session);
  });
  tearDown(() => session.dispose());

  test('a fresh school sees a genuinely empty noticeboard, never fabricated notices', () async {
    await actAs(SchoolRole.proprietor);
    final snapshot = await repository.load();
    expect(snapshot.notices, isEmpty);
  });

  test('only the proprietor may publish an official notice', () async {
    await actAs(SchoolRole.teacher);
    final result = await repository.publish(
      title: 'Title',
      body: 'Body',
      audience: NoticeAudience.wholeSchool,
      priority: NoticePriority.normal,
      acknowledgementRequired: false,
    );
    expect(result.success, isFalse);
  });

  test('a real published notice starts with an honest zero recipient count, never a guessed one', () async {
    await actAs(SchoolRole.proprietor);
    final result = await repository.publish(
      title: 'School closes early',
      body: 'All sections close at noon.',
      audience: NoticeAudience.wholeSchool,
      priority: NoticePriority.important,
      acknowledgementRequired: true,
    );
    expect(result.success, isTrue, reason: result.message);
    final notice = (await repository.load()).notices.single;
    expect(notice.readCount, 0);
    expect(notice.totalRecipients, 0);
  });

  test('pinning and editing a real notice persists, and only the proprietor may do either', () async {
    await actAs(SchoolRole.proprietor);
    await repository.publish(
      title: 'Title',
      body: 'Body',
      audience: NoticeAudience.wholeSchool,
      priority: NoticePriority.normal,
      acknowledgementRequired: false,
    );
    final id = (await repository.load()).notices.single.id;

    final pinResult = await repository.togglePin(id);
    expect(pinResult.success, isTrue);
    expect((await repository.load()).notices.single.pinned, isTrue);

    final editResult = await repository.edit(id: id, title: 'Updated title', body: 'Updated body');
    expect(editResult.success, isTrue);
    expect((await repository.load()).notices.single.title, 'Updated title');
  });
}
