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

    test('serves a nested tree with stable indexes matching allEndpoints order',
        () async {
      final res = await _getJson('$base/api/tree');
      expect(res['sourceName'], 'Test API');
      expect(res['mode'], 'action + response');
      expect(res['outputDir'], 'out/actions');
      expect(res['total'], 4);

      // Flatten the nested tree depth-first (endpoints before subfolders within
      // a folder) — must match EndpointTree.allEndpoints order exactly.
      final flat = _flattenEndpoints(res['roots'] as List);
      final allEndpoints = tree.allEndpoints;
      expect(flat.length, allEndpoints.length);
      for (var i = 0; i < flat.length; i++) {
        expect(flat[i]['index'], i);
        expect(flat[i]['name'], allEndpoints[i].name);
        expect(flat[i]['method'], allEndpoints[i].method.name);
      }
    });

    test('nests subfolders inside their parent folder', () async {
      final res = await _getJson('$base/api/tree');
      final roots = (res['roots'] as List).cast<Map>();

      // Root has: one endpoint (Root One) + the Users folder.
      final usersFolder = roots
          .firstWhere((n) => n['type'] == 'folder' && n['name'] == 'Users');
      expect(usersFolder['count'], 3); // 2 own + 1 in Admin subfolder

      final usersChildren = (usersFolder['children'] as List).cast<Map>();
      // Own endpoints come first, then the Admin subfolder.
      expect(usersChildren.first['type'], 'endpoint');
      final admin = usersChildren.firstWhere((n) => n['type'] == 'folder');
      expect(admin['name'], 'Admin');
      final adminChildren = (admin['children'] as List).cast<Map>();
      expect(adminChildren.single['name'], 'Ban User');
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

    test('/api/endpoint exposes output settings with derived defaults',
        () async {
      final res = await _getJson('$base/api/endpoint?index=1');
      final out = res['output'] as Map;
      // no saved overrides yet → blank current values
      expect(out['fileName'], '');
      expect(out['actionClass'], '');
      // derived defaults are present for prefill
      final defs = out['defaults'] as Map;
      expect(defs['fileName'], 'get_list_users_action.dart');
      expect(defs['actionClass'], 'GetListUsersAction');
      expect(defs['responseClass'], 'GetListUsersResponse');
    });

    test('/api/preview honors live class/file overrides', () async {
      final res = await _getJson(
          '$base/api/preview?index=1&actionClass=MyUsersAction&fileName=my_users');
      expect(res['fileName'], 'my_users.dart');
      expect(res['code'], contains('class MyUsersAction'));
      expect(res['code'], isNot(contains('class GetListUsersAction')));
    });

    test('/api/preview mode=response-only drops the action import', () async {
      final res =
          await _getJson('$base/api/preview?index=1&mode=response-only');
      expect(res['fileName'], endsWith('_response.dart'));
      expect(res['code'], isNot(contains('ApiRequestAction')));
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

  _isolateGroup();
}

void _isolateGroup() {
  group('spawnWebServerIsolate', () {
    test('serves /api/tree from a separate isolate', () async {
      final tree = EndpointTree(
        sourceName: 'Iso API',
        rootEndpoints: [_ep('Ping', '/ping', HttpMethod.GET)],
      );
      // Port 0 → OS-assigned free port, returned in the URL.
      final url = await spawnWebServerIsolate(
        tree: tree,
        outputDir: 'out/actions',
        logsDir: 'out/logs',
        baseUrl: null,
        token: null,
        generateAction: true,
        port: 0,
      );
      expect(url, isNotNull);
      expect(url, startsWith('http://127.0.0.1:'));

      final res = await _getJson('$url/api/tree');
      expect(res['sourceName'], 'Iso API');
      expect(res['total'], 1);
      expect(_flattenEndpoints(res['roots'] as List).single['name'], 'Ping');
    });
  });
}

/// Depth-first flatten of the nested tree's endpoint nodes, in the same order
/// the server assigns indexes (endpoints before subfolders within a folder).
List<Map> _flattenEndpoints(List nodes) {
  final out = <Map>[];
  for (final n in nodes.cast<Map>()) {
    if (n['type'] == 'endpoint') {
      out.add(n);
    } else {
      out.addAll(_flattenEndpoints(n['children'] as List));
    }
  }
  return out;
}

Future<Map<String, dynamic>> _getJson(String url) async {
  final client = HttpClient();
  final req = await client.getUrl(Uri.parse(url));
  final resp = await req.close();
  final body = await utf8.decoder.bind(resp).join();
  client.close();
  return jsonDecode(body) as Map<String, dynamic>;
}
