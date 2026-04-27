import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Inspects the host project's pubspec.yaml to decide what code to generate.
///
/// The generator can run in two modes:
/// - **Action + Response**: when the host project depends on `api_request`,
///   each file contains an `ApiRequestAction` subclass plus its response model.
/// - **Response only**: when `api_request` is not available, only the response
///   model is generated so the package is useful in any Dart project.
class PubspecInspector {
  /// Whether the project at [projectDir] declares `api_request` as a
  /// dependency (or dev_dependency / dependency_overrides).
  ///
  /// Returns `false` when there's no pubspec.yaml or it can't be parsed.
  static bool hasApiRequestDependency([String? projectDir]) {
    final dir = projectDir ?? Directory.current.path;
    final file = File(p.join(dir, 'pubspec.yaml'));
    if (!file.existsSync()) return false;

    try {
      final doc = loadYaml(file.readAsStringSync());
      if (doc is! Map) return false;

      const sections = [
        'dependencies',
        'dev_dependencies',
        'dependency_overrides',
      ];
      for (final section in sections) {
        final map = doc[section];
        if (map is Map && map.containsKey('api_request')) {
          return true;
        }
      }
    } catch (_) {
      // Malformed pubspec — treat as missing.
    }
    return false;
  }
}
