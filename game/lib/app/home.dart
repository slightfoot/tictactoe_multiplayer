import 'package:flutter/material.dart';
import 'package:common/common.dart';

import '../game/client.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late final GameClient client;

  @override
  void initState() {
    super.initState();
    client = GameClient(Uri.parse('ws://localhost:8080/ws'));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: client,
      builder: (BuildContext context, _) {
        switch (client.state) {
          case SessionState.none:
            return HomePage(client: client);
          case SessionState.waiting:
            return GameWaitingPage(client: client);
          case SessionState.playing:
            return GamePlayingPage(client: client);
          case SessionState.ended:
            return GameEndedPage(client: client);
        }
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.client});

  final GameClient client;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _sessionIdController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Home'),
            ElevatedButton(
              onPressed: () {
                widget.client.createRandomPlayer();
                widget.client.createSession();
              },
              child: const Text('Create Session'),
            ),
            const Divider(),
            Text('Join Session'),
            TextField(
              controller: _sessionIdController,
              decoration: const InputDecoration(
                hintText: 'Session ID',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                widget.client.createRandomPlayer();
                widget.client.joinSession(SessionId(_sessionIdController.text));
              },
              child: const Text('Join Session'),
            ),
          ],
        ),
      ),
    );
  }
}

class GameWaitingPage extends StatelessWidget {
  const GameWaitingPage({super.key, required this.client});

  final GameClient client;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Waiting for other players...'),
            Text(
              client.session.players
                  .map((el) => '${el.name} (${String.fromCharCode(el.icon)})')
                  .join(', '),
            ),
            const Divider(),
            Text('Session ID:'),
            SelectableText(client.session.id.value),
            const Divider(),
            if (client.session.owner == client.playerId) //
              ElevatedButton(
                onPressed: () {
                  client.startSession();
                },
                child: const Text('Start Session'),
              ),
          ],
        ),
      ),
    );
  }
}

class GamePlayingPage extends StatelessWidget {
  const GamePlayingPage({super.key, required this.client});

  final GameClient client;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Playing'),
            Text(
              client.session.players
                  .map((el) => '${el.name} (${String.fromCharCode(el.icon)})')
                  .join(', '),
            ),
            Divider(),
            Expanded(
              child: GameBoardWidget(
                board: client.board,
                onTap: client.playTurn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GameBoardWidget extends StatelessWidget {
  const GameBoardWidget({
    super.key,
    required this.board,
    required this.onTap,
  });

  final GameBoard board;
  final void Function(int row, int col) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < board.rows; row++) ...[
          Row(
            children: [
              for (var col = 0; col < board.cols; col++) ...[
                Expanded(
                  child: GameBoardCell(
                    value: board.get(row, col),
                    onTap: () => onTap(row, col),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class GameBoardCell extends StatelessWidget {
  const GameBoardCell({
    super.key,
    required this.value,
    required this.onTap,
  });

  final int value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white),
          ),
          child: value != 0
              ? Center(
                  child: Text(
                    String.fromCharCode(value),
                    style: TextStyle(fontSize: 32.0),
                  ),
                )
              : SizedBox.shrink(),
        ),
      ),
    );
  }
}

class GameEndedPage extends StatelessWidget {
  const GameEndedPage({super.key, required this.client});

  final GameClient client;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Game Ended'),
            Text(
              client.session.players
                  .map((el) => '${el.name} (${String.fromCharCode(el.icon)})')
                  .join(', '),
            ),
            Divider(),
            Text(
              'Winner is ${client.winner.name} '
              '(${String.fromCharCode(client.winner.icon)})',
            ),
          ],
        ),
      ),
    );
  }
}
