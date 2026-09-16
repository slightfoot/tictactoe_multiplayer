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
