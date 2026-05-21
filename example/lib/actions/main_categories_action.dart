import 'package:api_request/api_request.dart';

class MainCategoriesAction extends ApiRequestAction<MainCategoriesResponse> {
  @override
  RequestMethod get method => RequestMethod.GET;

  @override
  String get path => '/main-categories';

  @override
  ResponseBuilder<MainCategoriesResponse> get responseBuilder =>
      (json) => MainCategoriesResponse.fromJson(json);
}

class MainCategoriesResponse {
  String? message;
  Data? data;

  MainCategoriesResponse({this.message, this.data});

  MainCategoriesResponse.fromJson(Map<String, dynamic> json) {
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
  List<MainCategories>? mainCategories;
  List<Cities>? cities;

  Data({this.mainCategories, this.cities});

  Data.fromJson(Map<String, dynamic> json) {
    if (json['main_categories'] != null) {
      mainCategories = <MainCategories>[];
      json['main_categories'].forEach((v) {
        mainCategories!.add(MainCategories.fromJson(v));
      });
    }
    if (json['cities'] != null) {
      cities = <Cities>[];
      json['cities'].forEach((v) {
        cities!.add(Cities.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    if (mainCategories != null) {
      result['main_categories'] =
          mainCategories!.map((v) => v.toJson()).toList();
    }
    if (cities != null) {
      result['cities'] = cities!.map((v) => v.toJson()).toList();
    }
    return result;
  }
}

class MainCategories {
  int? id;
  String? name;
  String? icon;
  String? banner;
  dynamic parentId;
  List<Fields>? fields;

  MainCategories({
    this.id,
    this.name,
    this.icon,
    this.banner,
    this.parentId,
    this.fields,
  });

  MainCategories.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    icon = json['icon'];
    banner = json['banner'];
    parentId = json['parent_id'];
    if (json['fields'] != null) {
      fields = <Fields>[];
      json['fields'].forEach((v) {
        fields!.add(Fields.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['id'] = id;
    result['name'] = name;
    result['icon'] = icon;
    result['banner'] = banner;
    result['parent_id'] = parentId;
    if (fields != null) {
      result['fields'] = fields!.map((v) => v.toJson()).toList();
    }
    return result;
  }
}

class Fields {
  String? name;
  String? label;
  String? type;
  List<Options>? options;
  int? value;
  String? icon;

  Fields({
    this.name,
    this.label,
    this.type,
    this.options,
    this.value,
    this.icon,
  });

  Fields.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    label = json['label'];
    type = json['type'];
    if (json['options'] != null) {
      options = <Options>[];
      json['options'].forEach((v) {
        options!.add(Options.fromJson(v));
      });
    }
    value = json['value'];
    icon = json['icon'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['name'] = name;
    result['label'] = label;
    result['type'] = type;
    if (options != null) {
      result['options'] = options!.map((v) => v.toJson()).toList();
    }
    result['value'] = value;
    result['icon'] = icon;
    return result;
  }
}

class Options {
  int? id;
  String? name;
  String? icon;
  String? banner;
  int? parentId;

  Options({this.id, this.name, this.icon, this.banner, this.parentId});

  Options.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    icon = json['icon'];
    banner = json['banner'];
    parentId = json['parent_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['id'] = id;
    result['name'] = name;
    result['icon'] = icon;
    result['banner'] = banner;
    result['parent_id'] = parentId;
    return result;
  }
}

class Cities {
  int? id;
  String? name;

  Cities({this.id, this.name});

  Cities.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = <String, dynamic>{};
    result['id'] = id;
    result['name'] = name;
    return result;
  }
}
