import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/meals/data/meal_policy_copy.dart';
import 'package:schoolos_app/features/meals/domain/meal_models.dart';

List<SchoolMealDay> _meals() => const [
      SchoolMealDay(
        day: 'Monday',
        breakfast: 'Pap + akara',
        lunch: 'Jollof rice + chicken + vegetables',
        snack: 'Fruit',
        servings: 412,
        status: MealServiceStatus.completed,
        note: 'Standard school menu.',
      ),
      SchoolMealDay(
        day: 'Wednesday',
        breakfast: 'Moi-moi + pap',
        lunch: 'Rice + stew + fish',
        snack: 'Fruit',
        servings: 418,
        status: MealServiceStatus.serving,
        note: 'Sample service schedule.',
      ),
      SchoolMealDay(
        day: 'Friday',
        breakfast: 'Tea + bread',
        lunch: 'Fried rice + chicken',
        snack: 'Fruit',
        servings: 398,
        status: MealServiceStatus.planned,
        note: 'Friday service can follow the school timetable configured by the tenant.',
      ),
    ];

void main() {
  test('mealWeekdays names the real five school days in order', () {
    expect(mealWeekdays, ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']);
  });

  test('SchoolMealDay.unset is honestly empty and never reports as set', () {
    final unset = SchoolMealDay.unset('Tuesday');
    expect(unset.day, 'Tuesday');
    expect(unset.isSet, isFalse);
    expect(unset.breakfast, isEmpty);
    expect(unset.servings, 0);
  });

  test('a real saved day always reports as set', () {
    expect(_meals().first.isSet, isTrue);
  });

  test('meal stats are computed from the real meals/selection given, never a fixed sample', () {
    final meals = _meals();
    final stats = mealStats(meals, meals[1]);
    expect(stats[0].value, '3/5 days');
    expect(stats[1].value, '418');
    expect(stats[1].detail, 'Wednesday');

    final empty = mealStats(const [], SchoolMealDay.unset('Tuesday'));
    expect(empty[0].value, '0/5 days');
    expect(empty[1].value, '—');
  });

  test('meal locations and special flags stay honestly unavailable', () {
    final stats = mealStats(_meals(), _meals().first);
    expect(stats[2].value, '—');
    expect(stats[2].detail, 'Not available yet');
    expect(stats[3].value, '—');
    expect(stats[4].value, 'Later');
  });

  test('menu search covers day and meal content', () {
    final meals = _meals();
    expect(meals.where((meal) => meal.matches('jollof')), hasLength(1));
    expect(meals.where((meal) => meal.matches('Friday')).single.lunch, 'Fried rice + chicken');
    expect(meals.where((meal) => meal.matches('fruit')), hasLength(3));
  });

  test('meal serialization preserves only general menu fields', () {
    final source = _meals().first;
    final json = source.toJson();
    final restored = SchoolMealDay.fromJson(json);
    expect(restored.day, source.day);
    expect(restored.servings, source.servings);
    expect(restored.status, source.status);
    expect(json.keys, isNot(contains('allergy')));
    expect(json.keys, isNot(contains('diagnosis')));
    expect(json.keys, isNot(contains('religion')));
    expect(json.keys, isNot(contains('medicalHistory')));
  });

  test('privacy rule keeps sensitive child details restricted', () {
    expect(mealPrivacyRule, contains('allergy'));
    expect(mealPrivacyRule, contains('diagnosis'));
    expect(mealPrivacyRule, contains('religion'));
    expect(mealPrivacyRule, contains('medical history'));
    expect(mealPrivacyRule, contains('minimum meal-related instruction'));
  });
}
