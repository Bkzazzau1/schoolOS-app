import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';
import 'package:schoolos_app/features/principal/data/principal_approvals_repository.dart';
import 'package:schoolos_app/features/principal/domain/principal_approvals_models.dart';
import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const principal = SchoolMembership(
  id: 'p',
  schoolId: 's',
  schoolName: 'School',
  role: SchoolRole.principal,
);
void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late PrincipalApprovalsRepository repo;
  Future<void> setup([SchoolMembership member = principal]) async {
    db = LocalDatabase(
      cipher: PayloadCipher(secureStorage: MemorySecureStorage()),
      databasePath: ':memory:',
    );
    await db!.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([member]);
    await session.selectSchool(member);
    repo = PrincipalApprovalsRepository(
      localDatabase: db!,
      schoolSession: session,
    );
  }

  tearDown(() => db?.close());
  Future<void> submission({
    bool lesson = true,
    bool event = true,
    String className = 'JSS 2A',
    String tenant = 's',
    int version = 2,
    bool draft = false,
  }) async {
    final type = lesson
        ? 'teacher_lesson_plan'
        : 'teacher_assessment_score_sheet';
    await db!.upsertLocalRecord(
      tenantId: tenant,
      entityType: type,
      entityId: 'work',
      isDirty: true,
      payload: {
        'id': 'work',
        'className': className,
        'version': version,
        'status': draft ? 'draft' : 'submitted',
        'state': draft ? 'draft' : 'submittedForReview',
        'topic': 'Recorded topic',
        'objectives': 'Recorded objectives',
        'activities': 'Recorded activities',
        'assessment': 'Quiz',
        'assessmentLabel': 'Recorded assessment',
        'maximumScore': 20,
        'entries': [
          {'studentId': 'student', 'score': 12},
        ],
      },
    );
    if (event) {
      await db!.upsertLocalRecord(
        tenantId: tenant,
        entityType: lesson
            ? 'teacher_lesson_plan_event'
            : 'teacher_assessment_event',
        entityId: 'event-$version',
        isDirty: true,
        payload: {
          'id': 'event-$version',
          'planId': 'work',
          'sheetId': 'work',
          'version': version,
          'action': lesson ? 'submitted' : 'submittedForReview',
          'actorMembershipId': 'teacher-member',
          'occurredAt': '2026-09-22T10:00:00Z',
        },
      );
    }
  }

  test('fresh school contains no invented requests', () async {
    await setup();
    expect((await repo.load()).items, isEmpty);
  });
  test('seeded submitted plan without event is excluded', () async {
    await setup();
    await submission(event: false);
    expect((await repo.load()).items, isEmpty);
  });
  test('draft is excluded even with historical submission event', () async {
    await setup();
    await submission(draft: true);
    expect((await repo.load()).items, isEmpty);
  });
  for (final scope in ['Primary 3', 'Unknown']) {
    test('excludes $scope work', () async {
      await setup();
      await submission(className: scope);
      expect((await repo.load()).items, isEmpty);
    });
  }
  test('other tenant is excluded', () async {
    await setup();
    await submission(tenant: 'other');
    expect((await repo.load()).items, isEmpty);
  });
  test('real submission shows its recorded evidence and actor', () async {
    await setup();
    await submission();
    final item = (await repo.load()).items.single;
    expect(item.title, 'Recorded topic');
    expect(item.teacher, 'teacher-member');
    expect(item.summary, 'Recorded objectives');
  });
  test('assessment review preserves source marks and records actor', () async {
    await setup();
    await submission(lesson: false);
    final item = (await repo.load()).items.single;
    expect(
      (await repo.decide(
        approvalId: item.id,
        status: PrincipalApprovalStatus.approved,
        comment: 'Checked',
      )).success,
      isTrue,
    );
    final state = await repo.load();
    expect(state.approvedCount, 1);
    expect(state.decisions.single.reviewerMembershipId, 'p');
    final source = (await db!.getLocalRecords(
      tenantId: 's',
      entityType: 'teacher_assessment_score_sheet',
    )).single.payload;
    expect(source['entries'], [
      {'studentId': 'student', 'score': 12},
    ]);
    expect(source['state'], 'submittedForReview');
    expect(
      (await repo.decide(
        approvalId: item.id,
        status: PrincipalApprovalStatus.returned,
        comment: 'Again',
      )).success,
      isFalse,
    );
  });
  test('returned work requires explanation', () async {
    await setup();
    await submission();
    final id = (await repo.load()).items.single.id;
    expect(
      (await repo.decide(
        approvalId: id,
        status: PrincipalApprovalStatus.returned,
        comment: ' ',
      )).success,
      isFalse,
    );
    expect(
      (await repo.decide(
        approvalId: id,
        status: PrincipalApprovalStatus.returned,
        comment: 'Clarify objectives',
      )).success,
      isTrue,
    );
    expect((await repo.load()).returnedCount, 1);
  });
  test('new source version needs a new decision', () async {
    await setup();
    await submission();
    final id = (await repo.load()).items.single.id;
    await repo.decide(
      approvalId: id,
      status: PrincipalApprovalStatus.approved,
      comment: '',
    );
    await submission(version: 3);
    expect((await repo.load()).pendingCount, 1);
    expect(
      (await repo.decide(
        approvalId: id,
        status: PrincipalApprovalStatus.approved,
        comment: '',
      )).success,
      isFalse,
    );
  });
  test('nonprincipal cannot see or review submissions', () async {
    await setup(
      const SchoolMembership(
        id: 't',
        schoolId: 's',
        schoolName: 'School',
        role: SchoolRole.teacher,
      ),
    );
    await submission();
    expect((await repo.load()).items, isEmpty);
    expect(
      (await repo.decide(
        approvalId: 'teacher_lesson_plan:work:v2',
        status: PrincipalApprovalStatus.approved,
        comment: '',
      )).success,
      isFalse,
    );
  });
}
