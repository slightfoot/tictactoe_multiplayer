import 'dart:io';

import 'package:server/server.dart';

void main(List<String> args) async {
  final server = GameServer();
  // For running in containers, we respect the PORT environment variable.
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  // Use any (all available interfaces)
  await server.init(InternetAddress.anyIPv4, port);
}
