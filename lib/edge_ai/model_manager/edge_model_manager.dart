import '../models/edge_model_manifest.dart';

enum EdgeModelInstallState {
  notInstalled,
  installing,
  ready,
  incompatible,
  corrupt,
  updateAvailable,
}

class InstalledEdgeModel {
  const InstalledEdgeModel({
    required this.manifest,
    required this.localPath,
    required this.installedAt,
    required this.state,
  });

  final EdgeModelManifest manifest;
  final String localPath;
  final DateTime installedAt;
  final EdgeModelInstallState state;
}

/// Owns model lifecycle, not inference.
///
/// The implementation must verify model integrity before marking a model
/// ready, keep versions explicit, and never silently execute an unverified
/// file. Feature code asks for a capability and does not care where the model
/// file lives.
abstract interface class EdgeModelManager {
  Future<List<InstalledEdgeModel>> installedModels();

  Future<InstalledEdgeModel?> bestAvailable(EdgeAiCapability capability);

  Future<EdgeModelInstallState> status(EdgeModelManifest manifest);

  Future<InstalledEdgeModel> installVerifiedModel({
    required EdgeModelManifest manifest,
    required String sourcePath,
  });

  Future<void> removeModel(String installationKey);
}
