import 'package:api_request/api_request.dart';

class OnBoardingDataAction extends ApiRequestAction<OnBoardingDataResponse> {
  @override
  RequestMethod get method => RequestMethod.GET;

  @override
  String get path => '/onboarding/data';

  @override
  ResponseBuilder<OnBoardingDataResponse> get responseBuilder =>
      (json) => OnBoardingDataResponse.fromJson(json);
}

class OnBoardingDataResponse {
  String? message;
  Data? data;

  OnBoardingDataResponse({this.message, this.data});

  OnBoardingDataResponse.fromJson(Map<String, dynamic> json) {
    message = json['message'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['message'] = message;
    if (data != null) {
      result['data'] = data!.toJson();
    }
    return result;
  }
}

class Data {
  List<Onboarding>? onboarding;

  Data({this.onboarding});

  Data.fromJson(Map<String, dynamic> json) {
    if (json['onboarding'] != null) {
      onboarding = <Onboarding>[];
      json['onboarding'].forEach((v) {
        onboarding!.add(Onboarding.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    if (onboarding != null) {
      result['onboarding'] = onboarding!.map((v) => v.toJson()).toList();
    }
    return result;
  }
}

class Onboarding {
  int? id;
  String? title;
  String? description;
  String? file;

  Onboarding({this.id, this.title, this.description, this.file});

  Onboarding.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    title = json['title'];
    description = json['description'];
    file = json['file'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['id'] = id;
    result['title'] = title;
    result['description'] = description;
    result['file'] = file;
    return result;
  }
}
