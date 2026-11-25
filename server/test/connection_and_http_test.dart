import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:common/common.dart';
import 'package:http/http.dart' as http;
import 'package:server/connection.dart';
import 'package:server/models.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _InMemoryWebSocketChannel implements WebSocketChannel {
  final inbound = StreamController<dynamic>();
  final outbound = StreamController<dynamic>();

  @override
  Stream<dynamic> get stream => inbound.stream;

  @override
  WebSocketSink get sink => _InMemoryWebSocketSink(outbound.sink);

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => 'game.v1';

  @override
  Future<void> get ready => Future<void>.value();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _InMemoryWebSocketSink implements WebSocketSink {
  _InMemoryWebSocketSink(this._inner);

  final StreamSink<dynamic> _inner;

  @override
  void add(dynamic data) => _inner.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) => _inner.addError(error, stackTrace);

  @override
  Future<dynamic> addStream(Stream<dynamic> stream) => _inner.addStream(stream);

  @override
  Future<dynamic> close([int? closeCode, String? closeReason]) => _inner.close();

  @override
  Future<dynamic> get done => _inner.done;
}

Future<int> _allocateFreePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

void main() {
  test('ProtocolException formats message cleanly', () {
    const exception = ProtocolException('Invalid session');
    expect(exception.message, 'Invalid session');
    expect(exception.toString(), 'ProtocolException: Invalid session');
  });

  test(
    'GameConnection decodes inbound DTO stream, encodes outbound DTOs, and closes sink',
    () async {
      final channel = _InMemoryWebSocketChannel();
      final connection = GameConnection(PlayerId('p1'), channel);
      final received = <DataTransferObject>[];

      final runFuture = connection.run((conn, dto) async {
        expect(conn, same(connection));
        received.add(dto);
      });

      final startEvent = GameStartedEvent(SessionId('s1'));
      channel.inbound.add(json.encode(startEvent.toJson()));
      await channel.inbound.close();
      await runFuture;

      expect(received.single, isA<GameStartedEvent>());

      final outboundFuture = channel.outbound.stream.first;
      connection.send(CommandResponse.success(CommandId('c1')));
      final encoded = await outboundFuture as String;
      final decoded = DataTransferObject.fromJson(json.decode(encoded) as Map<String, Object?>);
      expect(decoded, isA<CommandResponse>());

      connection.close();
      await expectLater(channel.outbound.done, completes);
    },
  );

  test('sendToSession throws when session is missing', () {
    final server = GameServer();
    expect(
      () => server.sendToSession(SessionId('missing'), GameStartedEvent(SessionId('missing'))),
      throwsException,
    );
  });

  group('GameServer HTTP & WebSocket lifecycle', () {
    late GameServer server;
    late int port;

    setUpAll(() async {
      port = await _allocateFreePort();
      server = GameServer();
      await server.init(InternetAddress.loopbackIPv4, port);
    });

    test('GET / returns server banner and GET /ws without id returns 400', () async {
      final rootResp = await http.get(Uri.parse('http://127.0.0.1:$port/'));
      expect(rootResp.statusCode, 200);
      expect(rootResp.body, 'Server v1.0');

      final badWsResp = await http.get(Uri.parse('http://127.0.0.1:$port/ws'));
      expect(badWsResp.statusCode, 400);
      expect(badWsResp.body, 'Missing player id');
    });

    test(
      'WebSocket replaces duplicate player connection and broadcasts leave on disconnect',
      () async {
        final host = GamePlayer(id: PlayerId('host-1'), name: 'Host', icon: 1);
        final guest = GamePlayer(id: PlayerId('guest-1'), name: 'Guest', icon: 2);

        // First connection for host-1, soon superseded by a reconnect
        final staleHostWs = WebSocketChannel.connect(
          Uri.parse('ws://127.0.0.1:$port/ws?id=${host.id.value}'),
          protocols: ['game.v1'],
        );
        await staleHostWs.ready;
        final staleDone = staleHostWs.stream.drain<void>();

        final hostWs = WebSocketChannel.connect(
          Uri.parse('ws://127.0.0.1:$port/ws?id=${host.id.value}'),
          protocols: ['game.v1'],
        );
        await hostWs.ready;
        await expectLater(staleDone, completes);
        expect(server.connectionForPlayer(host.id), isNotNull);

        final hostIterator = StreamIterator<dynamic>(hostWs.stream);

        // Host creates session
        hostWs.sink.add(json.encode(CreateSessionRequest(CommandId('c1'), host).toJson()));
        await hostIterator.moveNext();
        final createResp =
            DataTransferObject.fromJson(
                  json.decode(hostIterator.current as String) as Map<String, Object?>,
                )
                as CreateSessionResponse;
        final sessionId = createResp.sessionId;

        // Guest connects and joins session
        final guestWs = WebSocketChannel.connect(
          Uri.parse('ws://127.0.0.1:$port/ws?id=${guest.id.value}'),
          protocols: ['game.v1'],
        );
        await guestWs.ready;
        final guestIterator = StreamIterator<dynamic>(guestWs.stream);

        guestWs.sink.add(
          json.encode(JoinSessionRequest(CommandId('c2'), sessionId, guest).toJson()),
        );
        await guestIterator.moveNext(); // JoinSessionResponse
        await hostIterator.moveNext(); // PlayerJoinedSessionEvent

        // Guest disconnects -> host receives PlayerLeftSessionEvent and guest is removed
        await guestIterator.cancel();
        await guestWs.sink.close();

        await hostIterator.moveNext();
        final leftEvent =
            DataTransferObject.fromJson(
                  json.decode(hostIterator.current as String) as Map<String, Object?>,
                )
                as PlayerLeftSessionEvent;
        expect(leftEvent.sessionId, sessionId);
        expect(leftEvent.playerId, guest.id);
        expect(server.sessions[sessionId]?.players.map((p) => p.id), [host.id]);

        await hostIterator.cancel();
        await hostWs.sink.close();
      },
    );
  });
}
