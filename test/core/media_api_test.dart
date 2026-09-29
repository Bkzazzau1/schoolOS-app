import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:schoolos_app/core/media/media_api.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'backend_test_support.dart';

http.Response rawResponse(List<int> bytes) => http.Response.bytes(bytes, 200);

const schoolId = '22222222-2222-2222-2222-222222222222';
const ownerMembership = SchoolMembership(id: '55555555-5555-5555-5555-555555555555', schoolId: schoolId, schoolName: 'BrightGate', role: SchoolRole.teacher);

Map<String, Object?> assetJson({
  String id = 'asset-1',
  String status = 'available',
  String mediaType = 'image',
  bool hasThumbnail = true,
}) =>
    {
      'id': id, 'ownerType': 'gallery_media_album', 'ownerId': 'album-1', 'category': 'gallery_photo',
      'fileName': 'sports-day.png', 'mimeType': 'image/png', 'mediaType': mediaType, 'byteSize': 4096,
      'visibility': 'school', 'status': status, 'failureCode': '', 'caption': 'The final', 'width': 6, 'height': 4,
      'hasThumbnail': hasThumbnail, 'uploadedByMembershipId': ownerMembership.id, 'createdAt': '2026-09-26T10:00:00+01:00',
      'updatedAt': '2026-09-26T10:00:01+01:00', 'version': 1,
    };

void main() {
  const base = '/api/v1/schools/$schoolId/media/';
  late FakeServer server;
  late MediaApi api;
  var reply = <String, Object?>{};
  var status = 200;

  setUp(() {
    reply = {};
    status = 200;
    server = FakeServer((r) async => jsonResponse(reply, status));
    api = MediaApi(api: apiFor(server));
  });

  String tail(int index) => server.requests[index].url.path.replaceFirst(base, '');
  Map<String, dynamic> body(int index) => jsonDecode(server.requests[index].body) as Map<String, dynamic>;

  test('list asks for one owner and parses every asset', () async {
    reply = {
      'assets': [assetJson(id: 'a1'), assetJson(id: 'a2', status: 'pending_upload', hasThumbnail: false)],
    };
    final assets = await api.list(ownerMembership, ownerType: 'gallery_media_album', ownerId: 'album-1');
    expect(tail(0), 'assets/');
    expect(server.requests.single.url.queryParameters, {'membership': ownerMembership.id, 'ownerType': 'gallery_media_album', 'ownerId': 'album-1'});
    expect(assets.map((a) => a.id), ['a1', 'a2']);
    expect(assets.first.isAvailable, isTrue);
    expect(assets.first.hasThumbnail, isTrue);
    expect(assets.last.isAvailable, isFalse);
  });

  test('initiate sends every field the server needs and returns the asset plus how to upload it', () async {
    reply = {
      'asset': assetJson(status: 'pending_upload'),
      'upload': {'mode': 'presigned_put', 'uploadUrl': 'https://bucket.example/key.png', 'method': 'PUT', 'headers': {'Content-Type': 'image/png'}, 'expiresAt': '2026-09-26T10:15:00+01:00'},
    };
    final (asset, instructions) = await api.initiate(
      ownerMembership, ownerType: 'gallery_media_album', ownerId: 'album-1', category: 'gallery_photo',
      fileName: 'day.png', mimeType: 'image/png', byteSize: 4096, sha256: 'a' * 64, caption: 'Sports day',
    );
    expect(tail(0), 'assets/');
    expect(body(0), {
      'ownerType': 'gallery_media_album', 'ownerId': 'album-1', 'category': 'gallery_photo', 'fileName': 'day.png',
      'mimeType': 'image/png', 'byteSize': 4096, 'sha256': 'a' * 64, 'caption': 'Sports day', 'visibility': 'private',
    });
    expect(asset.status, 'pending_upload');
    expect(instructions.mode, 'presigned_put');
    expect(instructions.uploadUrl, 'https://bucket.example/key.png');
    expect(instructions.headers['Content-Type'], 'image/png');
  });

  test('complete and retire post to their own addresses and return the updated asset', () async {
    reply = {'asset': assetJson(status: 'available')};
    final completed = await api.complete(ownerMembership, 'asset-1');
    expect(tail(0), 'assets/asset-1/complete/');
    expect(completed.status, 'available');

    reply = {'asset': assetJson(status: 'retired')};
    final retired = await api.retire(ownerMembership, 'asset-1', reason: 'wrong album');
    expect(tail(1), 'assets/asset-1/retire/');
    expect(body(1), {'reason': 'wrong album'});
    expect(retired.status, 'retired');
  });

  test('downloadInfo asks with or without the thumbnail flag', () async {
    reply = {'mode': 'redirect', 'url': 'https://bucket.example/key.png?sig=x', 'mimeType': 'image/png', 'expiresAt': '2026-09-26T10:05:00+01:00'};
    final info = await api.downloadInfo(ownerMembership, 'asset-1');
    expect(server.requests.single.url.queryParameters.containsKey('thumbnail'), isFalse);
    expect((info.mode, info.url, info.mimeType), ('redirect', 'https://bucket.example/key.png?sig=x', 'image/png'));

    await api.downloadInfo(ownerMembership, 'asset-1', thumbnail: true);
    expect(server.requests.last.url.queryParameters['thumbnail'], '1');
  });

  test('streamBytes fetches the exact relative address the server gave, under this schools own media base', () async {
    server = FakeServer((r) async => rawResponse([1, 2, 3, 4]));
    api = MediaApi(api: apiFor(server));
    final bytes = await api.streamBytes(ownerMembership, 'assets/asset-1/raw/?thumbnail=1');
    expect(bytes, [1, 2, 3, 4]);
    expect(tail(0), 'assets/asset-1/raw/');
    expect(server.requests.single.url.queryParameters, {'thumbnail': '1', 'membership': ownerMembership.id});
  });

  test('a refusal carries the servers own code, the same way every other feature reads it', () async {
    status = 400;
    reply = {'code': 'file_too_large', 'message': 'That file is larger than this allows.'};
    await expectLater(
      api.initiate(ownerMembership, ownerType: 'gallery_media_album', ownerId: 'album-1', category: 'gallery_photo', fileName: 'x.png', mimeType: 'image/png', byteSize: 1, sha256: 'a' * 64),
      throwsA(isA<Exception>()),
    );
  });
}
