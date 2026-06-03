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

  /// Generates and writes code for a single endpoint.
  ///
  /// When [generateAction] is `true` (default) the file contains an
  /// `ApiRequestAction` subclass plus its response model.
  /// When `false` only the response model is generated — useful for projects
  /// that don't depend on the `api_request` package.
  String? emit({
    required ApiEndpoint endpoint,
    required String outputDir,
    ResponseDefinition? response,
    String? customFileName,
    bool generateAction = true,
  }) {
    try {
      final responseClassName = endpoint.responseClassName;
      final hasResponse = response != null && response.hasJson;

      String fileContent;
      if (generateAction) {
        if (hasResponse) {
          final action = _actionGenerator.generate(endpoint);
          final responseCode = _responseGenerator.generate(
              response.jsonBody!, responseClassName,
              schema: response.schema);
          fileContent = '$action\n\n$responseCode\n';
        } else {
          fileContent = _actionGenerator.generateActionOnly(endpoint);
        }
      } else {
        // Response-only mode: skip files we can't usefully generate.
        if (!hasResponse) {
          _logger.w(
              'Skipped ${endpoint.name}: no response data available '
              '(response-only mode).');
          return null;
        }
        fileContent = _responseGenerator.generate(
            response.jsonBody!, responseClassName,
            schema: response.schema);
      }

      final formatter = DartFormatter(
          languageVersion: DartFormatter.latestLanguageVersion);
      final formattedCode = formatter.format(fileContent);

      Directory(outputDir).createSync(recursive: true);
      final fileName = customFileName ?? _fileNameFor(endpoint, generateAction);
      final filePath = '$outputDir/$fileName';
      File(filePath).writeAsStringSync(formattedCode);

      _logger.i('Generated $filePath');
      return filePath;
    } catch (e) {
      _logger.e('Error generating code for ${endpoint.name}', error: e);
      return null;
    }
  }

  /// Batch generate — each endpoint becomes its own self-contained file.
  int emitBatch({
    required Map<ApiEndpoint, ResponseDefinition?> endpointResponses,
    required String outputDir,
    bool generateAction = true,
  }) {
    int generated = 0;

    for (final entry in endpointResponses.entries) {
      final filePath = emit(
        endpoint: entry.key,
        outputDir: outputDir,
        response: entry.value,
        generateAction: generateAction,
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
    bool generateAction = true,
  }) {
    try {
      final responseClassName = endpoint.responseClassName;
      final hasResponse = response != null && response.hasJson;

      String fileContent;
      if (generateAction) {
        if (hasResponse) {
          final action = _actionGenerator.generate(endpoint);
          final responseCode = _responseGenerator.generate(
              response.jsonBody!, responseClassName,
              schema: response.schema);
          fileContent = '$action\n\n$responseCode\n';
        } else {
          fileContent = _actionGenerator.generateActionOnly(endpoint);
        }
      } else {
        if (!hasResponse) return null;
        fileContent = _responseGenerator.generate(
            response.jsonBody!, responseClassName,
            schema: response.schema);
      }

      final formatter = DartFormatter(
          languageVersion: DartFormatter.latestLanguageVersion);
      return formatter.format(fileContent);
    } catch (e) {
      _logger.e('Error generating code for ${endpoint.name}', error: e);
      return null;
    }
  }

  String _fileNameFor(ApiEndpoint endpoint, bool generateAction) {
    if (generateAction) return endpoint.fileName;
    // In response-only mode, "<name>_action.dart" would mislead readers —
    // emit "<name>_response.dart" instead.
    return endpoint.fileName.replaceAll('_action.dart', '_response.dart');
  }
}
