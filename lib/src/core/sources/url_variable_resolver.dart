import '../models/api_endpoint.dart';
import '../models/api_folder.dart';
import '../models/endpoint_tree.dart';

/// Resolves Apidog URL-variable path prefixes across an entire [EndpointTree].
///
/// Apidog encodes some endpoints as `/<url_var>/login`, where `<url_var>` is an
/// environment variable pointing at a full base URL (e.g.
/// `https://host/api/v1/system-user`). The variable must NOT be substituted
/// into the spec text (it would corrupt the path), so it survives as the first
/// path segment. This resolver rewrites each such endpoint to:
///   - a clean path with the variable prefix stripped (`/login`)
///   - a [ApiEndpoint.baseUrlOverride] holding the variable's URL
///   - a name rebuilt from the clean path
///
/// Endpoints without a URL-variable prefix pass through unchanged. Folder
/// structure is preserved. This is the single source of truth used by both the
/// terminal generate flow and the web server so their output is identical.
class UrlVariableResolver {
  final Map<String, String> urlVars;

  const UrlVariableResolver(this.urlVars);

  /// Returns a new tree with every endpoint resolved. A no-op when [urlVars] is
  /// empty.
  EndpointTree resolveTree(EndpointTree tree) {
    if (urlVars.isEmpty) return tree;
    return EndpointTree(
      sourceName: tree.sourceName,
      rootEndpoints: tree.rootEndpoints.map(resolveEndpoint).toList(),
      folders: tree.folders.map(_resolveFolder).toList(),
    );
  }

  ApiFolder _resolveFolder(ApiFolder f) => ApiFolder(
        name: f.name,
        endpoints: f.endpoints.map(resolveEndpoint).toList(),
        subfolders: f.subfolders.map(_resolveFolder).toList(),
      );

  /// Resolves a single endpoint. Returns it unchanged if its first path segment
  /// isn't a known URL variable.
  ApiEndpoint resolveEndpoint(ApiEndpoint ep) {
    if (urlVars.isEmpty) return ep;
    final segments = ep.path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty || !urlVars.containsKey(segments.first)) return ep;

    final base = urlVars[segments.first]!;
    final cleanPath = '/${segments.sublist(1).join('/')}';
    return ApiEndpoint(
      name: _nameFromCleanPath(cleanPath, ep.method.name),
      path: cleanPath,
      method: ep.method,
      description: ep.description,
      body: ep.body,
      headers: ep.headers,
      queryParams: ep.queryParams,
      auth: ep.auth,
      response: ep.response,
      baseUrlOverride: base,
    );
  }

  /// Builds a PascalCase name from the cleaned path's last few meaningful
  /// segments, ignoring numeric ids and `{param}` placeholders.
  static String _nameFromCleanPath(String path, String method) {
    final segments = path
        .split('/')
        .where((s) =>
            s.isNotEmpty &&
            !RegExp(r'^\d+$').hasMatch(s) &&
            !RegExp(r'^\{.*\}$').hasMatch(s))
        .toList();
    if (segments.isEmpty) return method;

    final nameParts =
        segments.length <= 3 ? segments : segments.sublist(segments.length - 3);
    return nameParts
        .join('-')
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), ' ')
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase() + s.substring(1))
        .join();
  }
}
