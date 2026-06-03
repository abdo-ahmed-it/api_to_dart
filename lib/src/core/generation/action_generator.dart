import 'dart:convert';

import '../models/api_endpoint.dart';
import '../models/body_definition.dart';

class ActionGenerator {
  /// Generates a Dart action class string for the given endpoint.
  /// The generated class extends ApiRequestAction from the api_request package.
  String generate(ApiEndpoint endpoint) {
    final actionClassName = endpoint.actionClassName;
    final responseType = endpoint.responseClassName;

    final authText = _getAuthRequiredText(endpoint);
    final toMapText = _getToMapText(endpoint);
    final dataTypeText = _getDataTypeText(endpoint);
    final filesText = _getFilesText(endpoint);

    return '''
import 'package:api_request/api_request.dart';


class $actionClassName extends ApiRequestAction<$responseType> {
  $authText

  @override
  RequestMethod get method => RequestMethod.${endpoint.method.name};

  @override
  String get path => '${endpoint.path}';

  $toMapText

  $dataTypeText

  $filesText

  @override
  ResponseBuilder<$responseType> get responseBuilder =>
      (json) => $responseType.fromJson(json);
}
  ''';
  }

  /// Generates an action-only class (no response model) when response
  /// data is unavailable.
  String generateActionOnly(ApiEndpoint endpoint) {
    final actionClassName = endpoint.actionClassName;

    final authText = _getAuthRequiredText(endpoint);
    final toMapText = _getToMapText(endpoint);
    final dataTypeText = _getDataTypeText(endpoint);
    final filesText = _getFilesText(endpoint);

    return '''
import 'package:api_request/api_request.dart';


class $actionClassName extends ApiRequestAction<dynamic> {
  $authText

  @override
  RequestMethod get method => RequestMethod.${endpoint.method.name};

  @override
  String get path => '${endpoint.path}';

  $toMapText

  $dataTypeText

  $filesText

  @override
  ResponseBuilder<dynamic> get responseBuilder => (json) => json;
}
  ''';
  }

  String _getAuthRequiredText(ApiEndpoint endpoint) {
    if (endpoint.requiresAuth) {
      return '''
  @override
  bool get authRequired => true;
      ''';
    }
    return '';
  }

  String _getToMapText(ApiEndpoint endpoint) {
    final body = endpoint.body;
    if (body == null || body.isEmpty) return '';

    if (body.hasFormFields) {
      final formDataString = jsonEncode(body.formFields);
      return '''
  @override
  Map<String, dynamic> get toMap => $formDataString;
      ''';
    } else if (body.hasRawBody) {
      return '''
  @override
  Map<String, dynamic> get toMap => jsonDecode('${body.rawBody?.replaceAll("'", "\\\\'")}');
      ''';
    }
    return '';
  }

  String _getDataTypeText(ApiEndpoint endpoint) {
    final body = endpoint.body;
    if (body == null || body.contentType == null) return '';

    if (body.hasFiles) {
      return '''
  @override
  ContentDataType? get contentDataType => ContentDataType.formData;
  // Note: This action includes file uploads which need to be handled separately
      ''';
    }

    final typeMapping = {
      BodyContentType.formData: 'formData',
      BodyContentType.urlEncoded: 'formData',
      BodyContentType.rawJson: 'bodyData',
      BodyContentType.multipart: 'formData',
    };

    final typeName = typeMapping[body.contentType];
    if (typeName != null) {
      return '''
  @override
  ContentDataType? get contentDataType => ContentDataType.$typeName;
      ''';
    }
    return '';
  }

  String _getFilesText(ApiEndpoint endpoint) {
    final body = endpoint.body;
    if (body == null || !body.hasFiles) return '';

    final fieldNames = body.files!.map((f) => f.fieldName).join(', ');
    return '''
  // TODO: Implement file handling for the following fields:
  // $fieldNames
      ''';
  }
}
