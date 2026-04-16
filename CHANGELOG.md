## 0.1.0

- Initial release
- Multi-source support: Postman collections, OpenAPI 3.x specs, Apidog projects, local YAML files
- Apidog integration: fetch projects, environments, and variables via API
- Interactive terminal endpoint selector with tree navigation
- Smart response resolution: live fetch → example → schema → action-only
- Request logging with detailed .log files per endpoint
- Dart model generation with fromJson/toJson from actual API responses
- Auto-resolve environment variables from Apidog
- Settings persistence per-project in .apigen/config.yaml
- Support for all HTTP methods: GET, POST, PUT, PATCH, DELETE
- PascalCase naming with smart path-based name generation
- Handles duplicate class names and null types in generated models
