## 0.5.0

### Added
- **Local web UI** — a browser-based, Apidog-like workspace to browse, try, and
  generate from your endpoints. Two ways in:
  - The interactive wizard (`api2dart` with no args) prints an **optional web
    link** after loading endpoints — for any source (Postman/Apidog/file). The
    terminal selector still works exactly as before; the link is an extra way
    to work in the browser. The server runs until `Ctrl+C`.
  - `api2dart serve -s <source> -c <file>` opens the web UI directly for a
    **local file** (and auto-opens the browser; `--no-open` to skip,
    `-p/--port` to choose a port). For live Apidog/Postman fetch, use the
    wizard.
  - The UI mirrors the terminal selector's nested folder tree (collapsed by
    default), with live search, per-method filters, and folder/master
    checkboxes — selection state and scroll are preserved while you pick.
  - **Request builder** — editable method/URL + Params/Headers/Body/Auth tabs
    and a **Send** button that fires the real request and shows status, time,
    response headers, and formatted JSON. The session token is applied
    automatically (Bearer) for authenticated endpoints.
  - **Code preview** of the generated Dart per endpoint.
  - **Generate selected** writes the exact same `*_action.dart` /
    `*_response.dart` files and Markdown logs as the terminal `generate`,
    including correct Apidog URL-variable path/base-URL resolution (see Fixed).
  - Keyboard: `/` focuses search, `Ctrl/Cmd+Enter` sends. Loopback-only; works
    in non-TTY environments.

### Fixed
- Apidog endpoints whose paths use a URL-variable prefix (e.g.
  `/system_user_url/login`) are now resolved consistently across the terminal
  and web flows: the prefix is stripped, the correct per-endpoint base URL is
  applied, and the name is rebuilt from the clean path. Previously this
  resolution happened only in the terminal generate path, so the web UI showed
  and generated wrong URLs/paths for such Apidog projects. The logic now lives
  in a shared `UrlVariableResolver` used by both.

## 0.4.0

### Added
- New `api2dart resend <log-file.md>` command. Every generated request log now
  ends with a `## Resend` section and a hidden machine-readable request block.
  Running `resend` on a log file replays the exact request (method, URL,
  headers, query, body) and overwrites the same file in place with the fresh
  status, response and timing. The file stays replayable indefinitely. The
  human-facing `## cURL` snippet is preserved for manual copy/paste.
  - On a failed request (no response), the file is left unchanged.
  - Older log files without the metadata block report a clear error pointing
    the user to re-run `generate`.

## 0.3.2

### Fixed
- Endpoints sharing a path but differing in HTTP method (e.g. `GET /users`
  and `POST /users`) no longer overwrite each other. Generated action and
  file names are now prefixed with the method
  (`GetUsersAction` / `get_users_action.dart`,
  `PostUsersAction` / `post_users_action.dart`). The prefix is skipped when
  the name already starts with the method to avoid duplication like
  `GetGetUsers`.
- Fixed structural equality in the json_to_dart model deduplication.
  `TypeDefinition` / `ClassDefinition` declared a method named `operator`
  instead of overriding `operator ==`, so `==` fell back to identity and
  identical nested objects were never merged — emitting duplicate suffixed
  classes (`Data2`, `Links2`) plus orphan, never-referenced classes.
  Structurally identical objects now collapse to one class while distinct
  same-named objects still get distinct names.

## 0.3.1

### Changed
- Running `api2dart` with no arguments now launches the interactive
  wizard directly instead of printing the usage screen. All other
  commands and flags (`--help`, `version`, `upgrade`, etc.) behave
  exactly as before.

## 0.3.0

### New
- `version` subcommand — prints the installed version.
- `upgrade` subcommand — pulls the latest release from pub.dev.
- Automatic update notice after any command when a newer version
  is available on pub.dev.

### Changed
- Request logs are now Markdown (`.md`) instead of plain `.log`, with
  formatted sections for URL, headers, request body, status code, and
  response body.
- Generated files are written under a dated subfolder
  (`<output>/<YYYY-MM-DD>/actions/` and `.../logs/`) so repeated runs
  don't overwrite previous outputs. The default `--output` is now
  `api2dart` (was `lib/actions`).

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
