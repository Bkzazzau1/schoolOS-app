import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_admissions_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_admissions_models.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_students_models.dart';
import 'package:schoolos_app/features/proprietor/data/owner_attention_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_enrollment.dart';
import 'package:schoolos_app/features/proprietor/data/owner_finance_overview.dart';
import 'package:schoolos_app/features/proprietor/data/owner_payroll_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_reports.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_overview.dart';
import 'package:schoolos_app/features/proprietor/data/proprietor_ai_service.dart';
import 'package:schoolos_app/features/proprietor/presentation/proprietor_enrollment_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

AdmissionApplicant applicant(String ref, String section, AdmissionStage stage, {String closed = '', bool docsPending = false}) => AdmissionApplicant(
      reference: ref,
      name: 'Child $ref',
      section: section,
      className: 'Class',
      guardian: 'Guardian',
      phone: '0803',
      stage: stage,
      submitted: '1 Sep',
      birthCertificate: docsPending ? AdmissionDocumentStatus.pending : AdmissionDocumentStatus.received,
      closedReason: closed,
    );

AdministratorStudentRecord student(String id, String className, {AdministratorStudentStatus status = AdministratorStudentStatus.active}) =>
    AdministratorStudentRecord(id: id, name: 'Student $id', className: className, primaryGuardian: 'G', status: status);

OwnerReports reportsWith(OwnerEnrollment? enrollment) => buildOwnerReports(
      staff: buildStaffOverview(people: const [], sections: const [], leaders: const [], now: DateTime(2026, 9, 21)),
      finance: buildFinanceOverview(
        concessions: const [],
        payroll: const PayrollSnapshot(staff: [], profiles: {}, authorizers: []),
        batches: const [],
      ),
      attention: const OwnerAttention(items: [], leadership: []),
      now: DateTime(2026, 9, 21),
      enrollment: enrollment,
    );

void main() {
  test('reports and the AI use the real enrollment when there is one, and say nothing is recorded when there is not', () {
    final none = reportsWith(null);
    expect(none.unavailable.map((d) => d.title), contains('Enrollment & admissions'));
    final noAnswer = ProprietorAiService(none).answer('How is enrollment?');
    expect(noAnswer.answer, contains('nothing has been recorded'));

    final e = buildOwnerEnrollment(students: [student('1', 'Primary 3')], applicants: [applicant('A2', 'Primary', AdmissionStage.offer)]);
    final some = reportsWith(e);
    final doc = some.available.firstWhere((d) => d.title == 'Enrollment & admissions');
    expect(doc.sections.first.lines.join(' '), contains('Active students: 1'));
    expect(some.unavailable.map((d) => d.title), isNot(contains('Enrollment & admissions')));
    final answer = ProprietorAiService(some).answer('Summarize enrollment');
    expect(answer.answer, contains('1 students are on the register and 1 applications are open'));
    expect(answer.interpretation, contains('Retention and trends are not recorded'));
  });

  test('an empty school says so and shows zeros, not sample figures', () {
    final e = buildOwnerEnrollment(students: const [], applicants: const []);
    expect(e.empty, isTrue);
    expect(e.kpis.map((k) => k.value), ['0', '0', '0', '0', '0']);
    expect(e.watch, isEmpty);
  });

  test('students, applications, offers and acceptances are counted by section from the real records', () {
    final e = buildOwnerEnrollment(
      students: [
        student('1', 'Primary 3'),
        student('2', 'Primary 4'),
        student('3', 'JSS 1'),
        student('4', 'Nursery 2'),
        student('5', 'SS1A', status: AdministratorStudentStatus.transferredOut),
      ],
      applicants: [
        applicant('A1', 'Primary', AdmissionStage.documents, docsPending: true),
        applicant('A2', 'Primary', AdmissionStage.offer),
        applicant('A3', 'Primary', AdmissionStage.accepted),
        applicant('A4', 'Secondary', AdmissionStage.registered),
        applicant('A5', 'Nursery', AdmissionStage.screening),
        applicant('A6', 'Secondary', AdmissionStage.offer, closed: 'Moved away'),
      ],
    );
    String kpi(String label) => e.kpis.firstWhere((k) => k.label == label).value;
    expect(kpi('Active students'), '4', reason: 'a student who left is not active');
    expect(kpi('Applications'), '5', reason: 'a closed application is not counted');
    expect(kpi('Offers issued'), '3');
    expect(kpi('Accepted'), '2');
    expect(kpi('Registered'), '1');

    final primary = e.sections.firstWhere((s) => s.section == 'Primary');
    expect((primary.activeStudents, primary.applications, primary.offers, primary.accepted), (2, 3, 2, 1));
    final early = e.sections.firstWhere((s) => s.section == 'Early Years');
    expect((early.activeStudents, early.applications), (1, 1), reason: 'Nursery applicants count as Early Years');
    expect(e.applications, 5);
    expect(e.activeStudents, 4);
  });

  test('the owner is told what is waiting: accepted children to register and applications waiting on documents', () {
    final e = buildOwnerEnrollment(
      students: [student('1', 'Primary 3')],
      applicants: [
        applicant('A1', 'Primary', AdmissionStage.documents, docsPending: true),
        applicant('A3', 'Primary', AdmissionStage.accepted),
      ],
    );
    final titles = e.watch.map((w) => w.title).toList();
    expect(titles, contains('1 accepted child is waiting to be registered'));
    expect(titles, contains('1 application is waiting on documents'));
    expect(titles.any((t) => t.contains('most applications')), isTrue);
    expect(e.watch.last.action, contains('Capacity limits are not configured'));
  });

  test('the brief lists what is recorded and says retention and trends are not available', () {
    final e = buildOwnerEnrollment(students: [student('1', 'Primary 3')], applicants: [applicant('A2', 'Primary', AdmissionStage.offer)]);
    final text = renderEnrollmentBrief(schoolName: 'BrightGate', date: DateTime(2026, 9, 21), enrollment: e);
    expect(text, contains('Generated: 2026-09-21'));
    expect(text, contains('Active students: 1'));
    expect(text, contains('NOT AVAILABLE YET'));
    expect(text, contains('Retention and enrollment trend'));
    expect(text, isNot(contains('648')));
  });

  testWidgets('the owner enrollment page shows the demo school counted from its register and pipeline', (tester) async {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const owner = SchoolMembership(id: 'm-owner', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.proprietor);
    late OwnerEnrollmentRepository repository;
    await tester.runAsync(() async {
      final db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
      await db.initialize();
      addTearDown(db.close);
      final session = SchoolSessionController(store: FakeSessionStore());
      await session.setMemberships([owner]);
      await session.selectSchool(owner);
      repository = OwnerEnrollmentRepository(
        students: AdministratorStudentsRepository(localDatabase: db, schoolSession: session),
        admissions: AdministratorAdmissionsRepository(localDatabase: db, schoolSession: session),
      );
      await repository.load();
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ProprietorEnrollmentPage(schoolName: 'BrightGate', onActionRequested: (_) {}, repository: repository)),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.text('Active students'), findsOneWidget);
    expect(find.text('Not available yet'), findsOneWidget);
    expect(find.textContaining('Retention and the enrollment trend'), findsOneWidget);
    late OwnerEnrollment data;
    await tester.runAsync(() async => data = await repository.load());
    expect(data.activeStudents, greaterThan(15));
    expect(data.applications, 5);
    expect(data.watch, isNotEmpty);
  });
}
