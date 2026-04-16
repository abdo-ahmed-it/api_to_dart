import 'dart:io';

import 'package:dart_style/dart_style.dart';

import '../logger/logger.dart';
import '../models/api_endpoint.dart';
import '../models/response_definition.dart';
import 'action_generator.dart';
import 'model_deduplicator.dart';
import 'response_generator.dart';

class CodeEmitter {
  final ActionGenerator _actionGenerator;
  final ResponseGenerator _responseGenerator;
  final ModelDeduplicator _deduplicator;
  final Logger _logger;

  CodeEmitter({
    ActionGenerator? actionGenerator,
    ResponseGenerator? responseGenerator,
    ModelDeduplicator? deduplicator,
    required Logger logger,
  })  : _actionGenerator = actionGenerator ?? ActionGenerator(),
        _responseGenerator = responseGenerator ?? ResponseGenerator(),
        _deduplicator = deduplicator ?? ModelDeduplicator(),
        _logger = logger;

  /// Generates and writes action + response code for a single endpoint.
  /// Returns the file path of the generated file, or null on failure.
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

  /// Batch generate with shared model deduplication.
  /// Generates all actions, finds duplicate models, writes shared models
  /// to models/ folder, and writes actions with proper imports.
  ///
  /// Returns the number of successfully generated files.
  int emitBatch({
    required Map<ApiEndpoint, ResponseDefinition?> endpointResponses,
    required String outputDir,
  }) {
    // Collect JSON responses for deduplication
    final jsonResponses = <String, String>{}; // endpointName -> jsonBody
    final endpointsByName = <String, ApiEndpoint>{};

    for (final entry in endpointResponses.entries) {
      final endpoint = entry.key;
      final response = entry.value;
      final name = endpoint.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

      endpointsByName[name] = endpoint;

      if (response != null && response.hasJson) {
        jsonResponses[name] = response.jsonBody!;
      }
    }

    // Run deduplication
    final dedup = _deduplicator.deduplicate(jsonResponses);

    // Write shared models if any
    if (dedup.sharedModels.isNotEmpty && dedup.sharedModelsCode.isNotEmpty) {
      try {
        final modelsDir = '$outputDir/models';
        Directory(modelsDir).createSync(recursive: true);

        final formatter = DartFormatter(
            languageVersion: DartFormatter.latestLanguageVersion);
        final formattedShared = formatter.format(dedup.sharedModelsCode);

        final sharedPath = '$modelsDir/shared_models.dart';
        File(sharedPath).writeAsStringSync(formattedShared);
        _logger.i(
            'Generated $sharedPath (${dedup.sharedModels.length} shared models: ${dedup.sharedModelNames.join(', ')})');
      } catch (e) {
        _logger.e('Error writing shared models', error: e);
      }
    }

    // Write each action file
    int generated = 0;
    final formatter =
        DartFormatter(languageVersion: DartFormatter.latestLanguageVersion);

    for (final entry in endpointResponses.entries) {
      final endpoint = entry.key;
      final response = entry.value;
      final name = endpoint.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

      try {
        String fileContent;
        final hasSharedModels = dedup.sharedModelNames.isNotEmpty &&
            dedup.sharedModels.any((m) => m.usedBy.contains(name));

        if (response != null && response.hasJson) {
          final action = _actionGenerator.generate(endpoint);

          // Get response code (with shared models removed)
          var responseCode = dedup.responseCode[name];
          if (responseCode == null || responseCode.trim().isEmpty) {
            responseCode =
                _responseGenerator.generateUnsafe(response.jsonBody!, '${name}Response');
          }

          if (hasSharedModels) {
            // Inject shared_models import after the existing import line
            final actionWithImport = action.replaceFirst(
              "import 'package:api_request/api_request.dart';",
              "import 'package:api_request/api_request.dart';\nimport 'models/shared_models.dart';",
            );
            fileContent = '$actionWithImport\n\n$responseCode\n';
          } else {
            fileContent = '$action\n\n$responseCode\n';
          }
        } else {
          fileContent = _actionGenerator.generateActionOnly(endpoint);
        }

        Directory(outputDir).createSync(recursive: true);
        final formattedCode = formatter.format(fileContent);
        final filePath = '$outputDir/${endpoint.fileName}';
        File(filePath).writeAsStringSync(formattedCode);
        _logger.i('Generated $filePath');
        generated++;
      } catch (e) {
        _logger.e('Error generating code for ${endpoint.name}', error: e);
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
