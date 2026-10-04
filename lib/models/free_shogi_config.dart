// 自由将棋の駒ポイント定義とルール設定
import '../piece.dart';

/// 駒ポイント値（自由将棋で使用）
class FreeShogiFiece {
  static const Map<PieceType, int> points = {
    PieceType.pawn: 1,         // 歩
    PieceType.lance: 3,        // 香
    PieceType.knight: 3,       // 桂
    PieceType.silver: 4,       // 銀
    PieceType.gold: 5,         // 金
    PieceType.bishop: 8,       // 角
    PieceType.rook: 10,        // 飛
    PieceType.king: 0,         // 玉（交換不可・固定）
    PieceType.promotedPawn: 2,     // 成歩
    PieceType.promotedLance: 4,    // 成香
    PieceType.promotedKnight: 4,   // 成桂
    PieceType.promotedSilver: 5,   // 成銀
    PieceType.promotedBishop: 9,   // 成角
    PieceType.promotedRook: 11,    // 成飛
  };

  /// デフォルト予算（各プレイヤー）
  static const int defaultBudget = 60;

  /// ポイントを計算（複数駒）
  static int calculateTotal(Map<PieceType, int> pieces) {
    int total = 0;
    pieces.forEach((type, count) {
      total += (points[type] ?? 0) * count;
    });
    return total;
  }
}

/// 自由将棋テンプレート
class FreeShogiFiemplateEntry {
  final String id;
  final String name;
  final String description;
  final List<List<Piece?>> p1Board;  // 先手初期配置（9×9）
  final List<List<Piece?>> p2Board;  // 後手初期配置（9×9）
  final int p1Budget;
  final int p2Budget;
  final DateTime createdAt;

  FreeShogiFiemplateEntry({
    required this.id,
    required this.name,
    this.description = '',
    required this.p1Board,
    required this.p2Board,
    this.p1Budget = FreeShogiFiece.defaultBudget,
    this.p2Budget = FreeShogiFiece.defaultBudget,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// JSON化
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'p1Board': _boardToJson(p1Board),
      'p2Board': _boardToJson(p2Board),
      'p1Budget': p1Budget,
      'p2Budget': p2Budget,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// JSONから復元
  factory FreeShogiFiemplateEntry.fromJson(Map<String, dynamic> json) {
    return FreeShogiFiemplateEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      p1Board: _boardFromJson(json['p1Board']),
      p2Board: _boardFromJson(json['p2Board']),
      p1Budget: json['p1Budget'] as int? ?? FreeShogiFiece.defaultBudget,
      p2Budget: json['p2Budget'] as int? ?? FreeShogiFiece.defaultBudget,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  static List<List<dynamic>> _boardToJson(List<List<Piece?>> board) {
    return board.map((row) {
      return row.map((p) {
        if (p == null) return null;
        return {'t': p.type.index, 'p1': p.isPlayer1};
      }).toList();
    }).toList();
  }

  static List<List<Piece?>> _boardFromJson(dynamic data) {
    if (data == null) return List.generate(9, (_) => List<Piece?>.filled(9, null));
    try {
      final rows = data as List;
      return List.generate(9, (r) {
        final row = r < rows.length ? rows[r] as List? : null;
        if (row == null) return List<Piece?>.filled(9, null);
        return List.generate(9, (c) {
          final cell = c < row.length ? row[c] : null;
          if (cell == null) return null;
          final t = cell['t'] as int?;
          final p1 = cell['p1'] as bool? ?? true;
          if (t == null || t < 0 || t >= PieceType.values.length) return null;
          return Piece(PieceType.values[t], p1);
        });
      });
    } catch (_) {
      return List.generate(9, (_) => List<Piece?>.filled(9, null));
    }
  }
}
