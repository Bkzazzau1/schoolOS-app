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
      );
}

class GalleryStat {
  const GalleryStat(this.label, this.value, this.detail);

  final String label;
  final String value;
  final String detail;
}

class GalleryPermissions {
  const GalleryPermissions({required this.canApproveVisibility});

  final bool canApproveVisibility;
}
