import 'auth_definition.dart';
import 'body_definition.dart';
import 'response_definition.dart';

enum HttpMethod { GET, POST, PUT, PATCH, DELETE }

class ApiEndpoint {
  final String name;
  final String path;
  final HttpMethod method;
  final String? description;
  final BodyDefinition? body;
  final Map<String, String> headers;
  final Map<String, String> queryParams;
  final AuthDefinition auth;
  final ResponseDefinition? response;

  const ApiEndpoint({
    required this.name,
    required this.path,
    required this.method,
    this.description,
    this.body,
    this.headers = const {},
    this.queryParams = const {},
    this.auth = const AuthDefinition(type: AuthType.none),
    this.response,
  });

  /// PascalCase name stripped of non-alphanumeric chars.
  String get _cleanName {
    final stripped = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (stripped.isEmpty) return 'Unknown';
    // Ensure first letter is uppercase
    return stripped[0].toUpperCase() + stripped.substring(1);
  }

  String get actionClassName => '${_cleanName}Action';

  String get responseClassName => '${_cleanName}Response';

  String get fileName {
    // Convert PascalCase to snake_case
    final snake = _cleanName
        .replaceAllMapped(
            RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]}_${m[2]}')
        .toLowerCase();
    return '${snake}_action.dart';
  }

  String get methodString => method.name;

  bool get requiresAuth => auth.requiresAuth;
}
