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

  String toFormattedString() {
    final sb = StringBuffer();

    sb.writeln('=[ requestName ]===================');
    sb.writeln('"$requestName"');
    sb.writeln();
    sb.writeln('=[ requestMethod ]===================');
    sb.writeln('"$requestMethod"');
    sb.writeln();
    sb.writeln('=[ url ]===================');
    sb.writeln('"$url"');
    sb.writeln();
    sb.writeln('=[ statusCode ]===================');
    sb.writeln(statusCode ?? 'null');
    sb.writeln();
    sb.writeln('=[ headers ]===================');
    sb.writeln(_prettyJson(headers));
    sb.writeln();
    sb.writeln('=[ queryParameters ]===================');
    sb.writeln(_prettyJson(queryParameters));
    sb.writeln();
    sb.writeln('=[ requestBody ]===================');
    sb.writeln(_prettyJson(requestBody ?? {}));
    sb.writeln();
    sb.writeln('=[ responseBody ]===================');
    sb.writeln(_prettyJson(responseBody));
    sb.writeln();
    sb.writeln('=[ sentTime ]===================');
    sb.writeln('"${sentTime.toIso8601String()}"');
    sb.writeln();
    sb.writeln('=[ receivedTime ]===================');
    sb.writeln('"${(receivedTime ?? sentTime).toIso8601String()}"');

    return sb.toString();
  }

  void writeToFile(String outputDir, String fileName) {
    final dir = Directory('$outputDir/logs');
    dir.createSync(recursive: true);
    final filePath = '${dir.path}/$fileName.log';
    File(filePath).writeAsStringSync(toFormattedString());
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
