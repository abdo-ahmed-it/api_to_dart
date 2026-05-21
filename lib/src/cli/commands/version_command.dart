import 'dart:io';

import 'package:args/command_runner.dart';

import '../../core/update_checker.dart';
import '../../core/version.dart';
import '../ui/terminal_utils.dart';

class VersionCommand extends Command {
  @override
  String get name => 'version';

  @override
  String get description =>
      'Show the installed api2dart version and check for updates.';

  @override
  String get invocation => 'api2dart version';

  @override
  List<String> get aliases => const ['--version', '-v'];

  @override
  Future<void> run() async {
    stdout.writeln('api2dart ${TerminalUtils.bold(packageVersion)}');
    stdout.writeln(TerminalUtils.gray('package: $packageName'));

    final latest = await UpdateChecker.fetchLatestVersion(force: true);
    if (latest == null) {
      stdout.writeln(TerminalUtils.gray(
          'Could not reach pub.dev to check for updates.'));
      return;
    }

    if (UpdateChecker.isNewer(packageVersion, latest)) {
      stdout.writeln('');
      stdout.writeln(TerminalUtils.yellow(
          '✦ A new version is available: $packageVersion → $latest'));
      stdout.writeln(TerminalUtils.gray(
          '  Run `api2dart upgrade` to update.'));
    } else {
      stdout
          .writeln(TerminalUtils.green('✓ You are on the latest version.'));
    }
  }
}
