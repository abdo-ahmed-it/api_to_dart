enum ResponseSource { schema, example, fetched, none }

class ResponseDefinition {
  final ResponseSource source;
  final String? jsonBody;
  final Map<String, dynamic>? schema;

  const ResponseDefinition({
    required this.source,
    this.jsonBody,
    this.schema,
  });

  bool get hasJson => jsonBody != null && jsonBody!.isNotEmpty;
  bool get hasSchema => schema != null && schema!.isNotEmpty;

  static const empty = ResponseDefinition(source: ResponseSource.none);
}
