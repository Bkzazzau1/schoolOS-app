import '../../shared/models/school_membership.dart';

enum AppCapability {
  dashboard,
  administration,
  students,
  attendance,
  academics,
  lessonPlans,
  finance,
  messaging,
}

abstract final class RolePermissions {
  static Set<AppCapability> forRole(SchoolRole role) {
    return switch (role) {
      SchoolRole.proprietor => AppCapability.values.toSet(),
      SchoolRole.administrator => {
          AppCapability.dashboard,
          AppCapability.administration,
          AppCapability.students,
          AppCapability.attendance,
          AppCapability.messaging,
        },
      SchoolRole.principal => {
          AppCapability.dashboard,
          AppCapability.students,
          AppCapability.attendance,
          AppCapability.academics,
          AppCapability.lessonPlans,
          AppCapability.finance,
          AppCapability.messaging,
        },
      SchoolRole.teacher => {
          AppCapability.dashboard,
          AppCapability.students,
          AppCapability.attendance,
          AppCapability.academics,
          AppCapability.lessonPlans,
          AppCapability.messaging,
        },
      SchoolRole.accountant => {
          AppCapability.dashboard,
          AppCapability.students,
          AppCapability.finance,
          AppCapability.messaging,
        },
      SchoolRole.parent => {
          AppCapability.dashboard,
          AppCapability.academics,
          AppCapability.messaging,
        },
      SchoolRole.student => {
          AppCapability.dashboard,
          AppCapability.academics,
          AppCapability.messaging,
        },
      SchoolRole.staff => {
          AppCapability.dashboard,
          AppCapability.students,
          AppCapability.messaging,
        },
    };
  }

  static bool can(SchoolRole role, AppCapability capability) {
    return forRole(role).contains(capability);
  }
}
