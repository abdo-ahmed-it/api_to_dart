import 'package:api_to_dart/api_to_dart.dart';
import 'package:test/test.dart';

void main() {
  group('RequestLog resend metadata', () {
    test('round-trips request data through markdown', () {
      final log = RequestLog(
        requestName: 'create_user',
        requestMethod: 'POST',
        url: 'https://api.example.com/users?role=admin',
        statusCode: 201,
        headers: {
          'Authorization': 'Bearer abc123',
          'Content-Type': 'application/json',
        },
        queryParameters: {'role': 'admin'},
        requestBody: '{"name":"Sara"}',
        responseBody: '{"id":1,"name":"Sara"}',
        sentTime: DateTime(2026, 1, 1, 10, 0, 0),
        receivedTime: DateTime(2026, 1, 1, 10, 0, 1),
      );

      final restored = RequestLog.fromMarkdown(log.toMarkdown());

      expect(restored, isNotNull);
      expect(restored!.requestName, 'create_user');
      expect(restored.requestMethod, 'POST');
      expect(restored.url, 'https://api.example.com/users?role=admin');
      expect(restored.headers['Authorization'], 'Bearer abc123');
      expect(restored.queryParameters['role'], 'admin');
      expect(restored.requestBody, '{"name":"Sara"}');
      // Response/status are intentionally not restored — they're regenerated.
      expect(restored.statusCode, isNull);
    });

    test('round-trips form-field (Map) request bodies', () {
      final log = RequestLog(
        requestName: 'login',
        requestMethod: 'POST',
        url: 'https://api.example.com/login',
        headers: const {},
        requestBody: const {'email': 'a@b.com', 'password': 'x'},
        sentTime: DateTime(2026, 1, 1),
      );

      final restored = RequestLog.fromMarkdown(log.toMarkdown());

      expect(restored, isNotNull);
      expect(restored!.requestBody, isA<Map>());
      expect((restored.requestBody as Map)['email'], 'a@b.com');
    });

    test('embeds a resend snippet matching the file name', () {
      final log = RequestLog(
        requestName: 'Get Users',
        requestMethod: 'GET',
        url: 'https://api.example.com/users',
        sentTime: DateTime(2026, 1, 1),
      );

      final md = log.toMarkdown(fileName: 'get_users_action');

      expect(md, contains("api2dart resend 'get_users_action.md'"));
    });

    test('returns null for content without metadata', () {
      expect(RequestLog.fromMarkdown('# Just a heading\n\nno meta'), isNull);
    });
  });
}
