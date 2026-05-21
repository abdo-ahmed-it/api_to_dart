import 'package:api_request/api_request.dart';

class GetPrivacyAction extends ApiRequestAction<dynamic> {
  @override
  RequestMethod get method => RequestMethod.GET;

  @override
  String get path => '/privacy';

  @override
  ResponseBuilder<dynamic> get responseBuilder => (json) => json;
}
