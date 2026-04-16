import '../models/api_source_config.dart';
import '../models/endpoint_tree.dart';

abstract class ApiSource {
  Future<EndpointTree> parse(ApiSourceConfig config);
  String get sourceName;
}
