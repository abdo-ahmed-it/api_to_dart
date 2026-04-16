import 'package:api_request/api_request.dart';

class NotificationsMarkAllAsReadAction
    extends ApiRequestAction<NotificationsMarkAllAsReadResponse> {
  @override
  bool get authRequired => true;

  @override
  RequestMethod get method => RequestMethod.POST;

  @override
  String get path => '/notifications/mark-all-as-read';

  @override
  Map<String, dynamic> get toMap => {"per_page": "10"};

  @override
  ContentDataType? get contentDataType => ContentDataType.formData;

  @override
  ResponseBuilder<NotificationsMarkAllAsReadResponse> get responseBuilder =>
      (json) => NotificationsMarkAllAsReadResponse.fromJson(json);
}

class NotificationsMarkAllAsReadResponse {
  bool? status;
  String? message;
  List<dynamic>? response;

  NotificationsMarkAllAsReadResponse({
    this.status,
    this.message,
    this.response,
  });

  NotificationsMarkAllAsReadResponse.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    message = json['message'];
    response =
        json['response'] != null ? List<dynamic>.from(json['response']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['status'] = status;
    result['message'] = message;
    result['response'] = response;
    return result;
  }
}
