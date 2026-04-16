import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../logger/logger.dart';

/// Fetches project data from Apidog API.
class ApidogFetcher {
  static const String _baseUrl = 'https://api.apidog.com/v1';
  static const String _internalBaseUrl = 'https://api.apidog.com/api/v1';
  static const String _apiVersion = '2024-03-28';
  final String token;
  final Logger _logger;

  ApidogFetcher({required this.token, required Logger logger})
      : _logger = logger;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'X-Apidog-Api-Version': _apiVersion,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Map<String, String> _internalHeaders(String projectId) => {
        'Authorization': 'Bearer $token',
        'X-Apidog-Api-Version': _apiVersion,
        'X-Project-Id': projectId,
        'X-Client-Mode': 'web',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Get all projects for the current user.
  Future<List<ApidogProject>> getProjects() async {
    try {
      final response = await http.get(
        Uri.parse('$_internalBaseUrl/user-projects'),
        headers: {
          ..._headers,
          'X-Client-Mode': 'web',
        },
      );

      if (response.statusCode != 200) {
        _logger.w('Failed to fetch projects (${response.statusCode})');
        return [];
      }

      final data = jsonDecode(response.body);
      if (data is! Map || data['data'] is! List) return [];

      final projects = data['data'] as List<dynamic>;
      return projects.map((p) => ApidogProject(
        id: p['id']?.toString() ?? '',
        name: p['name']?.toString() ?? 'Unknown',
      )).toList();
    } catch (e) {
      _logger.w('Failed to fetch projects: $e');
      return [];
    }
  }

  /// Get all environments for a project.
  Future<List<ApidogEnvironment>> getEnvironments(String projectId) async {
    try {
      final response = await http.get(
        Uri.parse('$_internalBaseUrl/projects/$projectId/environments'),
        headers: _internalHeaders(projectId),
      );

      if (response.statusCode != 200) {
        _logger.w(
            'Failed to fetch environments (${response.statusCode})');
        return [];
      }

      final data = jsonDecode(response.body);
      final envList = data['data'] as List<dynamic>? ?? [];

      return envList.map((e) {
        final vars = <String, String>{};
        final varList = e['variables'] as List<dynamic>? ?? [];
        for (final v in varList) {
          final name = v['name']?.toString();
          final value = v['value']?.toString() ?? v['initialValue']?.toString() ?? '';
          if (name != null && name.isNotEmpty && value.isNotEmpty) {
            vars[name] = value;
          }
        }

        return ApidogEnvironment(
          id: e['id'] is int ? e['id'] : int.tryParse(e['id'].toString()) ?? 0,
          name: e['name']?.toString() ?? 'Unknown',
          baseUrl: e['baseUrl']?.toString() ?? '',
          variables: vars,
        );
      }).toList();
    } catch (e) {
      _logger.w('Failed to fetch environments: $e');
      return [];
    }
  }

  /// Export project as OpenAPI spec (JSON string).
  Future<String?> exportOpenApi(String projectId, {int? environmentId}) async {
    try {
      final body = <String, dynamic>{
        'scope': {
          'type': 'ALL',
        },
        'oasVersion': '3.1',
        'exportFormat': 'JSON',
        'options': {
          'addFoldersToTags': true,
          'includeApidogExtensionProperties': true,
        },
      };

      if (environmentId != null) {
        body['environmentIds'] = [environmentId];
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/projects/$projectId/export-openapi'),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        _logger.e(
            'Apidog API error (${response.statusCode}): ${_truncate(response.body, 200)}');
        return null;
      }

      // Apidog may wrap the OpenAPI spec in a response envelope
      try {
        final parsed = jsonDecode(response.body);
        if (parsed is Map<String, dynamic>) {
          if (parsed.containsKey('data') && parsed['data'] is Map) {
            return jsonEncode(parsed['data']);
          }
          if (parsed.containsKey('openapi') || parsed.containsKey('paths')) {
            return response.body;
          }
          return response.body;
        }
      } catch (_) {}

      return response.body;
    } catch (e) {
      _logger.e('Failed to export OpenAPI spec', error: e);
      return null;
    }
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}

class ApidogProject {
  final String id;
  final String name;

  ApidogProject({required this.id, required this.name});
}

class ApidogEnvironment {
  final int id;
  final String name;
  final String baseUrl;
  final Map<String, String> variables;

  ApidogEnvironment({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.variables,
  });
}
