import '../models/body_definition.dart';

/// Processes raw body data (from Postman JSON, YAML config, etc.)
/// into a canonical [BodyDefinition].
BodyDefinition processBody(dynamic body) {
  if (body is BodyDefinition) {
    return body;
  }

  if (body == null) {
    return const BodyDefinition();
  }

  if (body is Map) {
    final String? mode = body['mode']?.toString();
    final dynamic data = body['data'];

    // If no mode specified but has data map, treat as form data
    if (mode == null && data is Map) {
      final formData = <String, String>{};
      data.forEach((key, value) {
        formData[key.toString()] = value.toString();
      });
      return BodyDefinition(
        contentType: BodyContentType.formData,
        formFields: formData,
      );
    }

    switch (mode) {
      case 'formdata':
        return _processFormData(data);
      case 'urlencoded':
        return _processUrlEncoded(data);
      case 'raw':
        return BodyDefinition(
          contentType: BodyContentType.rawJson,
          rawBody: data.toString(),
        );
      default:
        return const BodyDefinition();
    }
  }

  return const BodyDefinition();
}

/// Process Postman-style formdata (array of {key, value, type} objects)
/// or a simple key-value map.
BodyDefinition processPostmanFormData(List<dynamic> formdata) {
  final formFields = <String, String>{};
  final files = <FileField>[];

  for (final field in formdata) {
    if (field is Map) {
      final key = field['key']?.toString() ?? '';
      final type = field['type']?.toString() ?? 'text';
      if (type == 'file') {
        files.add(FileField(fieldName: key, filePath: field['src']?.toString()));
      } else {
        formFields[key] = field['value']?.toString() ?? '';
      }
    }
  }

  return BodyDefinition(
    contentType:
        files.isNotEmpty ? BodyContentType.multipart : BodyContentType.formData,
    formFields: formFields.isNotEmpty ? formFields : null,
    files: files.isNotEmpty ? files : null,
  );
}

BodyDefinition _processFormData(dynamic data) {
  final formData = <String, String>{};
  final files = <FileField>[];

  if (data is Map) {
    data.forEach((key, value) {
      if (value is Map && value['type'] == 'file' && value['src'] != null) {
        files.add(
            FileField(fieldName: key.toString(), filePath: value['src'].toString()));
      } else {
        formData[key.toString()] = value.toString();
      }
    });
  }

  return BodyDefinition(
    contentType:
        files.isNotEmpty ? BodyContentType.multipart : BodyContentType.formData,
    formFields: formData.isNotEmpty ? formData : null,
    files: files.isNotEmpty ? files : null,
  );
}

BodyDefinition _processUrlEncoded(dynamic data) {
  final formData = <String, String>{};
  if (data is Map) {
    data.forEach((key, value) {
      formData[key.toString()] = value.toString();
    });
  }
  return BodyDefinition(
    contentType: BodyContentType.urlEncoded,
    formFields: formData.isNotEmpty ? formData : null,
  );
}
