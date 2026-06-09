import 'dart:io';

import 'package:api_to_dart/api_to_dart.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigStorage YAML escaping (P0 regression)', () {
    late Directory tempDir;
    late String originalCwd;

    setUp(() {
      originalCwd = Directory.current.path;
      tempDir = Directory.systemTemp.createTempSync('api2dart_cfg_test');
      Directory.current = tempDir;
    });

    tearDown(() {
      Directory.current = originalCwd;
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('round-trips a JSON value containing quotes and braces', () {
      final json =
          '{"GET /users":{"fileName":"user.dart","actionClass":"UserAction"}}';
      ConfigStorage.set('wizard.output_overrides', json);
      expect(ConfigStorage.get('wizard.output_overrides'), json);
    });

    test('saving a quote-laden value does not destroy other keys', () {
      ConfigStorage.set('apidog.token', 'secret-token-123');
      ConfigStorage.set('wizard.base_url', 'https://api.example.com');
      // this previously corrupted the whole file
      ConfigStorage.set('wizard.output_overrides', '{"k":{"v":"x\\"y"}}');

      // unrelated keys must still be readable afterwards
      expect(ConfigStorage.get('apidog.token'), 'secret-token-123');
      expect(ConfigStorage.get('wizard.base_url'), 'https://api.example.com');
      expect(
          ConfigStorage.get('wizard.output_overrides'), '{"k":{"v":"x\\"y"}}');
    });

    test('handles backslashes and newlines', () {
      const v = 'a\\b\nc"d';
      ConfigStorage.set('x.y', v);
      expect(ConfigStorage.get('x.y'), v);
    });
  });
}
