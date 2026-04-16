import 'dart:io';

class TerminalUtils {
  static const String esc = '\x1B';

  // Cursor visibility
  static void hideCursor() => stdout.write('$esc[?25l');
  static void showCursor() => stdout.write('$esc[?25h');

  // Cursor movement
  static void moveUp([int n = 1]) => stdout.write('$esc[${n}A');
  static void moveDown([int n = 1]) => stdout.write('$esc[${n}B');
  static void moveToColumn(int col) => stdout.write('$esc[${col}G');

  // Clear
  static void clearLine() => stdout.write('$esc[2K');
  static void clearFromCursor() => stdout.write('$esc[0J');

  // Colors
  static String green(String text) => '\x1B[32m$text\x1B[0m';
  static String yellow(String text) => '\x1B[33m$text\x1B[0m';
  static String blue(String text) => '\x1B[34m$text\x1B[0m';
  static String gray(String text) => '\x1B[90m$text\x1B[0m';
  static String bold(String text) => '\x1B[1m$text\x1B[0m';
  static String cyan(String text) => '\x1B[36m$text\x1B[0m';

  /// Read a single keypress from stdin.
  /// Returns the key as a string representation.
  static String readKey() {
    stdin.echoMode = false;
    stdin.lineMode = false;

    try {
      final byte = stdin.readByteSync();

      if (byte == 27) {
        // Escape sequence
        final next = stdin.readByteSync();
        if (next == 91) {
          // CSI sequence
          final code = stdin.readByteSync();
          switch (code) {
            case 65:
              return 'up';
            case 66:
              return 'down';
            case 67:
              return 'right';
            case 68:
              return 'left';
            default:
              return 'unknown';
          }
        }
        return 'escape';
      }

      switch (byte) {
        case 10: // Enter
        case 13:
          return 'enter';
        case 32: // Space
          return 'space';
        case 113: // q
          return 'q';
        case 97: // a
          return 'a';
        case 110: // n
          return 'n';
        default:
          return String.fromCharCode(byte);
      }
    } finally {
      stdin.echoMode = true;
      stdin.lineMode = true;
    }
  }
}
