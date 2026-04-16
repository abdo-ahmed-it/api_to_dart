import 'package:api_request/api_request.dart';

class NotificationsAction extends ApiRequestAction<NotificationsResponse> {
  @override
  bool get authRequired => true;

  @override
  RequestMethod get method => RequestMethod.GET;

  @override
  String get path => '/notifications';

  @override
  Map<String, dynamic> get toMap => {"per_page": "10"};

  @override
  ContentDataType? get contentDataType => ContentDataType.formData;

  @override
  ResponseBuilder<NotificationsResponse> get responseBuilder =>
      (json) => NotificationsResponse.fromJson(json);
}

class NotificationsResponse {
  bool? status;
  String? message;
  Response? response;

  NotificationsResponse({this.status, this.message, this.response});

  NotificationsResponse.fromJson(Map<String, dynamic> json) {
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
  List<Data2>? data;
  Links2? links;
  Meta? meta;

  Response({this.data, this.links, this.meta});

  Response.fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      data = <Data2>[];
      json['data'].forEach((v) {
        data!.add(Data2.fromJson(v));
      });
    }
    links = json['links'] != null ? Links2.fromJson(json['links']) : null;
    meta = json['meta'] != null ? Meta.fromJson(json['meta']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    if (data != null) {
      result['data'] = data!.map((v) => v.toJson()).toList();
    }
    if (links != null) {
      result['links'] = links!.toJson();
    }
    if (meta != null) {
      result['meta'] = meta!.toJson();
    }
    return result;
  }
}

class Data {
  String? id;
  Data2? data;
  String? readAt;
  String? readAtText;
  dynamic createdBy;
  String? createdAtText;

  Data({
    this.id,
    this.data,
    this.readAt,
    this.readAtText,
    this.createdBy,
    this.createdAtText,
  });

  Data.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    data = json['data'] != null ? Data2.fromJson(json['data']) : null;
    readAt = json['read_at'];
    readAtText = json['read_at_text'];
    createdBy = json['created_by'];
    createdAtText = json['created_at_text'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['id'] = id;
    if (data != null) {
      result['data'] = data!.toJson();
    }
    result['read_at'] = readAt;
    result['read_at_text'] = readAtText;
    result['created_by'] = createdBy;
    result['created_at_text'] = createdAtText;
    return result;
  }
}

class Data2 {
  Body? body;
  String? url;
  String? urlLabel;
  int? moduleNotificationId;
  int? modelId;
  String? modelType;
  dynamic group;
  dynamic createdById;
  dynamic createdByType;
  String? message;

  Data2({
    this.body,
    this.url,
    this.urlLabel,
    this.moduleNotificationId,
    this.modelId,
    this.modelType,
    this.group,
    this.createdById,
    this.createdByType,
    this.message,
  });

  Data2.fromJson(Map<String, dynamic> json) {
    body = json['body'] != null ? Body.fromJson(json['body']) : null;
    url = json['url'];
    urlLabel = json['url_label'];
    moduleNotificationId = json['module_notification_id'];
    modelId = json['model_id'];
    modelType = json['model_type'];
    group = json['group'];
    createdById = json['created_by_id'];
    createdByType = json['created_by_type'];
    message = json['message'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    if (body != null) {
      result['body'] = body!.toJson();
    }
    result['url'] = url;
    result['url_label'] = urlLabel;
    result['module_notification_id'] = moduleNotificationId;
    result['model_id'] = modelId;
    result['model_type'] = modelType;
    result['group'] = group;
    result['created_by_id'] = createdById;
    result['created_by_type'] = createdByType;
    result['message'] = message;
    return result;
  }
}

class Body {
  String? ar;
  String? en;

  Body({this.ar, this.en});

  Body.fromJson(Map<String, dynamic> json) {
    ar = json['ar'];
    en = json['en'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['ar'] = ar;
    result['en'] = en;
    return result;
  }
}

class Links {
  String? first;
  String? last;
  dynamic prev;
  String? next;

  Links({this.first, this.last, this.prev, this.next});

  Links.fromJson(Map<String, dynamic> json) {
    first = json['first'];
    last = json['last'];
    prev = json['prev'];
    next = json['next'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['first'] = first;
    result['last'] = last;
    result['prev'] = prev;
    result['next'] = next;
    return result;
  }
}

class Meta {
  int? currentPage;
  int? from;
  int? lastPage;
  List<Links2>? links;
  String? path;
  int? perPage;
  int? to;
  int? total;

  Meta({
    this.currentPage,
    this.from,
    this.lastPage,
    this.links,
    this.path,
    this.perPage,
    this.to,
    this.total,
  });

  Meta.fromJson(Map<String, dynamic> json) {
    currentPage = json['current_page'];
    from = json['from'];
    lastPage = json['last_page'];
    if (json['links'] != null) {
      links = <Links2>[];
      json['links'].forEach((v) {
        links!.add(Links2.fromJson(v));
      });
    }
    path = json['path'];
    perPage = json['per_page'];
    to = json['to'];
    total = json['total'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['current_page'] = currentPage;
    result['from'] = from;
    result['last_page'] = lastPage;
    if (links != null) {
      result['links'] = links!.map((v) => v.toJson()).toList();
    }
    result['path'] = path;
    result['per_page'] = perPage;
    result['to'] = to;
    result['total'] = total;
    return result;
  }
}

class Links2 {
  String? url;
  String? label;
  int? page;
  bool? active;

  Links2({this.url, this.label, this.page, this.active});

  Links2.fromJson(Map<String, dynamic> json) {
    url = json['url'];
    label = json['label'];
    page = json['page'];
    active = json['active'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['url'] = url;
    result['label'] = label;
    result['page'] = page;
    result['active'] = active;
    return result;
  }
}
