import 'package:api_request_generator/src/cli/cli_app.dart';

void main(List<String> arguments) async {
  final app = CliApp();
  await app.run(arguments);
}
