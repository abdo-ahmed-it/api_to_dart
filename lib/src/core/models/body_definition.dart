enum BodyContentType { formData, urlEncoded, rawJson, multipart }

class FileField {
  final String fieldName;
  final String? filePath;

  const FileField({required this.fieldName, this.filePath});
}

class BodyDefinition {
  final BodyContentType? contentType;
  final Map<String, String>? formFields;
  final String? rawBody;
  final List<FileField>? files;

  const BodyDefinition({
    this.contentType,
    this.formFields,
    this.rawBody,
    this.files,
  });

  bool get hasFiles => files != null && files!.isNotEmpty;
  bool get hasFormFields => formFields != null && formFields!.isNotEmpty;
  bool get hasRawBody => rawBody != null && rawBody!.isNotEmpty;
  bool get isEmpty =>
      contentType == null && !hasFormFields && !hasRawBody && !hasFiles;
}
