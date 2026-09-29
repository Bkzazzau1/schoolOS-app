// Reading the server's JSON without trusting its shape: a missing or odd field becomes an empty value. The same
// small helpers `lib/features/bankconnect/domain/json_read.dart` defines for feature code - kept as its own copy
// here so `lib/core` never depends on a feature folder.

DateTime? readTime(Object? value) => value is String ? DateTime.tryParse(value) : null;

Map<String, dynamic> readMap(Object? value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> readMaps(Object? value) => value is List ? [for (final item in value) readMap(item)] : const [];
