part of '../dtos.dart';

sealed class GameEvent extends DataTransferObject {
  const GameEvent(this.sessionId);

  final SessionId sessionId;

  @override
  Map<String, Object?> toJson() {
    return {
      ...super.toJson(),
      'sessionId': sessionId.value,
    };
  }
}

final class PlayerJoinedSessionEvent extends GameEvent {
  PlayerJoinedSessionEvent(super.sessionId, this.player);

  final GamePlayer player;

  @override
  final type = DtoType.playerJoinedSessionEvent;

  factory PlayerJoinedSessionEvent.fromJson(Map<String, Object?> json) {
    return PlayerJoinedSessionEvent(
      SessionId(json['sessionId'] as String),
      GamePlayer.fromJson(json['player'] as Map<String, Object?>),
    );
  }

  @override
  Map<String, Object?> toJson() {
    return {
      ...super.toJson(),
      'player': player.toJson(),
    };
  }
}

final class PlayerLeftSessionEvent extends GameEvent {
  PlayerLeftSessionEvent(super.sessionId, this.playerId);

  final PlayerId playerId;

  @override
  final type = DtoType.playerLeftSessionEvent;

  factory PlayerLeftSessionEvent.fromJson(Map<String, Object?> json) {
    return PlayerLeftSessionEvent(
      SessionId(json['sessionId'] as String),
      PlayerId(json['playerId'] as String),
    );
  }

  @override
  Map<String, Object?> toJson() {
    return {
      ...super.toJson(),
      'playerId': playerId.value,
    };
  }
}

final class GameStartedEvent extends GameEvent {
  GameStartedEvent(super.sessionId);

  @override
  final type = DtoType.gameStartedEvent;

  factory GameStartedEvent.fromJson(Map<String, Object?> json) {
    return GameStartedEvent(SessionId(json['sessionId'] as String));
  }
}

final class GameEndedEvent extends GameEvent {
  GameEndedEvent(super.sessionId, this.winner);

  final GamePlayer? winner;

  @override
  final type = DtoType.gameEndedEvent;

  factory GameEndedEvent.fromJson(Map<String, Object?> json) {
    return GameEndedEvent(
      SessionId(json['sessionId'] as String),
      json['winner'] != null ? GamePlayer.fromJson(json['winner'] as Map<String, Object?>) : null,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return {
      ...super.toJson(),
      if (winner != null) //
        'winner': winner!.toJson(),
    };
  }
}

final class GameTurnEvent extends GameEvent {
  GameTurnEvent(super.sessionId, this.playerId, this.row, this.col);

  final PlayerId playerId;
  final int row;
  final int col;

  @override
  final type = DtoType.gameTurnEvent;

  factory GameTurnEvent.fromJson(Map<String, Object?> json) {
    return GameTurnEvent(
      SessionId(json['sessionId'] as String),
      PlayerId(json['playerId'] as String),
      json['row'] as int,
      json['col'] as int,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return {
      ...super.toJson(),
      'playerId': playerId.value,
      'row': row,
      'col': col,
    };
  }
}
