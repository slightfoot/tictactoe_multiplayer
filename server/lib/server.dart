import 'dart:async';
import 'dart:io';

import 'package:common/common.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'connection.dart';

class GameServer {
  final connections = <PlayerId, GameConnection>{};
  final sessions = <GameSession>[];

  // Initialize
  Future<void> init(InternetAddress host, [int port = 8080]) async {
    // Create a router
    final router = Router()
      ..get('/', _rootHandler)
      ..get('/ws', _outerWebSocketHandler);

    // Configure a pipeline that logs requests.
    final handler =
        Pipeline() //
            .addMiddleware(logRequests())
            .addHandler(router.call);

    // Start the server
    final server = await serve(
      handler,
      host,
      port,
      shared: true,
      poweredByHeader: null,
    );

    print('GameServer listening: ${server.port}');
  }

  Response _rootHandler(Request request) {
    return Response.ok('Server v1.0');
  }

  FutureOr<Response> _outerWebSocketHandler(Request request) {
    final rawPlayerId = request.headers['x-player-id'];
    if (rawPlayerId == null) {
      return Response.badRequest(body: 'Missing player id');
    }
    final playerId = PlayerId(rawPlayerId);
    return webSocketHandler(
      (WebSocketChannel webSocket, String? subprotocol) {
        print('WebSocket connection: $subprotocol from $playerId');
        if (subprotocol != 'game.v1') {
          throw Exception('Unsupported protocol: $subprotocol');
        }
        final connection = GameConnection(playerId, webSocket);
        if (connections[playerId] case final oldConnection?) {
          print('Player already connected: $playerId, closing old connection');
          oldConnection.close();
        }
        connections[playerId] = connection;
        unawaited(connection.run());
      },
      protocols: ['game.v1'],
      pingInterval: const Duration(seconds: 30),
    )(request);
  }
}
