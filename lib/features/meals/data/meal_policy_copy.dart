import '../domain/meal_models.dart';

/// The real, fixed shape of a school week - a fact about calendars, not data about any particular
/// school - used to show every weekday as its own slot even before a school has set that day's menu.
const mealWeekdays = <String>['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

const mealPrivacyRule =
    'The general cafeteria page should not expose a child\'s allergy, diagnosis, religion or medical history. Staff receive only the minimum meal-related instruction necessary for safe service.';

/// Computed from [meals] - the real, locally-held menu days a school has actually set, never a
/// fixed sample week. "Meal locations" and "special meal flags" stay honestly unavailable: nothing
/// in the app tracks either yet, the same way meal payments already say so.
List<MealStat> mealStats(List<SchoolMealDay> meals, SchoolMealDay selected) => [
      MealStat('Weekly menu', '${meals.length}/${mealWeekdays.length} days', 'Configured so far this week'),
      MealStat(
        'Selected-day servings',
        selected.isSet ? '${selected.servings}' : '—',
        selected.isSet ? selected.day : '${selected.day} not set yet',
      ),
      const MealStat('Meal locations', '—', 'Not available yet'),
      const MealStat('Special meal flags', '—', 'Not available yet'),
      const MealStat('Meal payments', 'Later', 'Not available yet'),
    ];
