import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/student/data/student_repository.dart';
import 'package:schoolos_app/features/student/presentation/student_workspace_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';
import 'core/backend_test_support.dart';

class _Database implements LocalDatabase {
  final records = <String, LocalRecord>{};
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final args = invocation.namedArguments;
    final key = '${args[#tenantId]}/${args[#entityType]}/${args[#entityId]}';
    if (invocation.memberName == #getLocalRecord) {
      return Future<LocalRecord?>.value(records[key]);
    }
    if (invocation.memberName == #getLocalRecords) {
      final prefix = '${args[#tenantId]}/${args[#entityType]}/';
      return Future<List<LocalRecord>>.value([
        for (final entry in records.entries)
          if (entry.key.startsWith(prefix)) entry.value,
      ]);
    }
    if (invocation.memberName == #upsertLocalRecord) {
      records[key] = LocalRecord(
        tenantId: args[#tenantId],
        entityType: args[#entityType],
        entityId: args[#entityId],
        payload: Map<String, Object?>.from(args[#payload]),
        updatedAt: DateTime.now(),
        isDirty: false,
      );
      return Future<void>.value();
    }
    if (invocation.memberName == #queueMutation) {
      return Future<String>.value('mutation-${records.length}');
    }
    if (invocation.memberName == #pendingCount) {
      return 0;
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  const student = SchoolMembership(
    id: 'student',
    schoolId: 'school',
    schoolName: 'School',
    role: SchoolRole.student,
  );
  const other = SchoolMembership(
    id: 'other',
    schoolId: 'school',
    schoolName: 'School',
    role: SchoolRole.student,
  );
  late _Database database;
  late SchoolSessionController session;
  late StudentRepository repository;
  late DateTime now;
  setUp(() async {
    LocalDatabase.blockDemoSeeds = false;
    database = _Database();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([student, other]);
    await session.selectSchool(student);
    now = DateTime(2026, 9, 22, 9);
    repository = StudentRepository(
      database: database,
      session: session,
      membership: student,
      now: () => now,
    );
  });
  tearDown(() {
    session.dispose();
    LocalDatabase.blockDemoSeeds = false;
  });
  test(
    'practice resumes, scores only chosen answers, and locks submission',
    () async {
      await repository.startPractice();
      final deadline = (await repository.load())['deadline'];
      await repository.answer(0, 1);
      now = now.add(const Duration(minutes: 2));
      await repository.startPractice();
      expect((await repository.load())['deadline'], deadline);
      await repository.submit();
      expect((await repository.load())['score'], 1);
      await expectLater(repository.answer(1, 2), throwsStateError);
      await repository.submit();
      expect((await repository.load())['score'], 1);
    },
  );
  test('expired practice rejects answers and can submit saved work', () async {
    await repository.startPractice();
    now = now.add(const Duration(minutes: 11));
    await expectLater(repository.answer(0, 1), throwsStateError);
    await repository.submit();
    expect((await repository.load())['score'], 0);
  });
  test('other memberships cannot read or change this student state', () async {
    await repository.saveTasks([
      {'title': 'Revise', 'done': false},
    ]);
    await session.selectSchool(other);
    await expectLater(repository.load(), throwsStateError);
    await expectLater(repository.saveTasks([]), throwsStateError);
    final otherRepository = StudentRepository(
      database: database,
      session: session,
      membership: other,
    );
    expect(await otherRepository.load(), isEmpty);
  });
  test('live mode never starts sample exams', () async {
    LocalDatabase.blockDemoSeeds = true;
    await expectLater(repository.startPractice(), throwsStateError);
    expect(database.records, isEmpty);
  });
  test('study tasks persist without resetting the practice attempt', () async {
    await repository.startPractice();
    await repository.answer(0, 1);
    await repository.saveTasks([{'title': 'Revise fractions', 'done': true}]);
    final reopened = StudentRepository(database: database, session: session, membership: student);
    final state = await reopened.load();
    expect((state['answers'] as List).first, 1);
    expect((state['tasks'] as List).single, {'title': 'Revise fractions', 'done': true});
  });
  testWidgets('phone student can answer, submit practice and see result', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: StudentWorkspacePage(
          membership: student,
          localDatabase: database,
          schoolSession: session,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('My performance'), findsOneWidget);
    await tester.tap(find.byTooltip('Student menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CBT'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start practice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start practice'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Finish practice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish practice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Student menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Performance'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('1 / 5 correct · Practice only'));
    expect(find.text('1 / 5 correct · Practice only'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
