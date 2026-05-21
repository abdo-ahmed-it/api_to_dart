import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'version.dart';

/// Checks pub.dev for a newer version of the CLI.
///
/// Caches the latest known version in `~/.api2dart/update_check.json` and
/// only hits the network once per [cacheTtl] (default: 1 day).
class UpdateChecker {
  static const Duration cacheTtl = Duration(days: 1);
  static const Duration networkTimeout = Duration(seconds: 3);

  static String get _cacheDir {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    return p.join(home, '.api2dart');
  }

  static String get _cachePath => p.join(_cacheDir, 'update_check.json');

  /// Fetches the latest version, using the cache when fresh.
  ///
  /// Returns `null` if the lookup fails (offline, timeout, etc.) so callers
  /// can silently skip showing an update message.
  static Future<String?> fetchLatestVersion({bool force = false}) async {
    if (!force) {
      final cached = _readCache();
      if (cached != null) return cached;
    }

    try {
      final response = await http
          .get(
            Uri.parse('https://pub.dev/api/packages/$packageName'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(networkTimeout);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latest = data['latest'] as Map<String, dynamic>?;
      final version = latest?['version'] as String?;
      if (version == null) return null;

      _writeCache(version);
      return version;
    } catch (_) {
      return null;
    }
  }

  /// Compares two semver strings. Returns true if [latest] > [current].
  /// Handles pre-release suffixes by treating them as lower than the release.
  static bool isNewer(String current, String latest) {
    final c = _parseVersion(current);
    final l = _parseVersion(latest);
    for (var i = 0; i < 3; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  static List<int> _parseVersion(String version) {
    final core = version.split('-').first.split('+').first;
    final parts = core.split('.');
    final result = <int>[0, 0, 0];
    for (var i = 0; i < 3 && i < parts.length; i++) {
      result[i] = int.tryParse(parts[i]) ?? 0;
    }
    return result;
  }

  static String? _readCache() {
    try {
      final file = File(_cachePath);
      if (!file.existsSync()) return null;
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final checkedAt = DateTime.tryParse(data['checked_at'] as String? ?? '');
      final version = data['latest'] as String?;
      if (checkedAt == null || version == null) return null;
      if (DateTime.now().difference(checkedAt) > cacheTtl) return null;
      return version;
    } catch (_) {
      return null;
    }
  }

  static void _writeCache(String version) {
    try {
      Directory(_cacheDir).createSync(recursive: true);
      File(_cachePath).writeAsStringSync(jsonEncode({
        'latest': version,
        'checked_at': DateTime.now().toIso8601String(),
      }));
    } catch (_) {
      // Cache failures are non-fatal.
    }
  }
}
