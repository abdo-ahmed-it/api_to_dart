# API to Dart

A Dart CLI tool that converts any API (**Postman**, **OpenAPI**, **Apidog**, or **YAML**) into type-safe Dart code — request actions, response models, or just response models when you don't need actions. Features an interactive terminal UI for selecting endpoints.

## Features

- **Multi-source support** — Postman collections, OpenAPI 3.x specs, Apidog projects, local YAML files
- **Postman integration** — Browse workspaces, environments, and collections from the Postman API
- **Apidog integration** — Fetches projects, environments, and variables from the Apidog API
- **Interactive endpoint selector** — Tree view with folder navigation and batch selection
- **Smart response resolution** — Live fetch → example → schema → empty fallback
- **Two output modes** — Action + Response (when `api_request` is in your pubspec) or Response-only
- **Auto-detection** — Picks the right output mode based on your `pubspec.yaml`
- **Request logging** — `.log` file for every HTTP request with full headers, body, timing
- **Environment variables** — Auto-resolves `{{variables}}` from Postman/Apidog environments
- **Settings persistence** — Saves project/environment config per-project in `.api2dart/`

## Installation

Add as a dev dependency in your Flutter/Dart project:

```yaml
dev_dependencies:
  api_to_dart:
    git:
      url: https://github.com/abdo-ahmed-it/api_to_dart.git
```

Then run:

```bash
dart pub get
```

## Quick Start

### Interactive mode (recommended)

```bash
dart run api_to_dart generate
```

This launches the wizard:

1. **Select source** — Local file, Postman API, or Apidog API
2. **Select endpoints** — Interactive tree with keyboard navigation
3. **Generate** — Files are written under `api2dart/<date>/actions/` (and request logs under `.../logs/`)

After loading endpoints, the wizard also prints an **optional web UI link**
(e.g. `http://127.0.0.1:4321`). Open it to browse, search/filter, **try
requests live**, preview the generated Dart, and select/generate from the
browser — a richer alternative to the terminal selector. The terminal flow
keeps working as before; the link is just an extra option. The web server runs
until you press `Ctrl+C`.

### Web UI for a local file (`serve`)

If you already have a Postman/OpenAPI/YAML file on disk, you can open the web UI
directly without the wizard:

```bash
dart run api_to_dart serve -s openapi -c openapi.yaml -b https://api.example.com
# prints a localhost link and (by default) opens your browser; --no-open to skip
```

`serve` parses a **local file** only. To pull live from Apidog/Postman
(token/project/environment) and still get the web UI, use `generate` — its
wizard prints the same link.

### With Postman

```
? Select source: Postman (fetch from API)
? Postman API Key: PMAK-xxxxx
  Loading workspaces...
? Select workspace: My Team (team)
  Loading environments...
? Select environment: Production
  ✓ Environment: Production (8 variables)
  Loading collections...
? Select collection: My API
  ✓ Loaded 42 endpoints
? Select endpoints: ...
  ✓ Generated 5 files
```

### With Apidog

```
? Select source: Apidog (fetch from API)
? Apidog API Token: adgp_xxxxx
  Loading projects...
? Select project: My App
  Loading environments...
? Select environment: Develop Env (https://api.example.com)
  ✓ Loaded 50 endpoints
? Select endpoints: ...
  ✓ Generated 5 files
```

Next time — goes straight to endpoint selection (settings saved in `.api2dart/config.yaml`).

### With flags (CI / scripting)

```bash
# Generate all endpoints from a Postman collection
dart run api_to_dart generate \
  -s postman \
  -c postman_collection.json \
  -b https://api.example.com \
  --no-interactive

# Force response-only mode (no api_request import)
dart run api_to_dart generate \
  -s openapi \
  -c openapi.yaml \
  -m response-only \
  --no-interactive

# Dry run — preview without writing files
dart run api_to_dart generate \
  -s postman \
  -c collection.json \
  --dry-run --no-interactive
```

### Reset saved settings

```bash
# Clear wizard selections (keep saved API tokens)
dart run api_to_dart reset

# Clear everything, including saved Postman/Apidog tokens
dart run api_to_dart reset --all

# Skip the confirmation prompt
dart run api_to_dart reset -y
```

### Version & upgrade

```bash
# Show the installed version (also: --version, -v)
api2dart version

# Upgrade to the latest version on pub.dev
api2dart upgrade
```

You'll automatically see a notice after any command when a new version is available:

```
✦ Update available: 0.2.0 → 0.3.0
  Run `api2dart upgrade` to install the new version.
```

### Flags

#### `generate`

| Flag | Short | Description |
|------|-------|-------------|
| `--source` | `-s` | Source type: `postman`, `openapi`, `apidog`, `file` |
| `--config` | `-c` | Path to collection/spec file |
| `--output` | `-o` | Output directory (default: `lib/actions`) |
| `--base-url` | `-b` | Base URL for live fetch |
| `--token` | `-t` | Authentication token for live fetch |
| `--mode` | `-m` | `auto` (default), `action`, or `response-only` |
| `--no-interactive` | | Skip selector, generate all |
| `--dry-run` | | Preview only |

#### `reset`

| Flag | Short | Description |
|------|-------|-------------|
| `--all` | | Also delete saved Postman / Apidog tokens |
| `--yes` | `-y` | Skip the confirmation prompt |

#### `upgrade`

| Flag | Short | Description |
|------|-------|-------------|
| `--force` | `-f` | Re-activate even if already on the latest version |

## Keyboard Controls

| Key | Action |
|-----|--------|
| `↑` `↓` | Navigate |
| `Space` | Toggle selection |
| `→` | Expand folder |
| `←` | Collapse folder |
| `a` | Select all |
| `n` | Deselect all |
| `Enter` | Generate selected |
| `q` | Quit |

## Output Modes

### Action + Response (default when `api_request` is detected)

Each endpoint becomes a file with both an `ApiRequestAction` subclass and its response model.

`lib/actions/login_action.dart`:

```dart
import 'package:api_request/api_request.dart';

class LoginAction extends ApiRequestAction<LoginResponse> {
  @override
  bool get authRequired => true;

  @override
  RequestMethod get method => RequestMethod.POST;

  @override
  String get path => '/auth/login';

  @override
  Map<String, dynamic> get toMap => {"phone": "123456789"};

  @override
  ContentDataType? get contentDataType => ContentDataType.formData;

  @override
  ResponseBuilder<LoginResponse> get responseBuilder =>
      (json) => LoginResponse.fromJson(json);
}

class LoginResponse {
  bool? status;
  String? message;
  Data? data;
  // ... fromJson, toJson
}
```

### Response-only (default when `api_request` is missing)

For projects that don't use the `api_request` package. Only the model is generated, with no `api_request` import.

`lib/models/login_response.dart`:

```dart
class LoginResponse {
  bool? status;
  String? message;
  Data? data;

  LoginResponse({this.status, this.message, this.data});

  LoginResponse.fromJson(Map<String, dynamic> json) { ... }
  Map<String, dynamic> toJson() { ... }
}
```

In response-only mode, endpoints with no response data are skipped (there's nothing useful to emit).

### Picking the mode explicitly

The CLI auto-detects from your `pubspec.yaml`. You can override with `-m`:

- `-m auto` — auto-detect (default)
- `-m action` — force action + response
- `-m response-only` — force response-only

## Request log

For every endpoint, a `.log` file is written next to the output:

`lib/actions/logs/login_action.log`:

```
=[ requestName ]===================
"Login"

=[ url ]===================
"https://api.example.com/auth/login"

=[ statusCode ]===================
200

=[ responseBody ]===================
{ "status": true, "message": "Success", "data": { ... } }
```

Failed requests (non-2xx) create only the log file — no Dart code is generated.

## Response Resolution

The tool resolves each endpoint's response using this priority:

1. **Live fetch** — Sends the actual request to the server (best quality models)
2. **Example** — Uses the example from the OpenAPI spec or Postman saved response
3. **Schema** — Generates synthetic JSON from the OpenAPI schema
4. **Empty** — Falls back to `dynamic` response type (action mode) or skips the file (response-only)

## Project Structure

```
lib/
  src/
    core/              # Reusable logic (pure Dart, no CLI dependencies)
      models/          # ApiEndpoint, EndpointTree, BodyDefinition, etc.
      sources/         # PostmanSource, OpenApiSource, ApidogSource, LocalFileSource
        api_fetchers/  # PostmanFetcher, ApidogFetcher, ConfigStorage
      generation/      # ActionGenerator, ResponseGenerator, CodeEmitter, PubspecInspector
      resolution/      # HttpClient, ResponseResolver
      json_to_dart/    # JSON-to-Dart model generator
      logger/          # Abstract Logger + ConsoleLogger
    cli/               # Terminal UI (CLI-only)
      commands/        # GenerateCommand, ResetCommand, VersionCommand, UpgradeCommand
      wizard/          # Interactive wizard
      ui/              # EndpointSelector, FileBrowser, Prompts
```

## Requirements

- Dart SDK >= 3.6.2
- For Postman integration: API key from [Postman API keys](https://postman.co/settings/me/api-keys)
- For Apidog integration: API Access Token from [Apidog Settings](https://app.apidog.com/settings/api-access-token)
- Action mode requires the [`api_request`](https://pub.dev/packages/api_request) package in your pubspec; response-only mode has no runtime dependencies

## License

See [LICENSE](LICENSE) file.
