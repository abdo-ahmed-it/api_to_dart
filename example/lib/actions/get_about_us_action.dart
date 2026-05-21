import 'package:api_request/api_request.dart';

class GetAboutUsAction extends ApiRequestAction<dynamic> {
  @override
  RequestMethod get method => RequestMethod.GET;

  @override
  String get path => '/about';

  @override
  ResponseBuilder<dynamic> get responseBuilder => (json) => json;
}
