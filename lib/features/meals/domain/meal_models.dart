enum MealServiceStatus {
  planned('Planned'),
  serving('Serving'),
  completed('Completed');

  const MealServiceStatus(this.label);
  final String label;
}

class SchoolMealDay {
  const SchoolMealDay({
    required this.day,
    required this.breakfast,
    required this.lunch,
    required this.snack,
    required this.servings,
    required this.status,
    required this.note,
  });

  final String day;
  final String breakfast;
  final String lunch;
  final String snack;
  final int servings;
  final MealServiceStatus status;
  final String note;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return '$day $breakfast $lunch $snack'.toLowerCase().contains(normalized);
  }

  SchoolMealDay copyWith({
    String? breakfast,
    String? lunch,
    String? snack,
    int? servings,
    MealServiceStatus? status,
    String? note,
  }) {
    return SchoolMealDay(
      day: day,
      breakfast: breakfast ?? this.breakfast,
      lunch: lunch ?? this.lunch,
      snack: snack ?? this.snack,
      servings: servings ?? this.servings,
      status: status ?? this.status,
      note: note ?? this.note,
    );
  }

  Map<String, Object?> toJson() => {
        'day': day,
        'breakfast': breakfast,
        'lunch': lunch,
        'snack': snack,
        'servings': servings,
        'status': status.name,
        'note': note,
      };

  factory SchoolMealDay.fromJson(Map<String, dynamic> json) => SchoolMealDay(
        day: json['day'] as String,
        breakfast: json['breakfast'] as String,
        lunch: json['lunch'] as String,
        snack: json['snack'] as String,
        servings: json['servings'] as int,
        status: MealServiceStatus.values.byName(json['status'] as String),
        note: json['note'] as String,
      );
}

class MealStat {
  const MealStat(this.label, this.value, this.detail);

  final String label;
  final String value;
  final String detail;
}

class MealPermissions {
  const MealPermissions({required this.canEditMenu});

  final bool canEditMenu;
}
