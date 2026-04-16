import 'dart:collection';

import 'package:dart_style/dart_style.dart';
import 'package:json_ast/json_ast.dart' show parse, Settings, Node;

import 'helpers.dart';
import 'syntax.dart';

class DartCode extends WithWarning<String> {
  DartCode(super.result, super.warnings);

  String get code => result;
}

/// A Hint is a user type correction.
class Hint {
  final String path;
  final String type;

  Hint(this.path, this.type);
}

class ModelGenerator {
  final String _rootClassName;
  final bool _privateFields;
  List<ClassDefinition> allClasses = <ClassDefinition>[];
  final Map<String, String> sameClassMapping = HashMap<String, String>();
  /// Tracks used class names to avoid duplicates
  final Set<String> _usedClassNames = {};
  late List<Hint> hints;

  ModelGenerator(this._rootClassName, [this._privateFields = false, hints]) {
    if (hints != null) {
      this.hints = hints;
    } else {
      this.hints = <Hint>[];
    }
  }

  Hint? _hintForPath(String path) {
    final hint =
        hints.firstWhere((h) => h.path == path, orElse: () => Hint("", ""));
    if (hint.path == "") {
      return null;
    }
    return null;
  }

  /// Gets a unique class name, appending a number if the name is already taken
  /// by a class with different fields.
  String _uniqueClassName(String name, ClassDefinition newClass) {
    // If name not used yet, reserve it
    if (!_usedClassNames.contains(name)) {
      _usedClassNames.add(name);
      return name;
    }

    // Check if existing class with this name has the same fields
    final existing = allClasses.where((c) => c.name == name).firstOrNull;
    if (existing != null && existing == newClass) {
      return name; // Same structure, reuse the name
    }

    // Name collision with different structure — find unique name
    int suffix = 2;
    while (_usedClassNames.contains('$name$suffix')) {
      suffix++;
    }
    final uniqueName = '$name$suffix';
    _usedClassNames.add(uniqueName);
    return uniqueName;
  }

  List<Warning> _generateClassDefinition(String className,
      dynamic jsonRawDynamicData, String path, Node? astNode) {
    List<Warning> warnings = <Warning>[];
    if (jsonRawDynamicData is List) {
      if (jsonRawDynamicData.isEmpty) return warnings;
      final node = navigateNode(astNode, '0');
      _generateClassDefinition(className, jsonRawDynamicData[0], path, node!);
    } else {
      final Map<dynamic, dynamic> jsonRawData = jsonRawDynamicData;
      final keys = jsonRawData.keys;
      ClassDefinition classDefinition =
          ClassDefinition(className, _privateFields);
      for (var key in keys) {
        TypeDefinition typeDef;
        final hint = _hintForPath('$path/$key');
        final node = navigateNode(astNode, key);
        if (hint != null) {
          typeDef = TypeDefinition(hint.type, astNode: node);
        } else {
          typeDef = TypeDefinition.fromDynamic(jsonRawData[key], node);
        }
        if (typeDef.name == 'Class') {
          typeDef.name = camelCase(key);
        }
        if (typeDef.name == 'List' && typeDef.subtype == 'Null') {
          warnings.add(newEmptyListWarn('$path/$key'));
        }
        if (typeDef.subtype != null && typeDef.subtype == 'Class') {
          typeDef.subtype = camelCase(key);
        }
        if (typeDef.isAmbiguous) {
          warnings.add(newAmbiguousListWarn('$path/$key'));
        }
        // Convert Null type to dynamic
        if (typeDef.name == 'Null') {
          typeDef.name = 'dynamic';
        }
        classDefinition.addField(key, typeDef);
      }

      // Check for structurally identical class
      final similarClass = allClasses.firstWhere((cd) => cd == classDefinition,
          orElse: () => ClassDefinition(""));
      if (similarClass.name != "") {
        final similarClassName = similarClass.name;
        final currentClassName = classDefinition.name;
        sameClassMapping[currentClassName] = similarClassName;
      } else {
        // Get a unique name for this class
        final uniqueName = _uniqueClassName(className, classDefinition);
        if (uniqueName != className) {
          // Need to remap — the class got a new name
          sameClassMapping[className] = uniqueName;
          classDefinition = ClassDefinition(uniqueName, _privateFields);
          // Re-add all fields
          final Map<dynamic, dynamic> jsonRawData2 = jsonRawDynamicData;
          for (var key in jsonRawData2.keys) {
            final node = navigateNode(astNode, key);
            var typeDef = TypeDefinition.fromDynamic(jsonRawData2[key], node);
            if (typeDef.name == 'Class') {
              typeDef.name = camelCase(key);
            }
            if (typeDef.subtype != null && typeDef.subtype == 'Class') {
              typeDef.subtype = camelCase(key);
            }
            if (typeDef.name == 'Null') {
              typeDef.name = 'dynamic';
            }
            classDefinition.addField(key, typeDef);
          }
        }
        allClasses.add(classDefinition);
      }

      final dependencies = classDefinition.dependencies;
      for (var dependency in dependencies) {
        List<Warning> warns = <Warning>[];
        if (dependency.typeDef.name == 'List') {
          if (jsonRawData[dependency.name].length > 0) {
            dynamic toAnalyze;
            if (!dependency.typeDef.isAmbiguous) {
              WithWarning<Map> mergeWithWarning = mergeObjectList(
                  jsonRawData[dependency.name], '$path/${dependency.name}');
              toAnalyze = mergeWithWarning.result;
              warnings.addAll(mergeWithWarning.warnings);
            } else {
              toAnalyze = jsonRawData[dependency.name][0];
            }
            final node = navigateNode(astNode, dependency.name);
            warns = _generateClassDefinition(dependency.className, toAnalyze,
                '$path/${dependency.name}', node);
          }
        } else {
          final node = navigateNode(astNode, dependency.name);
          warns = _generateClassDefinition(dependency.className,
              jsonRawData[dependency.name], '$path/${dependency.name}', node);
        }
        warnings.addAll(warns);
      }
    }
    return warnings;
  }

  DartCode generateUnsafeDart(String rawJson) {
    final jsonRawData = decodeJSON(rawJson);
    final astNode = parse(rawJson, Settings());
    List<Warning> warnings =
        _generateClassDefinition(_rootClassName, jsonRawData, "", astNode);
    // After generating all classes, replace omitted similar classes
    // and resolve renamed classes
    for (var c in allClasses) {
      final fieldsKeys = c.fields.keys;
      for (var f in fieldsKeys) {
        final typeForField = c.fields[f];
        if (typeForField != null) {
          if (sameClassMapping.containsKey(typeForField.name)) {
            c.fields[f]!.name = sameClassMapping[typeForField.name]!;
          }
          if (typeForField.subtype != null &&
              sameClassMapping.containsKey(typeForField.subtype)) {
            c.fields[f]!.subtype = sameClassMapping[typeForField.subtype]!;
          }
        }
      }
    }
    return DartCode(allClasses.map((c) => c.toString()).join('\n'), warnings);
  }

  DartCode generateDartClasses(String rawJson) {
    final unsafeDartCode = generateUnsafeDart(rawJson);
    final formatter =
        DartFormatter(languageVersion: DartFormatter.latestLanguageVersion);
    return DartCode(
        formatter.format(unsafeDartCode.code), unsafeDartCode.warnings);
  }
}
