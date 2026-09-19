import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/meals/data/meal_demo_data.dart';
import 'package:schoolos_app/features/meals/domain/meal_models.dart';

void main() {
  test('website meal seed has five school days', () {
    expect(mealWebsiteSeed, hasLength(5));
    expect(mealWebsiteSeed.map((meal) => meal.day).toList(), [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
    ]);
  });

  test('Wednesday preserves the website serving sample', () {
    final wednesday = mealWebsiteSeed[2];
    expect(wednesday.day, 'Wednesday');
    expect(wednesday.servings, 418);
    expect(wednesday.status, MealServiceStatus.serving);
    expect(wednesday.breakfast, 'Moi-moi + pap');
    expect(wednesday.lunch, 'Rice + stew + fish');
  });

  test('website cafeteria KPI scope remains stable', () {
    final stats = mealStats(mealWebsiteSeed, mealWebsiteSeed[2]);
    expect(stats[0].value, '5 days');
    expect(stats[1].value, '418');
    expect(mealLocations, 2);
    expect(specialMealFlags, 7);
    expect(mealPaymentIntegration, 'Later');
  });

  test('menu search covers day and meal content', () {
    expect(mealWebsiteSeed.where((meal) => meal.matches('plantain')), hasLength(1));
    expect(mealWebsiteSeed.where((meal) => meal.matches('Friday')).single.lunch,
        'Fried rice + chicken');
    expect(mealWebsiteSeed.where((meal) => meal.matches('fruit')), hasLength(4));
  });

  test('meal serialization preserves only general menu fields', () {
    final source = mealWebsiteSeed.first;
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
