import 'dart:io';

import 'package:yaml/yaml.dart';

import '../models/api_endpoint.dart';
import '../models/api_source_config.dart';
import '../models/auth_definition.dart';
import '../models/body_definition.dart';
import '../models/endpoint_tree.dart';
import 'api_source.dart';

class LocalFileSource implements ApiSource {
  @override
  String get sourceName => 'Local YAML/JSON File';

  @override
  Future<EndpointTree> parse(ApiSourceConfig config) async {
    final filePath = config.filePath;
    if (filePath == null || filePath.isEmpty) {
      throw ArgumentError('filePath is required for LocalFileSource');
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      throw FileSystemException('Config file not found', filePath);
    }

    final content = file.readAsStringSync();
    final Map<String, dynamic> data;

    try {
      final yamlDoc = loadYaml(content);
      data = (yamlDoc is YamlMap) ? _yamlMapToMap(yamlDoc) : {};
    } catch (e) {
      throw FormatException('Failed to parse YAML config file: $e');
    }

    final endpoint = _parseEndpoint(data, config);

    return EndpointTree(
      sourceName: 'Single Action',
      rootEndpoints: [endpoint],
    );
  }

  ApiEndpoint _parseEndpoint(
      Map<String, dynamic> data, ApiSourceConfig config) {
    final path = data['path']?.toString() ?? '';
    final methodStr = data['method']?.toString() ?? 'GET';
    final method = _parseHttpMethod(methodStr);
    final actionName =
        (data['action_name']?.toString() ?? '').trim().replaceAll(' ', '');
    final name = actionName.isNotEmpty
        ? actionName
        : path
            .split('/')
            .lastWhere((part) => part.isNotEmpty, orElse: () => 'Action');

    // Headers
    final headers = <String, String>{};
    if (data['headers'] is Map) {
      (data['headers'] as Map).forEach((key, value) {
        headers[key.toString()] = value.toString();
      });
    }

    // Query params
    final queryParams = <String, String>{};
    if (data['query_params'] is Map) {
      (data['query_params'] as Map).forEach((key, value) {
        queryParams[key.toString()] = value.toString();
      });
    }

    // Auth
    final auth = _parseAuth(data['auth']);

    // Body
    final body = _parseBody(data['body']);

    return ApiEndpoint(
      name: name,
      path: path,
      method: method,
      headers: headers,
      queryParams: queryParams,
      auth: auth,
      body: body,
    );
  }

  HttpMethod _parseHttpMethod(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return HttpMethod.GET;
      case 'POST':
        return HttpMethod.POST;
      case 'PUT':
        return HttpMethod.PUT;
      case 'PATCH':
        return HttpMethod.PATCH;
      case 'DELETE':
        return HttpMethod.DELETE;
      default:
        return HttpMethod.GET;
    }
  }

  AuthDefinition _parseAuth(dynamic auth) {
    if (auth == null || auth is! Map) return AuthDefinition.noAuth;

    final type = auth['type']?.toString() ?? 'none';
    final token = auth['token']?.toString();

    switch (type) {
      case 'bearer':
        return AuthDefinition(type: AuthType.bearer, token: token);
      case 'basic':
        return AuthDefinition(type: AuthType.basic, token: token);
      case 'none':
        return AuthDefinition.noAuth;
      default:
        return AuthDefinition.noAuth;
    }
  }

  BodyDefinition? _parseBody(dynamic body) {
    if (body == null || body is! Map) return null;

    final mode = body['mode']?.toString();
    final data = body['data'];

    if (mode == null && data is Map) {
      final formData = <String, String>{};
      data.forEach((key, value) {
        formData[key.toString()] = value.toString();
      });
      return BodyDefinition(
        contentType: BodyContentType.formData,
        formFields: formData,
      );
    }

    switch (mode) {
      case 'formdata':
        final formData = <String, String>{};
        if (data is Map) {
          data.forEach((key, value) {
            formData[key.toString()] = value.toString();
          });
        }
        return BodyDefinition(
          contentType: BodyContentType.formData,
          formFields: formData.isNotEmpty ? formData : null,
        );
      case 'urlencoded':
        final formData = <String, String>{};
        if (data is Map) {
          data.forEach((key, value) {
            formData[key.toString()] = value.toString();
          });
        }
        return BodyDefinition(
          contentType: BodyContentType.urlEncoded,
          formFields: formData.isNotEmpty ? formData : null,
        );
      case 'raw':
        return BodyDefinition(
          contentType: BodyContentType.rawJson,
          rawBody: data?.toString(),
        );
      default:
        return null;
    }
  }

  Map<String, dynamic> _yamlMapToMap(YamlMap yamlMap) {
    final map = <String, dynamic>{};
    for (final entry in yamlMap.entries) {
      if (entry.value is YamlMap) {
        map[entry.key.toString()] = _yamlMapToMap(entry.value as YamlMap);
      } else if (entry.value is YamlList) {
        map[entry.key.toString()] = (entry.value as YamlList)
            .map((e) => e is YamlMap ? _yamlMapToMap(e) : e)
            .toList();
      } else {
        map[entry.key.toString()] = entry.value;
      }
    }
    return map;
  }
}
