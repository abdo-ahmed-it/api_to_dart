import 'dart:convert';

import '../logger/logger.dart';
import '../models/api_endpoint.dart';
import '../models/auth_definition.dart';
import '../models/response_definition.dart';
import 'http_client.dart';

class ResponseResolver {
  final ApiHttpClient _httpClient;
  final Logger _logger;

  ResponseResolver({
    required ApiHttpClient httpClient,
    required Logger logger,
  })  : _httpClient = httpClient,
        _logger = logger;

  /// Resolves the response for an endpoint using the fallback chain:
  /// 1. Example with good data → use directly
  /// 2. Live fetch → send real request to server
  /// 3. Schema → generate synthetic JSON
  /// 4. Example with empty arrays → use anyway (better than nothing)
  /// 5. None → return empty (generator will use dynamic)
  Future<ResponseDefinition> resolve(
    ApiEndpoint endpoint, {
    required String baseUrl,
    String? token,
  }) async {
    final response = endpoint.response;

    // 1. If we have an example with good data (no empty arrays), use it
    if (response != null && response.hasJson) {
      if (!_hasEmptyArrays(response.jsonBody!)) {
        _logger.i('${endpoint.name}: Using example response');
        return response;
      }
      // Has empty arrays — try live fetch first
      _logger.i(
          '${endpoint.name}: Example has empty arrays — trying live fetch');
    }

    // 2. Try live fetch if we have a base URL
    if (baseUrl.isNotEmpty) {
      final fetched = await _tryLiveFetch(endpoint, baseUrl, token);
      if (fetched != null) {
        return fetched;
      }
    }

    // 3. Try schema
    if (response != null && response.hasSchema) {
      _logger.i('${endpoint.name}: Generating from schema');
      final syntheticJson = _schemaToJson(response.schema!);
      if (syntheticJson != null) {
        return ResponseDefinition(
          source: ResponseSource.schema,
          jsonBody: syntheticJson,
          schema: response.schema,
        );
      }
    }

    // 4. If we had an example (even with empty arrays), use it anyway
    if (response != null && response.hasJson) {
      _logger.i('${endpoint.name}: Using example response (with empty arrays)');
      return response;
    }

    // 5. Nothing available
    _logger.w(
        '${endpoint.name}: No response available — generating action-only');
    return ResponseDefinition.empty;
  }

  Future<ResponseDefinition?> _tryLiveFetch(
    ApiEndpoint endpoint,
    String baseUrl,
    String? token,
  ) async {
    _logger.i('${endpoint.name}: Fetching live response from server');

    final url = '$baseUrl${endpoint.path}';

    final authDef = token != null && token.isNotEmpty
        ? AuthDefinition(
            type: endpoint.auth.type != AuthType.none
                ? endpoint.auth.type
                : AuthType.bearer,
            token: token,
          )
        : endpoint.auth;

    try {
      final result = await _httpClient.request(
        url: url,
        method: endpoint.method,
        headers: endpoint.headers.isNotEmpty ? endpoint.headers : null,
        queryParams:
            endpoint.queryParams.isNotEmpty ? endpoint.queryParams : null,
        body: endpoint.body,
        auth: authDef,
      );

      if (result != null && result.isSuccess && result.body.isNotEmpty) {
        // Verify it's valid JSON
        try {
          jsonDecode(result.body);
          _logger.i('${endpoint.name}: ✓ Got live response');
          return ResponseDefinition(
            source: ResponseSource.fetched,
            jsonBody: result.body,
          );
        } catch (_) {
          _logger.w('${endpoint.name}: Live response is not valid JSON');
        }
      } else if (result != null) {
        _logger.w(
            '${endpoint.name}: Server returned ${result.statusCode}');
      }
    } catch (e) {
      _logger.w('${endpoint.name}: Live fetch failed: $e');
    }

    return null;
  }

  bool _hasEmptyArrays(String jsonBody) {
    try {
      final decoded = jsonDecode(jsonBody);
      return _checkEmptyArrays(decoded);
    } catch (_) {
      return false;
    }
  }

  bool _checkEmptyArrays(dynamic value) {
    if (value is List && value.isEmpty) return true;
    if (value is Map) {
      return value.values.any(_checkEmptyArrays);
    }
    return false;
  }

  String? _schemaToJson(Map<String, dynamic> schema) {
    try {
      final example = _schemaToValue(schema);
      if (example != null) {
        return jsonEncode(example);
      }
    } catch (e) {
      _logger.w('Failed to generate synthetic JSON from schema: $e');
    }
    return null;
  }

  dynamic _schemaToValue(Map<String, dynamic> schema) {
    final type = schema['type']?.toString();

    switch (type) {
      case 'object':
        final properties =
            schema['properties'] as Map<String, dynamic>? ?? {};
        final result = <String, dynamic>{};
        properties.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            result[key] = _schemaToValue(value);
          }
        });
        return result;

      case 'array':
        final items = schema['items'] as Map<String, dynamic>?;
        if (items != null) {
          return [_schemaToValue(items)];
        }
        return [];

      case 'string':
        return schema['example']?.toString() ?? 'string';
      case 'integer':
        return schema['example'] ?? 0;
      case 'number':
        return schema['example'] ?? 0.0;
      case 'boolean':
        return schema['example'] ?? false;
      default:
        // Check for properties (implicit object)
        if (schema.containsKey('properties')) {
          final properties =
              schema['properties'] as Map<String, dynamic>? ?? {};
          final result = <String, dynamic>{};
          properties.forEach((key, value) {
            if (value is Map<String, dynamic>) {
              result[key] = _schemaToValue(value);
            }
          });
          return result.isNotEmpty ? result : null;
        }
        return null;
    }
  }
}
