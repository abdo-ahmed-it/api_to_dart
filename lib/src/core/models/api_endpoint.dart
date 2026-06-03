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

  /// PascalCase name stripped of non-alphanumeric chars, prefixed with the
  /// HTTP method so endpoints sharing a path (e.g. `GET /users` and
  /// `POST /users`) don't collide on class/file names.
  String get _cleanName {
    final stripped = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final raw = stripped.isEmpty ? 'Unknown' : stripped;
    final base = '${raw[0].toUpperCase()}${raw.substring(1)}';
    // PascalCase the method (GET -> Get) and prepend it so endpoints sharing a
    // path differ by method. Skip when the name already starts with the method
    // (e.g. "GetUsers" + GET) to avoid "GetGetUsers".
    final methodPart = method.name[0].toUpperCase() +
        method.name.substring(1).toLowerCase();
    if (base.toLowerCase().startsWith(method.name.toLowerCase())) {
      return base;
    }
    return '$methodPart$base';
  }

  String get actionClassName => '${_cleanName}Action';

  String get responseClassName => '${_cleanName}Response';

  String get fileName {
    // Convert PascalCase to snake_case
    final snake = _cleanName
        .replaceAllMapped(
            RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}')
        .toLowerCase();
    return '${snake}_action.dart';
  }

  String get methodString => method.name;

  bool get requiresAuth => auth.requiresAuth;
}
