import 'package:args/command_runner.dart';

import '../core/logger/console_logger.dart';
import 'commands/generate_command.dart';

class CliApp {
  final CommandRunner _runner;

  CliApp()
      : _runner = CommandRunner(
          'apigen',
          'Generate API request actions from Postman, OpenAPI, Apidog, or YAML',
        ) {
    _runner.addCommand(GenerateCommand());
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
