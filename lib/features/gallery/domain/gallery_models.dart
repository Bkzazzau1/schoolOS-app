enum GalleryVisibility {
  internal('Internal'),
  parents('Parents'),
  publicShowcase('Public showcase');

  const GalleryVisibility(this.label);
  final String label;
}

class GalleryMediaItem {
  const GalleryMediaItem({
    required this.id,
    required this.title,
    required this.album,
    required this.audience,
    required this.owner,
    required this.date,
    required this.count,
    required this.visibility,
    required this.consent,
    required this.note,
    this.termId = '',
    this.termName = '',
    this.sessionName = '',
    this.classId = '',
    this.className = '',
    this.excursionId = '',
    this.excursionTitle = '',
  });

  final String id;
  final String title;
  final String album;
  final String audience;
  final String owner;
  final String date;
  final int count;
  final GalleryVisibility visibility;
  final String consent;
  final String note;

  /// The real academic term these media were taken in. Empty only for
  /// albums recorded before this link existed.
  final String termId;
  final String termName;
  final String sessionName;

  /// Which class this album is for, when it is one real class rather than
  /// a whole-school or club event. Empty when there is no single class.
  final String classId;
  final String className;

  /// The excursion this album is the photos for, when it is one - this is
  /// "the album in the excursion". Empty for albums not tied to a trip.
  final String excursionId;
  final String excursionTitle;

  /// True once this album has a real academic term, not just a free-text
  /// album label. Albums seeded before the term link existed may not.
  bool get hasCanonicalTerm => termId.isNotEmpty;

  bool matches(String query, GalleryVisibility? visibilityFilter) {
    final normalized = query.trim().toLowerCase();
    final haystack = '$title $album $owner'.toLowerCase();
    final queryMatches = normalized.isEmpty || haystack.contains(normalized);
    final visibilityMatches = visibilityFilter == null || visibility == visibilityFilter;
    return queryMatches && visibilityMatches;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'album': album,
        'audience': audience,
        'owner': owner,
        'date': date,
        'count': count,
        'visibility': visibility.name,
        'consent': consent,
        'note': note,
        'termId': termId,
        'termName': termName,
        'sessionName': sessionName,
        'classId': classId,
        'className': className,
        'excursionId': excursionId,
        'excursionTitle': excursionTitle,
      };

  factory GalleryMediaItem.fromJson(Map<String, dynamic> json) => GalleryMediaItem(
        id: json['id'] as String,
        title: json['title'] as String,
        album: json['album'] as String,
        audience: json['audience'] as String,
        owner: json['owner'] as String,
        date: json['date'] as String,
        count: json['count'] as int,
        visibility: GalleryVisibility.values.byName(json['visibility'] as String),
        consent: json['consent'] as String,
        note: json['note'] as String,
        termId: json['termId'] as String? ?? '',
        termName: json['termName'] as String? ?? '',
        sessionName: json['sessionName'] as String? ?? '',
        classId: json['classId'] as String? ?? '',
        className: json['className'] as String? ?? '',
        excursionId: json['excursionId'] as String? ?? '',
        excursionTitle: json['excursionTitle'] as String? ?? '',
      );
}

class GalleryStat {
  const GalleryStat(this.label, this.value, this.detail);

  final String label;
  final String value;
  final String detail;
}

class GalleryPermissions {
  const GalleryPermissions({
    required this.canManage,
    required this.canContribute,
    required this.canApproveVisibility,
  });

  /// Proprietor, Principal or Administrator: may add or edit any album.
  final bool canManage;

  /// Teacher or Staff: may add an album and edit only the ones they added.
  final bool canContribute;

  /// Proprietor or Principal only: making an album a public showcase is a
  /// leadership call, matching the backend's guarded value.
  final bool canApproveVisibility;

  bool get canCreateAlbum => canManage || canContribute;
}
