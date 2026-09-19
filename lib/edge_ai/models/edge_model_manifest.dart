enum EdgeAiCapability {
  lessonPlanText,
  ocr,
  documentQuality,
  documentClassification,
  visionDetection,
}

enum EdgeModelFormat {
  onnx,
  tflite,
}

class EdgeModelManifest {
  const EdgeModelManifest({
    required this.id,
    required this.version,
    required this.capability,
    required this.format,
    required this.fileName,
    required this.sha256,
    required this.sizeBytes,
    required this.minimumRamMb,
    this.androidSupported = true,
    this.windowsSupported = true,
  });

  final String id;
  final String version;
  final EdgeAiCapability capability;
  final EdgeModelFormat format;
  final String fileName;
  final String sha256;
  final int sizeBytes;
  final int minimumRamMb;
  final bool androidSupported;
  final bool windowsSupported;

  String get installationKey => '$id@$version';

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'version': version,
      'capability': capability.name,
      'format': format.name,
      'fileName': fileName,
      'sha256': sha256,
      'sizeBytes': sizeBytes,
      'minimumRamMb': minimumRamMb,
      'androidSupported': androidSupported,
      'windowsSupported': windowsSupported,
    };
  }

  factory EdgeModelManifest.fromJson(Map<String, dynamic> json) {
    return EdgeModelManifest(
      id: json['id'] as String,
      version: json['version'] as String,
      capability: EdgeAiCapability.values.byName(json['capability'] as String),
      format: EdgeModelFormat.values.byName(json['format'] as String),
      fileName: json['fileName'] as String,
      sha256: json['sha256'] as String,
      sizeBytes: json['sizeBytes'] as int,
      minimumRamMb: json['minimumRamMb'] as int,
      androidSupported: json['androidSupported'] as bool? ?? true,
      windowsSupported: json['windowsSupported'] as bool? ?? true,
    );
  }
}
