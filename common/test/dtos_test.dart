import 'dart:convert';

import 'package:common/common.dart';
import 'package:test/test.dart';

T _roundtrip<T extends DataTransferObject>(T dto) {
  final raw = json.decode(json.encode(dto.toJson())) as Map<String, Object?>;
  return DataTransferObject.fromJson(raw) as T;
}

void main() {
  final cmdId = CommandId('cmd-42');
  final sessionId = SessionId('sess-99');
  final player = GamePlayer(id: PlayerId('p-1'), name: 'Alice', icon: 0x1F604);
  final board = GameBoard.empty(3, 3)..set(1, 2, player.icon);
  final session = GameSession(
    id: sessionId,
    owner: player.id,
    players: [player],
    state: SessionState.waiting,
  );

  group('DtoType', () {
    test('resolves all known wire values and rejects unknown types', () {
      for (final dtoType in DtoType.values) {
        expect(dtoType.toString(), dtoType.value);
        expect(dtoType.toJson(), dtoType.value);
        expect(DtoType.fromValue(dtoType.value), dtoType);
      }
      expect(() => DtoType.fromValue('BogusDto'), throwsException);
    });
  });

  group('Session DTOs', () {
    test('CreateSessionRequest and CreateSessionResponse roundtrip', () {
      final req = _roundtrip(CreateSessionRequest(cmdId, player));
      expect(req.type, DtoType.createSessionRequest);
      expect(req.id, cmdId);
      expect(req.player.id, player.id);
      expect(req.player.name, 'Alice');

      final resp = _roundtrip(CreateSessionResponse(cmdId, sessionId));
      expect(resp.type, DtoType.createSessionResponse);
      expect(resp.id, cmdId);
      expect(resp.sessionId, sessionId);
    });

    test('JoinSessionRequest and JoinSessionResponse roundtrip', () {
      final req = _roundtrip(JoinSessionRequest(cmdId, sessionId, player));
      expect(req.type, DtoType.joinSessionRequest);
      expect(req.id, cmdId);
      expect(req.sessionId, sessionId);
      expect(req.player.icon, player.icon);

      final resp = _roundtrip(JoinSessionResponse(cmdId, session, board));
      expect(resp.type, DtoType.joinSessionResponse);
      expect(resp.id, cmdId);
      expect(resp.session.id, sessionId);
      expect(resp.board.get(1, 2), player.icon);
    });

    test('StartSessionRequest and StartSessionResponse roundtrip', () {
      final req = _roundtrip(StartSessionRequest(cmdId, sessionId));
      expect(req.type, DtoType.startSessionRequest);
      expect(req.id, cmdId);
      expect(req.sessionId, sessionId);

      final resp = _roundtrip(StartSessionResponse(cmdId, sessionId, board));
      expect(resp.type, DtoType.startSessionResponse);
      expect(resp.id, cmdId);
      expect(resp.sessionId, sessionId);
      expect(resp.board.get(1, 2), player.icon);
    });
  });

  group('Command DTOs', () {
    test('CommandResponse.success omits error and CommandResponse.error preserves error', () {
      final ok = CommandResponse.success(cmdId);
      expect(ok.toJson().containsKey('error'), isFalse);
      final restoredOk = _roundtrip(ok);
      expect(restoredOk.type, DtoType.commandResponse);
      expect(restoredOk.id, cmdId);
      expect(restoredOk.success, isTrue);
      expect(restoredOk.error, isNull);

      final err = _roundtrip(CommandResponse.error(cmdId, 'Bad move'));
      expect(err.id, cmdId);
      expect(err.success, isFalse);
      expect(err.error, 'Bad move');
    });

    test('GameCommandTurn roundtrips coordinates and IDs', () {
      final turn = _roundtrip(GameCommandTurn(cmdId, sessionId, 2, 1));
      expect(turn.type, DtoType.gameCommandTurn);
      expect(turn.id, cmdId);
      expect(turn.sessionId, sessionId);
      expect(turn.row, 2);
      expect(turn.col, 1);
    });
  });

  group('Event DTOs', () {
    test('GameStarted, PlayerJoined, PlayerLeft, and GameTurn events roundtrip', () {
      final started = _roundtrip(GameStartedEvent(sessionId));
      expect(started.type, DtoType.gameStartedEvent);
      expect(started.sessionId, sessionId);

      final joined = _roundtrip(PlayerJoinedSessionEvent(sessionId, player));
      expect(joined.type, DtoType.playerJoinedSessionEvent);
      expect(joined.sessionId, sessionId);
      expect(joined.player.id, player.id);

      final left = _roundtrip(PlayerLeftSessionEvent(sessionId, player.id));
      expect(left.type, DtoType.playerLeftSessionEvent);
      expect(left.sessionId, sessionId);
      expect(left.playerId, player.id);

      final turn = _roundtrip(GameTurnEvent(sessionId, player.id, 0, 2));
      expect(turn.type, DtoType.gameTurnEvent);
      expect(turn.sessionId, sessionId);
      expect(turn.playerId, player.id);
      expect(turn.row, 0);
      expect(turn.col, 2);
    });

    test('GameEndedEvent roundtrips both with winner and with null winner', () {
      final withWinner = _roundtrip(GameEndedEvent(sessionId, player));
      expect(withWinner.type, DtoType.gameEndedEvent);
      expect(withWinner.sessionId, sessionId);
      expect(withWinner.winner?.id, player.id);

      final draw = GameEndedEvent(sessionId, null);
      expect(draw.toJson().containsKey('winner'), isFalse);
      final restoredDraw = _roundtrip(draw);
      expect(restoredDraw.sessionId, sessionId);
      expect(restoredDraw.winner, isNull);
    });
  });
}
