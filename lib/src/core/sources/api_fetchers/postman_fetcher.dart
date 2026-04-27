import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../logger/logger.dart';

/// Fetches collections from Postman API.
class PostmanFetcher {
  static const String _baseUrl = 'https://api.getpostman.com';
  final String apiKey;
  final Logger _logger;

  PostmanFetcher({required this.apiKey, required Logger logger})
      : _logger = logger;

  Map<String, String> get _headers => {'X-Api-Key': apiKey};

  /// Get all workspaces.
  Future<List<PostmanWorkspace>> getWorkspaces() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/workspaces'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        _logger.e('Postman API error: ${response.statusCode} ${response.body}');
        return [];
      }

      final data = jsonDecode(response.body);
      final workspaces = data['workspaces'] as List<dynamic>? ?? [];

      return workspaces
          .map((w) => PostmanWorkspace(
                id: w['id'].toString(),
                name: w['name'].toString(),
                type: w['type']?.toString() ?? 'personal',
              ))
          .toList();
    } catch (e) {
      _logger.e('Failed to fetch workspaces', error: e);
      return [];
    }
  }

  /// Get all collections, optionally filtered by workspace.
  Future<List<PostmanCollectionInfo>> getCollections(
      {String? workspaceId}) async {
    try {
      var url = '$_baseUrl/collections';
      if (workspaceId != null) {
        url += '?workspace=$workspaceId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        _logger.e('Postman API error: ${response.statusCode} ${response.body}');
        return [];
      }

      final data = jsonDecode(response.body);
      // Postman API returns the list under "collections" (plural).
      // Accept both keys to stay robust if the response format varies.
      final raw = data['collections'] ?? data['collection'];
      final collections = raw is List ? raw : <dynamic>[];

      return collections
          .map((c) => PostmanCollectionInfo(
                id: c['id']?.toString() ?? c['uid']?.toString() ?? '',
                uid: c['uid']?.toString() ?? c['id']?.toString() ?? '',
                name: c['name']?.toString() ?? 'Unknown',
              ))
          .toList();
    } catch (e) {
      _logger.e('Failed to fetch collections', error: e);
      return [];
    }
  }

  /// Get all environments in a workspace (id + name only).
  /// To read variables, call [getEnvironment] with the uid.
  Future<List<PostmanEnvironmentInfo>> getEnvironments(
      {String? workspaceId}) async {
    try {
      var url = '$_baseUrl/environments';
      if (workspaceId != null) {
        url += '?workspace=$workspaceId';
      }

      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode != 200) {
        _logger.e(
            'Postman API error: ${response.statusCode} ${response.body}');
        return [];
      }

      final data = jsonDecode(response.body);
      final raw = data['environments'] ?? data['environment'];
      final environments = raw is List ? raw : <dynamic>[];

      return environments.map((e) {
        final id = e['id']?.toString() ?? '';
        final uid = e['uid']?.toString() ?? id;
        return PostmanEnvironmentInfo(
          id: id,
          uid: uid,
          name: e['name']?.toString() ?? 'Unknown',
        );
      }).toList();
    } catch (e) {
      _logger.e('Failed to fetch environments', error: e);
      return [];
    }
  }

  /// Get a single environment with its variables (key/value pairs).
  /// Disabled variables are skipped.
  Future<PostmanEnvironment?> getEnvironment(String environmentUid) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/environments/$environmentUid'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        _logger.e(
            'Postman API error: ${response.statusCode} ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body);
      final env = data['environment'];
      if (env is! Map) return null;

      final values = env['values'] is List ? env['values'] as List : const [];
      final variables = <String, String>{};
      for (final v in values) {
        if (v is! Map) continue;
        if (v['enabled'] == false) continue;
        final key = v['key']?.toString();
        final value = v['value']?.toString() ?? '';
        if (key != null && key.isNotEmpty) {
          variables[key] = value;
        }
      }

      return PostmanEnvironment(
        id: env['id']?.toString() ?? '',
        uid: env['uid']?.toString() ?? environmentUid,
        name: env['name']?.toString() ?? 'Unknown',
        variables: variables,
      );
    } catch (e) {
      _logger.e('Failed to fetch environment', error: e);
      return null;
    }
  }

  /// Get a full collection by UID.
  /// Returns the raw JSON string (Postman collection format).
  Future<String?> getCollection(String collectionUid) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/collections/$collectionUid'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        _logger.e('Postman API error: ${response.statusCode} ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body);
      final collection = data['collection'];
      if (collection != null) {
        return jsonEncode(collection);
      }
      return null;
    } catch (e) {
      _logger.e('Failed to fetch collection', error: e);
      return null;
    }
  }
}

class PostmanWorkspace {
  final String id;
  final String name;
  final String type;

  PostmanWorkspace(
      {required this.id, required this.name, required this.type});
}

class PostmanCollectionInfo {
  final String id;
  final String uid;
  final String name;

  PostmanCollectionInfo(
      {required this.id, required this.uid, required this.name});
}

class PostmanEnvironmentInfo {
  final String id;
  final String uid;
  final String name;

  PostmanEnvironmentInfo(
      {required this.id, required this.uid, required this.name});
}

class PostmanEnvironment {
  final String id;
  final String uid;
  final String name;
  final Map<String, String> variables;

  PostmanEnvironment({
    required this.id,
    required this.uid,
    required this.name,
    required this.variables,
  });
}
