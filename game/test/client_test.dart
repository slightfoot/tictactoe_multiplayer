import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:common/common.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/game/client.dart';

void main() {
  late HttpServer httpServer;
  late StreamController<WebSocket> serverSockets;
  late StreamIterator<WebSocket> socketIterator;

  setUpAll(() {
    HttpOverrides.global = null;
  });

  setUp(() async {
    serverSockets = StreamController<WebSocket>();
    socketIterator = StreamIterator<WebSocket>(serverSockets.stream);
    httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    httpServer.listen((request) async {
      final ws = await WebSocketTransformer.upgrade(
        request,
        protocolSelector: (_) => 'game.v1',
      );
      serverSockets.add(ws);
    });
  });

  tearDown(() async {
    await socketIterator.cancel();
    await serverSockets.close();
    await httpServer.close(force: true);
  });

  Future<(GameClient, WebSocket, StreamQueueLike)> connectClient() async {
    final uri = Uri.parse('ws://127.0.0.1:${httpServer.port}/ws');
    final client = GameClient(uri);
    await socketIterator.moveNext();
    final serverWs = socketIterator.current;
    final incoming = StreamQueueLike(serverWs);
    return (client, serverWs, incoming);
  }

  void sendDto(WebSocket ws, DataTransferObject dto) {
    ws.add(json.encode(dto.toJson()));
  }

  Future<void> pumpEventQueueTicks() => Future<void>.delayed(const Duration(milliseconds: 20));

  test('createSession, events, turns, winner, and command responses update client state', () async {
    final (client, serverWs, incoming) = await connectClient();
    var notifications = 0;
    client.addListener(() => notifications++);

    // Ignore non-String frames, uncorrelated responses, and unhandled command DTOs safely
    client.createRandomPlayer();
    serverWs.add(<int>[1, 2, 3]);
    sendDto(serverWs, CreateSessionResponse(CommandId('orphan-session-resp'), SessionId('s-none')));
    sendDto(serverWs, CommandResponse.success(CommandId('orphan-cmd-resp')));
    sendDto(
      serverWs,
      CreateSessionRequest(
        CommandId('unexpected-req'),
        GamePlayer(id: PlayerId('p-x'), name: 'X', icon: 1),
      ),
    );
    await pumpEventQueueTicks();

    // After orphan CreateSessionResponse without _player, reset fresh client below; verify no crash
    await serverWs.close();

    final (freshClient, freshWs, freshIncoming) = await connectClient();
    notifications = 0;
    freshClient.addListener(() => notifications++);

    // Precondition checks before joining a session
    await expectLater(freshClient.startSession(), throwsException);
    await expectLater(freshClient.playTurn(0, 0), throwsException);

    freshClient.createRandomPlayer();
    final createFuture = freshClient.createSession();
    final createRaw = json.decode(await freshIncoming.nextString()) as Map<String, Object?>;
    final createReq = DataTransferObject.fromJson(createRaw) as CreateSessionRequest;

    final sessionId = SessionId('session-1');
    sendDto(freshWs, CreateSessionResponse(createReq.id, sessionId));
    await createFuture;
    expect(freshClient.state, SessionState.waiting);
    expect(freshClient.session.id, sessionId);
    expect(notifications, 1);

    // Precondition checks while already in a session
    await expectLater(freshClient.createSession(), throwsException);
    await expectLater(freshClient.joinSession(sessionId), throwsException);

    // Uncorrelated CommandResponse and unhandled request DTO do not throw
    sendDto(freshWs, CommandResponse.success(CommandId('untracked')));
    sendDto(freshWs, StartSessionRequest(CommandId('unhandled-req'), sessionId));

    // Self join event is ignored; peer join event adds player
    sendDto(
      freshWs,
      PlayerJoinedSessionEvent(
        sessionId,
        GamePlayer(id: freshClient.playerId, name: 'Self', icon: 10),
      ),
    );
    final rival = GamePlayer(id: PlayerId('p-rival'), name: 'Rival', icon: 99);
    sendDto(freshWs, PlayerJoinedSessionEvent(sessionId, rival));
    await pumpEventQueueTicks();
    expect(freshClient.session.players, hasLength(2));
    expect(notifications, 2);

    // Start session response
    final startFuture = freshClient.startSession();
    final startRaw = json.decode(await freshIncoming.nextString()) as Map<String, Object?>;
    final startReq = DataTransferObject.fromJson(startRaw) as StartSessionRequest;
    sendDto(freshWs, StartSessionResponse(startReq.id, sessionId, GameBoard.empty(5, 5)));
    await startFuture;
    expect(freshClient.state, SessionState.playing);
    expect(freshClient.board.rows, 5);

    // Play turn -> CommandResponse.success + GameTurnEvent
    final turnFuture = freshClient.playTurn(2, 3);
    final turnRaw = json.decode(await freshIncoming.nextString()) as Map<String, Object?>;
    final turnReq = DataTransferObject.fromJson(turnRaw) as GameCommandTurn;
    sendDto(freshWs, CommandResponse.success(turnReq.id));
    await turnFuture;

    sendDto(freshWs, GameTurnEvent(sessionId, rival.id, 2, 3));
    sendDto(freshWs, GameEndedEvent(sessionId, rival));
    sendDto(freshWs, PlayerLeftSessionEvent(sessionId, rival.id));
    await pumpEventQueueTicks();

    expect(freshClient.board.get(2, 3), 99);
    expect(freshClient.state, SessionState.ended);
    expect(freshClient.winner.id, rival.id);
    expect(freshClient.session.players.map((p) => p.id), [freshClient.playerId]);

    // CommandResponse.error rejects pending command future
    final failingTurn = freshClient.playTurn(0, 0);
    final failRaw = json.decode(await freshIncoming.nextString()) as Map<String, Object?>;
    final failReq = DataTransferObject.fromJson(failRaw) as GameCommandTurn;
    sendDto(freshWs, CommandResponse.error(failReq.id, 'Invalid move'));
    await expectLater(failingTurn, throwsException);

    await freshWs.close();
  });

  test(
    'joinSession, non-owner startSession guard, and GameStartedEvent transition guest client',
    () async {
      final (client, serverWs, incoming) = await connectClient();
      final guest = GamePlayer(id: client.playerId, name: 'Guest', icon: 42);
      client.setPlayer(guest);

      final sessionId = SessionId('session-2');
      final joinFuture = client.joinSession(sessionId);
      final joinRaw = json.decode(await incoming.nextString()) as Map<String, Object?>;
      final joinReq = DataTransferObject.fromJson(joinRaw) as JoinSessionRequest;

      final session = GameSession(
        id: sessionId,
        owner: PlayerId('owner-1'),
        players: [guest],
        state: SessionState.waiting,
      );
      sendDto(serverWs, JoinSessionResponse(joinReq.id, session, GameBoard.empty(5, 5)));
      await joinFuture;
      expect(client.state, SessionState.waiting);

      // Non-owner cannot start session
      await expectLater(client.startSession(), throwsException);

      sendDto(serverWs, GameStartedEvent(sessionId));
      await pumpEventQueueTicks();
      expect(client.state, SessionState.playing);

      await serverWs.close();
    },
  );
}

class StreamQueueLike {
  StreamQueueLike(Stream<dynamic> stream) : _iterator = StreamIterator<dynamic>(stream);

  final StreamIterator<dynamic> _iterator;

  Future<String> nextString() async {
    final hasNext = await _iterator.moveNext();
    if (!hasNext) {
      throw StateError('Stream closed unexpectedly');
    }
    return _iterator.current as String;
  }
}
