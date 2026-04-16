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

    // Step 3: Find truly duplicated classes (same name AND similar fields)
    final sharedModels = <SharedModel>[];
    final sharedModelNames = <String>{};
    // Classes with same name but different fields — need renaming
    final classesToRename = <String, Map<String, ClassDefinition>>{}; // className -> {endpointName -> classDef}

    for (final entry in classNameToEndpoints.entries) {
      if (entry.value.length < 2) continue;

      final definitions = classNameToDefinitions[entry.key]!;

      // Check if all definitions have similar fields (>= 60% overlap)
      if (_areDefinitionsSimilar(definitions)) {
        // Truly the same model — merge fields (union)
        final mergedFields = <String, String>{};
        for (final classDef in definitions) {
          for (final fieldEntry in classDef.fields.entries) {
            final fieldName = fixFieldName(fieldEntry.key,
                typeDef: fieldEntry.value, privateField: false);
            final typeName = _typeDefToString(fieldEntry.value);
            if (!mergedFields.containsKey(fieldName)) {
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
      } else {
        // Same name but different fields — rename each to be unique
        for (int i = 0; i < definitions.length; i++) {
          classesToRename
              .putIfAbsent(entry.key, () => {})
              [entry.value[i]] = definitions[i];
        }
      }
    }

    // Step 3b: Rename conflicting classes by prefixing with endpoint name
    for (final entry in classesToRename.entries) {
      final className = entry.key;
      for (final endpointEntry in entry.value.entries) {
        final endpointName = endpointEntry.key;
        final classDef = endpointEntry.value;
        // Find this class in the endpoint's class list and rename it
        final endpointClasses = allClassesPerEndpoint[endpointName];
        if (endpointClasses != null) {
          for (final cls in endpointClasses) {
            if (cls.name == className) {
              // Rename: "Data" → "NotificationsData" (using endpoint name prefix)
              // Also update references in other classes of this endpoint
              final newName = '${endpointName}$className';
              _renameClassInEndpoint(endpointClasses, className, newName);
              break;
            }
          }
        }
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

  /// Checks if all class definitions are similar enough to be merged.
  /// Uses field name overlap — if >= 60% of fields match, they're similar.
  bool _areDefinitionsSimilar(List<ClassDefinition> definitions) {
    if (definitions.length < 2) return true;

    for (int i = 0; i < definitions.length; i++) {
      for (int j = i + 1; j < definitions.length; j++) {
        final fieldsA = definitions[i].fields.keys.toSet();
        final fieldsB = definitions[j].fields.keys.toSet();

        if (fieldsA.isEmpty && fieldsB.isEmpty) continue;

        final intersection = fieldsA.intersection(fieldsB).length;
        final union = fieldsA.union(fieldsB).length;

        if (union == 0) continue;
        final similarity = intersection / union;

        if (similarity < 0.6) return false;
      }
    }
    return true;
  }

  /// Renames a class within an endpoint's class list,
  /// updating all references (field types, subtypes) to the old name.
  void _renameClassInEndpoint(
      List<ClassDefinition> classes, String oldName, String newName) {
    for (final cls in classes) {
      // Rename the class itself
      if (cls.name == oldName) {
        // ClassDefinition._name is final, so we need to update fields
        // that reference this class in other classes
      }

      // Update field references in ALL classes of this endpoint
      for (final field in cls.fields.values) {
        if (field.name == oldName) {
          field.name = newName;
        }
        if (field.subtype == oldName) {
          field.subtype = newName;
        }
      }
    }
  }

  String _typeDefToString(TypeDefinition typeDef) {
    if (typeDef.subtype != null) {
      return '${typeDef.name}<${typeDef.subtype}>';
    }
    return typeDef.name;
  }
}
