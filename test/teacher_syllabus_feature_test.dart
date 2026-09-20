import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_syllabus_demo_data.dart';
import 'package:schoolos_app/features/teacher/data/teacher_syllabus_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_syllabus_models.dart';
import 'package:schoolos_app/features/teacher/presentation/teacher_syllabus_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

void main() {
  test('Syllabus preserves exact four classes and thirty-two website rows', () {
    expect(teacherSyllabusClassOptions, ['JSS 2A', 'JSS 2B', 'JSS 3A', 'SS 1A']);
    expect(teacherSyllabusRows, hasLength(32));
    for (final className in teacherSyllabusClassOptions) {
      expect(
        teacherSyllabusRows.where((row) => row.className == className),
        hasLength(8),
      );
    }
  });

  test('Syllabus preserves exact website progress and pacing snapshot', () {
    expect(teacherSyllabusProgressByClass, {
      'JSS 2A': 72,
      'JSS 2B': 68,
      'JSS 3A': 81,
      'SS 1A': 64,
    });
    expect(teacherSyllabusPacingLabel('JSS 2B'), 'Behind');
    expect(teacherSyllabusPacingHint('JSS 2B'), '2 lessons behind expected pace');
    expect(teacherSyllabusPacingLabel('JSS 2A'), 'On track');
    expect(teacherSyllabusNextTopic('JSS 2A'), 'Word Problems');
    expect(teacherSyllabusNextTopic('JSS 3A'), 'Variation');
    expect(teacherSyllabusNextTopic('SS 1A'), 'Graphs');
  });

  test('JSS 2A exact website rows and lesson totals remain intact', () {
    final rows = teacherSyllabusRows
        .where((row) => row.className == 'JSS 2A')
        .toList(growable: false);
    expect(rows[0].topic, 'Whole Numbers Review');
    expect(rows[0].plannedLessons, 2);
    expect(rows[4].topic, 'Linear Equations');
    expect(rows[4].approvedStatus, TeacherSyllabusStatus.inProgress);
    expect(rows[5].approvedStatus, TeacherSyllabusStatus.current);
    expect(rows[6].topic, 'Word Problems');
    expect(rows[7].topic, 'Graphs of Linear Equations');
    expect(rows.fold<int>(0, (sum, row) => sum + row.plannedLessons), 23);
  });

  test('JSS 2B week six preserves explicit behind state', () {
    final row = teacherSyllabusRows.singleWhere(
      (item) => item.className == 'JSS 2B' && item.week == 6,
    );
    expect(row.topic, 'Linear Equations');
    expect(row.approvedStatus, TeacherSyllabusStatus.behind);
    expect(teacherSyllabusAiInsight('JSS 2B'), contains('one lesson is recovered'));
    expect(teacherSyllabusAiInsight('JSS 2B'), contains('word problems'));
  });

  test('approved row and reported progress serialize independently', () {
    final row = teacherSyllabusRows.first;
    final restoredRow = TeacherSyllabusRow.fromJson(row.toJson());
    expect(restoredRow.id, 'JSS 2A-W1');
    expect(restoredRow.approvedStatus, TeacherSyllabusStatus.completed);

    const progress = TeacherSyllabusProgressRecord(
      id: 'JSS 2A-W6',
      className: 'JSS 2A',
      week: 6,
      reportedStatus: TeacherSyllabusStatus.completed,
      actorMembershipId: 'teacher-1',
      version: 2,
      updatedAt: '2026-09-20T04:30:00Z',
    );
    final restoredProgress = TeacherSyllabusProgressRecord.fromJson(progress.toJson());
    expect(restoredProgress.reportedStatus, TeacherSyllabusStatus.completed);
    expect(restoredProgress.version, 2);
    expect(restoredProgress.actorMembershipId, 'teacher-1');
  });

  test('syllabus progress event preserves append-only audit evidence', () {
    const event = TeacherSyllabusProgressEvent(
      id: 'evt-1',
      recordId: 'JSS 2A-W6',
      action: TeacherSyllabusProgressAction.markedComplete,
      actorMembershipId: 'teacher-1',
      version: 2,
      occurredAt: '2026-09-20T04:30:00Z',
    );
    final restored = TeacherSyllabusProgressEvent.fromJson(event.toJson());
    expect(restored.recordId, 'JSS 2A-W6');
    expect(restored.action, TeacherSyllabusProgressAction.markedComplete);
    expect(restored.version, 2);
  });

  test('teacher authority never includes approved curriculum mutation', () {
    final fake = _FakeSyllabusRepository();
    const teacher = SchoolMembership(
      id: 'teacher-1',
      schoolId: 'school-1',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.teacher,
    );
    const principal = SchoolMembership(
      id: 'principal-1',
      schoolId: 'school-1',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.principal,
    );

    final teacherPermissions = fake.permissionsFor(teacher);
    expect(teacherPermissions.canViewAssignedScheme, isTrue);
    expect(teacherPermissions.canReportCoverage, isTrue);
    expect(teacherPermissions.canEditApprovedScheme, isFalse);
    expect(teacherPermissions.canReorderTopics, isFalse);
    expect(teacherPermissions.canConfirmLeadershipApproval, isFalse);
    expect(fake.permissionsFor(principal).canReportCoverage, isFalse);
  });

  test('syllabus boundaries keep AI and offline reports non-authoritative', () {
    expect(teacherSyllabusAuthorityBoundary, contains('cannot silently change'));
    expect(teacherSyllabusAuthorityBoundary, contains('authorized academic approval'));
    expect(teacherSyllabusAiBoundary, contains('cannot rewrite the approved scheme'));
    expect(teacherSyllabusAiBoundary, contains('skip prerequisite'));
    expect(teacherSyllabusOfflineBoundary, contains('teacher-reported local record'));
    expect(teacherSyllabusOfflineBoundary, contains('not leadership approval'));
  });

  test('syllabus search matches week topic and effective status', () {
    final row = teacherSyllabusRows.singleWhere(
      (item) => item.className == 'JSS 2A' && item.week == 7,
    );
    expect(row.matches('word problems'), isTrue);
    expect(row.matches('7'), isTrue);
    expect(row.matches('upcoming'), isTrue);
    expect(
      row.matches('completed', reportedStatus: TeacherSyllabusStatus.completed),
      isTrue,
    );
  });

  testWidgets('Syllabus renders website snapshot and JSS 2B pacing alert', (
    tester,
  ) async {
    final fake = _FakeSyllabusRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherSyllabusPage(
            repository: fake,
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Syllabus Tracker'), findsOneWidget);
    expect(find.text('72%'), findsOneWidget);
    expect(find.text('Word Problems'), findsWidgets);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('JSS 2B').last);
    await tester.pumpAndSettle();

    expect(find.text('68%'), findsOneWidget);
    expect(find.text('Pacing alert'), findsOneWidget);
    expect(find.text('Plan recovery lesson'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mark complete records teacher progress without changing approved row', (
    tester,
  ) async {
    final fake = _FakeSyllabusRepository();
    var mutations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherSyllabusPage(
            repository: fake,
            onNavigate: (_) {},
            onMutationQueued: () => mutations++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final target = teacherSyllabusRows.singleWhere(
      (row) => row.className == 'JSS 2A' && row.week == 6,
    );
    expect(target.approvedStatus, TeacherSyllabusStatus.current);

    final completeButtons = find.text('Mark complete');
    await tester.ensureVisible(completeButtons.at(5));
    await tester.tap(completeButtons.at(5));
    await tester.pumpAndSettle();

    expect(fake.progress['JSS 2A-W6']?.reportedStatus, TeacherSyllabusStatus.completed);
    expect(target.approvedStatus, TeacherSyllabusStatus.current);
    expect(find.textContaining('teacher reported'), findsWidgets);
    expect(mutations, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Syllabus routes lesson planning and AI actions correctly', (
    tester,
  ) async {
    String? destination;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherSyllabusPage(
            repository: _FakeSyllabusRepository(),
            onNavigate: (value) => destination = value,
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Lesson plans'));
    await tester.pump();
    expect(destination, 'lesson-plans');

    await tester.ensureVisible(find.text('Ask AI for pacing plan'));
    await tester.tap(find.text('Ask AI for pacing plan'));
    await tester.pump();
    expect(destination, 'ai');
  });

  testWidgets('Syllabus renders on phone without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherSyllabusPage(
            repository: _FakeSyllabusRepository(),
            onNavigate: (_) {},
            onMutationQueued: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Syllabus Tracker'), findsOneWidget);
    expect(find.text('Scheme of work'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeSyllabusRepository implements TeacherSyllabusRepository {
  final Map<String, TeacherSyllabusProgressRecord> progress = {};
  final List<TeacherSyllabusProgressEvent> events = [];

  @override
  TeacherSyllabusPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherSyllabusPermissions(
      canViewAssignedScheme: teacher,
      canReportCoverage: teacher,
      canEditApprovedScheme: false,
      canReorderTopics: false,
      canConfirmLeadershipApproval: false,
    );
  }

  @override
  Future<TeacherSyllabusSnapshot> load() async => TeacherSyllabusSnapshot(
        rows: teacherSyllabusRows,
        progress: Map<String, TeacherSyllabusProgressRecord>.from(progress),
        events: List<TeacherSyllabusProgressEvent>.from(events),
        permissions: permissionsFor(
          const SchoolMembership(
            id: 'teacher-1',
            schoolId: 'school-1',
            schoolName: 'BrightGate Academy',
            role: SchoolRole.teacher,
          ),
        ),
      );

  @override
  Future<TeacherSyllabusActionResult> markStatus({
    required TeacherSyllabusRow row,
    required TeacherSyllabusStatus status,
  }) async {
    final oldVersion = progress[row.id]?.version ?? 0;
    final record = TeacherSyllabusProgressRecord(
      id: row.id,
      className: row.className,
      week: row.week,
      reportedStatus: status,
      actorMembershipId: 'teacher-1',
      version: oldVersion + 1,
      updatedAt: '2026-09-20T04:30:00Z',
    );
    progress[row.id] = record;
    events.add(
      TeacherSyllabusProgressEvent(
        id: 'event-${row.id}-${record.version}',
        recordId: row.id,
        action: status == TeacherSyllabusStatus.completed
            ? TeacherSyllabusProgressAction.markedComplete
            : TeacherSyllabusProgressAction.markedInProgress,
        actorMembershipId: 'teacher-1',
        version: record.version,
        occurredAt: '2026-09-20T04:30:00Z',
      ),
    );
    return TeacherSyllabusActionResult(
      success: true,
      message: 'Coverage updated locally. The approved scheme itself was not changed.',
      record: record,
    );
  }
}
