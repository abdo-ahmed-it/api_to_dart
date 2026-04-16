import 'dart:convert';

import 'package:http/http.dart' as http;

import '../logger/logger.dart';
import '../models/api_endpoint.dart';
import '../models/auth_definition.dart';
import '../models/body_definition.dart';

class HttpResult {
  final int statusCode;
  final String body;
  final Map<String, String> headers;

  const HttpResult({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

class ApiHttpClient {
  final Logger _logger;

  ApiHttpClient({required Logger logger}) : _logger = logger;

  Future<HttpResult?> request({
    required String url,
    required HttpMethod method,
    Map<String, String>? headers,
    Map<String, String>? queryParams,
    BodyDefinition? body,
    AuthDefinition? auth,
  }) async {
    final finalHeaders = <String, String>{
      'Accept': 'application/json',
      ...?headers,
      ..._authHeaders(auth),
    };

    final uri = Uri.parse(url).replace(
      queryParameters:
          queryParams != null && queryParams.isNotEmpty ? queryParams : null,
    );

    _logger.n(
      'Fetching Response:\n'
      'URL: $uri\n'
      'Method: ${method.name}\n'
      'Headers: $finalHeaders',
    );

    try {
      final response = await _executeRequest(
        uri: uri,
        method: method,
        headers: finalHeaders,
        body: body,
      );

      if (response != null) {
        final result = HttpResult(
          statusCode: response.statusCode,
          body: response.body,
          headers: response.headers,
        );

        _logResponse(response, uri.toString(), method.name, finalHeaders);
        return result;
      }
      return null;
    } catch (e) {
      _logger.e('Failed to fetch ${method.name} $uri', error: e);
      return null;
    }
  }

  Map<String, String> _authHeaders(AuthDefinition? auth) {
    if (auth == null || !auth.requiresAuth || auth.token == null) return {};

    switch (auth.type) {
      case AuthType.bearer:
        return {'Authorization': 'Bearer ${auth.token}'};
      case AuthType.basic:
        return {'Authorization': 'Basic ${auth.token}'};
      case AuthType.apiKey:
        final headerName = auth.headerName ?? 'X-Api-Key';
        return {headerName: auth.token!};
      case AuthType.none:
        return {};
    }
  }

  Future<http.Response?> _executeRequest({
    required Uri uri,
    required HttpMethod method,
    required Map<String, String> headers,
    BodyDefinition? body,
  }) async {
    switch (method) {
      case HttpMethod.GET:
        return http.get(uri, headers: headers);
      case HttpMethod.POST:
        return _requestWithBody('POST', uri, headers, body);
      case HttpMethod.PUT:
        return _requestWithBody('PUT', uri, headers, body);
      case HttpMethod.PATCH:
        return _requestWithBody('PATCH', uri, headers, body);
      case HttpMethod.DELETE:
        return http.delete(uri, headers: headers);
    }
  }

  Future<http.Response?> _requestWithBody(
    String method,
    Uri uri,
    Map<String, String> headers,
    BodyDefinition? body,
  ) async {
    if (body == null || body.isEmpty) {
      return _sendSimple(method, uri, headers);
    }

    switch (body.contentType) {
      case BodyContentType.formData:
      case BodyContentType.urlEncoded:
        headers['Content-Type'] = 'application/x-www-form-urlencoded';
        return _sendSimple(method, uri, headers, bodyFields: body.formFields);

      case BodyContentType.rawJson:
        headers['Content-Type'] = 'application/json';
        return _sendSimple(method, uri, headers, bodyString: body.rawBody);

      case BodyContentType.multipart:
        final request = http.MultipartRequest(method, uri);
        request.headers.addAll(headers);
        if (body.formFields != null) {
          request.fields.addAll(body.formFields!);
        }
        // File handling would go here for real multipart uploads
        final streamedResponse = await request.send();
        return http.Response.fromStream(streamedResponse);

      case null:
        return _sendSimple(method, uri, headers);
    }
  }

  Future<http.Response> _sendSimple(
    String method,
    Uri uri,
    Map<String, String> headers, {
    Map<String, String>? bodyFields,
    String? bodyString,
  }) async {
    switch (method) {
      case 'POST':
        return http.post(uri,
            headers: headers, body: bodyString ?? bodyFields);
      case 'PUT':
        return http.put(uri,
            headers: headers, body: bodyString ?? bodyFields);
      case 'PATCH':
        return http.patch(uri,
            headers: headers, body: bodyString ?? bodyFields);
      default:
        return http.post(uri,
            headers: headers, body: bodyString ?? bodyFields);
    }
  }

  void _logResponse(
    http.Response response,
    String url,
    String method,
    Map<String, String> headers,
  ) {
    final prettyResponse = _prettyJson(response.body);
    final logMessage = 'Response:\n'
        'URL: $url\n'
        'Method: $method\n'
        'Status: ${response.statusCode}\n'
        'Response: $prettyResponse';

    if (response.statusCode >= 200 && response.statusCode < 300) {
      _logger.d(logMessage);
    } else {
      _logger.e(logMessage);
    }
  }

  String _prettyJson(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (e) {
      return rawJson;
    }
  }
}
