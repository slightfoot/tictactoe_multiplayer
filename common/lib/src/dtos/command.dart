part of '../dtos.dart';

final class CommandResponse extends DataTransferObject {
  const CommandResponse._(this.id, this.success, this.error);

  const CommandResponse.success(this.id) : success = true, error = null;

  const CommandResponse.error(this.id, this.error) : success = false;

  final CommandId id;
  final bool success;
  final String? error;

  @override
  final type = DtoType.commandResponse;

  factory CommandResponse.fromJson(Map<String, Object?> json) {
    return CommandResponse._(
      CommandId(json['id'] as String),
      json['success'] as bool,
      json['error'] as String?,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return {
      ...super.toJson(),
      'id': id.value,
      'success': success,
      if (error != null) //
        'error': error,
    };
  }
}

sealed class DtoCommand extends DataTransferObject {
  const DtoCommand(this.id);

  final CommandId id;

  @override
  Map<String, Object?> toJson() {
    return {
      ...super.toJson(),
      'id': id.value,
    };
  }
}

sealed class GameCommand extends DtoCommand {
  const GameCommand(super.id, this.sessionId);

  final SessionId sessionId;

  @override
  Map<String, Object?> toJson() {
    return {
      ...super.toJson(),
      'sessionId': sessionId.value,
    };
  }
}

final class GameCommandTurn extends GameCommand {
  GameCommandTurn(
    super.id,
    super.sessionId,
    this.row,
    this.col,
  );

  final int row;
  final int col;

  @override
  final type = DtoType.gameCommandTurn;

  factory GameCommandTurn.fromJson(Map<String, Object?> json) {
    return GameCommandTurn(
      CommandId(json['id'] as String),
      SessionId(json['sessionId'] as String),
      json['row'] as int,
      json['col'] as int,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return {
      ...super.toJson(),
      'row': row,
      'col': col,
    };
  }
}
