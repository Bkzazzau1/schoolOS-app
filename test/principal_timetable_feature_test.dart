import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/principal/data/principal_timetable_demo_data.dart';
import 'package:schoolos_app/features/principal/domain/principal_timetable_models.dart';

void main() {
  test('principal timetable preserves exact website seed and KPIs', () {
    expect(principalTimetableLessons.length, 11);
    expect(principalTimetableLessonsThisWeek, 186);
    expect(principalTimetableTodayLessons, 38);
    expect(principalTimetableLessons.where((lesson) => lesson.status == PrincipalTimetableStatus.substitution).length, 1);
    expect(principalTimetableLessons.where((lesson) => lesson.status == PrincipalTimetableStatus.uncovered).length, 1);
    expect(principalTimetableLessons.where((lesson) => lesson.status == PrincipalTimetableStatus.clash).length, 1);
  });

  test('website exception lessons retain exact operational evidence', () {
    final substitution = principalTimetableLessons.firstWhere((lesson) => lesson.id == 'TT-103');
    final uncovered = principalTimetableLessons.firstWhere((lesson) => lesson.id == 'TT-104');
    final clash = principalTimetableLessons.firstWhere((lesson) => lesson.id == 'TT-106');

    expect(substitution.className, 'JSS 3A');
    expect(substitution.teacher, 'Mr. Peter James');
    expect(uncovered.subject, 'Physics');
    expect(uncovered.teacher, 'Unassigned');
    expect(uncovered.room, 'Lab 2');
    expect(clash.teacher, 'Mrs. Fatima Bello');
    expect(clash.time, '10:20 - 11:00');
  });

  test('teacher load and room utilization match website', () {
    expect(principalTeacherLoads.length, 5);
    expect(principalTeacherLoads.where((row) => row.status == 'Heavy').length, 2);
    expect(principalTeacherLoads.firstWhere((row) => row.name == 'Mrs. Amina Yusuf').lessons, 24);
    expect(principalTeacherLoads.firstWhere((row) => row.name == 'Mrs. Fatima Bello').lessons, 26);
    expect(principalRoomUtilization.length, 5);
    expect(principalRoomUtilization.firstWhere((row) => row.room == 'B12').utilization, 86);
    expect(principalRoomUtilization.firstWhere((row) => row.room == 'Lab 2').utilization, 50);
  });

  test('timetable lesson and exception audit serialize', () {
    final lesson = PrincipalTimetableLesson.fromJson(principalTimetableLessons.first.toJson());
    expect(lesson.id, 'TT-101');
    expect(lesson.status, PrincipalTimetableStatus.scheduled);

    const state = PrincipalTimetableExceptionState(
      lessonId: 'TT-104',
      handled: true,
      updatedByMembershipId: 'MEM-PRINCIPAL-01',
      updatedAt: '2026-09-19T17:20:00Z',
    );
    final restoredState = PrincipalTimetableExceptionState.fromJson(state.toJson());
    expect(restoredState.handled, isTrue);
    expect(restoredState.updatedByMembershipId, 'MEM-PRINCIPAL-01');

    const event = PrincipalTimetableExceptionEvent(
      id: 'TT-104-1',
      lessonId: 'TT-104',
      action: PrincipalTimetableExceptionAction.handled,
      actorMembershipId: 'MEM-PRINCIPAL-01',
      occurredAt: '2026-09-19T17:20:00Z',
    );
    final restoredEvent = PrincipalTimetableExceptionEvent.fromJson(event.toJson());
    expect(restoredEvent.action, PrincipalTimetableExceptionAction.handled);
    expect(restoredEvent.actorMembershipId, 'MEM-PRINCIPAL-01');
  });

  test('principal timetable authority remains Secondary and exception-only', () {
    expect(principalTimetablePermissions.canViewSecondaryTimetable, isTrue);
    expect(principalTimetablePermissions.canHandleExceptions, isTrue);
    expect(principalTimetablePermissions.canEditScheduleDirectly, isFalse);
    expect(principalTimetablePermissions.canManagePrimary, isFalse);
    expect(principalTimetableAuthorityBoundary, contains('Secondary School'));
    expect(principalTimetableExceptionBoundary, contains('do not silently reassign'));
    expect(principalTimetableExceptionBoundary, contains('change a lesson time'));
    expect(principalTimetableAuditBoundary, contains('timestamp'));
  });

  test('AI can advise on workload but cannot alter timetable', () {
    expect(principalTimetableAiInsight, contains('uncovered Physics lesson'));
    expect(principalTimetableAiInsight, contains('teacher clash'));
    expect(principalTimetableAiInsight, contains('Mrs. Amina Yusuf'));
    expect(principalTimetableAiInsight, contains('Mrs. Fatima Bello'));
    expect(principalTimetableAiBoundary, contains('must not silently alter'));
  });
}
