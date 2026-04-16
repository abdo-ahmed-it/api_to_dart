import 'dart:io';

import 'package:dart_console/dart_console.dart';

final _console = Console();

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

  /// Creates a clickable file link using OSC 8 hyperlink sequence.
  static String fileLink(String filePath, {String? label}) {
    final displayText = label ?? filePath;
    return '\x1B]8;;file://$filePath\x1B\\$displayText\x1B]8;;\x1B\\';
  }

  /// Read a single keypress from stdin.
  /// Uses dart_console for cross-platform support (fixes Windows arrow keys).
  static String readKey() {
    final key = _console.readKey();

    if (key.isControl) {
      switch (key.controlChar) {
        case ControlCharacter.arrowUp:
          return 'up';
        case ControlCharacter.arrowDown:
          return 'down';
        case ControlCharacter.arrowRight:
          return 'right';
        case ControlCharacter.arrowLeft:
          return 'left';
        case ControlCharacter.enter:
          return 'enter';
        case ControlCharacter.escape:
          return 'escape';
        case ControlCharacter.ctrlC:
          return 'q';
        default:
          return 'unknown';
      }
    }

    switch (key.char) {
      case ' ':
        return 'space';
      case 'q':
      case 'Q':
        return 'q';
      case 'a':
      case 'A':
        return 'a';
      case 'n':
      case 'N':
        return 'n';
      default:
        return key.char;
    }
  }
}
