import 'api_endpoint.dart';
import 'api_folder.dart';

class EndpointTree {
  final String sourceName;
  final List<ApiFolder> folders;
  final List<ApiEndpoint> rootEndpoints;

  const EndpointTree({
    required this.sourceName,
    this.folders = const [],
    this.rootEndpoints = const [],
  });

  List<ApiEndpoint> get allEndpoints {
    final result = <ApiEndpoint>[...rootEndpoints];
    for (final folder in folders) {
      result.addAll(folder.allEndpoints);
    }
    return result;
  }

  int get totalEndpoints => allEndpoints.length;

  bool get isEmpty => rootEndpoints.isEmpty && folders.isEmpty;
}
