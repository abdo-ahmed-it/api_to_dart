import 'helpers.dart';

/// A type correction sourced from an OpenAPI schema: it tells the model
/// generator that the field at [path] is a string enum whose allowed values
/// are [values], and that it should be emitted as a Dart enum named [name].
///
/// [path] uses the same format the model generator walks fields with —
/// `/<key>` segments rooted at the empty string, with list elements sharing
/// their list's path (no index). E.g. `/response/user/status`.
class EnumHint {
  final String path;
  final String name;
  final List<String> values;

  EnumHint(this.path, this.name, this.values);
}

/// Walks a resolved OpenAPI schema (the shape stored in
/// `ResponseDefinition.schema`, with `$ref`s already resolved) and collects
/// every string field that declares an `enum: [...]`.
///
/// Paths are built to match `ModelGenerator`'s field-walking exactly so the
/// hints line up with the JSON example it generates code from.
class EnumExtractor {
  final List<EnumHint> _hints = [];
  final Set<String> _usedNames = {};

  List<EnumHint> extract(Map<String, dynamic> schema) {
    _walk(schema, '', null);
    return _hints;
  }

  void _walk(Map<String, dynamic> schema, String path, String? key) {
    final type = schema['type']?.toString();

    // A string field carrying an `enum` list is what we're after.
    final enumValues = schema['enum'];
    if (type == 'string' && enumValues is List && enumValues.isNotEmpty) {
      final values =
          enumValues.where((v) => v != null).map((v) => v.toString()).toList();
      if (values.isNotEmpty && key != null) {
        _hints.add(EnumHint(path, _enumNameFor(key), values));
      }
      return;
    }

    switch (type) {
      case 'object':
        final properties = schema['properties'] as Map<String, dynamic>?;
        if (properties != null) {
          properties.forEach((propKey, value) {
            if (value is Map<String, dynamic>) {
              _walk(value, '$path/$propKey', propKey);
            }
          });
        }
        break;
      case 'array':
        // List elements share their list's path (no index), matching the
        // model generator's traversal of merged list objects.
        final items = schema['items'];
        if (items is Map<String, dynamic>) {
          _walk(items, path, key);
        }
        break;
    }
  }

  /// Derives a unique, PascalCase enum type name from the field key.
  String _enumNameFor(String key) {
    var base = camelCase(key);
    if (base.isEmpty) base = 'Enum';
    var name = base;
    var suffix = 2;
    while (_usedNames.contains(name)) {
      name = '$base$suffix';
      suffix++;
    }
    _usedNames.add(name);
    return name;
  }
}
