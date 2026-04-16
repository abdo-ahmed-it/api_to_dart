import 'dart:convert';

import '../json_to_dart/helpers.dart';
import '../json_to_dart/model_generator.dart';
import '../json_to_dart/syntax.dart';

/// Represents a parsed model class with its fields for comparison.
class ParsedModel {
  final String name;
  final Map<String, String> fields; // fieldName -> typeName
  final String sourceEndpoint; // which endpoint generated this

  ParsedModel({
    required this.name,
    required this.fields,
    required this.sourceEndpoint,
  });
}

/// Represents a shared model that has been deduplicated.
class SharedModel {
  final String name;
  final Map<String, String> fields; // union of all fields (nullable)
  final List<String> usedBy; // endpoint names using this model

  SharedModel({
    required this.name,
    required this.fields,
    required this.usedBy,
  });
}

/// Result of deduplication: which models are shared and which are unique per endpoint.
class DeduplicationResult {
  /// Models shared across multiple endpoints → go in models/ folder
  final List<SharedModel> sharedModels;

  /// Per-endpoint: map of endpointName → list of unique model class names
  final Map<String, List<String>> uniqueModelsPerEndpoint;

  /// Per-endpoint: the response class code (may reference shared models)
  final Map<String, String> responseCode;

  /// The shared models code
  final String sharedModelsCode;

  /// Names of shared model classes (for imports)
  final Set<String> sharedModelNames;

  DeduplicationResult({
    required this.sharedModels,
    required this.uniqueModelsPerEndpoint,
    required this.responseCode,
    required this.sharedModelsCode,
    required this.sharedModelNames,
  });
}

class ModelDeduplicator {
  /// Analyzes multiple JSON responses and deduplicates common models.
  ///
  /// [responses] is a map of endpointName → JSON response body string.
  /// Returns a DeduplicationResult with shared and unique models.
  DeduplicationResult deduplicate(Map<String, String> responses) {
    if (responses.isEmpty) {
      return DeduplicationResult(
        sharedModels: [],
        uniqueModelsPerEndpoint: {},
        responseCode: {},
        sharedModelsCode: '',
        sharedModelNames: {},
      );
    }

    // If only one endpoint, no deduplication needed
    if (responses.length == 1) {
      final entry = responses.entries.first;
      final className = '${entry.key}Response';
      final generator = ModelGenerator(className);
      final code = generator.generateUnsafeDart(entry.value);

      return DeduplicationResult(
        sharedModels: [],
        uniqueModelsPerEndpoint: {entry.key: []},
        responseCode: {entry.key: code.code},
        sharedModelsCode: '',
        sharedModelNames: {},
      );
    }

    // Step 1: Generate all classes for each endpoint
    final allClassesPerEndpoint = <String, List<ClassDefinition>>{};
    for (final entry in responses.entries) {
      final className = '${entry.key}Response';
      final generator = ModelGenerator(className);
      try {
        generator.generateUnsafeDart(entry.value);
        allClassesPerEndpoint[entry.key] = generator.allClasses;
      } catch (_) {
        allClassesPerEndpoint[entry.key] = [];
      }
    }

    // Step 2: Find classes with same name across endpoints (excluding Response classes)
    final classNameToEndpoints = <String, List<String>>{};
    final classNameToDefinitions = <String, List<ClassDefinition>>{};

    for (final entry in allClassesPerEndpoint.entries) {
      for (final classDef in entry.value) {
        // Skip the top-level Response class (it's always unique)
        if (classDef.name.endsWith('Response')) continue;

        classNameToEndpoints
            .putIfAbsent(classDef.name, () => [])
            .add(entry.key);
        classNameToDefinitions
            .putIfAbsent(classDef.name, () => [])
            .add(classDef);
      }
    }

    // Step 3: Find duplicated classes (appear in 2+ endpoints)
    final sharedModels = <SharedModel>[];
    final sharedModelNames = <String>{};

    for (final entry in classNameToEndpoints.entries) {
      if (entry.value.length >= 2) {
        // Merge fields from all definitions (union)
        final mergedFields = <String, String>{};
        for (final classDef in classNameToDefinitions[entry.key]!) {
          for (final fieldEntry in classDef.fields.entries) {
            final fieldName = fixFieldName(fieldEntry.key,
                typeDef: fieldEntry.value, privateField: false);
            final typeName = _typeDefToString(fieldEntry.value);
            // If field already exists with different type, keep the more general one
            if (mergedFields.containsKey(fieldName)) {
              // Keep existing — both are nullable anyway
            } else {
              mergedFields[fieldName] = typeName;
            }
          }
        }

        sharedModels.add(SharedModel(
          name: entry.key,
          fields: mergedFields,
          usedBy: entry.value,
        ));
        sharedModelNames.add(entry.key);
      }
    }

    // Step 4: Generate code for each endpoint, marking shared models
    final responseCode = <String, String>{};
    final uniqueModelsPerEndpoint = <String, List<String>>{};

    for (final entry in allClassesPerEndpoint.entries) {
      final uniqueClasses = <String>[];
      final sb = StringBuffer();

      for (final classDef in entry.value) {
        if (sharedModelNames.contains(classDef.name)) {
          // This class is shared — skip generating it here
          continue;
        }
        sb.writeln(classDef.toString());
        uniqueClasses.add(classDef.name);
      }

      responseCode[entry.key] = sb.toString();
      uniqueModelsPerEndpoint[entry.key] = uniqueClasses;
    }

    // Step 5: Generate shared models code
    final sharedSb = StringBuffer();
    for (final shared in sharedModels) {
      // Find the most complete ClassDefinition for this shared model
      final definitions = classNameToDefinitions[shared.name]!;
      // Pick the one with the most fields
      definitions.sort((a, b) => b.fields.length.compareTo(a.fields.length));
      final bestDef = definitions.first;
      sharedSb.writeln(bestDef.toString());
    }

    return DeduplicationResult(
      sharedModels: sharedModels,
      uniqueModelsPerEndpoint: uniqueModelsPerEndpoint,
      responseCode: responseCode,
      sharedModelsCode: sharedSb.toString(),
      sharedModelNames: sharedModelNames,
    );
  }

  String _typeDefToString(TypeDefinition typeDef) {
    if (typeDef.subtype != null) {
      return '${typeDef.name}<${typeDef.subtype}>';
    }
    return typeDef.name;
  }
}
