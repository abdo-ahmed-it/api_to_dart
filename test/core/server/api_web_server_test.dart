import 'dart:convert';
import 'dart:io';

import 'package:api_to_dart/api_to_dart.dart';
import 'package:test/test.dart';

/// A silent logger so server tests don't spam the test output.
class _SilentLogger implements Logger {
  @override
  void d(String message) {}
  @override
  void i(String message) {}
  @override
  void w(String message) {}
  @override
  void e(String message, {Object? error}) {}
  @override
  void n(String message) {}
}

ApiEndpoint _ep(String name, String path, HttpMethod method) => ApiEndpoint(
      name: name,
      path: path,
      method: method,
    );

void main() {
  group('ApiWebServer /api/tree', () {
    late ApiWebServer server;
    late String base;

    // A tree that mixes root endpoints, a folder, and a nested subfolder so we
    // can assert the index order matches EndpointTree.allEndpoints exactly.
    final tree = EndpointTree(
      sourceName: 'Test API',
      rootEndpoints: [_ep('Root One', '/root', HttpMethod.GET)],
      folders: [
        ApiFolder(
          name: 'Users',
          endpoints: [
            _ep('List Users', '/users', HttpMethod.GET),
            _ep('Create User', '/users', HttpMethod.POST),
          ],
          subfolders: [
            ApiFolder(
              name: 'Admin',
              endpoints: [_ep('Ban User', '/users/ban', HttpMethod.DELETE)],
            ),
          ],
        ),
      ],
    );

    setUp(() async {
      server = ApiWebServer(
        tree: tree,
        outputDir: 'out/actions',
        logsDir: 'out/logs',
        baseUrl: null,
        token: null,
        generateAction: true,
        logger: _SilentLogger(),
      );
      final url = await server.start(0); // port 0 → OS picks a free port
      base = url;
    });

    tearDown(() async {
      await server.stop();
    });

    test('binds to loopback only', () {
      expect(base, startsWith('http://127.0.0.1:'));
    });

    test('serves endpoints with stable indexes matching allEndpoints order',
        () async {
      final res = await _getJson('$base/api/tree');
      expect(res['sourceName'], 'Test API');
      expect(res['mode'], 'action + response');
      expect(res['outputDir'], 'out/actions');

      final endpoints = (res['endpoints'] as List).cast<Map>();
      expect(endpoints.length, 4);

      // Index order must equal EndpointTree.allEndpoints:
      // root first, then folder endpoints, then nested subfolder endpoints.
      final allEndpoints = tree.allEndpoints;
      for (var i = 0; i < endpoints.length; i++) {
        expect(endpoints[i]['index'], i);
        expect(endpoints[i]['name'], allEndpoints[i].name);
        expect(endpoints[i]['method'], allEndpoints[i].method.name);
      }
    });

    test('reports folder paths including nested labels', () async {
      final res = await _getJson('$base/api/tree');
      final endpoints = (res['endpoints'] as List).cast<Map>();

      final byName = {for (final e in endpoints) e['name']: e['folderPath']};
      expect(byName['Root One'], '');
      expect(byName['List Users'], 'Users');
      expect(byName['Create User'], 'Users');
      expect(byName['Ban User'], 'Users / Admin');
    });

    test('serves the HTML page at /', () async {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse('$base/'));
      final resp = await req.close();
      final body = await utf8.decoder.bind(resp).join();
      client.close();

      expect(resp.statusCode, 200);
      expect(body, contains('api2dart'));
      expect(body, contains('/api/generate'));
    });

    test('returns 404 for unknown routes', () async {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse('$base/nope'));
      final resp = await req.close();
      await resp.drain();
      client.close();
      expect(resp.statusCode, 404);
    });

    test('rejects generate with no selection', () async {
      final client = HttpClient();
      final req = await client.postUrl(Uri.parse('$base/api/generate'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'selectedIndexes': <int>[]}));
      final resp = await req.close();
      final body = await utf8.decoder.bind(resp).join();
      client.close();

      expect(resp.statusCode, 400);
      expect(jsonDecode(body)['error'], contains('No endpoints selected'));
    });

    test('/api/endpoint returns editable detail for an index', () async {
      final res = await _getJson('$base/api/endpoint?index=1');
      expect(res['name'], 'List Users');
      expect(res['method'], 'GET');
      expect(res['path'], '/users');
      expect(res['folderPath'], 'Users');
      expect(res['headers'], isA<List>());
      expect(res['queryParams'], isA<List>());
      expect(res['auth'], isA<Map>());
      expect(res['body'], isA<Map>());
    });

    test('/api/endpoint rejects an out-of-range index', () async {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse('$base/api/endpoint?index=99'));
      final resp = await req.close();
      await resp.drain();
      client.close();
      expect(resp.statusCode, 400);
    });

    test('/api/preview returns generated code for an index', () async {
      final res = await _getJson('$base/api/preview?index=1');
      expect(res['fileName'], endsWith('.dart'));
      expect(res['code'], isA<String>());
      // action mode → the code should reference ApiRequestAction
      expect(res['code'], contains('Action'));
    });

    test('/api/try requires a URL', () async {
      final client = HttpClient();
      final req = await client.postUrl(Uri.parse('$base/api/try'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'method': 'GET', 'url': ''}));
      final resp = await req.close();
      final body = await utf8.decoder.bind(resp).join();
      client.close();
      expect(resp.statusCode, 400);
      expect(jsonDecode(body)['error'], contains('URL is required'));
    });
  });
}

Future<Map<String, dynamic>> _getJson(String url) async {
  final client = HttpClient();
  final req = await client.getUrl(Uri.parse(url));
  final resp = await req.close();
  final body = await utf8.decoder.bind(resp).join();
  client.close();
  return jsonDecode(body) as Map<String, dynamic>;
}
