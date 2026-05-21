import 'package:api_request/api_request.dart';

class GetTermsConditionsAction extends ApiRequestAction<dynamic> {
  @override
  RequestMethod get method => RequestMethod.GET;

  @override
  String get path => '/terms-conditions';

  @override
  ResponseBuilder<dynamic> get responseBuilder => (json) => json;
}
