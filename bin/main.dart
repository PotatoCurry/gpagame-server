import 'package:gpagame/gpagame.dart';

Future main() async {
  final app = Application<GpagameChannel>()
      ..options.configurationFilePath = "config.yaml"
      ..options.port = 8888;

  hierarchicalLoggingEnabled = true;
  // final count = Platform.numberOfProcessors ~/ 2;
  // await app.start(numberOfInstances: count > 0 ? count : 1);
  // We don't need multiple isolates, one makes websockets easier to work with
  await app.start(numberOfInstances: 1);

  print("Application started on port: ${app.options.port}.");
  print("Use Ctrl-C (SIGINT) to stop running the application.");
}
