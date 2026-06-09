import 'dart:io';

import 'package:api_to_dart/src/core/logger/console_logger.dart';
import 'package:api_to_dart/src/core/server/browser_token_capture.dart';
import 'package:test/test.dart';

void main() {
  group('BrowserTokenCapture', () {
    test('returns the token submitted via the local page', () async {
      // Instead of opening a browser, post a token to the capture server's
      // /token endpoint — exactly what the local page's JS does.
      final capture = BrowserTokenCapture(
        logger: ConsoleLogger(),
        onOpen: (url) async {
          final client = HttpClient();
          final req = await client.postUrl(Uri.parse('${url}token'));
          req.write('token=secret-abc-123');
          final res = await req.close();
          await res.drain<void>();
          client.close();
        },
      );

      final token = await capture.captureToken(
        providerName: 'TestProvider',
        tokenPageUrl: 'https://example.com/token',
        timeout: const Duration(seconds: 5),
      );

      expect(token, 'secret-abc-123');
    });

    test('trims and url-decodes the submitted token', () async {
      final capture = BrowserTokenCapture(
        logger: ConsoleLogger(),
        onOpen: (url) async {
          final client = HttpClient();
          final req = await client.postUrl(Uri.parse('${url}token'));
          // A token containing a '+' would be corrupted without decoding.
          req.write('token=${Uri.encodeQueryComponent('  tok+en/x  ')}');
          final res = await req.close();
          await res.drain<void>();
          client.close();
        },
      );

      final token = await capture.captureToken(
        providerName: 'TestProvider',
        tokenPageUrl: 'https://example.com/token',
        timeout: const Duration(seconds: 5),
      );

      expect(token, 'tok+en/x');
    });

    test('returns null when the user never submits (timeout)', () async {
      final capture = BrowserTokenCapture(
        logger: ConsoleLogger(),
        onOpen: (_) async {}, // open nothing; let it time out
      );

      final sw = Stopwatch()..start();
      final token = await capture.captureToken(
        providerName: 'TestProvider',
        tokenPageUrl: 'https://example.com/token',
        timeout: const Duration(milliseconds: 500),
      );
      sw.stop();

      expect(token, isNull);
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(400));
    });

    test('returns null when an empty token is submitted', () async {
      final capture = BrowserTokenCapture(
        logger: ConsoleLogger(),
        onOpen: (url) async {
          final client = HttpClient();
          final req = await client.postUrl(Uri.parse('${url}token'));
          req.write('token=');
          final res = await req.close();
          await res.drain<void>();
          client.close();
        },
      );

      final token = await capture.captureToken(
        providerName: 'TestProvider',
        tokenPageUrl: 'https://example.com/token',
        timeout: const Duration(milliseconds: 800),
      );

      expect(token, isNull);
    });
  });
}
