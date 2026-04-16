import 'api_endpoint.dart';

class ApiFolder {
  final String name;
  final List<ApiFolder> subfolders;
  final List<ApiEndpoint> endpoints;

  const ApiFolder({
    required this.name,
    this.subfolders = const [],
    this.endpoints = const [],
  });

  List<ApiEndpoint> get allEndpoints {
    final result = <ApiEndpoint>[...endpoints];
    for (final folder in subfolders) {
      result.addAll(folder.allEndpoints);
    }
    return result;
  }

  int get totalEndpoints => allEndpoints.length;

  bool get isEmpty => endpoints.isEmpty && subfolders.isEmpty;
}
