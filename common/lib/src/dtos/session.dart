part of '../dtos.dart';

sealed class SessionCommand extends DtoCommand {
  const SessionCommand(super.id);
}

sealed class SessionResponse extends DtoCommand {
  const SessionResponse(super.id);
}

final class CreateSessionRequest extends SessionCommand {
  const CreateSessionRequest(
    super.id,
    this.player,
  );

  final GamePlayer player;

  @override
  final type = DtoType.createSessionRequest;

  factory CreateSessionRequest.fromJson(Map<String, Object?> json) {
    return CreateSessionRequest(
      CommandId(json['id'] as String),
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

final class CreateSessionResponse extends SessionResponse {
  const CreateSessionResponse(super.id, this.sessionId);

  final SessionId sessionId;

  @override
  final type = DtoType.createSessionResponse;

  factory CreateSessionResponse.fromJson(Map<String, Object?> json) {
    return CreateSessionResponse(
      CommandId(json['id'] as String),
      SessionId(json['sessionId'] as String),
    );
  }

  @override
  Map<String, Object?> toJson() {
    return {
      ...super.toJson(),
      'sessionId': sessionId.value,
    };
  }
}

final class JoinSessionRequest extends SessionCommand {
  JoinSessionRequest(super.id, this.sessionId, this.player);

  final SessionId sessionId;
  final GamePlayer player;

  @override
  final type = DtoType.joinSessionRequest;

  factory JoinSessionRequest.fromJson(Map<String, Object?> json) {
    return JoinSessionRequest(
      CommandId(json['id'] as String),
      SessionId(json['sessionId'] as String),
      GamePlayer.fromJson(json['player'] as Map<String, Object?>),
    );
  }

  @override
  Map<String, Object?> toJson() {
    return {
      ...super.toJson(),
      'sessionId': sessionId.value,
      'player': player.toJson(),
    };
  }
}

final class JoinSessionResponse extends SessionResponse {
  JoinSessionResponse(super.id, this.session, this.board);

  final GameSession session;
  final GameBoard board;

  @override
  final type = DtoType.joinSessionResponse;

  factory JoinSessionResponse.fromJson(Map<String, Object?> json) {
    return JoinSessionResponse(
      CommandId(json['id'] as String),
      GameSession.fromJson(json['session'] as Map<String, Object?>),
      GameBoard.fromJson(json['board'] as Map<String, Object?>),
    );
  }

  @override
  Map<String, Object?> toJson() {
    return {
      ...super.toJson(),
      'session': session.toJson(),
      'board': board.toJson(),
    };
  }
}

final class StartSessionRequest extends SessionCommand {
  const StartSessionRequest(super.id, this.sessionId);

  final SessionId sessionId;

  @override
  final type = DtoType.startSessionRequest;

  factory StartSessionRequest.fromJson(Map<String, Object?> json) {
    return StartSessionRequest(
      CommandId(json['id'] as String),
      SessionId(json['sessionId'] as String),
    );
  }

  @override
  Map<String, Object?> toJson() {
    return {
      ...super.toJson(),
      'sessionId': sessionId.value,
    };
  }
}

final class StartSessionResponse extends SessionResponse {
  const StartSessionResponse(super.id, this.sessionId, this.board);

  final SessionId sessionId;
  final GameBoard board;

  @override
  final type = DtoType.startSessionResponse;

  factory StartSessionResponse.fromJson(Map<String, Object?> json) {
    return StartSessionResponse(
      CommandId(json['id'] as String),
      SessionId(json['sessionId'] as String),
      GameBoard.fromJson(json['board'] as Map<String, Object?>),
    );
  }

  @override
  Map<String, Object?> toJson() {
    return {
      ...super.toJson(),
      'sessionId': sessionId.value,
      'board': board.toJson(),
    };
  }
}
