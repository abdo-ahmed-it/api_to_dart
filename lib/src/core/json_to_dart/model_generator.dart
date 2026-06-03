import 'dart:collection';

import 'package:dart_style/dart_style.dart';

import 'enum_extractor.dart';
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
  final Set<String> _usedClassNames = {};
  late List<Hint> hints;

  /// Enum corrections sourced from an OpenAPI schema, keyed by field path.
  final List<EnumHint> enumHints;

  /// Enum declarations to emit, deduped by enum name.
  final Map<String, EnumDefinition> _enums = {};

  ModelGenerator(
    this._rootClassName, [
    this._privateFields = false,
    hints,
    List<EnumHint>? enumHints,
  ]) : enumHints = enumHints ?? <EnumHint>[] {
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
    return hint;
  }

  EnumHint? _enumHintForPath(String path) {
    for (final h in enumHints) {
      if (h.path == path) return h;
    }
    return null;
  }

  String _uniqueClassName(String name, ClassDefinition newClass) {
    if (!_usedClassNames.contains(name)) {
      _usedClassNames.add(name);
      return name;
    }

    final existing = allClasses.where((c) => c.name == name).firstOrNull;
    if (existing != null && existing == newClass) {
      return name;
    }

    int suffix = 2;
    while (_usedClassNames.contains('$name$suffix')) {
      suffix++;
    }
    final uniqueName = '$name$suffix';
    _usedClassNames.add(uniqueName);
    return uniqueName;
  }

  List<Warning> _generateClassDefinition(
      String className, dynamic jsonRawDynamicData, String path) {
    List<Warning> warnings = <Warning>[];
    if (jsonRawDynamicData is List) {
      if (jsonRawDynamicData.isEmpty) return warnings;
      _generateClassDefinition(className, jsonRawDynamicData[0], path);
    } else {
      final Map<dynamic, dynamic> jsonRawData = jsonRawDynamicData;
      final keys = jsonRawData.keys;
      ClassDefinition classDefinition =
          ClassDefinition(className, _privateFields);
      for (var key in keys) {
        TypeDefinition typeDef;
        final hint = _hintForPath('$path/$key');
        if (hint != null) {
          typeDef = TypeDefinition(hint.type);
        } else {
          typeDef = TypeDefinition.fromDynamic(jsonRawData[key]);
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
        if (typeDef.name == 'Null') {
          typeDef.name = 'dynamic';
        }
        // OpenAPI-sourced enum: replace the inferred String (or List<String>)
        // with a reference to a generated Dart enum.
        final enumHint = _enumHintForPath('$path/$key');
        if (enumHint != null) {
          _enums.putIfAbsent(
              enumHint.name, () => EnumDefinition(enumHint.name, enumHint.values));
          typeDef.isEnum = true;
          if (typeDef.name == 'List') {
            typeDef.subtype = enumHint.name;
          } else {
            typeDef.name = enumHint.name;
            typeDef.subtype = null;
          }
        }
        classDefinition.addField(key, typeDef);
      }

      final similarClass = allClasses.firstWhere((cd) => cd == classDefinition,
          orElse: () => ClassDefinition(""));
      if (similarClass.name != "") {
        final similarClassName = similarClass.name;
        final currentClassName = classDefinition.name;
        sameClassMapping[currentClassName] = similarClassName;
      } else {
        final uniqueName = _uniqueClassName(className, classDefinition);
        if (uniqueName != className) {
          sameClassMapping[className] = uniqueName;
          classDefinition = ClassDefinition(uniqueName, _privateFields);
          final Map<dynamic, dynamic> jsonRawData2 = jsonRawDynamicData;
          for (var key in jsonRawData2.keys) {
            var typeDef = TypeDefinition.fromDynamic(jsonRawData2[key]);
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
            warns = _generateClassDefinition(
                dependency.className, toAnalyze, '$path/${dependency.name}');
          }
        } else {
          warns = _generateClassDefinition(dependency.className,
              jsonRawData[dependency.name], '$path/${dependency.name}');
        }
        warnings.addAll(warns);
      }
    }
    return warnings;
  }

  DartCode generateUnsafeDart(String rawJson) {
    final jsonRawData = decodeJSON(rawJson);
    List<Warning> warnings =
        _generateClassDefinition(_rootClassName, jsonRawData, "");
    for (var c in allClasses) {
      final fieldsKeys = c.fields.keys;
      for (var f in fieldsKeys) {
        final typeForField = c.fields[f];
        // Enum-typed fields point at standalone enum declarations and must not
        // be remapped through the data-class dedup table.
        if (typeForField != null && !typeForField.isEnum) {
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
    final classCode = allClasses.map((c) => c.toString()).join('\n');
    final enumCode = _enums.values.map((e) => e.toString()).join('\n');
    final code = enumCode.isEmpty ? classCode : '$classCode\n$enumCode';
    return DartCode(code, warnings);
  }

  DartCode generateDartClasses(String rawJson) {
    final unsafeDartCode = generateUnsafeDart(rawJson);
    final formatter =
        DartFormatter(languageVersion: DartFormatter.latestLanguageVersion);
    return DartCode(
        formatter.format(unsafeDartCode.code), unsafeDartCode.warnings);
  }
}
