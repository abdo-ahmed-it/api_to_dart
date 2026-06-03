import '../json_to_dart/enum_extractor.dart';
import '../json_to_dart/model_generator.dart';

class ResponseGenerator {
  /// Generates Dart model classes from a JSON response string.
  ///
  /// When [schema] (a resolved OpenAPI schema) is provided, string fields
  /// declaring an `enum` are emitted as real Dart enums with an `unknown`
  /// fallback instead of plain `String`.
  ///
  /// Returns the formatted Dart code string.
  String generate(String jsonBody, String className,
      {Map<String, dynamic>? schema}) {
    final model = ModelGenerator(className, false, null, _enumHints(schema));
    final code = model.generateDartClasses(jsonBody);
    return code.code;
  }

  /// Generates unformatted Dart model classes (for cases where
  /// formatting will be done later).
  String generateUnsafe(String jsonBody, String className,
      {Map<String, dynamic>? schema}) {
    final model = ModelGenerator(className, false, null, _enumHints(schema));
    final code = model.generateUnsafeDart(jsonBody);
    return code.code;
  }

  List<EnumHint> _enumHints(Map<String, dynamic>? schema) {
    if (schema == null || schema.isEmpty) return const [];
    return EnumExtractor().extract(schema);
  }
}
