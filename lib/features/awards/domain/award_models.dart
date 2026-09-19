enum AwardRecipientType {
  student('Student'),
  teacher('Teacher'),
  team('Team'),
  house('House'),
  club('Club'),
  staff('Staff');

  const AwardRecipientType(this.label);
  final String label;
}

enum AwardVisibility {
  schoolAndParents('School + parents'),
  publicShowcase('Public showcase'),
  internalOnly('Internal only');

  const AwardVisibility(this.label);
  final String label;
}

class AwardRecognition {
  const AwardRecognition({
    required this.id,
    required this.title,
    required this.recipient,
    required this.recipientType,
    required this.section,
    required this.category,
    required this.citation,
    required this.issuer,
    required this.date,
    required this.visibility,
    required this.badge,
  });

  final String id;
  final String title;
  final String recipient;
  final AwardRecipientType recipientType;
  final String section;
  final String category;
  final String citation;
  final String issuer;
  final String date;
  final AwardVisibility visibility;
  final String badge;

  bool get isPublic => visibility == AwardVisibility.publicShowcase;

  bool matches(
    String query, {
    AwardRecipientType? recipientTypeFilter,
    AwardVisibility? visibilityFilter,
  }) {
    if (recipientTypeFilter != null && recipientType != recipientTypeFilter) {
      return false;
    }
    if (visibilityFilter != null && visibility != visibilityFilter) {
      return false;
    }
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return '$title $recipient $section $category'
        .toLowerCase()
        .contains(normalized);
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'recipient': recipient,
        'recipientType': recipientType.name,
        'section': section,
        'category': category,
        'citation': citation,
        'issuer': issuer,
        'date': date,
        'visibility': visibility.name,
        'badge': badge,
      };

  factory AwardRecognition.fromJson(Map<String, dynamic> json) =>
      AwardRecognition(
        id: json['id'] as String,
        title: json['title'] as String,
        recipient: json['recipient'] as String,
        recipientType:
            AwardRecipientType.values.byName(json['recipientType'] as String),
        section: json['section'] as String,
        category: json['category'] as String,
        citation: json['citation'] as String,
        issuer: json['issuer'] as String,
        date: json['date'] as String,
        visibility: AwardVisibility.values.byName(json['visibility'] as String),
        badge: json['badge'] as String,
      );
}

class AwardStat {
  const AwardStat(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
}

class AwardPermissions {
  const AwardPermissions({required this.canCreateDrafts});
  final bool canCreateDrafts;
}
