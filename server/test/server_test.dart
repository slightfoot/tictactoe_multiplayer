import 'package:common/common.dart';
import 'package:server/connection.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _RecordingConnection implements GameConnection {
  _RecordingConnection(this.playerId);

  @override
  final PlayerId playerId;

  final List<DataTransferObject> sent = [];

  @override
  WebSocketChannel get webSocket => throw UnimplementedError();

  @override
  void send(DataTransferObject message) => sent.add(message);

  @override
  void close() {}

  @override
  Future<void> run(GameEventHandler handler) async {}
}

void main() {
  late GameServer server;
  late GamePlayer hostPlayer;
  late GamePlayer guestPlayer;
  late _RecordingConnection hostConn;
  late _RecordingConnection guestConn;

  setUp(() {
    server = GameServer();
    hostPlayer = GamePlayer(id: PlayerId('p-host'), name: 'Host', icon: 1);
    guestPlayer = GamePlayer(id: PlayerId('p-guest'), name: 'Guest', icon: 2);
    hostConn = _RecordingConnection(hostPlayer.id);
    guestConn = _RecordingConnection(guestPlayer.id);
    server.connections[hostPlayer.id] = hostConn;
    server.connections[guestPlayer.id] = guestConn;
  });

  Future<SessionId> createSession() async {
    await server.onDtoReceived(
      hostConn,
      CreateSessionRequest(CommandId('cmd-create'), hostPlayer),
    );
    final response = hostConn.sent.single as CreateSessionResponse;
    hostConn.sent.clear();
    return response.sessionId;
  }

  test('ignores non-command DTOs', () async {
    await server.onDtoReceived(hostConn, GameStartedEvent(SessionId('s1')));
    expect(hostConn.sent, isEmpty);
  });

  test('CreateSessionRequest creates waiting session or rejects mismatched player', () async {
    await server.onDtoReceived(
      hostConn,
      CreateSessionRequest(CommandId('cmd-bad'), guestPlayer),
    );
    final err = hostConn.sent.single as CommandResponse;
    expect(err.success, isFalse);
    expect(err.error, 'Player id mismatch');
    hostConn.sent.clear();

    final sessionId = await createSession();
    expect(server.sessions[sessionId]?.state, SessionState.waiting);
    expect(server.sessions[sessionId]?.owner, hostPlayer.id);
    expect(server.games[sessionId]?.rows, 5);
  });

  test('JoinSessionRequest validates session and player, then broadcasts join', () async {
    await server.onDtoReceived(
      guestConn,
      JoinSessionRequest(CommandId('cmd-missing'), SessionId('missing'), guestPlayer),
    );
    expect((guestConn.sent.removeLast() as CommandResponse).error, 'Session not found');

    final sessionId = await createSession();

    await server.onDtoReceived(
      guestConn,
      JoinSessionRequest(CommandId('cmd-mismatch'), sessionId, hostPlayer),
    );
    expect((guestConn.sent.removeLast() as CommandResponse).error, 'Player id mismatch');

    await server.onDtoReceived(
      guestConn,
      JoinSessionRequest(CommandId('cmd-join'), sessionId, guestPlayer),
    );
    expect(guestConn.sent.first, isA<JoinSessionResponse>());
    expect(guestConn.sent.last, isA<PlayerJoinedSessionEvent>());
    expect(hostConn.sent.single, isA<PlayerJoinedSessionEvent>());
  });

  test('StartSessionRequest enforces session existence and ownership', () async {
    await server.onDtoReceived(
      hostConn,
      StartSessionRequest(CommandId('cmd-missing'), SessionId('missing')),
    );
    expect((hostConn.sent.removeLast() as CommandResponse).error, 'Session not found');

    final sessionId = await createSession();

    await server.onDtoReceived(
      guestConn,
      StartSessionRequest(CommandId('cmd-not-owner'), sessionId),
    );
    expect((guestConn.sent.removeLast() as CommandResponse).error, 'Player is not the owner');

    await server.onDtoReceived(
      hostConn,
      StartSessionRequest(CommandId('cmd-start'), sessionId),
    );
    expect(server.sessions[sessionId]?.state, SessionState.playing);
    expect(hostConn.sent.first, isA<GameStartedEvent>());
    expect(hostConn.sent.last, isA<StartSessionResponse>());
  });

  test('GameCommandTurn records moves, broadcasts winner, and handles errors', () async {
    await server.onDtoReceived(
      hostConn,
      GameCommandTurn(CommandId('cmd-missing'), SessionId('missing'), 0, 0),
    );
    expect((hostConn.sent.removeLast() as CommandResponse).error, 'Session not found');

    final sessionId = await createSession();

    // Non-member player triggers generic internal error boundary
    await server.onDtoReceived(
      guestConn,
      GameCommandTurn(CommandId('cmd-outsider'), sessionId, 0, 0),
    );
    expect((guestConn.sent.removeLast() as CommandResponse).error, 'Internal error');

    // Complete a 5-in-a-row along row 0
    for (var col = 0; col < 5; col++) {
      hostConn.sent.clear();
      await server.onDtoReceived(
        hostConn,
        GameCommandTurn(CommandId('turn-$col'), sessionId, 0, col),
      );
      expect(hostConn.sent.first, isA<CommandResponse>());
      expect(hostConn.sent[1], isA<GameTurnEvent>());
      if (col < 4) {
        expect(hostConn.sent, hasLength(2));
      } else {
        final ended = hostConn.sent.last as GameEndedEvent;
        expect(ended.winner?.id, hostPlayer.id);
      }
    }
  });

  test('unsupported DtoCommand (SessionResponse) returns internal error', () async {
    await server.onDtoReceived(
      hostConn,
      CreateSessionResponse(CommandId('cmd-resp'), SessionId('s1')),
    );
    final err = hostConn.sent.single as CommandResponse;
    expect(err.success, isFalse);
    expect(err.error, 'Internal error');
  });
}
