// Manual JSON serialization (no code generation needed)

class BlunderInfo {
  final int moveNum;
  final int evalDelta;
  final String? fromSquare;
  final String toSquare;
  final String pieceMoved;
  final DateTime analyzedAt;

  BlunderInfo({
    required this.moveNum,
    required this.evalDelta,
    required this.fromSquare,
    required this.toSquare,
    required this.pieceMoved,
    required this.analyzedAt,
  });

  factory BlunderInfo.fromJson(Map<String, dynamic> json) {
    return BlunderInfo(
      moveNum: json['moveNum'] as int,
      evalDelta: json['evalDelta'] as int,
      fromSquare: json['fromSquare'] as String?,
      toSquare: json['toSquare'] as String,
      pieceMoved: json['pieceMoved'] as String,
      analyzedAt: DateTime.parse(json['analyzedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'moveNum': moveNum,
    'evalDelta': evalDelta,
    'fromSquare': fromSquare,
    'toSquare': toSquare,
    'pieceMoved': pieceMoved,
    'analyzedAt': analyzedAt.toIso8601String(),
  };
}

class GoodMoveInfo {
  final int moveNum;
  final int evalDelta;
  final String toSquare;
  final String pieceMoved;
  final DateTime analyzedAt;

  GoodMoveInfo({
    required this.moveNum,
    required this.evalDelta,
    required this.toSquare,
    required this.pieceMoved,
    required this.analyzedAt,
  });

  factory GoodMoveInfo.fromJson(Map<String, dynamic> json) {
    return GoodMoveInfo(
      moveNum: json['moveNum'] as int,
      evalDelta: json['evalDelta'] as int,
      toSquare: json['toSquare'] as String,
      pieceMoved: json['pieceMoved'] as String,
      analyzedAt: DateTime.parse(json['analyzedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'moveNum': moveNum,
    'evalDelta': evalDelta,
    'toSquare': toSquare,
    'pieceMoved': pieceMoved,
    'analyzedAt': analyzedAt.toIso8601String(),
  };
}

class GameAnalysis {
  final String id;
  final DateTime playedAt;
  final List<int> evalHistory;
  final List<String> moveNotations;
  final bool playerWon;
  final int movesCount;
  final List<BlunderInfo> blunders;
  final List<GoodMoveInfo> goodMoves;
  final String? openingName;

  GameAnalysis({
    required this.id,
    required this.playedAt,
    required this.evalHistory,
    required this.moveNotations,
    required this.playerWon,
    required this.movesCount,
    required this.blunders,
    required this.goodMoves,
    required this.openingName,
  });

  factory GameAnalysis.fromJson(Map<String, dynamic> json) {
    return GameAnalysis(
      id: json['id'] as String,
      playedAt: DateTime.parse(json['playedAt'] as String),
      evalHistory: List<int>.from(json['evalHistory'] as List),
      moveNotations: List<String>.from(json['moveNotations'] as List),
      playerWon: json['playerWon'] as bool,
      movesCount: json['movesCount'] as int,
      blunders: (json['blunders'] as List)
          .map((v) => BlunderInfo.fromJson(v as Map<String, dynamic>))
          .toList(),
      goodMoves: (json['goodMoves'] as List)
          .map((v) => GoodMoveInfo.fromJson(v as Map<String, dynamic>))
          .toList(),
      openingName: json['openingName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'playedAt': playedAt.toIso8601String(),
    'evalHistory': evalHistory,
    'moveNotations': moveNotations,
    'playerWon': playerWon,
    'movesCount': movesCount,
    'blunders': blunders.map((v) => v.toJson()).toList(),
    'goodMoves': goodMoves.map((v) => v.toJson()).toList(),
    'openingName': openingName,
  };
}

class BlunderPattern {
  final String boardHash;
  final int occurrenceCount;
  final List<String> mistakes;
  final DateTime lastOccurred;

  BlunderPattern({
    required this.boardHash,
    required this.occurrenceCount,
    required this.mistakes,
    required this.lastOccurred,
  });

  factory BlunderPattern.fromJson(Map<String, dynamic> json) {
    return BlunderPattern(
      boardHash: json['boardHash'] as String,
      occurrenceCount: json['occurrenceCount'] as int,
      mistakes: List<String>.from(json['mistakes'] as List),
      lastOccurred: DateTime.parse(json['lastOccurred'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'boardHash': boardHash,
    'occurrenceCount': occurrenceCount,
    'mistakes': mistakes,
    'lastOccurred': lastOccurred.toIso8601String(),
  };
}
