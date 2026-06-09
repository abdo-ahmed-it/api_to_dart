import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../logger/logger.dart';

/// Guided "paste your token" flow that feels like a browser login.
///
/// Providers like Apidog and Postman do not expose an OAuth / device-flow
/// login, so a token still has to be created by hand on their settings page.
/// This helper makes that as smooth as possible: it spins up a tiny localhost
/// server, opens the browser to a local page (with a button that opens the
/// provider's token page), the user pastes the freshly-created token and hits
/// submit, and the token is delivered straight back to the CLI — no manual
/// terminal paste.
///
/// Returns the captured token, or `null` if the user cancelled, the wait timed
/// out, or the local server could not start. Callers should fall back to a
/// plain terminal prompt when this returns `null`.
class BrowserTokenCapture {
  final Logger _logger;

  /// Test seam: called with the local capture URL instead of launching the
  /// real OS browser. Defaults to the platform browser opener.
  final Future<void> Function(String url)? onOpen;

  BrowserTokenCapture({required Logger logger, this.onOpen}) : _logger = logger;

  /// Runs the capture flow for [providerName] (e.g. "Apidog", "Postman").
  ///
  /// [tokenPageUrl] is the provider's settings page where the user creates the
  /// token; the local page links to it. [steps] are the human instructions
  /// shown as a numbered list (the navigation the user follows after the page
  /// opens — e.g. "Settings → Personal Access Token → New"). [timeout] bounds
  /// how long we wait for the user before giving up so the wizard never hangs
  /// forever.
  Future<String?> captureToken({
    required String providerName,
    required String tokenPageUrl,
    List<String>? steps,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    } catch (_) {
      // Could not bind — let the caller fall back to a terminal prompt.
      return null;
    }

    final localUrl = 'http://localhost:${server.port}/';
    final completer = Completer<String?>();
    StreamSubscription<HttpRequest>? sub;

    sub = server.listen((request) async {
      try {
        await _handleRequest(
          request,
          providerName: providerName,
          tokenPageUrl: tokenPageUrl,
          steps: steps,
          completer: completer,
        );
      } catch (_) {
        // Never let a malformed request crash the wizard.
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        } catch (_) {}
      }
    });

    stdout.writeln('');
    _logger.i('Opening your browser to sign in to $providerName…');
    _logger.i('If it does not open, visit: $localUrl');
    await (onOpen ?? _openInBrowser)(localUrl);

    String? token;
    try {
      token = await completer.future.timeout(timeout);
    } on TimeoutException {
      _logger.w('Timed out waiting for the token. Falling back to terminal.');
      token = null;
    } finally {
      await sub.cancel();
      await server.close(force: true);
    }

    return (token != null && token.isNotEmpty) ? token : null;
  }

  Future<void> _handleRequest(
    HttpRequest request, {
    required String providerName,
    required String tokenPageUrl,
    required List<String>? steps,
    required Completer<String?> completer,
  }) async {
    final response = request.response;

    // Token submission from the local page.
    if (request.method == 'POST' && request.uri.path == '/token') {
      final body = await utf8.decodeStream(request);
      final token = _parseToken(body);

      response.headers.contentType = ContentType.json;
      if (token != null && token.isNotEmpty) {
        response.write('{"ok":true}');
        await response.close();
        if (!completer.isCompleted) completer.complete(token);
      } else {
        response.statusCode = HttpStatus.badRequest;
        response.write('{"ok":false}');
        await response.close();
      }
      return;
    }

    // User cancelled from the local page.
    if (request.uri.path == '/cancel') {
      response.headers.contentType = ContentType.html;
      response.write(_donePage('Cancelled — you can close this tab.'));
      await response.close();
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    // Anything else → serve the capture page.
    response.headers.contentType = ContentType.html;
    response.write(_capturePage(providerName, tokenPageUrl, steps));
    await response.close();
  }

  /// Extracts the token from a urlencoded ("token=...") or raw body.
  String? _parseToken(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('token=')) {
      return Uri.decodeQueryComponent(trimmed.substring('token='.length))
          .trim();
    }
    // Fall back to treating the whole body as the token.
    return trimmed;
  }

  /// Opens [url] in the OS default browser. Best-effort — a failure just leaves
  /// the printed link for the user to open manually. Mirrors
  /// `ServeCommand._openInBrowser`.
  Future<void> _openInBrowser(String url) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      }
    } catch (_) {
      // Non-fatal: the link is already printed above.
    }
  }

  String _capturePage(
      String providerName, String tokenPageUrl, List<String>? steps) {
    // Build the numbered instructions. Each provider passes its own navigation
    // (e.g. Apidog's "Settings → Personal Access Token → New"); fall back to a
    // generic three-step flow when none is given. The final paste step is
    // always appended so it stays in sync with the button label below.
    final providedSteps = (steps == null || steps.isEmpty)
        ? <String>['Create a new access token and copy it.']
        : steps;
    final stepItems = StringBuffer()
      ..writeln(
          '<li>Open your <a href="$tokenPageUrl" target="_blank" rel="noopener">$providerName account</a> (button below).</li>');
    // Steps are trusted, code-defined strings (may contain light markup like
    // <strong>), never user input — so they're emitted as-is.
    for (final step in providedSteps) {
      stepItems.writeln('<li>$step</li>');
    }
    stepItems.writeln('<li>Paste the token here and press <strong>Continue</strong>.</li>');

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sign in to $providerName · API to Dart</title>
<style>
  :root { color-scheme: light dark; }
  * { box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    margin: 0; min-height: 100vh; display: flex; align-items: center;
    justify-content: center; background: #0f172a; color: #e2e8f0;
  }
  .card {
    width: 100%; max-width: 460px; margin: 24px; padding: 32px;
    background: #1e293b; border-radius: 16px;
    box-shadow: 0 20px 60px rgba(0,0,0,.4);
  }
  h1 { font-size: 20px; margin: 0 0 4px; }
  .sub { color: #94a3b8; font-size: 14px; margin: 0 0 24px; }
  ol { padding-left: 20px; color: #cbd5e1; font-size: 14px; line-height: 1.7; }
  ol a { color: #38bdf8; }
  .btn {
    display: inline-block; width: 100%; text-align: center; cursor: pointer;
    border: 0; border-radius: 10px; padding: 12px 16px; font-size: 15px;
    font-weight: 600; margin-top: 12px; text-decoration: none;
  }
  .primary { background: #38bdf8; color: #04293a; }
  .ghost { background: transparent; color: #94a3b8; font-weight: 500; }
  textarea {
    width: 100%; margin-top: 16px; padding: 12px; border-radius: 10px;
    border: 1px solid #334155; background: #0f172a; color: #e2e8f0;
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 13px;
    resize: vertical; min-height: 72px;
  }
  .ok { color: #4ade80; } .err { color: #f87171; }
  #msg { margin-top: 12px; font-size: 14px; min-height: 18px; }
</style>
</head>
<body>
<div class="card">
  <h1>Sign in to $providerName</h1>
  <p class="sub">Create an access token, then paste it below — it returns to the CLI automatically.</p>
  <ol>
$stepItems  </ol>
  <a class="btn primary" href="$tokenPageUrl" target="_blank" rel="noopener">Open $providerName</a>
  <textarea id="token" placeholder="Paste your token here" autofocus></textarea>
  <button class="btn primary" id="submit">Continue</button>
  <button class="btn ghost" id="cancel">Cancel</button>
  <div id="msg"></div>
</div>
<script>
  const msg = document.getElementById('msg');
  document.getElementById('submit').addEventListener('click', async () => {
    const token = document.getElementById('token').value.trim();
    if (!token) { msg.textContent = 'Please paste a token first.'; msg.className = 'err'; return; }
    msg.textContent = 'Sending…'; msg.className = '';
    try {
      const res = await fetch('/token', { method: 'POST', body: 'token=' + encodeURIComponent(token) });
      if (res.ok) {
        document.body.innerHTML = '<div class="card"><h1 class="ok">✓ Connected</h1><p class="sub">You can close this tab and return to the terminal.</p></div>';
      } else {
        msg.textContent = 'That token was rejected. Try again.'; msg.className = 'err';
      }
    } catch (e) {
      msg.textContent = 'Could not reach the CLI. Is it still running?'; msg.className = 'err';
    }
  });
  document.getElementById('cancel').addEventListener('click', async () => {
    try { await fetch('/cancel'); } catch (e) {}
    document.body.innerHTML = '<div class="card"><h1>Cancelled</h1><p class="sub">You can close this tab.</p></div>';
  });
</script>
</body>
</html>
''';
  }

  String _donePage(String message) => '''
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<style>body{font-family:-apple-system,sans-serif;background:#0f172a;color:#e2e8f0;
display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0}</style>
</head><body><p>$message</p></body></html>
''';
}
