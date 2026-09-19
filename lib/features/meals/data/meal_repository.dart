import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/meal_models.dart';
import 'meal_demo_data.dart';

class MealSnapshot {
  const MealSnapshot({required this.meals, required this.permissions});

  final List<SchoolMealDay> meals;
  final MealPermissions permissions;
}

class MealActionResult {
  const MealActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class MealRepository {
  MealRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'school_meal_day';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  MealPermissions permissionsFor(SchoolMembership membership) {
    return MealPermissions(canEditMenu: membership.role == SchoolRole.proprietor);
  }

  Future<MealSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final meal in mealWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _entityType,
          entityId: meal.day.toLowerCase(),
          payload: meal.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _entityType,
      );
    }

    final dayOrder = <String, int>{
      'Monday': 0,
      'Tuesday': 1,
      'Wednesday': 2,
      'Thursday': 3,
      'Friday': 4,
    };
    final meals = records
        .map((record) => SchoolMealDay.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) =>
          (dayOrder[a.day] ?? 99).compareTo(dayOrder[b.day] ?? 99));

    return MealSnapshot(
      meals: meals,
      permissions: permissionsFor(membership),
    );
  }

  Future<MealActionResult> updateMenuDay(SchoolMealDay meal) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canEditMenu) {
      return const MealActionResult(
        success: false,
        message: 'This membership cannot edit the school meal menu.',
      );
    }

    if (meal.breakfast.trim().isEmpty ||
        meal.lunch.trim().isEmpty ||
        meal.snack.trim().isEmpty) {
      return const MealActionResult(
        success: false,
        message: 'Breakfast, lunch and snack are required.',
      );
    }
    if (meal.servings < 0) {
      return const MealActionResult(
        success: false,
        message: 'Servings cannot be negative.',
      );
    }

    final entityId = meal.day.toLowerCase();
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: entityId,
      payload: meal.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: entityId,
      operation: SyncOperation.update,
      payload: meal.toJson(),
    );

    return const MealActionResult(
      success: true,
      message: 'Menu changes saved offline and queued for sync.',
    );
  }
}
