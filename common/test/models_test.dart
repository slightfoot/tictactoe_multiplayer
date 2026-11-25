import 'dart:convert';

import 'package:common/common.dart';
import 'package:test/test.dart';

void main() {
  group('Extension IDs', () {
    test('CommandId, SessionId, and PlayerId wrap underlying values', () {
      expect(CommandId('cmd-1').value, 'cmd-1');
      expect(SessionId('sess-1').value, 'sess-1');
      expect(PlayerId('player-1').value, 'player-1');

      final randomA = CommandId.random;
      final randomB = CommandId.random;
      expect(randomA.value, isNotEmpty);
      expect(randomA.value, isNot(equals(randomB.value)));
    });
  });

  group('SessionState', () {
    test('roundtrips all enum states through JSON and toString', () {
      for (final state in SessionState.values) {
        expect(state.toString(), state.value);
        expect(state.toJson(), state.value);
        expect(SessionState.fromJson(state.toJson()), state);
      }
    });

    test('throws StateError for unknown state value', () {
      expect(() => SessionState.fromJson('invalid'), throwsStateError);
    });
  });

  group('GamePlayer & GameSession', () {
    test('GamePlayer roundtrips through JSON', () {
      final player = GamePlayer(id: PlayerId('p1'), name: 'Alice', icon: 0x1F600);
      final decoded = json.decode(json.encode(player.toJson())) as Map<String, Object?>;
      final restored = GamePlayer.fromJson(decoded);

      expect(restored.id, player.id);
      expect(restored.name, 'Alice');
      expect(restored.icon, 0x1F600);
    });

    test('GameSession copyWith and JSON roundtrip preserve and override fields', () {
      final p1 = GamePlayer(id: PlayerId('p1'), name: 'Alice', icon: 1);
      final p2 = GamePlayer(id: PlayerId('p2'), name: 'Bob', icon: 2);
      final session = GameSession(
        id: SessionId('s1'),
        owner: p1.id,
        players: [p1],
        state: SessionState.waiting,
      );

      final unchanged = session.copyWith();
      expect(unchanged.id, session.id);
      expect(unchanged.owner, session.owner);
      expect(unchanged.players, session.players);
      expect(unchanged.state, SessionState.waiting);

      final updated = session.copyWith(
        id: SessionId('s2'),
        owner: p2.id,
        players: [p1, p2],
        state: SessionState.playing,
      );
      final decoded = json.decode(json.encode(updated.toJson())) as Map<String, Object?>;
      final restored = GameSession.fromJson(decoded);

      expect(restored.id, SessionId('s2'));
      expect(restored.owner, p2.id);
      expect(restored.players, hasLength(2));
      expect(restored.players.last.name, 'Bob');
      expect(restored.state, SessionState.playing);
    });
  });

  group('GameBoard', () {
    test('empty initializes independent zeroed rows and supports get/set/JSON', () {
      final board = GameBoard.empty(3, 3);
      board.set(0, 1, 7);
      expect(board.get(0, 1), 7);
      expect(board.get(1, 1), 0);

      final decoded = json.decode(json.encode(board.toJson())) as Map<String, Object?>;
      final restored = GameBoard.fromJson(decoded);
      expect(restored.rows, 3);
      expect(restored.cols, 3);
      expect(restored.get(0, 1), 7);
      expect(restored.get(2, 2), 0);
    });

    test('checkWinner returns null on empty or incomplete boards', () {
      final board = GameBoard.empty(3, 3);
      expect(board.checkWinner(), isNull);

      board.set(0, 0, 1);
      board.set(0, 1, 2);
      board.set(0, 2, 1);
      expect(board.checkWinner(), isNull);
    });

    test('checkWinner detects row, column, main diagonal, and anti-diagonal wins', () {
      final rowBoard = GameBoard.empty(3, 3);
      for (var col = 0; col < 3; col++) {
        rowBoard.set(2, col, 11);
      }
      expect(rowBoard.checkWinner(), 11);

      final colBoard = GameBoard.empty(3, 3);
      for (var row = 0; row < 3; row++) {
        colBoard.set(row, 1, 22);
      }
      expect(colBoard.checkWinner(), 22);

      final mainDiag = GameBoard.empty(3, 3);
      for (var i = 0; i < 3; i++) {
        mainDiag.set(i, i, 33);
      }
      expect(mainDiag.checkWinner(), 33);

      final antiDiag = GameBoard.empty(3, 3);
      for (var i = 0; i < 3; i++) {
        antiDiag.set(i, 2 - i, 44);
      }
      expect(antiDiag.checkWinner(), 44);
    });
  });
}
