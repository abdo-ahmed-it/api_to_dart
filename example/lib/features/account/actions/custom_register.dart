import 'package:api_request/api_request.dart';

class RegisterAction extends ApiRequestAction<RegisterResponse> {
  @override
  RequestMethod get method => RequestMethod.POST;

  @override
  String get path => '/auth/register';

  @override
  ResponseBuilder<RegisterResponse> get responseBuilder =>
      (json) => RegisterResponse.fromJson(json);
}

class RegisterResponse {
  String? message;
  Errors? errors;

  RegisterResponse({this.message, this.errors});

  RegisterResponse.fromJson(Map<String, dynamic> json) {
    message = json['message'];
    errors = json['errors'] != null ? Errors.fromJson(json['errors']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['message'] = message;
    if (errors != null) {
      data['errors'] = errors!.toJson();
    }
    return data;
  }
}

class Errors {
  List<String>? type;
  List<String>? phone;

  Errors({this.type, this.phone});

  Errors.fromJson(Map<String, dynamic> json) {
    type = json['type'].cast<String>();
    phone = json['phone'].cast<String>();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['type'] = type;
    data['phone'] = phone;
    return data;
  }
}
