import 'package:api_request/api_request.dart';

class ProfileAction extends ApiRequestAction<ProfileResponse> {
  @override
  bool get authRequired => true;

  @override
  RequestMethod get method => RequestMethod.GET;

  @override
  String get path => '/profile';

  @override
  ResponseBuilder<ProfileResponse> get responseBuilder =>
      (json) => ProfileResponse.fromJson(json);
}

class ProfileResponse {
  bool? status;
  String? message;
  Response? response;

  ProfileResponse({this.status, this.message, this.response});

  ProfileResponse.fromJson(Map<String, dynamic> json) {
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
  User? user;

  Response({this.user});

  Response.fromJson(Map<String, dynamic> json) {
    user = json['user'] != null ? User.fromJson(json['user']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    if (user != null) {
      result['user'] = user!.toJson();
    }
    return result;
  }
}

class User {
  int? id;
  dynamic idNumber;
  dynamic jobTitle;
  String? name;
  String? email;
  String? phone;
  String? avatarUrl;
  int? abilitiesUpdatedAt;
  int? departmentId;
  dynamic sectionId;

  User({
    this.id,
    this.idNumber,
    this.jobTitle,
    this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    this.abilitiesUpdatedAt,
    this.departmentId,
    this.sectionId,
  });

  User.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    idNumber = json['id_number'];
    jobTitle = json['job_title'];
    name = json['name'];
    email = json['email'];
    phone = json['phone'];
    avatarUrl = json['avatar_url'];
    abilitiesUpdatedAt = json['abilities_updated_at'];
    departmentId = json['department_id'];
    sectionId = json['section_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['id'] = id;
    result['id_number'] = idNumber;
    result['job_title'] = jobTitle;
    result['name'] = name;
    result['email'] = email;
    result['phone'] = phone;
    result['avatar_url'] = avatarUrl;
    result['abilities_updated_at'] = abilitiesUpdatedAt;
    result['department_id'] = departmentId;
    result['section_id'] = sectionId;
    return result;
  }
}
