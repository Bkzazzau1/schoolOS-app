import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/auth/app_capability.dart';
import 'package:schoolos_app/edge_ai/models/edge_model_manifest.dart';
import 'package:schoolos_app/features/attendance/domain/attendance_models.dart';
import 'package:schoolos_app/features/lesson_plans/data/lesson_plan_generation_service.dart';
import 'package:schoolos_app/features/lesson_plans/domain/lesson_plan_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

void main() {
  test('school membership preserves tenant-specific role', () {
    const membership = SchoolMembership(
      id: 'membership-1',
      schoolId: 'school-a',
      schoolName: 'School A',
      role: SchoolRole.teacher,
    );

    final restored = SchoolMembership.fromJson(membership.toJson());

    expect(restored.id, membership.id);
    expect(restored.schoolId, 'school-a');
    expect(restored.role, SchoolRole.teacher);
    expect(restored.roleLabel, 'Teacher');
  });

  test('parent membership cannot inherit teacher-only capabilities', () {
    expect(
      RolePermissions.can(SchoolRole.parent, AppCapability.attendance),
      isFalse,
    );
    expect(
      RolePermissions.can(SchoolRole.parent, AppCapability.lessonPlans),
      isFalse,
    );
    expect(
      RolePermissions.can(SchoolRole.teacher, AppCapability.lessonPlans),
      isTrue,
    );
  });

  test('attendance entry changes status without changing student identity', () {
    const student = AttendanceStudent(
      id: 'student-1',
      admissionNumber: 'J1A-001',
      name: 'Aisha Musa',
    );
    const entry = AttendanceEntry(
      student: student,
      status: AttendanceStatus.present,
    );

    final absent = entry.copyWith(status: AttendanceStatus.absent);

    expect(absent.student.id, 'student-1');
    expect(absent.status, AttendanceStatus.absent);
    expect(absent.toJson()['status'], 'absent');
  });

  test('lesson plan remains available without edge or cloud AI', () async {
    const service = LessonPlanGenerationService();
    const request = LessonPlanRequest(
      schoolId: 'school-a',
      className: 'JSS 2',
      subject: 'Basic Science',
      topic: 'Photosynthesis',
      durationMinutes: 40,
      term: 'First Term',
      week: 5,
    );

    final result = await service.generate(
      request,
      tryEdgeAi: true,
      tryCloud: true,
    );

    expect(result.draft.mode, LessonPlanGenerationMode.offlineTemplate);
    expect(result.draft.objectives, isNotEmpty);
    expect(result.draft.teacherActivities, isNotEmpty);
    expect(result.usedEdgeAi, isFalse);
    expect(result.usedCloud, isFalse);
    expect(result.fallbackMessage, isNotNull);
  });

  test('edge model manifest preserves versioned capability metadata', () {
    const manifest = EdgeModelManifest(
      id: 'schoolos-lesson-plan-small',
      version: '1.0.0',
      capability: EdgeAiCapability.lessonPlanText,
      format: EdgeModelFormat.onnx,
      fileName: 'lesson-plan-small.onnx',
      sha256: 'abc123',
      sizeBytes: 1024,
      minimumRamMb: 2048,
    );

    final restored = EdgeModelManifest.fromJson(manifest.toJson());

    expect(restored.installationKey, 'schoolos-lesson-plan-small@1.0.0');
    expect(restored.capability, EdgeAiCapability.lessonPlanText);
    expect(restored.format, EdgeModelFormat.onnx);
    expect(restored.windowsSupported, isTrue);
    expect(restored.androidSupported, isTrue);
  });
}
