import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';
import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_desk.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_students_models.dart';
import 'package:schoolos_app/features/principal/data/principal_results_repository.dart';
import 'package:schoolos_app/features/principal/domain/principal_results_models.dart';
import 'package:schoolos_app/features/principal/presentation/principal_results_page.dart';

const principal = SchoolMembership(
  id: 'p',
  schoolId: 's',
  schoolName: 'School',
  role: SchoolRole.principal,
);
void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late PrincipalResultsRepository repository;
  Future<void> setUpSchool([SchoolMembership member = principal]) async {
    db = LocalDatabase(
      cipher: PayloadCipher(secureStorage: MemorySecureStorage()),
      databasePath: ':memory:',
    );
    await db!.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([member]);
    await session.selectSchool(member);
    repository = PrincipalResultsRepository(
      localDatabase: db!,
      schoolSession: session,
    );
  }

  tearDown(() => db?.close());
  test('classes come only from the real active Secondary register', () async {
    await setUpSchool();
    final register = await AdministratorStudentsRepository(
      localDatabase: db!,
      schoolSession: session,
    ).load();
    final counts = <String, int>{};
    for (final s in register.students.where(
      (s) =>
          sectionOfClass(s.className) == 'Secondary' &&
          s.status != AdministratorStudentStatus.transferredOut,
    )) {
      counts.update(s.className, (n) => n + 1, ifAbsent: () => 1);
    }
    final snapshot = await repository.load();
    expect({for (final c in snapshot.classes) c.className: c.students}, counts);
  });
  for (final field in [
    'average',
    'passRate',
    'reports',
    'students',
    'decisions',
    'release',
  ]) {
    test('missing $field evidence stays unavailable', () async {
      await setUpSchool();
      final s = await repository.load();
      switch (field) {
        case 'average':
          expect(s.schoolAverage, isNull);
        case 'passRate':
          expect(s.passRate, isNull);
        case 'reports':
          expect(s.reportsReady, 0);
        case 'students':
          expect(s.students, isEmpty);
        case 'decisions':
          expect(s.decisions, isEmpty);
        case 'release':
          expect(s.releasedClasses, 0);
      }
    });
  }
  for (final type in [
    'principal_result_class',
    'principal_student_report',
    'principal_report_review_decision',
  ]) {
    test('legacy fabricated $type records are never surfaced', () async {
      await setUpSchool();
      await db!.upsertLocalRecord(
        tenantId: 's',
        entityType: type,
        entityId: 'fake',
        payload: {'name': 'Invented person', 'average': 99},
      );
      final s = await repository.load();
      expect(s.students, isEmpty);
      expect(s.decisions, isEmpty);
      expect(s.classes.any((r) => r.className == 'fake'), isFalse);
    });
  }
  for (final action in PrincipalReportReviewAction.values) {
    test('cannot $action a nonexistent report', () async {
      await setUpSchool();
      expect(
        (await repository.reviewReport(
          studentId: 'fake',
          action: action,
          comment: '',
        )).success,
        isFalse,
      );
      expect(db!.pendingCount(tenantId: 's'), 0);
    });
  }
  test('non principal cannot see results', () async {
    await setUpSchool(
      const SchoolMembership(
        id: 't',
        schoolId: 's',
        schoolName: 'School',
        role: SchoolRole.teacher,
      ),
    );
    expect((await repository.load()).classes, isEmpty);
  });
  test(
    'no print or publication permission without actual report documents',
    () async {
      await setUpSchool();
      final p = (await repository.load()).permissions;
      expect(p.canOpenPrintPreview, isFalse);
      expect(p.canReleaseToParents, isFalse);
      expect(p.canEditScores, isFalse);
    },
  );
  testWidgets('honest empty results render on a phone', (tester) async {
    await tester.runAsync(() => setUpSchool());
    final snapshot = await tester.runAsync(() => repository.load());
    final fake = _SnapshotRepository(db!, session, snapshot!);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrincipalResultsPage(repository: fake, onNavigate: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Official term results: Not recorded yet.'),
      findsOneWidget,
    );
    expect(find.text('Approve report'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _SnapshotRepository extends PrincipalResultsRepository {
  _SnapshotRepository(
    LocalDatabase db,
    SchoolSessionController session,
    this.snapshot,
  ) : super(localDatabase: db, schoolSession: session);
  final PrincipalResultsSnapshot snapshot;
  @override
  Future<PrincipalResultsSnapshot> load() async => snapshot;
}
