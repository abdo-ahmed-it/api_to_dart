import 'package:api_request/api_request.dart';

class PrivacyPolicyAction extends ApiRequestAction<PrivacyPolicyResponse> {
  @override
  RequestMethod get method => RequestMethod.GET;

  @override
  String get path => '/settings/privacy_policy';

  @override
  ResponseBuilder<PrivacyPolicyResponse> get responseBuilder =>
      (json) => PrivacyPolicyResponse.fromJson(json);
}

class PrivacyPolicyResponse {
  String? message;
  dynamic data;

  PrivacyPolicyResponse({this.message, this.data});

  PrivacyPolicyResponse.fromJson(Map<String, dynamic> json) {
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
