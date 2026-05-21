import 'package:api_request/api_request.dart';

class GetFAQAction extends ApiRequestAction<dynamic> {
  @override
  RequestMethod get method => RequestMethod.GET;

  @override
  String get path => '/faq';

  @override
  ResponseBuilder<dynamic> get responseBuilder => (json) => json;
}
