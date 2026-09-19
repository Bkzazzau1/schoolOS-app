import '../domain/meal_models.dart';

const mealWebsiteSeed = <SchoolMealDay>[
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
    day: 'Tuesday',
    breakfast: 'Tea + bread + egg',
    lunch: 'Beans + plantain',
    snack: 'Yoghurt / fruit',
    servings: 405,
    status: MealServiceStatus.completed,
    note: 'Alternative meal requests handled privately where configured.',
  ),
  SchoolMealDay(
    day: 'Wednesday',
    breakfast: 'Moi-moi + pap',
    lunch: 'Rice + stew + fish',
    snack: 'Fruit',
    servings: 418,
    status: MealServiceStatus.serving,
    note: 'Sample active-service state in this prototype; the selected day is not tied to the current calendar date.',
  ),
  SchoolMealDay(
    day: 'Thursday',
    breakfast: 'Oats + milk',
    lunch: 'Yam porridge + vegetables',
    snack: 'Biscuit + drink',
    servings: 410,
    status: MealServiceStatus.planned,
    note: 'Menu can vary by school policy.',
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

const mealLocations = 2;
const specialMealFlags = 7;
const mealPaymentIntegration = 'Later';
const mealPrivacyRule =
    'The general cafeteria page should not expose a child\'s allergy, diagnosis, religion or medical history. Staff receive only the minimum meal-related instruction necessary for safe service.';

List<MealStat> mealStats(
  List<SchoolMealDay> meals,
  SchoolMealDay selected,
) => [
      MealStat('Weekly menu', '${meals.length} days', 'Sample school week'),
      MealStat(
        'Selected-day servings',
        '${selected.servings}',
        '${selected.day} sample',
      ),
      const MealStat('Meal locations', '2', 'Main cafeteria + Early Years'),
      const MealStat('Special meal flags', '7', 'Details restricted'),
      const MealStat('Payment integration', 'Later', 'UI phase only'),
    ];
