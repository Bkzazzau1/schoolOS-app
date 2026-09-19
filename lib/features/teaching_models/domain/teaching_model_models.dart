enum TeachingModelType {
  classTeacher('Class Teacher'),
  subjectTeacher('Subject Teacher'),
  hybrid('Hybrid');

  const TeachingModelType(this.label);
  final String label;
}

class TeachingClassConfig {
  const TeachingClassConfig({
    required this.id,
    required this.section,
    required this.className,
    required this.model,
    required this.leadTeacher,
    required this.specialistCoverage,
    required this.note,
  });

  final String id;
  final String section;
  final String className;
  final TeachingModelType model;
  final String leadTeacher;
  final String specialistCoverage;
  final String note;

  TeachingClassConfig copyWith({TeachingModelType? model}) => TeachingClassConfig(
        id: id,
        section: section,
        className: className,
        model: model ?? this.model,
        leadTeacher: leadTeacher,
        specialistCoverage: specialistCoverage,
        note: note,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'section': section,
        'className': className,
        'model': model.name,
        'leadTeacher': leadTeacher,
        'specialistCoverage': specialistCoverage,
        'note': note,
      };

  factory TeachingClassConfig.fromJson(Map<String, dynamic> json) =>
      TeachingClassConfig(
        id: json['id'] as String,
        section: json['section'] as String,
        className: json['className'] as String,
        model: TeachingModelType.values.byName(json['model'] as String),
        leadTeacher: json['leadTeacher'] as String,
        specialistCoverage: json['specialistCoverage'] as String,
        note: json['note'] as String,
      );
}

class TeachingModelInfo {
  const TeachingModelInfo({
    required this.model,
    required this.summary,
    required this.bestFit,
  });

  final TeachingModelType model;
  final String summary;
  final String bestFit;
}

class TeachingModelStat {
  const TeachingModelStat(this.label, this.value, this.detail);

  final String label;
  final String value;
  final String detail;
}

class TeachingModelPermissions {
  const TeachingModelPermissions({required this.canConfigureAllSections});

  final bool canConfigureAllSections;
}
