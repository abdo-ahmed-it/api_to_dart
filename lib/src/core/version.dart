import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Package name on pub.dev.
const String packageName = 'api_to_dart';

/// Fallback used if the pubspec can't be located at runtime (extremely rare —
/// only happens if the package was installed in an unusual way).
const String _fallbackVersion = '0.0.0';

String? _cachedVersion;

/// The installed CLI version, read from the package's bundled `pubspec.yaml`.
///
/// Resolved lazily on first access and then cached. Works both when running
/// from source (`dart run`) and when activated globally (`dart pub global
/// activate`) — in both cases we resolve a `package:` URI for this library
/// and walk up to its pubspec.
String get packageVersion {
  return _cachedVersion ??= _readPackageVersion();
}

String _readPackageVersion() {
  try {
    final pubspecPath = _findPubspec();
    if (pubspecPath == null) return _fallbackVersion;

    final doc = loadYaml(File(pubspecPath).readAsStringSync());
    if (doc is Map && doc['version'] is String) {
      return doc['version'] as String;
    }
  } catch (_) {
    // Fall through to fallback.
  }
  return _fallbackVersion;
}

String? _findPubspec() {
  // Resolve a library inside this package to a file URI, then walk up to the
  // package root (the parent of `lib/`).
  final libUri = Isolate.resolvePackageUriSync(
      Uri.parse('package:$packageName/api_to_dart.dart'));
  if (libUri != null && libUri.scheme == 'file') {
    final libDir = p.dirname(libUri.toFilePath());
    final candidate = p.join(p.dirname(libDir), 'pubspec.yaml');
    if (File(candidate).existsSync()) return candidate;
  }

  // Fallback: walk up from the running script (covers `dart run bin/...`
  // during development).
  final scriptPath = Platform.script.toFilePath();
  var dir = p.dirname(scriptPath);
  for (var i = 0; i < 5; i++) {
    final candidate = p.join(dir, 'pubspec.yaml');
    if (File(candidate).existsSync()) return candidate;
    final parent = p.dirname(dir);
    if (parent == dir) break;
    dir = parent;
  }
  return null;
}
