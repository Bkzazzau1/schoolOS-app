import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/edge_model_manifest.dart';
import 'edge_model_manager.dart';

class FileSystemEdgeModelManager implements EdgeModelManager {
  FileSystemEdgeModelManager();

  Directory? _rootDirectory;

  Future<Directory> _root() async {
    final existing = _rootDirectory;
    if (existing != null) return existing;

    final support = await getApplicationSupportDirectory();
    final root = Directory(p.join(support.path, 'edge_models'));
    await root.create(recursive: true);
    _rootDirectory = root;
    return root;
  }

  @override
  Future<List<InstalledEdgeModel>> installedModels() async {
    final root = await _root();
    final result = <InstalledEdgeModel>[];

    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;

      final metadataFile = File(p.join(entity.path, 'manifest.json'));
      if (!await metadataFile.exists()) continue;

      try {
        final decoded = jsonDecode(await metadataFile.readAsString());
        if (decoded is! Map<String, dynamic>) continue;

        final rawManifest = decoded['manifest'];
        if (rawManifest is! Map) continue;

        final manifest = EdgeModelManifest.fromJson(
          rawManifest.cast<String, dynamic>(),
        );
        final modelPath = p.join(entity.path, p.basename(manifest.fileName));
        final installedAt = DateTime.tryParse(
              decoded['installedAt'] as String? ?? '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        final state = await _validateInstalledFile(manifest, modelPath);

        result.add(
          InstalledEdgeModel(
            manifest: manifest,
            localPath: modelPath,
            installedAt: installedAt,
            state: state,
          ),
        );
      } catch (_) {
        // A broken metadata directory is ignored here. The installer only
        // writes metadata after a verified model file is in place.
      }
    }

    result.sort((a, b) => b.installedAt.compareTo(a.installedAt));
    return result;
  }

  @override
  Future<InstalledEdgeModel?> bestAvailable(
    EdgeAiCapability capability,
  ) async {
    final models = await installedModels();
    for (final model in models) {
      if (model.manifest.capability == capability &&
          model.state == EdgeModelInstallState.ready) {
        return model;
      }
    }
    return null;
  }

  @override
  Future<EdgeModelInstallState> status(EdgeModelManifest manifest) async {
    if (!_supportsCurrentPlatform(manifest)) {
      return EdgeModelInstallState.incompatible;
    }

    final directory = await _installationDirectory(manifest);
    final metadata = File(p.join(directory.path, 'manifest.json'));
    final model = File(p.join(directory.path, p.basename(manifest.fileName)));

    if (!await metadata.exists() || !await model.exists()) {
      return EdgeModelInstallState.notInstalled;
    }

    return _validateInstalledFile(manifest, model.path);
  }

  @override
  Future<InstalledEdgeModel> installVerifiedModel({
    required EdgeModelManifest manifest,
    required String sourcePath,
  }) async {
    if (!_supportsCurrentPlatform(manifest)) {
      throw StateError(
        'Model ${manifest.installationKey} is not compatible with this platform.',
      );
    }

    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Edge model source file does not exist.', sourcePath);
    }

    await _verifyFile(manifest, source);

    final directory = await _installationDirectory(manifest);
    await directory.create(recursive: true);

    final safeFileName = p.basename(manifest.fileName);
    final destination = File(p.join(directory.path, safeFileName));
    final partial = File('${destination.path}.part');

    if (await partial.exists()) await partial.delete();
    await source.copy(partial.path);

    try {
      await _verifyFile(manifest, partial);
      if (await destination.exists()) await destination.delete();
      await partial.rename(destination.path);

      final installedAt = DateTime.now().toUtc();
      final metadata = File(p.join(directory.path, 'manifest.json'));
      await metadata.writeAsString(
        jsonEncode({
          'manifest': manifest.toJson(),
          'installedAt': installedAt.toIso8601String(),
        }),
        flush: true,
      );

      return InstalledEdgeModel(
        manifest: manifest,
        localPath: destination.path,
        installedAt: installedAt,
        state: EdgeModelInstallState.ready,
      );
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }

  @override
  Future<void> removeModel(String installationKey) async {
    final root = await _root();
    final directory = Directory(
      p.join(root.path, _safeSegment(installationKey)),
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<Directory> _installationDirectory(EdgeModelManifest manifest) async {
    final root = await _root();
    return Directory(
      p.join(root.path, _safeSegment(manifest.installationKey)),
    );
  }

  Future<EdgeModelInstallState> _validateInstalledFile(
    EdgeModelManifest manifest,
    String modelPath,
  ) async {
    if (!_supportsCurrentPlatform(manifest)) {
      return EdgeModelInstallState.incompatible;
    }

    final file = File(modelPath);
    if (!await file.exists()) return EdgeModelInstallState.notInstalled;

    try {
      await _verifyFile(manifest, file);
      return EdgeModelInstallState.ready;
    } catch (_) {
      return EdgeModelInstallState.corrupt;
    }
  }

  Future<void> _verifyFile(
    EdgeModelManifest manifest,
    File file,
  ) async {
    final length = await file.length();
    if (manifest.sizeBytes > 0 && length != manifest.sizeBytes) {
      throw StateError(
        'Edge model size mismatch: expected ${manifest.sizeBytes}, got $length.',
      );
    }

    final digest = await crypto.sha256.bind(file.openRead()).first;
    final actualHash = digest.toString();
    final expectedHash = manifest.sha256.trim().toLowerCase();

    if (expectedHash.isEmpty || actualHash != expectedHash) {
      throw StateError('Edge model SHA-256 verification failed.');
    }
  }

  bool _supportsCurrentPlatform(EdgeModelManifest manifest) {
    if (Platform.isAndroid) return manifest.androidSupported;
    if (Platform.isWindows) return manifest.windowsSupported;
    return false;
  }
}

String _safeSegment(String value) {
  return value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
}
