import 'logger.dart';

class ColorsText {
  static const reset = '\x1B[0m';
  static const blue = '\x1B[34m';
  static const green = '\x1B[32m';
  static const red = '\x1B[31m';
  static const yellow = '\x1B[33m';
  static const orange = '\x1B[38;5;214m';
  static const gray = '\x1B[90m';
}

class ConsoleLogger implements Logger {
  String _getTimestamp() {
    return DateTime.now().toString().split('.').first;
  }

  @override
  void d(String message) {
    print(
        '${ColorsText.blue}┌── 🛠️ DEBUG ── ${_getTimestamp()} ──${ColorsText.reset}');
    print('${ColorsText.blue}│ $message${ColorsText.reset}');
    print(
        '${ColorsText.blue}└────────────────────────────${ColorsText.reset}');
  }

  @override
  void i(String message) {
    print(
        '${ColorsText.green}┌── ℹ️ INFO ── ${_getTimestamp()} ──${ColorsText.reset}');
    print('${ColorsText.green}│ $message${ColorsText.reset}');
    print(
        '${ColorsText.green}└────────────────────────────${ColorsText.reset}');
  }

  @override
  void w(String message) {
    print(
        '${ColorsText.yellow}┌── ⚠️ WARNING ── ${_getTimestamp()} ──${ColorsText.reset}');
    print('${ColorsText.yellow}│ $message${ColorsText.reset}');
    print(
        '${ColorsText.yellow}└────────────────────────────${ColorsText.reset}');
  }

  @override
  void e(String message, {Object? error}) {
    print(
        '${ColorsText.red}┌── ❌ ERROR ── ${_getTimestamp()} ──${ColorsText.reset}');
    print('${ColorsText.red}│ $message${ColorsText.reset}');
    if (error != null) {
      print(
          '${ColorsText.red}│ Error Details: $error${ColorsText.reset}');
    }
    print(
        '${ColorsText.red}└────────────────────────────${ColorsText.reset}');
  }

  @override
  void n(String message) {
    print('┌── 📝 NEUTRAL ── ${_getTimestamp()} ──');
    print('│ $message');
    print('└────────────────────────────');
  }
}
