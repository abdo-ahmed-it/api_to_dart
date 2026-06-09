import 'package:api_request/api_request.dart';

class GetHrLeaveRequestsAction
    extends ApiRequestAction<GetHrLeaveRequestsResponse> {
  @override
  bool get authRequired => true;

  @override
  RequestMethod get method => RequestMethod.GET;

  @override
  String get path => '/hr/leave-requests';

  @override
  ContentDataType? get contentDataType => ContentDataType.formData;

  @override
  ResponseBuilder<GetHrLeaveRequestsResponse> get responseBuilder =>
      (json) => GetHrLeaveRequestsResponse.fromJson(json);
}

class GetHrLeaveRequestsResponse {
  bool? status;
  String? message;
  Response? response;

  GetHrLeaveRequestsResponse({this.status, this.message, this.response});

  GetHrLeaveRequestsResponse.fromJson(Map<String, dynamic> json) {
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
  List<Data>? data;
  Links2? links;
  Meta? meta;

  Response({this.data, this.links, this.meta});

  Response.fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      data = <Data>[];
      json['data'].forEach((v) {
        data!.add(Data.fromJson(v));
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
  int? id;
  int? userId;
  int? leaveTypeId;
  int? leaveAllocationId;
  String? startDate;
  String? endDate;
  String? totalDays;
  String? status;
  String? statusText;
  String? reason;
  dynamic rejectionReason;
  int? commissionerUserId;
  String? approvedAt;
  dynamic rejectedAt;
  String? createdAt;
  LeaveType? leaveType;
  CommissionerUser? commissionerUser;
  CommissionerUser? approvedBy;
  dynamic rejectedBy;

  Data({
    this.id,
    this.userId,
    this.leaveTypeId,
    this.leaveAllocationId,
    this.startDate,
    this.endDate,
    this.totalDays,
    this.status,
    this.statusText,
    this.reason,
    this.rejectionReason,
    this.commissionerUserId,
    this.approvedAt,
    this.rejectedAt,
    this.createdAt,
    this.leaveType,
    this.commissionerUser,
    this.approvedBy,
    this.rejectedBy,
  });

  Data.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    userId = json['user_id'];
    leaveTypeId = json['leave_type_id'];
    leaveAllocationId = json['leave_allocation_id'];
    startDate = json['start_date'];
    endDate = json['end_date'];
    totalDays = json['total_days'];
    status = json['status'];
    statusText = json['status_text'];
    reason = json['reason'];
    rejectionReason = json['rejection_reason'];
    commissionerUserId = json['commissioner_user_id'];
    approvedAt = json['approved_at'];
    rejectedAt = json['rejected_at'];
    createdAt = json['created_at'];
    leaveType =
        json['leave_type'] != null
            ? LeaveType.fromJson(json['leave_type'])
            : null;
    commissionerUser =
        json['commissioner_user'] != null
            ? CommissionerUser.fromJson(json['commissioner_user'])
            : null;
    approvedBy =
        json['approved_by'] != null
            ? CommissionerUser.fromJson(json['approved_by'])
            : null;
    rejectedBy = json['rejected_by'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['id'] = id;
    result['user_id'] = userId;
    result['leave_type_id'] = leaveTypeId;
    result['leave_allocation_id'] = leaveAllocationId;
    result['start_date'] = startDate;
    result['end_date'] = endDate;
    result['total_days'] = totalDays;
    result['status'] = status;
    result['status_text'] = statusText;
    result['reason'] = reason;
    result['rejection_reason'] = rejectionReason;
    result['commissioner_user_id'] = commissionerUserId;
    result['approved_at'] = approvedAt;
    result['rejected_at'] = rejectedAt;
    result['created_at'] = createdAt;
    if (leaveType != null) {
      result['leave_type'] = leaveType!.toJson();
    }
    if (commissionerUser != null) {
      result['commissioner_user'] = commissionerUser!.toJson();
    }
    if (approvedBy != null) {
      result['approved_by'] = approvedBy!.toJson();
    }
    result['rejected_by'] = rejectedBy;
    return result;
  }
}

class LeaveType {
  int? id;
  String? name;
  int? defaultDaysPerYear;
  bool? isPaid;
  bool? requiresAttachment;
  int? maxConsecutiveDays;

  LeaveType({
    this.id,
    this.name,
    this.defaultDaysPerYear,
    this.isPaid,
    this.requiresAttachment,
    this.maxConsecutiveDays,
  });

  LeaveType.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    defaultDaysPerYear = json['default_days_per_year'];
    isPaid = json['is_paid'];
    requiresAttachment = json['requires_attachment'];
    maxConsecutiveDays = json['max_consecutive_days'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['id'] = id;
    result['name'] = name;
    result['default_days_per_year'] = defaultDaysPerYear;
    result['is_paid'] = isPaid;
    result['requires_attachment'] = requiresAttachment;
    result['max_consecutive_days'] = maxConsecutiveDays;
    return result;
  }
}

class CommissionerUser {
  int? id;
  String? name;
  String? email;
  String? phone;
  String? avatarUrl;

  CommissionerUser({
    this.id,
    this.name,
    this.email,
    this.phone,
    this.avatarUrl,
  });

  CommissionerUser.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    email = json['email'];
    phone = json['phone'];
    avatarUrl = json['avatar_url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['id'] = id;
    result['name'] = name;
    result['email'] = email;
    result['phone'] = phone;
    result['avatar_url'] = avatarUrl;
    return result;
  }
}

class Links {
  String? first;
  String? last;
  dynamic prev;
  dynamic next;

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
