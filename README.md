# API Request Generator

A Dart CLI tool that generates type-safe API request actions and response models from **Postman**, **OpenAPI**, **Apidog**, or **YAML** configs. Features an interactive terminal UI for selecting endpoints.

## Features

- **Multi-source support** — Postman collections, OpenAPI 3.x specs, Apidog projects, local YAML files
- **Apidog integration** — Fetches projects, environments, and variables directly from the Apidog API
- **Interactive endpoint selector** — Tree view with folder navigation, search, and batch selection
- **Smart response resolution** — Live fetch from server, with fallback to examples and schemas
- **Request logging** — Detailed `.log` files for every HTTP request with full headers, body, timing
- **Dart model generation** — Generates `fromJson`/`toJson` models from actual API responses
- **Environment variables** — Auto-resolves `{{variables}}` from Apidog environments
- **Settings persistence** — Saves project/environment config per-project in `.apigen/`

## Installation

Add as a dev dependency in your Flutter/Dart project:

```yaml
dev_dependencies:
  api_request_generator:
    git:
      url: https://github.com/abdo-ahmed-it/api_request_generator.git
```

Then run:

```bash
dart pub get
```

## Quick Start

### Interactive mode (recommended)

```bash
dart run api_request_generator generate
```

This launches the wizard:

1. **Select source** — Local file, Postman API, or Apidog API
2. **Select endpoints** — Interactive tree with keyboard navigation
3. **Generate** — Actions and models are created in `lib/actions/`

### With Apidog

First time:
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

Next time — goes straight to endpoint selection (settings saved in `.apigen/config.yaml`).

### With flags (CI/scripting)

```bash
# Generate all endpoints from a Postman collection
dart run api_request_generator generate \
  -s postman \
  -c postman_collection.json \
  -b https://api.example.com \
  --no-interactive

# Dry run — preview without writing files
dart run api_request_generator generate \
  -s postman \
  -c collection.json \
  --dry-run --no-interactive

# Reset saved settings
dart run api_request_generator generate --reset
```

### Flags

| Flag | Short | Description |
|------|-------|-------------|
| `--source` | `-s` | Source type: `postman`, `openapi`, `apidog`, `file` |
| `--config` | `-c` | Path to collection/spec file |
| `--output` | `-o` | Output directory (default: `lib/actions`) |
| `--base-url` | `-b` | Base URL for live fetch |
| `--token` | `-t` | Authentication token |
| `--no-interactive` | | Skip selector, generate all |
| `--dry-run` | | Preview only |
| `--reset` | | Clear saved settings |

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

## Generated Output

For each selected endpoint, the tool generates:

**Action file** (`lib/actions/login_action.dart`):
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

**Log file** (`lib/actions/logs/login_action.log`):
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

## Response Resolution

The tool resolves responses using this priority:

1. **Live fetch** — Sends the actual request to the server (best quality models)
2. **Example** — Uses the example from the OpenAPI spec
3. **Schema** — Generates synthetic JSON from the OpenAPI schema
4. **Action-only** — Generates the action with `dynamic` response type

Failed requests (non-2xx) create only a log file — no action is generated.

## Project Structure

```
lib/
  src/
    core/              # Reusable logic (for future VS Code extension)
      models/          # ApiEndpoint, EndpointTree, BodyDefinition, etc.
      sources/         # PostmanSource, OpenApiSource, ApidogSource, LocalFileSource
      generation/      # ActionGenerator, ResponseGenerator, CodeEmitter
      resolution/      # HttpClient, ResponseResolver
      json_to_dart/    # JSON to Dart model generator
      logger/          # Abstract Logger + ConsoleLogger
    cli/               # Terminal UI
      commands/        # GenerateCommand
      wizard/          # Interactive wizard
      ui/              # EndpointSelector, FileBrowser, Prompts
```

## Requirements

- Dart SDK >= 3.6.2
- For Apidog integration: API Access Token from [Apidog Settings](https://app.apidog.com/settings/api-access-token)
- Generated code requires the [api_request](https://pub.dev/packages/api_request) package

## License

See [LICENSE](LICENSE) file.
