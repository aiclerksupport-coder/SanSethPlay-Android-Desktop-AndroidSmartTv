import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sanseth_play/core/xtream_client.dart';

void main() {
  final account = XtreamAccount(
      server: Uri.parse('https://tv.example'),
      username: 'u test',
      password: 'p secret');

  test('provider server validation rejects embedded credentials and paths', () {
    expect(
        () => XtreamAccount(
            server: Uri.parse('https://u:p@tv.example'),
            username: 'u',
            password: 'p'),
        throwsFormatException);
    expect(
        () => XtreamAccount(
            server: Uri.parse('https://tv.example/untrusted'),
            username: 'u',
            password: 'p'),
        throwsFormatException);
  });

  test('encoded Xtream URLs use correct paths without credential truncation',
      () {
    final uri = account.mediaUrl(type: 'movie', id: '123', extension: 'mp4');
    expect(uri.pathSegments, ['movie', 'u test', 'p secret', '123.mp4']);
    expect(() => account.mediaUrl(type: 'live', id: '../admin'),
        throwsFormatException);
  });

  test('authenticate and fetch categories/catalog safely', () async {
    final client = XtreamClient(client: MockClient((request) async {
      final action = request.url.queryParameters['action'];
      final payload = switch (action) {
        null => {
            'user_info': {'auth': 1, 'status': 'Active'}
          },
        'get_live_categories' => [
            {'category_id': '1', 'category_name': 'News'}
          ],
        'get_live_streams' => [
            {'stream_id': 123, 'name': 'Channel One', 'category_id': '1'},
            {'stream_id': '../bad', 'name': 'Invalid'},
          ],
        _ => [],
      };
      return http.Response(jsonEncode(payload), 200);
    }));
    addTearDown(client.dispose);
    await client.authenticate(account);
    expect(
        (await client.categories(account, XtreamMediaType.live))['1'], 'News');
    final results = await client.catalog(account, XtreamMediaType.live);
    expect(results, hasLength(1));
    expect(client.channel(account, results.single).url.pathSegments.last,
        '123.ts');
  });

  test('provider auth failures are not treated as success', () async {
    final client = XtreamClient(
        client: MockClient((request) async => http.Response(
            jsonEncode({
              'user_info': {'auth': 0, 'status': 'Disabled'}
            }),
            200)));
    addTearDown(client.dispose);
    expect(client.authenticate(account), throwsFormatException);
  });

  test('large authorized catalog decodes safely and preserves metadata',
      () async {
    final payload = List.generate(
        2500,
        (i) => <String, Object>{
              'stream_id': i + 1,
              'name': 'Live Channel $i',
              'category_id': 'news',
            });
    final client = XtreamClient(
        client: MockClient(
            (request) async => http.Response(jsonEncode(payload), 200)));
    addTearDown(client.dispose);
    final items = await client.catalog(account, XtreamMediaType.live);
    expect(items, hasLength(2500));
    expect(items[2499].name, 'Live Channel 2499');
  });

  test('provider redirect is refused to avoid credential leakage', () async {
    final client = XtreamClient(
        client: MockClient((request) async => http.Response('', 302,
            headers: {'location': 'https://other.example'})));
    addTearDown(client.dispose);
    expect(client.authenticate(account), throwsFormatException);
  });

  test('series episodes map into playable episode paths', () async {
    final client = XtreamClient(
        client: MockClient((request) async => http.Response(
            jsonEncode({
              'episodes': {
                '1': [
                  {'id': '451', 'title': 'Pilot', 'container_extension': 'mkv'}
                ]
              }
            }),
            200)));
    addTearDown(client.dispose);
    final found = await client.episodes(account, '123');
    expect(found, hasLength(1));
    final item = const XtreamItem(
        id: '123',
        name: 'Series',
        categoryId: '2',
        type: XtreamMediaType.series);
    expect(
        client
            .channel(account, item,
                episodeId: found.first.id,
                episodeExtension: found.first.extension)
            .url
            .pathSegments
            .last,
        '451.mkv');
  });
}

// Additional catalog stress cases are deliberately isolated from external IPTV
// servers, so all CI builds run deterministically and without subscriptions.
