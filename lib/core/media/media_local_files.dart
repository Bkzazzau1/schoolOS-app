import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A picked or captured file's bytes, already safe in this app's own storage under a random name of SchoolOS's
/// own choosing - never the device's own path or a picker's temporary handle, which can stop working the moment
/// that screen closes. Its checksum is taken here, once, from the bytes that were actually written.
class CopiedMediaFile {
  const CopiedMediaFile({required this.localPath, required this.byteSize, required this.sha256});

  final String localPath;
  final int byteSize;
  final String sha256;
}

/// Copies a file's bytes into this app's own storage, and reads them back for sending. The one place in the app
/// that touches a queued upload's bytes on disk.
class MediaLocalFiles {
  /// [rootDirectory] is for tests (a temp folder of their own); the app leaves it out and gets its own folder in
  /// the platform's private support directory, the same base [LocalDatabase] uses for its database file.
  const MediaLocalFiles({Future<Directory> Function()? rootDirectory}) : _rootDirectory = rootDirectory;

  final Future<Directory> Function()? _rootDirectory;

  Future<Directory> _directory() async {
    final root = _rootDirectory != null ? await _rootDirectory() : await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, 'media_uploads'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<CopiedMediaFile> copyIntoAppStorage(Uint8List bytes, {required String suggestedExtension}) async {
    final dir = await _directory();
    final name = '${DateTime.now().microsecondsSinceEpoch}-${_randomSuffix()}$suggestedExtension';
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return CopiedMediaFile(localPath: file.path, byteSize: bytes.length, sha256: crypto.sha256.convert(bytes).toString());
  }

  Future<Uint8List> read(String localPath) => File(localPath).readAsBytes();

  Future<bool> exists(String localPath) => File(localPath).exists();

  /// Forgets a file's local copy once the server has it for good (or once its queued upload was cancelled).
  /// Never called for anything still `waiting`/`uploading` - see media_upload_queue.dart.
  Future<void> delete(String localPath) async {
    final file = File(localPath);
    if (await file.exists()) await file.delete();
  }
}

String _randomSuffix() {
  final random = Random.secure();
  return List<int>.generate(8, (_) => random.nextInt(256)).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
