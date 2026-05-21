import 'package:api_request/api_request.dart';

class GetCancellationTermsAction extends ApiRequestAction<dynamic> {
  @override
  RequestMethod get method => RequestMethod.GET;

  @override
  String get path => '/cancellation/terms';

  @override
  ResponseBuilder<dynamic> get responseBuilder => (json) => json;
}
