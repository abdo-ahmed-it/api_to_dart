import 'dart:io';

import '../../core/models/api_endpoint.dart';
import '../../core/models/api_folder.dart';
import '../../core/models/endpoint_tree.dart';
import 'terminal_utils.dart';

class _TreeNode {
  final String label;
  final int depth;
  final bool isFolder;
  bool isExpanded;
  bool isSelected;
  final ApiEndpoint? endpoint;
  final List<_TreeNode> children;

  _TreeNode({
    required this.label,
    this.depth = 0,
    this.isFolder = false,
    this.isExpanded = false,
    // ignore: unused_element_parameter
    this.isSelected = false,
    this.endpoint,
    this.children = const [],
  });
}

class EndpointSelector {
  final EndpointTree tree;
  bool _firstRender = true;
  int _lastRenderedLines = 0;

  EndpointSelector(this.tree);

  /// Shows an interactive tree selector and returns the selected endpoints.
  /// Returns null if the user cancels.
  List<ApiEndpoint>? selectInteractively() {
    final nodes = _buildFlatNodes();
    if (nodes.isEmpty) {
      print('No endpoints found in the collection.');
      return null;
    }

    int cursor = 0;

    TerminalUtils.hideCursor();

    try {
      // Initial render
      _renderFrame(nodes, cursor);

      while (true) {
        final key = TerminalUtils.readKey();

        switch (key) {
          case 'up':
            if (cursor > 0) cursor--;
            break;
          case 'down':
            final visible = _visibleNodes(nodes);
            if (cursor < visible.length - 1) cursor++;
            break;
          case 'space':
            final visible = _visibleNodes(nodes);
            if (cursor < visible.length) {
              final node = visible[cursor];
              if (node.isFolder) {
                _toggleFolder(node);
              } else {
                node.isSelected = !node.isSelected;
              }
            }
            break;
          case 'right':
            final visible = _visibleNodes(nodes);
            if (cursor < visible.length) {
              final node = visible[cursor];
              if (node.isFolder && !node.isExpanded) {
                node.isExpanded = true;
              }
            }
            break;
          case 'left':
            final visible = _visibleNodes(nodes);
            if (cursor < visible.length) {
              final node = visible[cursor];
              if (node.isFolder && node.isExpanded) {
                node.isExpanded = false;
                // Adjust cursor if it was on a now-hidden child
                final newVisible = _visibleNodes(nodes);
                if (cursor >= newVisible.length) {
                  cursor = newVisible.length - 1;
                }
              }
            }
            break;
          case 'a':
            _selectAll(nodes, true);
            break;
          case 'n':
            _selectAll(nodes, false);
            break;
          case 'enter':
            _clearFrame();
            TerminalUtils.showCursor();
            return _getSelectedEndpoints(nodes);
          case 'q':
          case 'escape':
            _clearFrame();
            TerminalUtils.showCursor();
            return null;
        }

        // Re-render
        _renderFrame(nodes, cursor);
      }
    } catch (_) {
      TerminalUtils.showCursor();
      rethrow;
    }
  }

  int _getMaxVisible() {
    try {
      // Leave room for header (2 lines), footer (2 lines), scroll indicators (2 lines)
      return (stdout.terminalLines - 6).clamp(5, 40);
    } catch (_) {
      return 20;
    }
  }

  void _renderFrame(List<_TreeNode> nodes, int cursor) {
    // Move cursor back to the start of the previous frame
    if (!_firstRender && _lastRenderedLines > 0) {
      stdout.write('\x1B[${_lastRenderedLines}A');
    }
    _firstRender = false;

    final visible = _visibleNodes(nodes);
    final selectedCount = _getSelectedEndpoints(nodes).length;
    final totalCount = tree.totalEndpoints;
    final maxVisible = _getMaxVisible();

    // Calculate scroll window
    final windowStart = _calculateWindowStart(cursor, visible.length, maxVisible);
    final windowEnd = (windowStart + maxVisible).clamp(0, visible.length);

    final lines = <String>[];

    lines.add(TerminalUtils.bold(
        'Select endpoints to generate ($selectedCount/$totalCount selected):'));
    lines.add('');

    // Scroll-up indicator
    if (windowStart > 0) {
      lines.add(TerminalUtils.gray('   ↑ $windowStart more above'));
    }

    for (int i = windowStart; i < windowEnd; i++) {
      final node = visible[i];
      final isCursor = i == cursor;
      final indent = '   ' * node.depth;
      final pointer = isCursor ? TerminalUtils.cyan(' > ') : '   ';

      if (node.isFolder) {
        final arrow = node.isExpanded ? '▼' : '▶';
        final folderCheck = _allChildrenSelected(node) ? '✓' : ' ';
        final label = TerminalUtils.yellow('📁 ${node.label}');
        lines.add('$pointer$indent[$folderCheck] $arrow $label');
      } else {
        final check = node.isSelected ? TerminalUtils.green('✓') : ' ';
        final methodColor = _methodColor(node.label);
        lines.add('$pointer$indent[$check] $methodColor');
      }
    }

    // Scroll-down indicator
    final below = visible.length - windowEnd;
    if (below > 0) {
      lines.add(TerminalUtils.gray('   ↓ $below more below'));
    }

    lines.add('');
    lines.add(TerminalUtils.gray(
        '  ↑/↓ Navigate  Space Toggle  → Expand  ← Collapse  a All  n None  Enter Generate  q Cancel'));

    // Write each line, clearing the rest of the line to avoid leftover chars
    for (final line in lines) {
      stdout.write('\x1B[2K');
      stdout.writeln(line);
    }

    // If previous render had more lines, clear the extra lines
    if (_lastRenderedLines > lines.length) {
      for (int i = 0; i < _lastRenderedLines - lines.length; i++) {
        stdout.write('\x1B[2K\n');
      }
      stdout.write('\x1B[${_lastRenderedLines - lines.length}A');
    }

    _lastRenderedLines = lines.length;
  }

  int _calculateWindowStart(int cursor, int total, int maxVisible) {
    if (total <= maxVisible) return 0;
    final halfWindow = maxVisible ~/ 2;
    var start = cursor - halfWindow;
    if (start < 0) start = 0;
    if (start + maxVisible > total) start = total - maxVisible;
    return start;
  }

  void _clearFrame() {
    if (_lastRenderedLines > 0) {
      stdout.write('\x1B[${_lastRenderedLines}A');
      for (int i = 0; i < _lastRenderedLines; i++) {
        stdout.write('\x1B[2K\n');
      }
      stdout.write('\x1B[${_lastRenderedLines}A');
    }
  }

  List<_TreeNode> _buildFlatNodes() {
    final nodes = <_TreeNode>[];

    for (final folder in tree.folders) {
      nodes.add(_buildFolderNode(folder, 0));
    }

    for (final endpoint in tree.rootEndpoints) {
      nodes.add(_TreeNode(
        label: _endpointLabel(endpoint),
        endpoint: endpoint,
      ));
    }

    return nodes;
  }

  _TreeNode _buildFolderNode(ApiFolder folder, int depth) {
    final children = <_TreeNode>[];

    for (final subfolder in folder.subfolders) {
      children.add(_buildFolderNode(subfolder, depth + 1));
    }

    for (final endpoint in folder.endpoints) {
      children.add(_TreeNode(
        label: _endpointLabel(endpoint),
        depth: depth + 1,
        endpoint: endpoint,
      ));
    }

    return _TreeNode(
      label: folder.name,
      depth: depth,
      isFolder: true,
      children: children,
    );
  }

  String _endpointLabel(ApiEndpoint endpoint) {
    final method = endpoint.method.name.padRight(6);
    return '$method  ${endpoint.path}';
  }

  List<_TreeNode> _visibleNodes(List<_TreeNode> nodes) {
    final visible = <_TreeNode>[];
    for (final node in nodes) {
      _collectVisible(node, visible);
    }
    return visible;
  }

  void _collectVisible(_TreeNode node, List<_TreeNode> visible) {
    visible.add(node);
    if (node.isFolder && node.isExpanded) {
      for (final child in node.children) {
        _collectVisible(child, visible);
      }
    }
  }

  void _toggleFolder(_TreeNode folder) {
    final allSelected = _allChildrenSelected(folder);
    _setChildrenSelected(folder, !allSelected);
  }

  bool _allChildrenSelected(_TreeNode folder) {
    for (final child in folder.children) {
      if (child.isFolder) {
        if (!_allChildrenSelected(child)) return false;
      } else {
        if (!child.isSelected) return false;
      }
    }
    return true;
  }

  void _setChildrenSelected(_TreeNode folder, bool selected) {
    for (final child in folder.children) {
      if (child.isFolder) {
        _setChildrenSelected(child, selected);
      } else {
        child.isSelected = selected;
      }
    }
  }

  void _selectAll(List<_TreeNode> nodes, bool selected) {
    for (final node in nodes) {
      if (node.isFolder) {
        _setChildrenSelected(node, selected);
      } else {
        node.isSelected = selected;
      }
    }
  }

  List<ApiEndpoint> _getSelectedEndpoints(List<_TreeNode> nodes) {
    final selected = <ApiEndpoint>[];
    for (final node in nodes) {
      _collectSelected(node, selected);
    }
    return selected;
  }

  void _collectSelected(_TreeNode node, List<ApiEndpoint> selected) {
    if (!node.isFolder && node.isSelected && node.endpoint != null) {
      selected.add(node.endpoint!);
    }
    for (final child in node.children) {
      _collectSelected(child, selected);
    }
  }

  String _methodColor(String label) {
    final parts = label.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return label;

    final method = parts[0].trim();
    final rest = parts.sublist(1).join(' ');

    switch (method.toUpperCase()) {
      case 'GET':
        return '${TerminalUtils.green(method.padRight(6))}  $rest';
      case 'POST':
        return '${TerminalUtils.yellow(method.padRight(6))}  $rest';
      case 'PUT':
        return '${TerminalUtils.blue(method.padRight(6))}  $rest';
      case 'PATCH':
        return '${TerminalUtils.cyan(method.padRight(6))}  $rest';
      case 'DELETE':
        return '\x1B[31m${method.padRight(6)}\x1B[0m  $rest';
      default:
        return label;
    }
  }
}
