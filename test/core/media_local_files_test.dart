import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/media/media_local_files.dart';

void main() {
  late Directory tempRoot;
  late MediaLocalFiles files;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('media_local_files_test_');
    files = MediaLocalFiles(rootDirectory: () async => tempRoot);
  });

  tearDown(() => tempRoot.deleteSync(recursive: true));

  test('a copy holds exactly the bytes given, with their real size and checksum', () async {
    final bytes = Uint8List.fromList(List<int>.generate(5000, (i) => i % 256));
    final copied = await files.copyIntoAppStorage(bytes, suggestedExtension: '.png');
    expect(copied.byteSize, 5000);
    expect(copied.sha256, crypto.sha256.convert(bytes).toString());
    expect(await File(copied.localPath).readAsBytes(), bytes);
    expect(copied.localPath, endsWith('.png'));
  });

  test('the copy lives under this apps own storage, never wherever the caller happened to point', () async {
    final copied = await files.copyIntoAppStorage(Uint8List.fromList([1, 2, 3]), suggestedExtension: '.jpg');
    expect(copied.localPath, contains('media_uploads'));
    expect(copied.localPath, isNot(contains('..')));
  });

  test('two copies never collide, even with identical bytes', () async {
    final bytes = Uint8List.fromList([9, 9, 9]);
    final first = await files.copyIntoAppStorage(bytes, suggestedExtension: '.png');
    final second = await files.copyIntoAppStorage(bytes, suggestedExtension: '.png');
    expect(first.localPath, isNot(second.localPath));
  });

  test('exists and read agree with what was actually written, and a missing path is honestly missing', () async {
    final copied = await files.copyIntoAppStorage(Uint8List.fromList([1, 2, 3]), suggestedExtension: '.png');
    expect(await files.exists(copied.localPath), isTrue);
    expect(await files.read(copied.localPath), [1, 2, 3]);
    expect(await files.exists('${tempRoot.path}/media_uploads/never-written.png'), isFalse);
  });

  test('deleting removes the file, and deleting an already-gone one is not an error', () async {
    final copied = await files.copyIntoAppStorage(Uint8List.fromList([1]), suggestedExtension: '.png');
    await files.delete(copied.localPath);
    expect(await files.exists(copied.localPath), isFalse);
    await files.delete(copied.localPath); // must not throw
  });
}
