import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:common/common.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_client/web_socket_client.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late final WebSocket webSocket;

  final playerId = PlayerId(Uuid().v4());

  @override
  void initState() {
    super.initState();
    webSocket = WebSocket(
      Uri.parse('ws://localhost:8080/ws'),
      protocols: ['game.v1'],
      headers: {
        'x-player-id': playerId.value,
      },
    );
    webSocket.messages.listen((event) {
      print('Received from server: $event');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Home'),

            ElevatedButton(
              onPressed: () {
                webSocket.send(
                  json.encode(CreateSessionRequest(CommandId('1'))),
                );
              },
              child: const Text('Create Session'),
            ),
            ElevatedButton(
              onPressed: () {
                webSocket.send(
                  json.encode(
                    JoinSessionRequest(
                      CommandId('2'),
                      SessionId('1'),
                      GamePlayer(playerId, 'Player 1', 1),
                    ),
                  ),
                );
              },
              child: const Text('Join Session'),
            ),
          ],
        ),
      ),
    );
  }
}
