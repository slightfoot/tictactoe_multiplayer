import 'dart:convert';

import 'package:common/common.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class GameConnection {
  GameConnection(this.playerId, this.webSocket);

  final PlayerId playerId;
  final WebSocketChannel webSocket;

  Stream<DataTransferObject> get _stream => webSocket.stream.map((message) {
    final data = json.decode(message as String);
    return DataTransferObject.fromJson(data);
  });

  Future<void> run() async {
    await for (final dto in _stream) {
      print('Received ${dto.type} from player [$playerId]');
      switch (dto) {
        case SessionCommand():
          switch (dto) {
            case CreateSessionRequest(:final id):
              print('CreateSessionRequest: $dto');
              send(
                CreateSessionResponse(
                  id,
                  SessionId('1'),
                ),
              );
            case JoinSessionRequest(:final id):
              print('JoinSessionRequest: $dto');
              send(
                JoinSessionResponse(
                  id,
                  GameSession(
                    SessionId('1'),
                    PlayerId('1'),
                    [],
                    SessionState.waiting,
                  ),
                  GameBoard(3, 3, [
                    [0, 1, 2],
                    [3, 4, 5],
                    [6, 7, 8],
                  ]),
                ),
              );
            default:
              throw UnsupportedError('SessionCommand: ${dto.type} not supported');
          }

        case GameCommand():
          switch (dto) {
            case GameCommandTurn():
              print('GameCommandTurn: $dto');
              send(
                GameCommandResponse(
                  dto.id,
                  true,
                  null,
                ),
              );
          }
        default:
          throw UnsupportedError('${dto.type} not supported');
      }
    }
  }

  void send(DataTransferObject message) {
    webSocket.sink.add(json.encode(message.toJson()));
  }

  void close() {
    webSocket.sink.close();
  }
}
