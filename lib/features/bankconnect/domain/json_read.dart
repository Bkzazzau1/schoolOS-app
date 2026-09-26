// Reading the server's JSON without trusting its shape: a missing or odd field becomes an empty value.

DateTime? readTime(Object? value) => value is String ? DateTime.tryParse(value) : null;

Map<String, dynamic> readMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> readMaps(Object? value) =>
    value is List ? [for (final item in value) readMap(item)] : const [];
