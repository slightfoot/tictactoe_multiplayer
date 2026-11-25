import 'package:common/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game/app/app.dart';
import 'package:game/app/home.dart';
import 'package:game/game/client.dart';
import 'package:game/main.dart' as app_entry;
import 'package:web_socket_client/web_socket_client.dart';

class _FakeGameClient extends ChangeNotifier implements GameClient {
  _FakeGameClient({
    PlayerId? playerId,
    this.currentSession,
    this.currentBoard,
    this.currentWinner,
  }) : playerId = playerId ?? PlayerId('p-host');

  @override
  final PlayerId playerId;

  GameSession? currentSession;
  GameBoard? currentBoard;
  GamePlayer? currentWinner;

  int randomPlayerCreatedCount = 0;
  int createSessionCount = 0;
  int startSessionCount = 0;
  SessionId? joinedSessionId;
  (int, int)? lastPlayedTurn;
  GamePlayer? assignedPlayer;

  @override
  WebSocket get webSocket => throw UnimplementedError();

  @override
  SessionState get state => currentSession?.state ?? SessionState.none;

  @override
  GameSession get session => currentSession!;

  @override
  GameBoard get board => currentBoard!;

  @override
  GamePlayer get winner => currentWinner!;

  @override
  void createRandomPlayer() => randomPlayerCreatedCount++;

  @override
  void setPlayer(GamePlayer player) => assignedPlayer = player;

  @override
  Future<void> createSession() async => createSessionCount++;

  @override
  Future<void> joinSession(SessionId sessionId) async => joinedSessionId = sessionId;

  @override
  Future<void> startSession() async => startSessionCount++;

  @override
  Future<void> playTurn(int row, int col) async => lastPlayedTurn = (row, col);

  @override
  Future<T> sendCommand<T>(DtoCommand command) => throw UnimplementedError();
}

void main() {
  testWidgets('main() and GameApp mount dark MaterialApp with Home -> HomePage', (tester) async {
    app_entry.main();
    await tester.pump();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(find.byType(GameApp), findsOneWidget);
    expect(materialApp.debugShowCheckedModeBanner, isFalse);
    expect(materialApp.theme?.brightness, Brightness.dark);
    expect(find.byType(Home), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);

    final homePage = tester.widget<HomePage>(find.byType(HomePage));
    homePage.client.webSocket.close();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 1, seconds: 1));
  });

  testWidgets('HomePage triggers createSession and joinSession actions', (tester) async {
    final client = _FakeGameClient();
    await tester.pumpWidget(MaterialApp(home: HomePage(client: client)));

    expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Session'));
    await tester.pump();
    expect(client.randomPlayerCreatedCount, 1);
    expect(client.createSessionCount, 1);

    await tester.enterText(find.byType(TextField), 'room-abc');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Join Session'));
    await tester.pump();
    expect(client.randomPlayerCreatedCount, 2);
    expect(client.joinedSessionId, SessionId('room-abc'));
  });

  testWidgets('GameWaitingPage shows Start Session only to owner', (tester) async {
    final host = GamePlayer(id: PlayerId('p-host'), name: 'Alice', icon: 0x1F600);
    final guest = GamePlayer(id: PlayerId('p-guest'), name: 'Bob', icon: 0x1F601);
    final session = GameSession(
      id: SessionId('sess-xyz'),
      owner: host.id,
      players: [host, guest],
      state: SessionState.waiting,
    );

    final ownerClient = _FakeGameClient(playerId: host.id, currentSession: session);
    await tester.pumpWidget(MaterialApp(home: GameWaitingPage(client: ownerClient)));

    expect(find.text('Waiting for other players...'), findsOneWidget);
    expect(find.text('Alice (\u{1F600}), Bob (\u{1F601})'), findsOneWidget);
    expect(find.text('sess-xyz'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Start Session'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Start Session'));
    await tester.pump();
    expect(ownerClient.startSessionCount, 1);

    final guestClient = _FakeGameClient(playerId: guest.id, currentSession: session);
    await tester.pumpWidget(MaterialApp(home: GameWaitingPage(client: guestClient)));
    expect(find.widgetWithText(ElevatedButton, 'Start Session'), findsNothing);
  });

  testWidgets('GamePlayingPage renders board cells and dispatches cell taps', (tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final host = GamePlayer(id: PlayerId('p-host'), name: 'Alice', icon: 0x2B50);
    final board = GameBoard.empty(3, 3)..set(1, 2, host.icon);
    final session = GameSession(
      id: SessionId('sess-play'),
      owner: host.id,
      players: [host],
      state: SessionState.playing,
    );
    final client = _FakeGameClient(
      playerId: host.id,
      currentSession: session,
      currentBoard: board,
    );

    await tester.pumpWidget(MaterialApp(home: GamePlayingPage(client: client)));

    expect(find.text('Playing'), findsOneWidget);
    expect(find.byType(GameBoardWidget), findsOneWidget);
    expect(find.byType(GameBoardCell), findsNWidgets(9));
    expect(find.text('\u{2B50}'), findsOneWidget);

    // Tap cell at row 2, col 0 (index 6 in 3x3 grid)
    await tester.tap(find.byType(GameBoardCell).at(6));
    await tester.pump();
    expect(client.lastPlayedTurn, (2, 0));
  });

  testWidgets('GameEndedPage displays players and winner summary', (tester) async {
    final host = GamePlayer(id: PlayerId('p-host'), name: 'Alice', icon: 0x1F3C6);
    final session = GameSession(
      id: SessionId('sess-end'),
      owner: host.id,
      players: [host],
      state: SessionState.ended,
    );
    final client = _FakeGameClient(
      playerId: host.id,
      currentSession: session,
      currentWinner: host,
    );

    await tester.pumpWidget(MaterialApp(home: GameEndedPage(client: client)));

    expect(find.text('Game Ended'), findsOneWidget);
    expect(find.text('Winner is Alice (\u{1F3C6})'), findsOneWidget);
  });
}
