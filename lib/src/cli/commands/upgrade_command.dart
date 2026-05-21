import 'dart:io';

import 'package:args/command_runner.dart';

import '../../core/logger/console_logger.dart';
import '../../core/logger/logger.dart';
import '../../core/update_checker.dart';
import '../../core/version.dart';
import '../ui/terminal_utils.dart';

class UpgradeCommand extends Command {
  UpgradeCommand() {
    argParser.addFlag('force',
        abbr: 'f',
        help: 'Run the upgrade even if already on the latest version.',
        negatable: false,
        defaultsTo: false);
  }

  @override
  String get name => 'upgrade';

  @override
  String get description =>
      'Upgrade api2dart to the latest version from pub.dev.';

  @override
  String get invocation => 'api2dart upgrade [--force]';

  @override
  Future<void> run() async {
    final Logger logger = ConsoleLogger();
    final force = argResults!['force'] as bool;

    stdout.writeln(TerminalUtils.gray('Checking pub.dev for the latest version...'));
    final latest = await UpdateChecker.fetchLatestVersion(force: true);

    if (latest == null) {
      logger.e('Could not reach pub.dev. Check your internet connection.');
      exitCode = 1;
      return;
    }

    if (!force && !UpdateChecker.isNewer(packageVersion, latest)) {
      logger.i('Already on the latest version ($packageVersion).');
      return;
    }

    stdout.writeln('');
    stdout.writeln(
        'Upgrading api2dart: ${TerminalUtils.bold(packageVersion)} → ${TerminalUtils.green(TerminalUtils.bold(latest))}');
    stdout.writeln('');

    final process = await Process.start(
      'dart',
      ['pub', 'global', 'activate', packageName],
      mode: ProcessStartMode.inheritStdio,
    );

    final code = await process.exitCode;
    if (code != 0) {
      logger.e('Upgrade failed (exit code $code). '
          'Try running manually: dart pub global activate $packageName');
      exitCode = code;
      return;
    }

    logger.i('✓ Upgraded to $latest.');
  }
}
