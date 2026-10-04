// lib/models/match.dart

class Match {
  final String id;
  final String player1Id;
  final String player2Id;
  final String boardState;
  final String? winner;
  final DateTime createdAt;

  Match({
    required this.id,
    required this.player1Id,
    required this.player2Id,
    required this.boardState,
    this.winner,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'player1_id': player1Id,
      'player2_id': player2Id,
      'board_state': boardState,
      'winner': winner,
      'created_at': createdAt,
    };
  }

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      id: json['id'] as String,
      player1Id: json['player1_id'] as String,
      player2Id: json['player2_id'] as String,
      boardState: json['board_state'] as String? ?? '',
      winner: json['winner'] as String?,
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }

  bool get isFinished => winner != null;
}
