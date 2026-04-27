import 'package:api_to_dart/src/cli/cli_app.dart';

void main(List<String> arguments) async {
  final app = CliApp();
  await app.run(arguments);
}
