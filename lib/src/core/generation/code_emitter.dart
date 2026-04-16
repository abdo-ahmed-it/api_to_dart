import 'dart:io';

import 'package:dart_style/dart_style.dart';

import '../logger/logger.dart';
import '../models/api_endpoint.dart';
import '../models/response_definition.dart';
import 'action_generator.dart';
import 'response_generator.dart';

class CodeEmitter {
  final ActionGenerator _actionGenerator;
  final ResponseGenerator _responseGenerator;
  final Logger _logger;

  CodeEmitter({
    ActionGenerator? actionGenerator,
    ResponseGenerator? responseGenerator,
    required Logger logger,
  })  : _actionGenerator = actionGenerator ?? ActionGenerator(),
        _responseGenerator = responseGenerator ?? ResponseGenerator(),
        _logger = logger;

  /// Generates and writes action + response code for a single endpoint.
  String? emit({
    required ApiEndpoint endpoint,
    required String outputDir,
    ResponseDefinition? response,
    String? customFileName,
  }) {
    try {
      final name = endpoint.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

      String fileContent;

      if (response != null && response.hasJson) {
        final action = _actionGenerator.generate(endpoint);
        final responseCode =
            _responseGenerator.generate(response.jsonBody!, '${name}Response');
        fileContent = '$action\n\n$responseCode\n';
      } else {
        fileContent = _actionGenerator.generateActionOnly(endpoint);
      }

      final formatter = DartFormatter(
          languageVersion: DartFormatter.latestLanguageVersion);
      final formattedCode = formatter.format(fileContent);

      Directory(outputDir).createSync(recursive: true);
      final fileName = customFileName ?? endpoint.fileName;
      final filePath = '$outputDir/$fileName';
      File(filePath).writeAsStringSync(formattedCode);

      _logger.i('Generated $filePath');
      return filePath;
    } catch (e) {
      _logger.e('Error generating code for ${endpoint.name}', error: e);
      return null;
    }
  }

  /// Batch generate — each action is self-contained with its own models.
  int emitBatch({
    required Map<ApiEndpoint, ResponseDefinition?> endpointResponses,
    required String outputDir,
  }) {
    int generated = 0;

    for (final entry in endpointResponses.entries) {
      final filePath = emit(
        endpoint: entry.key,
        outputDir: outputDir,
        response: entry.value,
      );

      if (filePath != null) {
        generated++;
      }
    }

    return generated;
  }

  /// Generates code as a string without writing to disk.
  String? generateCode({
    required ApiEndpoint endpoint,
    ResponseDefinition? response,
  }) {
    try {
      final name = endpoint.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

      String fileContent;

      if (response != null && response.hasJson) {
        final action = _actionGenerator.generate(endpoint);
        final responseCode =
            _responseGenerator.generate(response.jsonBody!, '${name}Response');
        fileContent = '$action\n\n$responseCode\n';
      } else {
        fileContent = _actionGenerator.generateActionOnly(endpoint);
      }

      final formatter = DartFormatter(
          languageVersion: DartFormatter.latestLanguageVersion);
      return formatter.format(fileContent);
    } catch (e) {
      _logger.e('Error generating code for ${endpoint.name}', error: e);
      return null;
    }
  }
}
