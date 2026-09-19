enum LostFoundStatus {
  unclaimed('Unclaimed'),
  claimReview('Claim review'),
  returned('Returned');

  const LostFoundStatus(this.label);
  final String label;
}

class LostFoundItem {
  const LostFoundItem({
    required this.id,
    required this.item,
    required this.category,
    required this.found,
    required this.date,
    required this.storage,
    required this.status,
    required this.claimant,
    required this.note,
  });

  final String id;
  final String item;
  final String category;
  final String found;
  final String date;
  final String storage;
  final LostFoundStatus status;
  final String claimant;
  final String note;

  bool get isOpen => status != LostFoundStatus.returned;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return '$item $category $found'.toLowerCase().contains(normalized);
  }

  LostFoundItem copyWith({LostFoundStatus? status}) => LostFoundItem(
        id: id,
        item: item,
        category: category,
        found: found,
        date: date,
        storage: storage,
        status: status ?? this.status,
        claimant: claimant,
        note: note,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'item': item,
        'category': category,
        'found': found,
        'date': date,
        'storage': storage,
        'status': status.name,
        'claimant': claimant,
        'note': note,
      };

  factory LostFoundItem.fromJson(Map<String, dynamic> json) => LostFoundItem(
        id: json['id'] as String,
        item: json['item'] as String,
        category: json['category'] as String,
        found: json['found'] as String,
        date: json['date'] as String,
        storage: json['storage'] as String,
        status: LostFoundStatus.values.byName(json['status'] as String),
        claimant: json['claimant'] as String,
        note: json['note'] as String,
      );
}

class LostFoundStat {
  const LostFoundStat(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
}

class LostFoundPermissions {
  const LostFoundPermissions({required this.canManageClaims});
  final bool canManageClaims;
}
