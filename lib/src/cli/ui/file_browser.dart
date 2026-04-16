import 'dart:io';

import 'package:path/path.dart' as p;

import 'terminal_utils.dart';

/// Interactive file browser for selecting files.
/// Returns the selected file path, or null if cancelled.
String? browseFiles({
  required String message,
  String? startDirectory,
  List<String> allowedExtensions = const [],
}) {
  var currentDir =
      Directory(startDirectory ?? Directory.current.path).absolute.path;

  bool firstRender = true;
  int lastRenderedLines = 0;

  TerminalUtils.hideCursor();

  try {
    int cursor = 0;

    while (true) {
      final entries = _getEntries(currentDir, allowedExtensions);

      // Clamp cursor
      if (cursor >= entries.length) cursor = entries.length - 1;
      if (cursor < 0) cursor = 0;

      // Calculate visible window (max 15 items)
      const maxVisible = 15;
      final windowStart = _calculateWindowStart(cursor, entries.length, maxVisible);
      final windowEnd = (windowStart + maxVisible).clamp(0, entries.length);
      final visibleEntries = entries.sublist(windowStart, windowEnd);

      // Build lines
      final lines = <String>[];
      lines.add(TerminalUtils.bold('? $message'));
      lines.add(
          '  📂 ${TerminalUtils.cyan(currentDir)}');
      lines.add('');

      for (int i = 0; i < visibleEntries.length; i++) {
        final entry = visibleEntries[i];
        final globalIndex = windowStart + i;
        final isCursor = globalIndex == cursor;
        final pointer = isCursor ? TerminalUtils.cyan(' > ') : '   ';

        if (entry.isParent) {
          lines.add('$pointer${TerminalUtils.gray('📁 ../')}');
        } else if (entry.isDirectory) {
          lines.add(
              '$pointer${TerminalUtils.yellow('📁 ${entry.name}/')}');
        } else {
          final icon = _fileIcon(entry.name);
          if (isCursor) {
            lines.add('$pointer$icon ${TerminalUtils.cyan(entry.name)}');
          } else {
            lines.add('$pointer$icon ${entry.name}');
          }
        }
      }

      // Scroll indicators
      if (entries.length > maxVisible) {
        if (windowStart > 0) {
          lines.add('   ${TerminalUtils.gray('  ↑ ${windowStart} more above')}');
        }
        final below = entries.length - windowEnd;
        if (below > 0) {
          lines.add('   ${TerminalUtils.gray('  ↓ $below more below')}');
        }
      }

      lines.add('');
      lines.add(TerminalUtils.gray(
          '  ↑/↓ Navigate  Enter Select  ← Back  q Cancel'));

      // Render
      if (!firstRender && lastRenderedLines > 0) {
        stdout.write('\x1B[${lastRenderedLines}A');
      }
      firstRender = false;

      for (final line in lines) {
        stdout.write('\x1B[2K');
        stdout.writeln(line);
      }
      // Clear extra lines from previous render
      if (lastRenderedLines > lines.length) {
        for (int i = 0; i < lastRenderedLines - lines.length; i++) {
          stdout.write('\x1B[2K\n');
        }
        stdout.write('\x1B[${lastRenderedLines - lines.length}A');
      }
      lastRenderedLines = lines.length;

      // Read key
      final key = TerminalUtils.readKey();

      switch (key) {
        case 'up':
          if (cursor > 0) cursor--;
          break;
        case 'down':
          if (cursor < entries.length - 1) cursor++;
          break;
        case 'left':
          // Go to parent directory
          final parent = Directory(currentDir).parent.path;
          if (parent != currentDir) {
            currentDir = parent;
            cursor = 0;
          }
          break;
        case 'enter':
          if (cursor < entries.length) {
            final entry = entries[cursor];
            if (entry.isParent) {
              final parent = Directory(currentDir).parent.path;
              if (parent != currentDir) {
                currentDir = parent;
                cursor = 0;
              }
            } else if (entry.isDirectory) {
              currentDir = entry.path;
              cursor = 0;
            } else {
              // File selected
              _clearFrame(lastRenderedLines);
              stdout.writeln(
                  '${TerminalUtils.green('✓')} $message: ${TerminalUtils.cyan(p.relative(entry.path))}');
              TerminalUtils.showCursor();
              return entry.path;
            }
          }
          break;
        case 'q':
        case 'escape':
          _clearFrame(lastRenderedLines);
          stdout.writeln(
              '${TerminalUtils.gray('✗')} $message: ${TerminalUtils.gray('cancelled')}');
          TerminalUtils.showCursor();
          return null;
      }
    }
  } catch (_) {
    TerminalUtils.showCursor();
    rethrow;
  }
}

void _clearFrame(int lines) {
  if (lines > 0) {
    stdout.write('\x1B[${lines}A');
    for (int i = 0; i < lines; i++) {
      stdout.write('\x1B[2K\n');
    }
    stdout.write('\x1B[${lines}A');
  }
}

int _calculateWindowStart(int cursor, int total, int maxVisible) {
  if (total <= maxVisible) return 0;
  final halfWindow = maxVisible ~/ 2;
  var start = cursor - halfWindow;
  if (start < 0) start = 0;
  if (start + maxVisible > total) start = total - maxVisible;
  return start;
}

class _FileEntry {
  final String name;
  final String path;
  final bool isDirectory;
  final bool isParent;

  _FileEntry({
    required this.name,
    required this.path,
    this.isDirectory = false,
    this.isParent = false,
  });
}

List<_FileEntry> _getEntries(
    String dirPath, List<String> allowedExtensions) {
  final entries = <_FileEntry>[];

  // Parent directory entry
  entries.add(_FileEntry(
    name: '..',
    path: Directory(dirPath).parent.path,
    isParent: true,
  ));

  try {
    final dir = Directory(dirPath);
    final items = dir.listSync()
      ..sort((a, b) {
        // Directories first, then files
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return p.basename(a.path)
            .toLowerCase()
            .compareTo(p.basename(b.path).toLowerCase());
      });

    for (final item in items) {
      final name = p.basename(item.path);

      // Skip hidden files/dirs
      if (name.startsWith('.')) continue;

      if (item is Directory) {
        entries.add(_FileEntry(
          name: name,
          path: item.path,
          isDirectory: true,
        ));
      } else if (item is File) {
        // Filter by extension if specified
        if (allowedExtensions.isNotEmpty) {
          final ext = p.extension(name).toLowerCase();
          if (!allowedExtensions.contains(ext)) continue;
        }
        entries.add(_FileEntry(
          name: name,
          path: item.path,
        ));
      }
    }
  } catch (_) {
    // Permission denied or other error — just show parent
  }

  return entries;
}

String _fileIcon(String name) {
  final ext = p.extension(name).toLowerCase();
  switch (ext) {
    case '.json':
      return '📄';
    case '.yaml':
    case '.yml':
      return '📝';
    case '.dart':
      return '🎯';
    default:
      return '📄';
  }
}
