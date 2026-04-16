# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Dart CLI tool (`apigen`) that generates type-safe API request action classes and response model classes from multiple sources: Postman collections, OpenAPI specs, Apidog exports, or YAML config files. Features interactive endpoint selection in the terminal.

Generated code targets the `api_request` package — each output file contains an `ApiRequestAction` subclass and a response model with `fromJson`/`toJson`.

## Build & Run

```bash
# Install dependencies
dart pub get

# Show help
dart run bin/api_request_generator.dart --help
dart run bin/api_request_generator.dart generate --help

# Generate from Postman collection (interactive selector)
dart run bin/api_request_generator.dart generate -s postman -c collection.json -b https://api.example.com

# Generate from OpenAPI spec
dart run bin/api_request_generator.dart generate -s openapi -c openapi.yaml -o lib/actions

# Generate from YAML config (single endpoint)
dart run bin/api_request_generator.dart generate -s file -c action_config.yaml

# Skip interactive selector (generate all)
dart run bin/api_request_generator.dart generate -s postman -c collection.json --no-interactive

# Dry run (preview without writing)
dart run bin/api_request_generator.dart generate -s postman -c collection.json --dry-run --no-interactive

# Run tests
dart test

# Analyze
dart analyze
```

## Architecture

The codebase follows a core/CLI separation — all logic lives in `lib/src/core/` (reusable by a future VS Code extension), while CLI-specific code lives in `lib/src/cli/`.

### Core (`lib/src/core/`)

**Models** (`models/`): Unified data types used across the tool.
- `ApiEndpoint` — canonical representation of any API endpoint (name, path, method, body, auth, headers, queryParams, response). All sources convert to this.
- `EndpointTree` / `ApiFolder` — tree structure grouping endpoints into folders
- `BodyDefinition` — request body with content type (formData, urlEncoded, rawJson, multipart)
- `AuthDefinition` — auth config (none, bearer, basic, apiKey)
- `ResponseDefinition` — response data with source tracking (schema, example, fetched, none)

**Sources** (`sources/`): Each implements `ApiSource.parse()` → `EndpointTree`.
- `PostmanSource` — parses Postman collection v2.1 JSON (recursive `item[]` traversal)
- `OpenApiSource` — parses OpenAPI 3.x specs (YAML/JSON), resolves `$ref`, extracts schemas
- `ApidogSource` — delegates to `OpenApiSource` (Apidog exports OpenAPI format)
- `LocalFileSource` — parses single-endpoint YAML config

**Generation** (`generation/`):
- `ActionGenerator` — produces `ApiRequestAction` subclass string from `ApiEndpoint`
- `ResponseGenerator` — wraps `ModelGenerator` to convert JSON → Dart model classes
- `CodeEmitter` — orchestrates generation, formatting, and file writing. Handles action-only fallback.
- `body_processor.dart` — converts raw body data (from Postman/YAML) into `BodyDefinition`

**Resolution** (`resolution/`):
- `ResponseResolver` — fallback chain: schema → example → live fetch → dynamic
- `ApiHttpClient` — HTTP client supporting GET, POST, PUT, PATCH, DELETE with auth and body handling

**JSON to Dart** (`json_to_dart/`): Converts JSON response strings into Dart model classes with `fromJson`/`toJson`. Uses `json_ast` for precise numeric type detection. `ModelGenerator` is the entry point; `syntax.dart` defines class/type definitions; `helpers.dart` handles type inference and object merging.

**Logger** (`logger/`): Abstract `Logger` interface + `ConsoleLogger` implementation with colored terminal output.

### CLI (`lib/src/cli/`)

- `cli_app.dart` — `CommandRunner` setup
- `commands/generate_command.dart` — main `generate` command with flags for source, config, output, auth, interactive/dry-run modes
- `ui/endpoint_selector.dart` — interactive tree selector using raw `dart:io` stdin
- `ui/terminal_utils.dart` — ANSI escape helpers

## Key Details

- This is a **pure Dart package** (no Flutter dependency).
- The interactive endpoint selector uses raw terminal input (`stdin.lineMode = false`). It cannot run in non-TTY environments — use `--no-interactive` for CI.
- Comments in older code (json_to_dart) may be in Arabic.
- `HttpMethod` enum uses uppercase names (GET, POST, etc.) to match HTTP method strings directly.
