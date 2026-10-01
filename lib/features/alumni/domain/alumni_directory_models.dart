/// A deliberately narrow, public-facing subset of a real, verified alumnus's profile - the same
/// restraint the server's own `AlumniDirectoryEntrySerializer` applies: never the private fields
/// (admission number, original student reference, email) [AlumniProfileRecord] carries for the
/// person's own self-view.
class AlumniDirectoryEntry {
  const AlumniDirectoryEntry({
    required this.membershipId,
    required this.name,
    required this.graduationYear,
    required this.graduationSet,
    required this.profession,
    required this.organisation,
    required this.locationText,
    required this.bio,
  });

  final String membershipId;
  final String name;
  final int? graduationYear;
  final String graduationSet;
  final String profession;
  final String organisation;
  final String locationText;
  final String bio;

  factory AlumniDirectoryEntry.fromJson(Map<String, dynamic> json) => AlumniDirectoryEntry(
        membershipId: json['membershipId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        graduationYear: json['graduationYear'] as int?,
        graduationSet: json['graduationSet'] as String? ?? '',
        profession: json['profession'] as String? ?? '',
        organisation: json['organisation'] as String? ?? '',
        locationText: json['locationText'] as String? ?? '',
        bio: json['bio'] as String? ?? '',
      );

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '$name $profession $organisation'.toLowerCase().contains(q);
  }
}
