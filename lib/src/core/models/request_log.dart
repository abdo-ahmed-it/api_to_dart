import 'dart:convert';
import 'dart:io';

class RequestLog {
  final String requestName;
  final String requestMethod;
  final String url;
  final int? statusCode;
  final Map<String, String> headers;
  final Map<String, String> queryParameters;
  final dynamic requestBody;
  final dynamic responseBody;
  final DateTime sentTime;
  final DateTime? receivedTime;

  RequestLog({
    required this.requestName,
    required this.requestMethod,
    required this.url,
    this.statusCode,
    this.headers = const {},
    this.queryParameters = const {},
    this.requestBody,
    this.responseBody,
    required this.sentTime,
    this.receivedTime,
  });

  String toMarkdown() {
    final sb = StringBuffer();
    final duration = (receivedTime ?? sentTime).difference(sentTime);
    final statusLine = _formatStatus(statusCode);

    sb.writeln('# $requestName');
    sb.writeln();

    // TL;DR — quick summary line
    sb.writeln(
        '> $statusLine `$requestMethod` $url — ${_formatDuration(duration)}');
    sb.writeln();

    sb.writeln('**Method:** `$requestMethod`  ');
    sb.writeln('**URL:** `$url`  ');
    sb.writeln('**Status:** $statusLine  ');
    sb.writeln('**Sent:** ${_formatTime(sentTime)}  ');
    sb.writeln('**Received:** ${_formatTime(receivedTime ?? sentTime)}  ');
    sb.writeln('**Duration:** `${_formatDuration(duration)}`');
    sb.writeln();

    sb.writeln('## Request');
    sb.writeln();

    sb.writeln('### Headers');
    sb.writeln();
    if (headers.isEmpty) {
      sb.writeln('_(none)_');
    } else {
      sb.writeln('```http');
      headers.forEach((k, v) => sb.writeln('$k: $v'));
      sb.writeln('```');
    }
    sb.writeln();

    sb.writeln('### Query Parameters');
    sb.writeln();
    if (queryParameters.isEmpty) {
      sb.writeln('_(none)_');
    } else {
      sb.writeln('```json');
      sb.writeln(_prettyJson(queryParameters));
      sb.writeln('```');
    }
    sb.writeln();

    sb.writeln('### Body');
    sb.writeln();
    if (!_hasBody(requestBody)) {
      sb.writeln('_(none)_');
    } else {
      sb.writeln('```json');
      sb.writeln(_prettyJson(requestBody));
      sb.writeln('```');
    }
    sb.writeln();

    sb.writeln('## Response');
    sb.writeln();
    sb.writeln('```json');
    sb.writeln(_prettyJson(responseBody));
    sb.writeln('```');
    sb.writeln();

    sb.writeln('## cURL');
    sb.writeln();
    sb.writeln('```bash');
    sb.writeln(_buildCurl());
    sb.writeln('```');

    return sb.toString();
  }

  /// Writes the log as a `.md` file under [logsDir]. The directory is created
  /// if it doesn't exist; all logs are written flat (no subfolders).
  void writeToFile(String logsDir, String fileName) {
    final dir = Directory(logsDir);
    dir.createSync(recursive: true);
    final filePath = '${dir.path}/$fileName.md';
    File(filePath).writeAsStringSync(toMarkdown());
  }

  String _formatStatus(int? code) {
    if (code == null) return '⚪ `—`';
    final icon = code >= 200 && code < 300
        ? '✅'
        : code >= 300 && code < 400
            ? '↪️'
            : code >= 400 && code < 500
                ? '⚠️'
                : '❌';
    return '$icon `$code ${_statusText(code)}`';
  }

  String _statusText(int code) {
    const known = {
      200: 'OK',
      201: 'Created',
      202: 'Accepted',
      204: 'No Content',
      301: 'Moved Permanently',
      302: 'Found',
      304: 'Not Modified',
      400: 'Bad Request',
      401: 'Unauthorized',
      403: 'Forbidden',
      404: 'Not Found',
      405: 'Method Not Allowed',
      409: 'Conflict',
      422: 'Unprocessable Entity',
      429: 'Too Many Requests',
      500: 'Internal Server Error',
      502: 'Bad Gateway',
      503: 'Service Unavailable',
      504: 'Gateway Timeout',
    };
    return known[code] ?? '';
  }

  String _formatTime(DateTime t) {
    final local = t.isUtc ? t.toLocal() : t;
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    final date =
        '${local.year}-${two(local.month)}-${two(local.day)}';
    final time =
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}.${three(local.millisecond)}';
    return '`$date $time`';
  }

  String _formatDuration(Duration d) {
    if (d.inMilliseconds < 1000) return '${d.inMilliseconds}ms';
    final seconds = d.inMilliseconds / 1000;
    if (seconds < 60) return '${seconds.toStringAsFixed(2)}s';
    final minutes = d.inSeconds ~/ 60;
    final remSeconds = d.inSeconds % 60;
    return '${minutes}m ${remSeconds}s';
  }

  String _buildCurl() {
    final sb = StringBuffer();
    final fullUrl = _urlWithQuery();
    sb.write("curl -X $requestMethod '$fullUrl'");
    headers.forEach((k, v) {
      sb.write(" \\\n  -H '$k: $v'");
    });
    if (_hasBody(requestBody)) {
      final bodyStr = requestBody is String
          ? requestBody as String
          : _prettyJson(requestBody);
      final escaped = bodyStr.replaceAll("'", r"'\''");
      sb.write(" \\\n  -d '$escaped'");
    }
    return sb.toString();
  }

  String _urlWithQuery() {
    if (queryParameters.isEmpty) return url;
    final query = queryParameters.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final separator = url.contains('?') ? '&' : '?';
    return '$url$separator$query';
  }

  bool _hasBody(dynamic data) {
    if (data == null) return false;
    if (data is String) return data.isNotEmpty;
    if (data is Map) return data.isNotEmpty;
    if (data is List) return data.isNotEmpty;
    return true;
  }

  String _prettyJson(dynamic data) {
    if (data == null) return '{}';
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        return const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (_) {
        return data;
      }
    }
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }
}
