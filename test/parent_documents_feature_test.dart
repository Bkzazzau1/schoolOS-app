import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/finance_office/data/finance_ledger_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_children_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_documents_repository.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const parent = SchoolMembership(id: 'm-parent', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.parent);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late ParentDocumentsRepository documents;
  late FinanceLedgerRepository ledger;

  Future<void> setUpFamily() async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([parent, teacher]);
    await session.selectSchool(parent);
    final students = AdministratorStudentsRepository(localDatabase: database, schoolSession: session);
    final children = ParentChildrenRepository(
      localDatabase: database,
      schoolSession: session,
      students: students,
      attendance: AdministratorAttendanceRepository(localDatabase: database, schoolSession: session),
      ledger: FinanceLedgerRepository(
        database: database,
        session: session,
        students: students,
        concessions: ConcessionRepository(localDatabase: database, schoolSession: session),
      ),
    );
    ledger = FinanceLedgerRepository(
      database: database,
      session: session,
      students: students,
      concessions: ConcessionRepository(localDatabase: database, schoolSession: session),
    );
    documents = ParentDocumentsRepository(
      localDatabase: database,
      schoolSession: session,
      children: children,
      ledger: ledger,
    );
  }

  tearDown(() => db?.close());

  test('documents are the real, non-voided payment receipts, never a disconnected fixed list', () async {
    await setUpFamily();
    final snapshot = await documents.load();
    final accounts = await ledger.accounts();
    final linkedIds = {'STU-001', 'PRI-003'};

    final expectedCount = accounts
        .where((account) => linkedIds.contains(account.student.id))
        .fold<int>(0, (sum, account) => sum + account.payments.where((p) => !p.isVoided).length);
    expect(snapshot.documents, hasLength(expectedCount));
    expect(snapshot.documents, isNotEmpty, reason: 'the seeded demo ledger always has at least one real payment');

    for (final document in snapshot.documents) {
      expect(document.typeLabel, 'Finance');
      expect(document.status.name, 'ready');
      expect(['Maryam Abdullahi', 'Hafsa Abdullahi'], contains(document.ownerLabel));
    }
  });

  test('no real report-card generation or per-student consent-request source exists yet', () async {
    await setUpFamily();
    final snapshot = await documents.load();
    expect(snapshot.consentRequests, isEmpty);
    expect(snapshot.consentHistory, isEmpty);
  });

  test('acting on a consent request that does not really exist is rejected, not silently accepted', () async {
    await setUpFamily();
    expect(
      documents.queueConsent(requestId: 'CONSENT-NOT-REAL'),
      throwsStateError,
    );
  });

  test('only a Parent membership can load family documents', () async {
    await setUpFamily();
    await session.selectSchool(teacher);
    expect(documents.load(), throwsStateError);
  });
}
