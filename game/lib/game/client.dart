import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:common/common.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_client/web_socket_client.dart';

class GameClient extends ChangeNotifier {
  factory GameClient(Uri uri) {
    final playerId = PlayerId(Uuid().v4());
    final client = GameClient._(
      playerId,
      WebSocket(
        uri.replace(queryParameters: {'id': playerId.value}),
        protocols: ['game.v1'],
      ),
    );
    client._run();
    return client;
  }

  GameClient._(
    this.playerId,
    this.webSocket,
  );

  final PlayerId playerId;
  final WebSocket webSocket;

  final _pendingCommands = <CommandId, Completer<dynamic>>{};

  GamePlayer? _player;
  GameSession? _session;
  GameBoard? _board;
  GamePlayer? _winner;

  SessionState get state => _session?.state ?? SessionState.none;

  GameSession get session => _session!;

  GameBoard get board => _board!;

  GamePlayer get winner => _winner!;

  void _run() {
    webSocket.messages.listen((message) {
      if (message is! String) {
        print('Expected string message, got $message');
        return;
      }
      final dto = DataTransferObject.fromJson(json.decode(message));
      print('Received from server: $dto');
      switch (dto) {
        case CreateSessionResponse(:final sessionId):
          _session = GameSession(
            id: sessionId,
            owner: playerId,
            players: [_player!],
            state: SessionState.waiting,
          );
          notifyListeners();
        case StartSessionResponse(:final board):
          _session = _session!.copyWith(state: SessionState.playing);
          _board = board;
          notifyListeners();
        case JoinSessionResponse(:final session, :final board):
          _session = session;
          _board = board;
          notifyListeners();
        case GameStartedEvent():
          _session = _session!.copyWith(state: SessionState.playing);
          notifyListeners();
        case PlayerJoinedSessionEvent(:final player):
          if (player.id != playerId) {
            _session = _session!.copyWith(
              players: [..._session!.players, player],
            );
            notifyListeners();
          }
        case PlayerLeftSessionEvent(:final playerId):
          _session = _session!.copyWith(
            players: _session!.players.where((p) => p.id != playerId).toList(),
          );
          notifyListeners();
        case GameTurnEvent(:final playerId, :final row, :final col):
          final player = _session!.players.firstWhere((p) => p.id == playerId);
          _board!.set(row, col, player.icon);
          notifyListeners();
        case GameEndedEvent():
          _session = _session!.copyWith(state: SessionState.ended);
          _winner = dto.winner;
          notifyListeners();
        default:
          print('Unhandled DTO: $dto');
          break;
      }
      if (dto is SessionResponse) {
        final completer = _pendingCommands.remove(dto.id);
        if (completer != null) {
          completer.complete(dto);
        }
      } else if (dto is CommandResponse) {
        final completer = _pendingCommands.remove(dto.id);
        if (completer != null) {
          if (dto.success) {
            completer.complete(dto);
          } else {
            completer.completeError(Exception(dto.error));
          }
        }
      } else {
        print('Unhandled DTO: $dto');
      }
    });
  }

  Future<T> sendCommand<T>(DtoCommand command) async {
    final completer = Completer<T>();
    _pendingCommands[command.id] = completer;
    webSocket.send(json.encode(command.toJson()));
    return await completer.future;
  }

  void createRandomPlayer() {
    // icon is a random emoji from unicode
    final icon = 0x1F600 + Random().nextInt(50);
    setPlayer(
      GamePlayer(
        id: playerId,
        name: 'Player 1',
        icon: icon,
      ),
    );
  }

  void setPlayer(GamePlayer player) {
    _player = player;
  }

  Future<void> createSession() async {
    if (_session != null) {
      throw Exception('Already in a session');
    }
    await sendCommand(CreateSessionRequest(CommandId.random, _player!));
  }

  Future<void> startSession() async {
    if (_session == null) {
      throw Exception('Not in a session');
    }
    if (_session!.owner != playerId) {
      throw Exception('Not the owner');
    }
    await sendCommand(StartSessionRequest(CommandId.random, _session!.id));
  }

  Future<void> joinSession(SessionId sessionId) async {
    if (_session != null) {
      throw Exception('Already in a session');
    }
    await sendCommand(JoinSessionRequest(CommandId.random, sessionId, _player!));
  }

  Future<void> playTurn(int row, int col) async {
    if (_session == null) {
      throw Exception('Not in a session');
    }
    await sendCommand(GameCommandTurn(CommandId.random, _session!.id, row, col));
  }
}
