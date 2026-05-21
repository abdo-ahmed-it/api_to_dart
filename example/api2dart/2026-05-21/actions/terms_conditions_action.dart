import 'package:api_request/api_request.dart';

class TermsConditionsAction extends ApiRequestAction<TermsConditionsResponse> {
  @override
  RequestMethod get method => RequestMethod.GET;

  @override
  String get path => '/settings/terms_conditions';

  @override
  ResponseBuilder<TermsConditionsResponse> get responseBuilder =>
      (json) => TermsConditionsResponse.fromJson(json);
}

class TermsConditionsResponse {
  String? message;
  dynamic data;

  TermsConditionsResponse({this.message, this.data});

  TermsConditionsResponse.fromJson(Map<String, dynamic> json) {
    message = json['message'];
    data = json['data'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['message'] = message;
    result['data'] = data;
    return result;
  }
}
