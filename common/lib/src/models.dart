extension type CommandId(String value) {}

extension type SessionId(String value) {}

extension type PlayerId(String value) {}

enum SessionState {
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
  GamePlayer(
    this.id,
    this.name,
    this.icon,
  );

  final PlayerId id;
  final String name;
  final int icon;

  factory GamePlayer.fromJson(Map<String, Object?> json) {
    return GamePlayer(
      PlayerId(json['id'] as String),
      json['name'] as String,
      json['icon'] as int,
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
  GameSession(
    this.id,
    this.owner,
    this.players,
    this.state,
  );

  final SessionId id;
  final PlayerId owner;
  final List<GamePlayer> players;
  final SessionState state;

  factory GameSession.fromJson(Map<String, Object?> json) {
    return GameSession(
      SessionId(json['id'] as String),
      PlayerId(json['owner'] as String),
      (json['players'] as List).map((p) {
        return GamePlayer.fromJson(p as Map<String, Object?>);
      }).toList(),
      SessionState.fromJson(json['state'] as String),
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
  GameBoard(this.rows, this.cols, this.data);

  final int rows;
  final int cols;
  final List<List<int>> data;

  void set(int row, int col, int value) {
    data[row][col] = value;
  }

  int get(int row, int col) => data[row][col];

  factory GameBoard.fromJson(Map<String, Object?> json) {
    return GameBoard(
      json['rows'] as int,
      json['cols'] as int,
      (json['data'] as List).cast<List<int>>(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'rows': rows,
      'cols': cols,
      'data': data,
    };
  }
}
