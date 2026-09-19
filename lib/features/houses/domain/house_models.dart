class SchoolHouse {
  const SchoolHouse({
    required this.id,
    required this.name,
    required this.captain,
    required this.coordinator,
    required this.members,
    required this.points,
    required this.sports,
    required this.academicCompetitions,
    required this.service,
    required this.status,
  });

  final String id;
  final String name;
  final String captain;
  final String coordinator;
  final int members;
  final int points;
  final int sports;
  final int academicCompetitions;
  final int service;
  final String status;

  int get componentTotal => sports + academicCompetitions + service;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return '$name $captain $coordinator'.toLowerCase().contains(normalized);
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'captain': captain,
        'coordinator': coordinator,
        'members': members,
        'points': points,
        'sports': sports,
        'academicCompetitions': academicCompetitions,
        'service': service,
        'status': status,
      };

  factory SchoolHouse.fromJson(Map<String, dynamic> json) => SchoolHouse(
        id: json['id'] as String,
        name: json['name'] as String,
        captain: json['captain'] as String,
        coordinator: json['coordinator'] as String,
        members: json['members'] as int,
        points: json['points'] as int,
        sports: json['sports'] as int,
        academicCompetitions: json['academicCompetitions'] as int,
        service: json['service'] as int,
        status: json['status'] as String,
      );
}

class HouseKpi {
  const HouseKpi(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
}

class HousePermissions {
  const HousePermissions({required this.canManageAll});
  final bool canManageAll;
}
