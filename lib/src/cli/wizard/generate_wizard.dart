import 'dart:convert';
import 'dart:io';

import '../../core/generation/code_emitter.dart';
import '../../core/generation/pubspec_inspector.dart';
import '../../core/logger/console_logger.dart';
import '../../core/logger/logger.dart';
import '../../core/models/api_endpoint.dart';
import '../../core/models/api_source_config.dart';
import '../../core/models/endpoint_tree.dart';
import '../../core/models/response_definition.dart';
import '../../core/resolution/http_client.dart';
import '../../core/resolution/response_resolver.dart';
import '../../core/sources/api_fetchers/apidog_fetcher.dart';
import '../../core/sources/api_fetchers/config_storage.dart';
import '../../core/sources/api_fetchers/postman_fetcher.dart';
import '../../core/sources/openapi_source.dart';
import '../../core/sources/postman_source.dart';
import '../ui/endpoint_selector.dart';
import '../ui/file_browser.dart';
import '../ui/prompts.dart';
import '../ui/terminal_utils.dart';

class GenerateWizard {
  final Logger _logger;

  GenerateWizard({Logger? logger}) : _logger = logger ?? ConsoleLogger();

  Future<void> run() async {
    _printBanner();

    // Check for saved settings
    final savedSource = ConfigStorage.get('wizard.source');
    _LoadResult? loadResult;

    if (savedSource != null) {
      // Try to load from saved settings
      loadResult = await _loadFromSavedSettings(savedSource);

      if (loadResult == null) {
        _logger.w('Saved settings failed. Starting fresh.');
        ConfigStorage.remove('wizard');
      }
    }

    // If no saved settings or they failed, ask the user
    if (loadResult == null) {
      loadResult = await _step1SelectAndLoad();
      if (loadResult == null) return;
    }

    final tree = loadResult.tree;
    var baseUrl = loadResult.baseUrl;
    var token = loadResult.token;

    if (tree.isEmpty) {
      _logger.w('No endpoints found.');
      return;
    }

    // Ask for base URL and token if not available (for live fetch)
    if (baseUrl == null || baseUrl.isEmpty) {
      final savedBaseUrl = ConfigStorage.get('wizard.base_url');
      if (savedBaseUrl != null && savedBaseUrl.isNotEmpty) {
        baseUrl = savedBaseUrl;
        _logger.i('✓ Base URL: $baseUrl');
      } else {
        stdout.writeln('');
        baseUrl = promptInput(
          message: 'Base URL (for fetching live responses)',
          hint: 'e.g. https://api.example.com',
        );
        if (baseUrl != null && baseUrl.isNotEmpty) {
          ConfigStorage.set('wizard.base_url', baseUrl);
        }
      }
    }

    if (token == null || token.isEmpty) {
      token = promptInput(
        message: 'Auth token (leave empty to skip)',
      );
    }

    stdout.writeln('');

    // Step 2 & 3: Select and generate loop
    final selector = EndpointSelector(tree);

    while (true) {
      stdout.writeln('');
      final selected = selector.selectInteractively();

      if (selected == null || selected.isEmpty) {
        _logger.i('Done.');
        return;
      }

      stdout.writeln('');
      _logger.i('Selected ${selected.length} endpoints — generating...');
      stdout.writeln('');

      await _step3Generate(
        endpoints: selected,
        baseUrl: baseUrl ?? '',
        token: token,
        urlVariables: loadResult.urlVariables,
      );

      // Deselect generated endpoints but keep tree state
      selector.deselectAll();
    }
  }

  void _printBanner() {
    stdout.writeln('');
    stdout.writeln(TerminalUtils.bold(
        '┌─────────────────────────────────────┐'));
    stdout.writeln(TerminalUtils.bold(
        '│   🚀 API to Dart                     │'));
    stdout.writeln(TerminalUtils.bold(
        '└─────────────────────────────────────┘'));
    stdout.writeln('');
  }

  // ── Load from saved settings ────────────────────────────────────────

  Future<_LoadResult?> _loadFromSavedSettings(String source) async {
    switch (source) {
      case 'local':
        final filePath = ConfigStorage.get('wizard.file_path');
        if (filePath == null) return null;
        _logger.i('Using saved settings: local file ($filePath)');
        return _loadLocalFile(filePath);

      case 'postman_api':
        final apiKey = ConfigStorage.get('postman.api_key');
        final collectionUid = ConfigStorage.get('wizard.postman_collection_uid');
        if (apiKey == null || collectionUid == null) return null;

        // Refresh environment variables if one was previously selected.
        final envUid = ConfigStorage.get('wizard.postman_environment_uid');
        final envName = ConfigStorage.get('wizard.postman_environment_name');
        Map<String, String>? envVars;
        if (envUid != null && envUid.isNotEmpty) {
          _logger.i(
              'Using saved settings: Postman API (Env: ${envName ?? envUid})');
          final fetcher = PostmanFetcher(apiKey: apiKey, logger: _logger);
          final env = await fetcher.getEnvironment(envUid);
          if (env != null) {
            envVars = env.variables;
            _logger.i('✓ Loaded ${envVars.length} environment variables');
          }
        } else {
          _logger.i('Using saved settings: Postman API');
        }

        return _fetchPostmanCollection(apiKey, collectionUid,
            environmentVars: envVars);

      case 'apidog_api':
        final token = ConfigStorage.get('apidog.token');
        final projectId = ConfigStorage.get('apidog.last_project_id');
        if (token == null || projectId == null) return null;
        final envIdStr = ConfigStorage.get('apidog.environment_id');
        final envId = envIdStr != null ? int.tryParse(envIdStr) : null;
        final envName = ConfigStorage.get('apidog.environment_name') ?? '';
        _logger.i('Using saved settings: Apidog (Project: $projectId, Env: $envName)');

        // Fetch fresh environment variables
        final fetcher = ApidogFetcher(token: token, logger: _logger);
        Map<String, String>? envVars;
        if (envId != null) {
          final envs = await fetcher.getEnvironments(projectId);
          final env = envs.where((e) => e.id == envId).firstOrNull;
          if (env != null) {
            envVars = env.variables;
            _logger.i('✓ Loaded ${envVars.length} environment variables');
          }
        }

        return _fetchApidogProject(token, projectId,
            environmentId: envId, envVariables: envVars);

      default:
        return null;
    }
  }

  // ── Step 1: Select source and load ──────────────────────────────────

  Future<_LoadResult?> _step1SelectAndLoad() async {
    final sourceIndex = promptSelect(
      message: 'Select source',
      options: [
        '📁 Browse local file',
        '🌐 Postman (fetch from API)',
        '🌐 Apidog (fetch from API)',
      ],
    );

    if (sourceIndex == -1) return null;

    switch (sourceIndex) {
      case 0:
        return _loadFromLocalFile();
      case 1:
        return _loadFromPostmanApi();
      case 2:
        return _loadFromApidogApi();
      default:
        return null;
    }
  }

  // ── Local file ──────────────────────────────────────────────────────

  Future<_LoadResult?> _loadFromLocalFile() async {
    final filePath = browseFiles(
      message: 'Select collection or spec file',
      allowedExtensions: ['.json', '.yaml', '.yml'],
    );

    if (filePath == null) return null;

    final result = await _loadLocalFile(filePath);
    if (result != null) {
      // Save settings
      ConfigStorage.set('wizard.source', 'local');
      ConfigStorage.set('wizard.file_path', filePath);
    }
    return result;
  }

  Future<_LoadResult?> _loadLocalFile(String filePath) async {
    stdout.writeln('');

    final ext = filePath.toLowerCase();
    EndpointTree tree;

    if (ext.endsWith('.json')) {
      _logger.i('Parsing as Postman collection...');
      try {
        final source = PostmanSource();
        tree = await source.parse(ApiSourceConfig(filePath: filePath));

        final file = File(filePath);
        final content = jsonDecode(file.readAsStringSync());
        final vars = _extractPostmanVariables(content);

        _logger.i('✓ ${tree.sourceName}: ${tree.totalEndpoints} endpoints');
        if (vars['base_url'] != null) {
          _logger.i('✓ Base URL: ${vars['base_url']}');
        }

        return _LoadResult(
          tree: tree,
          baseUrl: vars['base_url'],
          token: vars['token'],
        );
      } catch (_) {
        _logger.i('Not a Postman collection — trying OpenAPI...');
      }
    }

    try {
      _logger.i('Parsing as OpenAPI spec...');
      final source = OpenApiSource();
      tree = await source.parse(ApiSourceConfig(filePath: filePath));
      _logger.i('✓ ${tree.sourceName}: ${tree.totalEndpoints} endpoints');
      return _LoadResult(tree: tree);
    } catch (e) {
      _logger.e('Failed to parse file', error: e);
      return null;
    }
  }

  Map<String, String?> _extractPostmanVariables(
      Map<String, dynamic> collection) {
    final vars = <String, String?>{};
    final varList = collection['variable'] as List<dynamic>? ?? [];
    for (final v in varList) {
      if (v is Map) {
        final key = v['key']?.toString();
        final value = v['value']?.toString();
        if (key != null && value != null) {
          vars[key] = value;
        }
      }
    }
    return vars;
  }

  // ── Postman API ─────────────────────────────────────────────────────

  Future<_LoadResult?> _loadFromPostmanApi() async {
    var apiKey = ConfigStorage.get('postman.api_key');

    if (apiKey == null || apiKey.isEmpty) {
      stdout.writeln('');
      stdout.writeln(TerminalUtils.gray(
          '  Get your API key from: https://postman.co/settings/me/api-keys'));
      stdout.writeln('');

      apiKey = promptInput(message: 'Postman API Key');
      if (apiKey == null || apiKey.isEmpty) return null;

      ConfigStorage.set('postman.api_key', apiKey);
      _logger.i('✓ API key saved');
    }

    final fetcher = PostmanFetcher(apiKey: apiKey, logger: _logger);

    stdout.writeln('');
    _logger.i('Loading workspaces...');
    final workspaces = await fetcher.getWorkspaces();

    if (workspaces.isEmpty) {
      _logger.e(
          'No workspaces found. The saved Postman API key may be invalid '
          'or expired.\n'
          '  Run `api2dart reset --all` to clear it and try a new one.');
      return null;
    }

    final wsIndex = promptSelect(
      message: 'Select workspace',
      options: workspaces.map((w) => '${w.name} (${w.type})').toList(),
    );
    if (wsIndex == -1) return null;
    final workspaceId = workspaces[wsIndex].id;

    // Environment selection (optional)
    _logger.i('Loading environments...');
    final environments = await fetcher.getEnvironments(workspaceId: workspaceId);
    PostmanEnvironment? selectedEnv;

    if (environments.isEmpty) {
      _logger.i('No environments in this workspace — skipping.');
    } else {
      final options = ['(no environment)', ...environments.map((e) => e.name)];
      final envIndex = promptSelect(
        message: 'Select environment',
        options: options,
      );
      if (envIndex == -1) return null;

      if (envIndex > 0) {
        final envInfo = environments[envIndex - 1];
        _logger.i('Loading environment "${envInfo.name}"...');
        selectedEnv = await fetcher.getEnvironment(envInfo.uid);
        if (selectedEnv != null) {
          _logger.i(
              '✓ Environment: ${selectedEnv.name} (${selectedEnv.variables.length} variables)');
        } else {
          _logger.w('Failed to load environment, continuing without it.');
        }
      }
    }

    _logger.i('Loading collections...');
    final collections =
        await fetcher.getCollections(workspaceId: workspaceId);

    if (collections.isEmpty) {
      _logger.e('No collections found in this workspace');
      return null;
    }

    final colIndex = promptSelect(
      message: 'Select collection',
      options: collections.map((c) => c.name).toList(),
    );
    if (colIndex == -1) return null;

    final result = await _fetchPostmanCollection(
      apiKey,
      collections[colIndex].uid,
      environmentVars: selectedEnv?.variables,
    );

    if (result != null) {
      // Save settings
      ConfigStorage.set('wizard.source', 'postman_api');
      ConfigStorage.set(
          'wizard.postman_collection_uid', collections[colIndex].uid);
      if (selectedEnv != null) {
        ConfigStorage.set(
            'wizard.postman_environment_uid', selectedEnv.uid);
        ConfigStorage.set(
            'wizard.postman_environment_name', selectedEnv.name);
      } else {
        ConfigStorage.remove('wizard.postman_environment_uid');
        ConfigStorage.remove('wizard.postman_environment_name');
      }
    }
    return result;
  }

  Future<_LoadResult?> _fetchPostmanCollection(
    String apiKey,
    String collectionUid, {
    Map<String, String>? environmentVars,
  }) async {
    final fetcher = PostmanFetcher(apiKey: apiKey, logger: _logger);

    _logger.i('Loading collection...');
    final collectionJson = await fetcher.getCollection(collectionUid);

    if (collectionJson == null) {
      _logger.e('Failed to fetch collection');
      return null;
    }

    final tempFile = File('.api2dart_temp_collection.json');
    tempFile.writeAsStringSync(collectionJson);

    try {
      final source = PostmanSource();
      final tree =
          await source.parse(ApiSourceConfig(filePath: tempFile.path));

      final content = jsonDecode(collectionJson);
      // Merge: collection variables first, environment variables override.
      final vars = <String, String?>{
        ..._extractPostmanVariables(content),
        if (environmentVars != null) ...environmentVars,
      };

      _logger.i('✓ ${tree.sourceName}: ${tree.totalEndpoints} endpoints');

      // Pick base URL from common variable names.
      final baseUrl = vars['base_url'] ??
          vars['baseUrl'] ??
          vars['url'] ??
          vars['host'];
      if (baseUrl != null && baseUrl.isNotEmpty) {
        _logger.i('✓ Base URL: $baseUrl');
      }

      final token = vars['token'] ??
          vars['access_token'] ??
          vars['accessToken'] ??
          vars['auth_token'];

      return _LoadResult(
        tree: tree,
        baseUrl: baseUrl,
        token: token,
      );
    } finally {
      if (tempFile.existsSync()) tempFile.deleteSync();
    }
  }

  // ── Apidog API ──────────────────────────────────────────────────────

  Future<_LoadResult?> _loadFromApidogApi() async {
    var token = ConfigStorage.get('apidog.token');

    if (token == null || token.isEmpty) {
      stdout.writeln('');
      stdout.writeln(TerminalUtils.gray(
          '  Get your token from: https://app.apidog.com/settings/api-access-token'));
      stdout.writeln('');

      token = promptInput(message: 'Apidog API Token');
      if (token == null || token.isEmpty) return null;

      ConfigStorage.set('apidog.token', token);
      _logger.i('✓ Token saved');
    }

    final fetcher = ApidogFetcher(token: token, logger: _logger);

    // Fetch projects
    stdout.writeln('');
    _logger.i('Loading projects...');
    final projects = await fetcher.getProjects();

    if (projects.isEmpty) {
      _logger.e('No projects found. The saved Apidog token may be invalid '
          'or expired.\n'
          '  Run `api2dart reset --all` to clear it and try a new one.');
      return null;
    }

    final projIndex = promptSelect(
      message: 'Select project',
      options: projects.map((p) => p.name).toList(),
    );
    if (projIndex == -1) return null;

    final projectId = projects[projIndex].id;

    // Fetch environments
    _logger.i('Loading environments...');
    final environments = await fetcher.getEnvironments(projectId);

    ApidogEnvironment? selectedEnv;

    if (environments.isNotEmpty) {
      final envIndex = promptSelect(
        message: 'Select environment',
        options: environments
            .map((e) => '${e.name} (${e.baseUrl})')
            .toList(),
      );
      if (envIndex == -1) return null;
      selectedEnv = environments[envIndex];

      _logger.i('✓ Environment: ${selectedEnv.name}');
      _logger.i('✓ Base URL: ${selectedEnv.baseUrl}');
      if (selectedEnv.variables.isNotEmpty) {
        _logger.i('✓ Variables: ${selectedEnv.variables.keys.join(', ')}');
      }
    } else {
      _logger.w('Could not fetch environments');
    }

    final result = await _fetchApidogProject(
      token,
      projectId,
      environmentId: selectedEnv?.id,
      envVariables: selectedEnv?.variables,
    );

    if (result != null) {
      ConfigStorage.set('wizard.source', 'apidog_api');
      ConfigStorage.set('apidog.last_project_id', projectId);
      if (selectedEnv != null) {
        ConfigStorage.set('apidog.environment_id', selectedEnv.id.toString());
        ConfigStorage.set('apidog.environment_name', selectedEnv.name);
      }
    }
    return result;
  }

  Future<_LoadResult?> _fetchApidogProject(
    String token,
    String projectId, {
    int? environmentId,
    Map<String, String>? envVariables,
  }) async {
    final fetcher = ApidogFetcher(token: token, logger: _logger);

    _logger.i('Exporting project as OpenAPI...');
    final openApiJson = await fetcher.exportOpenApi(projectId,
        environmentId: environmentId);

    if (openApiJson == null) {
      _logger.e('Failed to export project. Check your token and project ID.');
      return null;
    }

    // Resolve {{variables}} in the exported spec using environment variables
    // Skip URL-type variables (they get embedded in paths and break them)
    var resolvedJson = openApiJson;
    int resolvedCount = 0;
    if (envVariables != null && envVariables.isNotEmpty) {
      envVariables.forEach((key, value) {
        if (value.startsWith('http://') || value.startsWith('https://')) {
          // URL variable — don't replace in spec, it would corrupt paths
          return;
        }
        if (value.isEmpty) return;
        resolvedJson = resolvedJson.replaceAll('{{$key}}', value);
        resolvedCount++;
      });
      if (resolvedCount > 0) {
        _logger.i('✓ Resolved $resolvedCount environment variables');
      }
    }

    final tempFile = File('.api2dart_temp_openapi.json');
    tempFile.writeAsStringSync(resolvedJson);

    try {
      final source = OpenApiSource();
      final tree =
          await source.parse(ApiSourceConfig(filePath: tempFile.path));

      // Extract base URL from environment or servers
      String? baseUrl;
      if (envVariables != null) {
        baseUrl = envVariables['url'] ?? envVariables['base_url'];
      }
      if (baseUrl == null || baseUrl.isEmpty) {
        try {
          final spec = jsonDecode(resolvedJson);
          final servers = spec['servers'];
          if (servers is List && servers.isNotEmpty) {
            baseUrl = servers[0]['url']?.toString();
          }
        } catch (_) {}
      }

      if (baseUrl != null && baseUrl.isNotEmpty) {
        _logger.i('✓ Base URL: $baseUrl');
      }

      _logger.i('✓ ${tree.sourceName}: ${tree.totalEndpoints} endpoints');

      // Collect URL-type variables for path resolution
      final urlVars = <String, String>{};
      if (envVariables != null) {
        envVariables.forEach((key, value) {
          if (value.startsWith('http://') || value.startsWith('https://')) {
            urlVars[key] = value;
          }
        });
      }

      return _LoadResult(
        tree: tree,
        baseUrl: baseUrl,
        token: envVariables?['token'] ?? envVariables?['mobile_token'],
        urlVariables: urlVars,
      );
    } catch (e) {
      _logger.e('Failed to parse exported spec', error: e);
      return null;
    } finally {
      if (tempFile.existsSync()) tempFile.deleteSync();
    }
  }

  // ── Step 3: Generate ───────────────────────────────────────────────

  /// Builds a PascalCase name from a clean path.
  String _nameFromCleanPath(String path, String method) {
    final segments = path
        .split('/')
        .where((s) =>
            s.isNotEmpty &&
            !RegExp(r'^\d+$').hasMatch(s) &&
            !RegExp(r'^\{.*\}$').hasMatch(s))
        .toList();

    if (segments.isEmpty) return method;

    final nameParts =
        segments.length <= 3 ? segments : segments.sublist(segments.length - 3);

    final pathName = nameParts
        .join('-')
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), ' ')
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase() + s.substring(1))
        .join();

    return pathName;
  }

  /// Resolves the actual base URL for an endpoint.
  /// Some endpoints use URL variables as path prefixes
  /// (e.g. path "/system_user_url/login" where system_user_url is a variable
  /// pointing to "https://host/api/v1/system-user").
  String _resolveBaseUrl(
      ApiEndpoint endpoint, String defaultBaseUrl, Map<String, String> urlVars) {
    if (urlVars.isEmpty) return defaultBaseUrl;

    final path = endpoint.path;
    // Check if the first path segment matches a URL variable name
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty && urlVars.containsKey(segments[0])) {
      return urlVars[segments[0]]!;
    }

    return defaultBaseUrl;
  }

  /// Gets the clean path for an endpoint, removing URL variable prefixes.
  String _resolveEndpointPath(ApiEndpoint endpoint, Map<String, String> urlVars) {
    if (urlVars.isEmpty) return endpoint.path;

    final segments = endpoint.path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty && urlVars.containsKey(segments[0])) {
      // Remove the URL variable prefix from the path
      return '/${segments.sublist(1).join('/')}';
    }

    return endpoint.path;
  }

  Future<void> _step3Generate({
    required List<ApiEndpoint> endpoints,
    required String baseUrl,
    String? token,
    Map<String, String> urlVariables = const {},
  }) async {
    final generateAction = PubspecInspector.hasApiRequestDependency();
    final outputDir = generateAction ? 'lib/actions' : 'lib/models';
    if (generateAction) {
      _logger.i('Detected `api_request` package → '
          'generating actions + responses in $outputDir');
    } else {
      _logger.i('No `api_request` package detected → '
          'generating response-only models in $outputDir');
    }

    final httpClient = ApiHttpClient(logger: _logger);
    final resolver = ResponseResolver(httpClient: httpClient);
    final emitter = CodeEmitter(logger: _logger);

    final endpointResponses = <ApiEndpoint, ResponseDefinition?>{};

    for (final endpoint in endpoints) {
      // Resolve the correct base URL and clean path for this endpoint
      final resolvedBaseUrl = _resolveBaseUrl(endpoint, baseUrl, urlVariables);
      final cleanPath = _resolveEndpointPath(endpoint, urlVariables);

      // Rebuild name from clean path if the path changed
      final name = cleanPath != endpoint.path
          ? _nameFromCleanPath(cleanPath, endpoint.method.name)
          : endpoint.name;

      // Create endpoint with clean path for code generation
      final cleanEndpoint = ApiEndpoint(
        name: name,
        path: cleanPath,
        method: endpoint.method,
        description: endpoint.description,
        body: endpoint.body,
        headers: endpoint.headers,
        queryParams: endpoint.queryParams,
        auth: endpoint.auth,
        response: endpoint.response,
      );

      ResolveResult result;
      try {
        result = await resolver.resolve(
          cleanEndpoint,
          baseUrl: resolvedBaseUrl,
          token: token,
        );
      } catch (e) {
        result = ResolveResult(response: ResponseDefinition.empty);
      }

      // Write log file for every request
      final logFileName = cleanEndpoint.fileName.replaceAll('.dart', '');
      if (result.log != null) {
        result.log!.writeToFile(outputDir, logFileName);
      }

      // Check if request failed (has log with non-success status)
      if (result.log != null &&
          result.log!.statusCode != null &&
          (result.log!.statusCode! < 200 || result.log!.statusCode! >= 300)) {
        final logPath = '${Directory.current.path}/$outputDir/logs/$logFileName.log';
        final link = TerminalUtils.fileLink(logPath, label: 'logs/$logFileName.log');
        _logger.e(
            '✗ ${cleanEndpoint.name} (${result.log!.statusCode}) → $link');
        continue; // Skip generating action for failed requests
      }

      endpointResponses[cleanEndpoint] = result.response;
    }

    final generated = emitter.emitBatch(
      endpointResponses: endpointResponses,
      outputDir: outputDir,
      generateAction: generateAction,
    );

    final failed = endpoints.length - generated;
    stdout.writeln('');
    _logger.i(
        '✅ Done! Generated $generated files${failed > 0 ? ', $failed failed' : ''} in $outputDir');
  }
}

class _LoadResult {
  final EndpointTree tree;
  final String? baseUrl;
  final String? token;
  final Map<String, String> urlVariables;

  _LoadResult({
    required this.tree,
    this.baseUrl,
    this.token,
    this.urlVariables = const {},
  });
}
