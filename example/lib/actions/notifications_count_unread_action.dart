import 'package:api_request/api_request.dart';

class NotificationsCountUnreadAction
    extends ApiRequestAction<NotificationsCountUnreadResponse> {
  @override
  bool get authRequired => true;

  @override
  RequestMethod get method => RequestMethod.GET;

  @override
  String get path => '/notifications/count-unread';

  @override
  ContentDataType? get contentDataType => ContentDataType.formData;

  @override
  ResponseBuilder<NotificationsCountUnreadResponse> get responseBuilder =>
      (json) => NotificationsCountUnreadResponse.fromJson(json);
}

class NotificationsCountUnreadResponse {
  bool? status;
  String? message;
  Response? response;

  NotificationsCountUnreadResponse({this.status, this.message, this.response});

  NotificationsCountUnreadResponse.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    message = json['message'];
    response =
        json['response'] != null ? Response.fromJson(json['response']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['status'] = status;
    result['message'] = message;
    if (response != null) {
      result['response'] = response!.toJson();
    }
    return result;
  }
}

class Response {
  int? count;

  Response({this.count});

  Response.fromJson(Map<String, dynamic> json) {
    count = json['count'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['count'] = count;
    return result;
  }
}
