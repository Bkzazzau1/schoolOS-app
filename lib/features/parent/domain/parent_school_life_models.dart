class ParentSchoolLifeActivity {
  const ParentSchoolLifeActivity({
    required this.childName,
    required this.activity,
    required this.schedule,
    required this.status,
  });

  final String childName;
  final String activity;
  final String schedule;
  final String status;

  Map<String, Object?> toJson() => {
        'childName': childName,
        'activity': activity,
        'schedule': schedule,
        'status': status,
      };

  factory ParentSchoolLifeActivity.fromJson(Map<String, dynamic> json) =>
      ParentSchoolLifeActivity(
        childName: json['childName'] as String? ?? '',
        activity: json['activity'] as String? ?? '',
        schedule: json['schedule'] as String? ?? '',
        status: json['status'] as String? ?? '',
      );
}

class ParentSchoolLifeEvent {
  const ParentSchoolLifeEvent({
    required this.dateLabel,
    required this.title,
    required this.scope,
  });

  final String dateLabel;
  final String title;
  final String scope;

  Map<String, Object?> toJson() => {
        'dateLabel': dateLabel,
        'title': title,
        'scope': scope,
      };

  factory ParentSchoolLifeEvent.fromJson(Map<String, dynamic> json) =>
      ParentSchoolLifeEvent(
        dateLabel: json['dateLabel'] as String? ?? '',
        title: json['title'] as String? ?? '',
        scope: json['scope'] as String? ?? '',
      );
}

class ParentSchoolLifeTransport {
  const ParentSchoolLifeTransport({
    required this.childName,
    required this.serviceCode,
    required this.status,
    required this.guardianSafeSummary,
  });

  final String childName;
  final String serviceCode;
  final String status;
  final String guardianSafeSummary;

  Map<String, Object?> toJson() => {
        'childName': childName,
        'serviceCode': serviceCode,
        'status': status,
        'guardianSafeSummary': guardianSafeSummary,
      };

  factory ParentSchoolLifeTransport.fromJson(Map<String, dynamic> json) =>
      ParentSchoolLifeTransport(
        childName: json['childName'] as String? ?? '',
        serviceCode: json['serviceCode'] as String? ?? '',
        status: json['status'] as String? ?? '',
        guardianSafeSummary: json['guardianSafeSummary'] as String? ?? '',
      );
}

class ParentSchoolLifeMealPlan {
  const ParentSchoolLifeMealPlan({
    required this.childName,
    required this.planLabel,
  });

  final String childName;
  final String planLabel;

  Map<String, Object?> toJson() => {
        'childName': childName,
        'planLabel': planLabel,
      };

  factory ParentSchoolLifeMealPlan.fromJson(Map<String, dynamic> json) =>
      ParentSchoolLifeMealPlan(
        childName: json['childName'] as String? ?? '',
        planLabel: json['planLabel'] as String? ?? '',
      );
}

class ParentSchoolLifeRecognition {
  const ParentSchoolLifeRecognition({
    required this.childName,
    required this.title,
    required this.periodLabel,
  });

  final String childName;
  final String title;
  final String periodLabel;

  Map<String, Object?> toJson() => {
        'childName': childName,
        'title': title,
        'periodLabel': periodLabel,
      };

  factory ParentSchoolLifeRecognition.fromJson(Map<String, dynamic> json) =>
      ParentSchoolLifeRecognition(
        childName: json['childName'] as String? ?? '',
        title: json['title'] as String? ?? '',
        periodLabel: json['periodLabel'] as String? ?? '',
      );
}

class ParentSchoolLifeSnapshot {
  const ParentSchoolLifeSnapshot({
    required this.familyAccountId,
    required this.activities,
    required this.events,
    required this.transport,
    required this.mealPlans,
    required this.todayMeal,
    required this.todayMealService,
    required this.recognition,
  });

  final String familyAccountId;
  final List<ParentSchoolLifeActivity> activities;
  final List<ParentSchoolLifeEvent> events;
  final List<ParentSchoolLifeTransport> transport;
  final List<ParentSchoolLifeMealPlan> mealPlans;
  final String todayMeal;
  final String todayMealService;
  final List<ParentSchoolLifeRecognition> recognition;

  Map<String, Object?> toJson() => {
        'familyAccountId': familyAccountId,
        'activities': activities.map((item) => item.toJson()).toList(),
        'events': events.map((item) => item.toJson()).toList(),
        'transport': transport.map((item) => item.toJson()).toList(),
        'mealPlans': mealPlans.map((item) => item.toJson()).toList(),
        'todayMeal': todayMeal,
        'todayMealService': todayMealService,
        'recognition': recognition.map((item) => item.toJson()).toList(),
      };

  factory ParentSchoolLifeSnapshot.fromJson(Map<String, dynamic> json) =>
      ParentSchoolLifeSnapshot(
        familyAccountId: json['familyAccountId'] as String? ?? '',
        activities: _maps(json['activities'])
            .map(ParentSchoolLifeActivity.fromJson)
            .toList(growable: false),
        events: _maps(json['events'])
            .map(ParentSchoolLifeEvent.fromJson)
            .toList(growable: false),
        transport: _maps(json['transport'])
            .map(ParentSchoolLifeTransport.fromJson)
            .toList(growable: false),
        mealPlans: _maps(json['mealPlans'])
            .map(ParentSchoolLifeMealPlan.fromJson)
            .toList(growable: false),
        todayMeal: json['todayMeal'] as String? ?? '',
        todayMealService: json['todayMealService'] as String? ?? '',
        recognition: _maps(json['recognition'])
            .map(ParentSchoolLifeRecognition.fromJson)
            .toList(growable: false),
      );
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}
