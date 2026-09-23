import 'package:uuid/uuid.dart';

extension type CommandId(String value) {
  static CommandId get random => CommandId(Uuid().v4());
}

extension type SessionId(String value) {}

extension type PlayerId(String value) {}

enum SessionState {
  none('none'),
  waiting('waiting'),
  playing('playing'),
  ended('ended');

  const SessionState(this.value);

  final String value;

  @override
  String toString() => value;

  String toJson() => value;

  static SessionState fromJson(String value) {
    return SessionState.values.firstWhere((e) => e.value == value);
  }
}

class GamePlayer {
  GamePlayer({
    required this.id,
    required this.name,
    required this.icon,
  });

  final PlayerId id;
  final String name;
  final int icon;

  factory GamePlayer.fromJson(Map<String, Object?> json) {
    return GamePlayer(
      id: PlayerId(json['id'] as String),
      name: json['name'] as String,
      icon: json['icon'] as int,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
    };
  }
}

class GameSession {
  GameSession({
    required this.id,
    required this.owner,
    required this.players,
    required this.state,
  });

  final SessionId id;
  final PlayerId owner;
  final List<GamePlayer> players;
  final SessionState state;

  GameSession copyWith({
    SessionId? id,
    PlayerId? owner,
    List<GamePlayer>? players,
    SessionState? state,
  }) {
    return GameSession(
      id: id ?? this.id,
      owner: owner ?? this.owner,
      players: players ?? this.players,
      state: state ?? this.state,
    );
  }

  factory GameSession.fromJson(Map<String, Object?> json) {
    return GameSession(
      id: SessionId(json['id'] as String),
      owner: PlayerId(json['owner'] as String),
      players: (json['players'] as List).map((p) {
        return GamePlayer.fromJson(p as Map<String, Object?>);
      }).toList(),
      state: SessionState.fromJson(json['state'] as String),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id.value,
      'owner': owner.value,
      'players': players.map((p) => p.toJson()).toList(),
      'state': state.name,
    };
  }
}

class GameBoard {
  GameBoard._({
    required this.rows,
    required this.cols,
    required this.data,
  });

  factory GameBoard.empty(int rows, int cols) {
    return GameBoard._(
      rows: rows,
      cols: cols,
      data: List<List<int>>.generate(rows, (int row) {
        return List<int>.filled(cols, 0);
      }),
    );
  }

  final int rows;
  final int cols;
  final List<List<int>> data;

  void set(int row, int col, int value) {
    data[row][col] = value;
  }

  int get(int row, int col) => data[row][col];

  factory GameBoard.fromJson(Map<String, Object?> json) {
    return GameBoard._(
      rows: json['rows'] as int,
      cols: json['cols'] as int,
      data: (json['data'] as List).map((row) {
        return (row as List).cast<int>().toList();
      }).toList(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'rows': rows,
      'cols': cols,
      'data': data,
    };
  }

  /// A winner is a row, col or diagonal that has all the same non-zero values
  int? checkWinner() {
    // Check rows
    for (var i = 0; i < rows; i++) {
      final row = data[i];
      if (row.every((e) => e == row[0]) && row[0] != 0) {
        return row[0];
      }
    }
    // Check cols
    for (var i = 0; i < cols; i++) {
      final col = data.map((row) => row[i]).toList();
      if (col.every((e) => e == col[0]) && col[0] != 0) {
        return col[0];
      }
    }
    // Check top-left to bottom-right diagonal
    final diag1 = List<int>.generate(rows, (i) => data[i][i]);
    if (diag1.every((e) => e == diag1[0]) && diag1[0] != 0) {
      return diag1[0];
    }
    // Check top-right to bottom-left diagonal
    final diag2 = List<int>.generate(rows, (i) => data[i][cols - i - 1]);
    if (diag2.every((e) => e == diag2[0]) && diag2[0] != 0) {
      return diag2[0];
    }
    return null;
  }
}
