import 'dart:async';
import 'dart:io';

import 'package:common/common.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'connection.dart';
import 'models.dart';

class GameServer {
  final connections = <PlayerId, GameConnection>{};
  final sessions = <SessionId, GameSession>{};
  final games = <SessionId, GameBoard>{};

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
    final rawPlayerId = request.requestedUri.queryParameters['id'];
    if (rawPlayerId == null) {
      return Response.badRequest(body: 'Missing player id');
    }
    final playerId = PlayerId(rawPlayerId);
    return webSocketHandler(
      (WebSocketChannel webSocket, String? subprotocol) async {
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
        await connection.run(onDtoReceived);
        connections.remove(playerId);
        sendLeaveEvent(playerId);
        print('WebSocket connection closed: $playerId');
      },
      protocols: ['game.v1'],
      pingInterval: const Duration(seconds: 30),
    )(request);
  }

  GameConnection? connectionForPlayer(PlayerId playerId) {
    return connections[playerId];
  }

  void sendToSession(SessionId sessionId, DataTransferObject event) {
    final session = sessions[sessionId];
    if (session == null) {
      throw Exception('Session not found: $sessionId');
    }
    for (final player in session.players) {
      connectionForPlayer(player.id)?.send(event);
    }
  }

  void sendLeaveEvent(PlayerId playerId) {
    for (final session in sessions.values.toList()) {
      if (session.players.any((p) => p.id == playerId)) {
        sendToSession(
          session.id,
          PlayerLeftSessionEvent(session.id, playerId),
        );
        sessions[session.id] = session.copyWith(
          players: session.players.where((p) => p.id != playerId).toList(),
        );
      }
    }
  }

  Future<void> onDtoReceived(GameConnection connection, DataTransferObject dto) async {
    if (dto is! DtoCommand) {
      return;
    }
    try {
      switch (dto) {
        case SessionCommand():
          switch (dto) {
            case CreateSessionRequest(:final id, :final player):
              print('CreateSessionRequest: $dto');
              if (player.id != connection.playerId) {
                throw ProtocolException('Player id mismatch');
              }
              final session = GameSession(
                id: SessionId(Uuid().v4()),
                owner: connection.playerId,
                players: [player],
                state: SessionState.waiting,
              );
              sessions[session.id] = session;
              games[session.id] = GameBoard.empty(5, 5);
              connection.send(CreateSessionResponse(id, session.id));
            case JoinSessionRequest(:final id, :final player):
              print('JoinSessionRequest: $dto');
              final session = sessions[dto.sessionId];
              if (session == null) {
                throw ProtocolException('Session not found');
              }
              // if (session.state != SessionState.waiting) {
              //   throw ProtocolException('Session is not waiting');
              // }
              if (player.id != connection.playerId) {
                throw ProtocolException('Player id mismatch');
              }
              session.players.add(dto.player);
              final game = games[session.id]!;
              connection.send(JoinSessionResponse(id, session, game));
              sendToSession(
                session.id,
                PlayerJoinedSessionEvent(session.id, dto.player),
              );
            case StartSessionRequest(:final id):
              print('StartSessionRequest: $dto');
              final session = sessions[dto.sessionId];
              if (session == null) {
                throw ProtocolException('Session not found');
              }
              if (session.owner != connection.playerId) {
                throw ProtocolException('Player is not the owner');
              }
              sessions[session.id] = session.copyWith(state: SessionState.playing);
              sendToSession(
                session.id,
                GameStartedEvent(session.id),
              );
              final game = games[session.id]!;
              connection.send(StartSessionResponse(id, session.id, game));
            default:
              throw UnsupportedError('SessionCommand: ${dto.type} not supported');
          }

        case GameCommand():
          switch (dto) {
            case GameCommandTurn():
              print('GameCommandTurn: $dto');
              final session = sessions[dto.sessionId];
              if (session == null) {
                throw ProtocolException('Session not found');
              }
              final game = games[session.id]!;
              final player = session.players.firstWhere(
                (player) => player.id == connection.playerId,
              );
              game.set(dto.row, dto.col, player.icon);
              connection.send(CommandResponse.success(dto.id));
              sendToSession(
                session.id,
                GameTurnEvent(session.id, player.id, dto.row, dto.col),
              );
              final icon = game.checkWinner();
              if (icon != null) {
                final winner = session.players.firstWhere(
                  (player) => player.icon == icon,
                );
                sendToSession(
                  session.id,
                  GameEndedEvent(session.id, winner),
                );
              }
          }
        default:
          throw UnsupportedError('DTO: ${dto.type} not supported');
      }
    } on ProtocolException catch (error, stackTrace) {
      print('ProtocolException: $error\n$stackTrace');
      connection.send(CommandResponse.error(dto.id, error.message));
    } catch (error, stackTrace) {
      print('Exception: $error\n$stackTrace');
      connection.send(CommandResponse.error(dto.id, 'Internal error'));
    }
  }
}
