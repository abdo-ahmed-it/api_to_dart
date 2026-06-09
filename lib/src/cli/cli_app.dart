import 'dart:io';

import 'package:args/command_runner.dart';

import '../core/logger/console_logger.dart';
import '../core/update_checker.dart';
import '../core/version.dart';
import 'commands/generate_command.dart';
import 'commands/resend_command.dart';
import 'commands/reset_command.dart';
import 'commands/upgrade_command.dart';
import 'commands/version_command.dart';
import 'ui/terminal_utils.dart';

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
    _runner.addCommand(ResendCommand());
    _runner.addCommand(ResetCommand());
    _runner.addCommand(VersionCommand());
    _runner.addCommand(UpgradeCommand());
  }

  Future<void> run(List<String> arguments) async {
    // When invoked with no arguments, launch the interactive wizard directly
    // instead of printing usage — this is the most common entry point and
    // matches what `api2dart generate` does.
    final effectiveArgs = arguments.isEmpty ? const ['generate'] : arguments;

    // Kick off a background update check (uses daily cache). We don't await
    // it here so the command isn't blocked by a slow network — we just
    // surface the result at the end if a newer version is known.
    final updateFuture = _shouldCheckUpdates(effectiveArgs)
        ? UpdateChecker.fetchLatestVersion()
        : Future<String?>.value(null);

    try {
      await _runner.run(effectiveArgs);
    } catch (e) {
      final logger = ConsoleLogger();
      logger.e('Error: $e');
    }

    await _maybeShowUpdateNotice(updateFuture);
  }

  /// Skip the update check for commands that already handle it themselves
  /// (`version`, `upgrade`) and for `--help` flows where the noise would be
  /// awkward.
  bool _shouldCheckUpdates(List<String> arguments) {
    if (arguments.isEmpty) return true;
    final first = arguments.first;
    const skip = {
      'version',
      '--version',
      '-v',
      'upgrade',
      'help',
      '--help',
      '-h',
    };
    return !skip.contains(first);
  }

  Future<void> _maybeShowUpdateNotice(Future<String?> future) async {
    try {
      final latest = await future;
      if (latest == null) return;
      if (!UpdateChecker.isNewer(packageVersion, latest)) return;

      stdout.writeln('');
      stdout.writeln(TerminalUtils.yellow(
          '✦ Update available: $packageVersion → $latest'));
      stdout.writeln(TerminalUtils.gray(
          '  Run `api2dart upgrade` to install the new version.'));
    } catch (_) {
      // Update notice is best-effort; never let it break the command.
    }
  }
}
