import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../generation/code_emitter.dart';
import '../logger/logger.dart';
import '../models/api_endpoint.dart';
import '../models/api_folder.dart';
import '../models/body_definition.dart';
import '../models/endpoint_tree.dart';
import '../models/response_definition.dart';
import '../resolution/http_client.dart';
import '../resolution/response_resolver.dart';
import 'web_assets.dart';

/// A local, loopback-only web UI for selecting endpoints and generating code.
///
/// Reuses the exact same core pipeline as the `generate` command
/// ([ResponseResolver] → [CodeEmitter] → [RequestLog.writeToFile]) so output on
/// disk is identical. The browser receives the endpoint tree as JSON (each
/// endpoint carries a stable `index` into [EndpointTree.allEndpoints]) and
/// posts back the selected indexes.
class ApiWebServer {
  final EndpointTree tree;
  final String outputDir;
  final String logsDir;
  final String? baseUrl;
  final String? token;
  final bool generateAction;
  final Logger logger;

  /// Stable, ordered list matching the indexes handed to the browser.
  final List<ApiEndpoint> _ordered;

  /// Parallel list of folder labels for each endpoint in [_ordered].
  final List<String> _folderPaths;

  HttpServer? _server;

  ApiWebServer({
    required this.tree,
    required this.outputDir,
    required this.logsDir,
    required this.baseUrl,
    required this.token,
    required this.generateAction,
    required this.logger,
  })  : _ordered = tree.allEndpoints,
        _folderPaths = _buildFolderPaths(tree);

  /// Builds folder labels in the SAME order as [EndpointTree.allEndpoints]
  /// (root endpoints first, then a depth-first walk of folders), so the index
  /// the browser sends maps back to the correct endpoint.
  static List<String> _buildFolderPaths(EndpointTree tree) {
    final paths = <String>[];
    paths.addAll(List.filled(tree.rootEndpoints.length, ''));
    void walk(ApiFolder folder, String prefix) {
      final label = prefix.isEmpty ? folder.name : '$prefix / ${folder.name}';
      paths.addAll(List.filled(folder.endpoints.length, label));
      for (final sub in folder.subfolders) {
        walk(sub, label);
      }
    }

    for (final folder in tree.folders) {
      walk(folder, '');
    }
    return paths;
  }

  /// Binds to loopback only (never exposed to the network) and starts serving.
  /// Returns the URL the user should open.
  Future<String> start(int port) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server = server;
    final url = 'http://${server.address.host}:${server.port}';
    unawaited(_serve(server));
    return url;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      try {
        await _route(request);
      } catch (e) {
        _json(request, 500, {'error': e.toString()});
      }
    }
  }

  Future<void> _route(HttpRequest req) async {
    final path = req.uri.path;
    final method = req.method;

    if (method == 'GET' && (path == '/' || path == '/index.html')) {
      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write(indexHtml);
      await req.response.close();
      return;
    }

    if (method == 'GET' && path == '/api/tree') {
      _json(req, 200, _treeJson());
      return;
    }

    if (method == 'GET' && path == '/api/endpoint') {
      _handleEndpointDetail(req);
      return;
    }

    if (method == 'GET' && path == '/api/preview') {
      _handlePreview(req);
      return;
    }

    if (method == 'POST' && path == '/api/try') {
      final body = await utf8.decoder.bind(req).join();
      await _handleTry(req, body);
      return;
    }

    if (method == 'POST' && path == '/api/generate') {
      final body = await utf8.decoder.bind(req).join();
      await _handleGenerate(req, body);
      return;
    }

    _json(req, 404, {'error': 'Not found: $method $path'});
  }

  /// Returns the index from `?index=N`, or null (after writing a 400) if absent
  /// or out of range.
  int? _indexParam(HttpRequest req) {
    final raw = req.uri.queryParameters['index'];
    final idx = raw == null ? null : int.tryParse(raw);
    if (idx == null || idx < 0 || idx >= _ordered.length) {
      _json(req, 400, {'error': 'Invalid or missing ?index'});
      return null;
    }
    return idx;
  }

  /// Full editable detail for one endpoint — what the "request builder" panel
  /// pre-fills (method, full URL, headers, query params, body, auth).
  void _handleEndpointDetail(HttpRequest req) {
    final idx = _indexParam(req);
    if (idx == null) return;
    final ep = _ordered[idx];

    String? bodyKind;
    String bodyText = '';
    final formFields = <Map<String, String>>[];
    final body = ep.body;
    if (body != null && !body.isEmpty) {
      if (body.hasRawBody) {
        bodyKind = 'raw';
        bodyText = body.rawBody ?? '';
      } else if (body.hasFormFields) {
        bodyKind = body.contentType == BodyContentType.urlEncoded
            ? 'urlencoded'
            : 'formdata';
        body.formFields!.forEach((k, v) {
          formFields.add({'key': k, 'value': v});
        });
      }
    }

    _json(req, 200, {
      'index': idx,
      'name': ep.name,
      'method': ep.method.name,
      'path': ep.path,
      'url': _fullUrl(ep),
      'description': ep.description,
      'folderPath': _folderPaths[idx],
      'headers': _kvList(ep.headers),
      'queryParams': _kvList(ep.queryParams),
      'auth': {
        'type': ep.auth.type.name,
        'token': ep.auth.token ?? '',
        'headerName': ep.auth.headerName,
      },
      'body': {
        'kind': bodyKind, // null | raw | formdata | urlencoded
        'raw': bodyText,
        'fields': formFields,
      },
      'responsePreview': ep.response?.jsonBody,
    });
  }

  /// The generated Dart code for one endpoint, without writing to disk — uses
  /// the same [CodeEmitter.generateCode] the disk path uses.
  void _handlePreview(HttpRequest req) {
    final idx = _indexParam(req);
    if (idx == null) return;
    final ep = _ordered[idx];

    final emitter = CodeEmitter(logger: logger);
    final code = emitter.generateCode(
      endpoint: ep,
      response: ep.response,
      generateAction: generateAction,
    );

    _json(req, 200, {
      'index': idx,
      'fileName': generateAction
          ? ep.fileName
          : ep.fileName.replaceAll('_action.dart', '_response.dart'),
      'code': code ??
          '// No code could be generated for this endpoint yet.\n'
              '// Send the request first to capture a response, or check the mode.',
      'hasResponse': ep.response?.hasJson ?? false,
    });
  }

  /// Sends a one-off request with the (possibly edited) values from the browser
  /// and returns the live response — the "Try it / Send" feature. Does NOT
  /// write any files.
  Future<void> _handleTry(HttpRequest req, String rawBody) async {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(rawBody) as Map<String, dynamic>;
    } catch (e) {
      _json(req, 400, {'error': 'Invalid request body: $e'});
      return;
    }

    final url = (payload['url'] as String?)?.trim() ?? '';
    if (url.isEmpty) {
      _json(req, 400, {'error': 'A URL is required to send the request.'});
      return;
    }
    final method = _parseMethod(payload['method'] as String? ?? 'GET');
    final headers = _kvToMap(payload['headers']);
    final query = _kvToMap(payload['queryParams']);
    final bodyDef = _bodyFromPayload(payload['body']);

    final httpClient = ApiHttpClient(logger: logger);
    final result = await httpClient.request(
      url: url,
      method: method,
      headers: headers.isNotEmpty ? headers : null,
      queryParams: query.isNotEmpty ? query : null,
      body: bodyDef,
    );

    if (result == null) {
      _json(req, 200, {
        'ok': false,
        'error': 'Request failed (no response). Check the URL and network.',
      });
      return;
    }

    _json(req, 200, {
      'ok': true,
      'status': result.statusCode,
      'timeMs': result.receivedTime.difference(result.sentTime).inMilliseconds,
      'requestUrl': result.requestUrl,
      'responseHeaders': result.headers,
      'body': result.body,
    });
  }

  Map<String, dynamic> _treeJson() {
    final endpoints = <Map<String, dynamic>>[];
    for (var i = 0; i < _ordered.length; i++) {
      final ep = _ordered[i];
      endpoints.add({
        'index': i,
        'name': ep.name,
        'method': ep.method.name,
        'path': ep.path,
        'folderPath': _folderPaths[i],
        'requiresAuth': ep.requiresAuth,
      });
    }
    return {
      'sourceName': tree.sourceName,
      'mode': generateAction ? 'action + response' : 'response-only',
      'outputDir': outputDir,
      'baseUrl': baseUrl ?? '',
      'endpoints': endpoints,
    };
  }

  /// Best-effort full URL for an endpoint: `baseUrl + path`, normalizing the
  /// slash at the join. Falls back to the raw path when no base URL was given.
  String _fullUrl(ApiEndpoint ep) {
    final b = baseUrl ?? '';
    if (b.isEmpty) return ep.path;
    final base = b.endsWith('/') ? b.substring(0, b.length - 1) : b;
    final path = ep.path.startsWith('/') ? ep.path : '/${ep.path}';
    return '$base$path';
  }

  List<Map<String, String>> _kvList(Map<String, String> map) =>
      map.entries.map((e) => {'key': e.key, 'value': e.value}).toList();

  /// Converts the browser's `[{key, value}]` list back into a string map,
  /// skipping blank keys.
  Map<String, String> _kvToMap(dynamic list) {
    final out = <String, String>{};
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          final k = (item['key'] ?? '').toString().trim();
          if (k.isEmpty) continue;
          out[k] = (item['value'] ?? '').toString();
        }
      }
    }
    return out;
  }

  HttpMethod _parseMethod(String raw) {
    final upper = raw.toUpperCase();
    return HttpMethod.values.firstWhere(
      (m) => m.name == upper,
      orElse: () => HttpMethod.GET,
    );
  }

  /// Builds a [BodyDefinition] from the browser's body payload
  /// (`{kind, raw, fields}`).
  BodyDefinition? _bodyFromPayload(dynamic body) {
    if (body is! Map) return null;
    final kind = body['kind'] as String?;
    if (kind == 'raw') {
      final raw = (body['raw'] ?? '').toString();
      if (raw.isEmpty) return null;
      return BodyDefinition(contentType: BodyContentType.rawJson, rawBody: raw);
    }
    if (kind == 'formdata' || kind == 'urlencoded') {
      final fields = _kvToMap(body['fields']);
      if (fields.isEmpty) return null;
      return BodyDefinition(
        contentType: kind == 'urlencoded'
            ? BodyContentType.urlEncoded
            : BodyContentType.formData,
        formFields: fields,
      );
    }
    return null;
  }

  Future<void> _handleGenerate(HttpRequest req, String rawBody) async {
    final List<int> indexes;
    try {
      final decoded = jsonDecode(rawBody) as Map<String, dynamic>;
      indexes = (decoded['selectedIndexes'] as List)
          .map((e) => (e as num).toInt())
          .where((i) => i >= 0 && i < _ordered.length)
          .toList();
    } catch (e) {
      _json(req, 400, {'error': 'Invalid request body: $e'});
      return;
    }

    if (indexes.isEmpty) {
      _json(req, 400, {'error': 'No endpoints selected.'});
      return;
    }

    final buffer = _BufferingLogger(logger);
    final httpClient = ApiHttpClient(logger: buffer);
    final resolver = ResponseResolver(httpClient: httpClient);
    final emitter = CodeEmitter(logger: buffer);

    final resolvedBaseUrl = baseUrl ?? '';
    final endpointResponses = <ApiEndpoint, ResponseDefinition?>{};
    final generated = <Map<String, dynamic>>[];
    final skipped = <Map<String, dynamic>>[];

    for (final i in indexes) {
      final endpoint = _ordered[i];
      buffer.i('Processing ${endpoint.method.name} ${endpoint.path}...');

      ResolveResult result;
      try {
        result = await resolver.resolve(
          endpoint,
          baseUrl: resolvedBaseUrl,
          token: token,
        );
      } catch (e) {
        result = ResolveResult(response: ResponseDefinition.empty);
      }

      final logFileName = endpoint.fileName.replaceAll('.dart', '');
      String? logFile;
      if (result.log != null) {
        result.log!.writeToFile(logsDir, logFileName);
        logFile = '$logsDir/$logFileName.md';
      }

      final status = result.log?.statusCode;
      if (status != null && (status < 200 || status >= 300)) {
        skipped.add({
          'name': endpoint.name,
          'reason': 'request failed ($status)',
          'logFile': logFile,
        });
        continue;
      }

      endpointResponses[endpoint] = result.response;
    }

    // Emit one endpoint at a time so we can report the file path per endpoint.
    for (final entry in endpointResponses.entries) {
      final filePath = emitter.emit(
        endpoint: entry.key,
        outputDir: outputDir,
        response: entry.value,
        generateAction: generateAction,
      );
      if (filePath != null) {
        generated.add({
          'file': filePath,
          'status': 200,
        });
      } else {
        skipped.add({
          'name': entry.key.name,
          'reason': 'nothing to generate (no response data)',
        });
      }
    }

    _json(req, 200, {
      'generated': generated,
      'skipped': skipped,
      'logs': buffer.messages,
      'outputDir': outputDir,
      'logsDir': logsDir,
    });
  }

  void _json(HttpRequest req, int status, Object body) {
    req.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    req.response.close();
  }
}

/// A [Logger] that mirrors messages to an underlying logger (terminal) while
/// also collecting them so they can be returned to the browser.
class _BufferingLogger implements Logger {
  final Logger _inner;
  final List<String> messages = [];

  _BufferingLogger(this._inner);

  @override
  void d(String message) {
    messages.add(message);
    _inner.d(message);
  }

  @override
  void i(String message) {
    messages.add(message);
    _inner.i(message);
  }

  @override
  void w(String message) {
    messages.add('⚠ $message');
    _inner.w(message);
  }

  @override
  void e(String message, {Object? error}) {
    messages.add('✗ $message${error != null ? ': $error' : ''}');
    _inner.e(message, error: error);
  }

  @override
  void n(String message) {
    messages.add(message);
    _inner.n(message);
  }
}

/// A no-op logger used inside the server isolate so it never writes to the
/// terminal (which the interactive selector owns in the main isolate).
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

/// Everything the server isolate needs to construct an [ApiWebServer]. All
/// fields are plain immutable data, so this passes cleanly across the isolate
/// boundary.
class WebServerConfig {
  final EndpointTree tree;
  final String outputDir;
  final String logsDir;
  final String? baseUrl;
  final String? token;
  final bool generateAction;
  final int port;
  final SendPort replyPort;

  const WebServerConfig({
    required this.tree,
    required this.outputDir,
    required this.logsDir,
    required this.baseUrl,
    required this.token,
    required this.generateAction,
    required this.port,
    required this.replyPort,
  });
}

/// Spawns the web server in a dedicated isolate and returns its URL.
///
/// This is what lets the web UI stay responsive while the main isolate is
/// blocked on the terminal selector's synchronous `readKey()` — the server's
/// own event loop runs independently. The browser can hit it any time.
///
/// Returns null if the server failed to start (e.g. the port is busy).
Future<String?> spawnWebServerIsolate({
  required EndpointTree tree,
  required String outputDir,
  required String logsDir,
  required String? baseUrl,
  required String? token,
  required bool generateAction,
  required int port,
}) async {
  final reply = ReceivePort();
  await Isolate.spawn(
    _webServerIsolateEntry,
    WebServerConfig(
      tree: tree,
      outputDir: outputDir,
      logsDir: logsDir,
      baseUrl: baseUrl,
      token: token,
      generateAction: generateAction,
      port: port,
      replyPort: reply.sendPort,
    ),
  );
  // The isolate sends back the URL string on success, or null on failure.
  final result = await reply.first;
  reply.close();
  return result as String?;
}

/// Isolate entrypoint: starts the server and reports its URL (or null) back.
Future<void> _webServerIsolateEntry(WebServerConfig config) async {
  try {
    final server = ApiWebServer(
      tree: config.tree,
      outputDir: config.outputDir,
      logsDir: config.logsDir,
      baseUrl: config.baseUrl,
      token: config.token,
      generateAction: config.generateAction,
      logger: _SilentLogger(),
    );
    final url = await server.start(config.port);
    config.replyPort.send(url);
    // Keep the isolate alive so the server keeps serving.
  } catch (_) {
    config.replyPort.send(null);
  }
}
