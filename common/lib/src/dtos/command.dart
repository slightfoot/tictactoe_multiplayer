part of '../dtos.dart';

final class GameCommandResponse extends DataTransferObject {
  GameCommandResponse(this.id, this.success, this.error);

  final CommandId id;
  final bool success;
  final String? error;

  @override
  final type = DtoType.gameCommandResponse;

  factory GameCommandResponse.fromJson(Map<String, Object?> json) {
    return GameCommandResponse(
      CommandId(json['id'] as String),
      json['success'] as bool,
      json['error'] as String?,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return {
      'id': id.value,
      'success': success,
      if (error != null) //
        'error': error,
    };
  }
}

sealed class GameCommand extends DataTransferObject {
  const GameCommand(this.id, this.sessionId);

  final CommandId id;
  final SessionId sessionId;

  @override
  Map<String, Object?> toJson() {
    return {
      ...super.toJson(),
      'id': id.value,
      'sessionId': sessionId.value,
    };
  }
}

final class GameCommandTurn extends GameCommand {
  GameCommandTurn(
    super.id,
    super.sessionId,
    this.playerId,
    this.row,
    this.col,
  );

  final PlayerId playerId;
  final int row;
  final int col;

  @override
  final type = DtoType.gameCommandTurn;

  factory GameCommandTurn.fromJson(Map<String, Object?> json) {
    return GameCommandTurn(
      CommandId(json['id'] as String),
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
