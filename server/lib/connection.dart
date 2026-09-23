import 'dart:convert';

import 'package:common/common.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef GameEventHandler = Future<void> Function(GameConnection connection, DataTransferObject dto);

class GameConnection {
  GameConnection(this.playerId, this.webSocket);

  final PlayerId playerId;
  final WebSocketChannel webSocket;

  Stream<DataTransferObject> get _stream => webSocket.stream.map((message) {
    final data = json.decode(message as String);
    return DataTransferObject.fromJson(data);
  });

  Future<void> run(GameEventHandler handler) async {
    await for (final dto in _stream) {
      print('Received ${dto.type} from player [$playerId]');
      await handler(this, dto);
    }
  }

  void send(DataTransferObject message) {
    webSocket.sink.add(json.encode(message.toJson()));
  }

  void close() {
    webSocket.sink.close();
  }
}
