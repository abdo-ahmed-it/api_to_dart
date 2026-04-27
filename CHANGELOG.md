## 0.2.0

**Renamed package** from `api_request_generator` to `api_to_dart`. The
executable is now `api2dart` and the per-project config directory is
`.api2dart/` (the previous `.apigen/` is no longer read or written).

### New
- `reset` subcommand for clearing saved settings. Defaults to wiping
  wizard selections only; pass `--all` to also remove saved
  Postman/Apidog tokens, or `-y` to skip the confirmation prompt.
- Postman environments — after picking a workspace the wizard now
  fetches its environments, lets you pick one (or skip), and merges
  the variables on top of any collection-level variables before
  resolving `base_url` / `token`.
- Response-only output mode for projects that don't depend on
  `api_request`. Auto-detected from the host `pubspec.yaml`; override
  with `-m, --mode={auto,action,response-only}`. In response-only mode
  files are written as `*_response.dart` (no `api_request` import) and
  endpoints with no response data are skipped.

### Fixed
- Postman collections list parsing: the API returns the array under
  the `collections` key (plural). The previous code read `collection`
  (singular) and always saw an empty list.
- Stop auto-clearing saved API tokens after a failed request. Network
  glitches or rate limits used to wipe a valid key; now the user is
  pointed at `api2dart reset --all` instead.

### Changed
- The `--reset` flag on `generate` was replaced by the standalone
  `reset` subcommand.
- Wizard banner, help text, and saved-settings paths updated for the
  new name.

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
