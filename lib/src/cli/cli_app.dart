import 'package:args/command_runner.dart';

import '../core/logger/console_logger.dart';
import 'commands/generate_command.dart';
import 'commands/reset_command.dart';

class CliApp {
  final CommandRunner _runner;

  CliApp()
      : _runner = CommandRunner(
          'api2dart',
          'Convert any API (Postman, OpenAPI, Apidog, or YAML) into '
              'type-safe Dart actions and response models.\n\n'
              'Run `api2dart generate` with no flags to launch the interactive '
              'wizard, or pass `-c <file>` to run non-interactively.',
        ) {
    _runner.addCommand(GenerateCommand());
    _runner.addCommand(ResetCommand());
  }

  Future<void> run(List<String> arguments) async {
    try {
      await _runner.run(arguments);
    } catch (e) {
      final logger = ConsoleLogger();
      logger.e('Error: $e');
    }
  }
}
