import 'dart:io';

import 'package:args/command_runner.dart';

import '../../core/generation/code_emitter.dart';
import '../../core/logger/console_logger.dart';
import '../../core/logger/logger.dart';
import '../../core/models/api_endpoint.dart';
import '../../core/models/api_source_config.dart';
import '../../core/models/endpoint_tree.dart';
import '../../core/models/response_definition.dart';
import '../../core/resolution/http_client.dart';
import '../../core/resolution/response_resolver.dart';
import '../../core/sources/api_source.dart';
import '../../core/sources/apidog_source.dart';
import '../../core/sources/local_file_source.dart';
import '../../core/sources/openapi_source.dart';
import '../../core/sources/postman_source.dart';
import '../ui/endpoint_selector.dart';
import '../wizard/generate_wizard.dart';

class GenerateCommand extends Command {
  GenerateCommand() {
    argParser
      ..addOption('source',
          abbr: 's',
          help: 'Source type',
          allowed: ['postman', 'openapi', 'apidog', 'file'])
      ..addOption('config',
          abbr: 'c', help: 'Path to the config/collection file')
      ..addOption('output',
          abbr: 'o',
          help: 'Output directory',
          defaultsTo: 'lib/actions')
      ..addOption('base-url',
          abbr: 'b', help: 'Base URL for the API')
      ..addOption('token',
          abbr: 't', help: 'Authentication token')
      ..addFlag('no-interactive',
          help: 'Skip interactive selector, generate all endpoints',
          negatable: false,
          defaultsTo: false)
      ..addFlag('dry-run',
          help: 'Show what would be generated without writing files',
          negatable: false,
          defaultsTo: false)
      ..addFlag('reset',
          help: 'Reset saved settings and start fresh',
          negatable: false,
          defaultsTo: false);
  }

  @override
  String get description =>
      'Generate API request actions from a collection or spec';

  @override
  String get name => 'generate';

  @override
  void run() async {
    final configPath = argResults!['config'] as String?;
    final resetFlag = argResults!['reset'] as bool;

    // If no config provided, launch interactive wizard
    if (configPath == null || configPath.isEmpty) {
      final wizard = GenerateWizard(reset: resetFlag);
      await wizard.run();
      return;
    }

    // Otherwise, run with flags (non-wizard mode)
    await _runWithFlags();
  }

  Future<void> _runWithFlags() async {
    final Logger logger = ConsoleLogger();
    final sourceType = argResults!['source'] as String? ?? 'postman';
    final configPath = argResults!['config'] as String;
    final outputDir = argResults!['output'] as String;
    final baseUrl = argResults!['base-url'] as String?;
    final token = argResults!['token'] as String?;
    final noInteractive = argResults!['no-interactive'] as bool;
    final dryRun = argResults!['dry-run'] as bool;

    // 1. Select source
    final ApiSource source;
    switch (sourceType) {
      case 'postman':
        source = PostmanSource();
        break;
      case 'openapi':
        source = OpenApiSource();
        break;
      case 'apidog':
        source = ApidogSource();
        break;
      case 'file':
        source = LocalFileSource();
        break;
      default:
        logger.e('Unknown source type: $sourceType');
        exit(1);
    }

    // 2. Parse source
    logger.i('Parsing ${source.sourceName} from $configPath...');
    EndpointTree tree;
    try {
      tree = await source.parse(ApiSourceConfig(
        filePath: configPath,
        baseUrl: baseUrl,
        token: token,
        outputDir: outputDir,
      ));
    } catch (e) {
      logger.e('Failed to parse source', error: e);
      exit(1);
    }

    if (tree.isEmpty) {
      logger.w('No endpoints found in the source');
      exit(0);
    }

    logger.i(
        'Found ${tree.totalEndpoints} endpoints in "${tree.sourceName}"');

    // 3. Select endpoints
    List<ApiEndpoint> selectedEndpoints;

    if (noInteractive) {
      selectedEndpoints = tree.allEndpoints;
      logger.i('Generating all ${selectedEndpoints.length} endpoints');
    } else {
      final selector = EndpointSelector(tree);
      final selected = selector.selectInteractively();

      if (selected == null || selected.isEmpty) {
        logger.w('No endpoints selected. Exiting.');
        exit(0);
      }
      selectedEndpoints = selected;
    }

    if (dryRun) {
      logger.i('Dry run — would generate ${selectedEndpoints.length} files:');
      for (final endpoint in selectedEndpoints) {
        logger.n(
            '  ${endpoint.method.name.padRight(6)} ${endpoint.path} → $outputDir/${endpoint.fileName}');
      }
      exit(0);
    }

    // 4. Resolve responses and batch generate with deduplication
    final httpClient = ApiHttpClient(logger: logger);
    final resolver = ResponseResolver(httpClient: httpClient, logger: logger);
    final emitter = CodeEmitter(logger: logger);

    final resolvedBaseUrl = baseUrl ?? '';
    final endpointResponses = <ApiEndpoint, ResponseDefinition?>{};

    for (final endpoint in selectedEndpoints) {
      logger.i(
          'Processing ${endpoint.method.name} ${endpoint.path}...');

      ResolveResult result;
      try {
        result = await resolver.resolve(
          endpoint,
          baseUrl: resolvedBaseUrl,
          token: token,
        );
      } catch (e) {
        logger.w(
            'Failed to resolve response for ${endpoint.name}: $e');
        result = ResolveResult(response: ResponseDefinition.empty);
      }
      endpointResponses[endpoint] = result.response;

      if (result.log != null) {
        result.log!.writeToFile(outputDir, endpoint.fileName.replaceAll('.dart', ''));
      }
    }

    final generated = emitter.emitBatch(
      endpointResponses: endpointResponses,
      outputDir: outputDir,
    );

    final failed = selectedEndpoints.length - generated;
    logger.i(
        'Done! Generated $generated files${failed > 0 ? ', $failed failed' : ''} in $outputDir');
  }
}
