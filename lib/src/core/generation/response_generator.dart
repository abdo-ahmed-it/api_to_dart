import '../json_to_dart/model_generator.dart';

class ResponseGenerator {
  /// Generates Dart model classes from a JSON response string.
  /// Returns the formatted Dart code string.
  String generate(String jsonBody, String className) {
    final model = ModelGenerator(className);
    final code = model.generateDartClasses(jsonBody);
    return code.code;
  }

  /// Generates unformatted Dart model classes (for cases where
  /// formatting will be done later).
  String generateUnsafe(String jsonBody, String className) {
    final model = ModelGenerator(className);
    final code = model.generateUnsafeDart(jsonBody);
    return code.code;
  }
}
