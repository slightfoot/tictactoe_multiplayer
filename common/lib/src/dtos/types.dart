part of '../dtos.dart';

enum DtoType {
  // session.dart
  createSessionRequest('CreateSessionRequest', CreateSessionRequest.fromJson),
  createSessionResponse('CreateSessionResponse', CreateSessionResponse.fromJson),
  joinSessionRequest('JoinSessionRequest', JoinSessionRequest.fromJson),
  joinSessionResponse('JoinSessionResponse', JoinSessionResponse.fromJson),
  startSessionRequest('StartSessionRequest', StartSessionRequest.fromJson),
  startSessionResponse('StartSessionResponse', StartSessionResponse.fromJson),
  // commands.dart
  commandResponse('GameCommandResponse', CommandResponse.fromJson),
  gameCommandTurn('GameCommandTurn', GameCommandTurn.fromJson),
  // events.dart
  gameStartedEvent('GameStartedEvent', GameStartedEvent.fromJson),
  playerJoinedSessionEvent('PlayerJoinedSessionEvent', PlayerJoinedSessionEvent.fromJson),
  playerLeftSessionEvent('PlayerLeftSessionEvent', PlayerLeftSessionEvent.fromJson),
  gameEndedEvent('GameEndedEvent', GameEndedEvent.fromJson),
  gameTurnEvent('GameTurnEvent', GameTurnEvent.fromJson),
  ;

  const DtoType(this.value, this.fromJson);

  final String value;
  final DataTransferObject Function(Map<String, Object?> json) fromJson;

  @override
  String toString() => value;

  String toJson() => value;

  static DtoType fromValue(String value) {
    return DtoType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw Exception('Unknown DTO type: $value'),
    );
  }
}
