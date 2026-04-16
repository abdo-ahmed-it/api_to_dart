import '../models/api_source_config.dart';
import '../models/endpoint_tree.dart';
import 'api_source.dart';
import 'openapi_source.dart';

/// Apidog source that delegates to OpenApiSource.
/// Apidog can export projects in OpenAPI format, so this source
/// handles any Apidog-specific preprocessing before delegating
/// to the standard OpenAPI parser.
class ApidogSource implements ApiSource {
  final OpenApiSource _openApiSource = OpenApiSource();

  @override
  String get sourceName => 'Apidog';

  @override
  Future<EndpointTree> parse(ApiSourceConfig config) async {
    // Apidog exports OpenAPI-compatible specs.
    // Parse using the OpenAPI source directly.
    final tree = await _openApiSource.parse(config);

    return EndpointTree(
      sourceName: 'Apidog: ${tree.sourceName}',
      folders: tree.folders,
      rootEndpoints: tree.rootEndpoints,
    );
  }
}
