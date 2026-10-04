// lib/models/unified_puzzle.dart
// 詰将棋JSON・lishogi・手筋トレーニングの3システムを統一するモデル。
//
// 使い方:
//   UnifiedPuzzle.fromTesuji(prob)   → 手筋トレーニング問題を変換
//   UnifiedPuzzle.fromLishogi(puzz)  → lishogi APIパズルを変換
//   UnifiedPuzzle.fromTsumeJson(map) → tsume_extra.json の1問を変換
//
// 共通フィールド:
//   id, type, title, difficulty, board, p1Hand, p2Hand, isPlayer1Turn
// 解答フォーマット:
//   - tsume/tesuji → moves (List<AMove>)
//   - lishogi      → usiMoves (List<String>)

import '../piece.dart';
import '../tesuji_problems.dart';
import '../services/lishogi_service.dart';

// ── パズル種別 ────────────────────────────────────────────────

enum PuzzleType {
  tsume,   // 詰将棋（JSON/ハンドメイド）
  lishogi, // lishogi.org パズル
  tesuji,  // 手筋トレーニング
}

// ── 統一パズルモデル ──────────────────────────────────────────

class UnifiedPuzzle {
  final PuzzleType type;
  final String id;
  final String title;

  /// 盤面・持ち駒・手番
  final List<List<Piece?>> board;
  final Map<PieceType, int> p1Hand;
  final Map<PieceType, int> p2Hand;
  final bool isPlayer1Turn;

  /// 難易度ラベル（"初級"/"中級"/"上級"）。lishogiはnull。
  final String? difficulty;

  /// lishogi レーティング。tsume/tesujiはnull。
  final int? rating;

  /// 手筋のカテゴリ（tesujiのみ）。
  final String? category;

  /// 手筋の解説（tesujiのみ）。
  final String? explanation;

  /// 詰み手数（tsumeのみ: 1/3/5/7）。
  final int? totalMoves;

  /// lishogi テーマタグ（lishogiのみ）。
  final List<String>? themes;

  // ── 解答フォーマット（いずれか1つがnull以外） ─────────────

  /// 構造化された解答手順（tsume/tesuji）。
  final List<AMove>? moves;

  /// USI形式の解答手順文字列（lishogiのみ）。
  final List<String>? usiMoves;

  const UnifiedPuzzle({
    required this.type,
    required this.id,
    required this.title,
    required this.board,
    required this.p1Hand,
    required this.p2Hand,
    required this.isPlayer1Turn,
    this.difficulty,
    this.rating,
    this.category,
    this.explanation,
    this.totalMoves,
    this.themes,
    this.moves,
    this.usiMoves,
  });

  // ── ファクトリコンストラクタ ──────────────────────────────────

  factory UnifiedPuzzle.fromTesuji(TesujiProb prob) {
    return UnifiedPuzzle(
      type: PuzzleType.tesuji,
      id: prob.id,
      title: prob.title,
      board: prob.board,
      p1Hand: prob.p1Hand,
      p2Hand: prob.p2Hand,
      isPlayer1Turn: prob.p1Turn,
      difficulty: prob.difficulty,
      category: prob.category,
      explanation: prob.explanation,
      moves: [prob.answer],
    );
  }

  factory UnifiedPuzzle.fromLishogi(LishogiPuzzle puzzle, PuzzleBoardState state) {
    final ratingStr = puzzle.rating.toString();
    final diff = puzzle.rating < 1200
        ? '初級'
        : puzzle.rating < 1600
            ? '中級'
            : '上級';
    return UnifiedPuzzle(
      type: PuzzleType.lishogi,
      id: puzzle.id,
      title: 'lishogi #${puzzle.id} ($ratingStr)',
      board: state.board,
      p1Hand: state.p1Hand,
      p2Hand: state.p2Hand,
      isPlayer1Turn: puzzle.isPlayer1Turn,
      difficulty: diff,
      rating: puzzle.rating,
      themes: puzzle.themes,
      usiMoves: puzzle.solution,
    );
  }

  factory UnifiedPuzzle.fromTsumeJson(Map<String, dynamic> json) {
    // board: 81要素の文字列リストを 9×9 の Piece? リストに変換
    final flatBoard = (json['board'] as List).cast<String>();
    final board = _parseFlatBoard(flatBoard);

    // p1Hand/p2Hand: {"GI": 1, "FU": 2} → Map<PieceType, int>
    final p1Hand = _parseHand(json['p1Hand'] as Map<String, dynamic>? ?? {});
    final p2Hand = _parseHand(json['p2Hand'] as Map<String, dynamic>? ?? {});

    // solution: [{fr,fc,tr,tc,drop?}] → List<AMove>
    final rawSol = (json['solution'] as List).cast<Map<String, dynamic>>();
    final moves = rawSol.map((s) {
      final drop = s['drop'] as String?;
      return AMove(
        fr: s['fr'] as int,
        fc: s['fc'] as int,
        tr: s['tr'] as int,
        tc: s['tc'] as int,
        drop: drop != null ? _parsePieceType(drop) : null,
      );
    }).toList();

    final movesCount = json['moves'] as int? ?? moves.length;

    return UnifiedPuzzle(
      type: PuzzleType.tsume,
      id: json['id'] as String,
      title: json['title'] as String? ?? '詰将棋',
      board: board,
      p1Hand: p1Hand,
      p2Hand: p2Hand,
      isPlayer1Turn: true, // 詰将棋は常に先手番
      difficulty: json['difficulty'] as String?,
      totalMoves: movesCount,
      moves: moves,
    );
  }

  // ── 共通ヘルパー ──────────────────────────────────────────────

  /// このパズルに解答が1手だけあるか（手筋テクニック確認用）
  bool get isSingleMove => moves != null && moves!.length == 1;

  /// タイプの日本語ラベル
  String get typeLabel {
    switch (type) {
      case PuzzleType.tsume: return totalMoves != null ? '$totalMoves手詰' : '詰将棋';
      case PuzzleType.lishogi: return 'lishogi';
      case PuzzleType.tesuji: return category ?? '手筋';
    }
  }

  /// 難易度または相当するラベル
  String get difficultyLabel => difficulty ?? (rating != null ? '$rating点' : '不明');
}

// ── 内部パーサー ──────────────────────────────────────────────

List<List<Piece?>> _parseFlatBoard(List<String> flat) {
  final board = List.generate(9, (_) => List<Piece?>.filled(9, null));
  for (int i = 0; i < flat.length && i < 81; i++) {
    final s = flat[i];
    if (s.isEmpty) continue;
    final isP1 = s.startsWith('+');
    final code = s.substring(1);
    final type = _parsePieceType(code);
    if (type != null) board[i ~/ 9][i % 9] = Piece(type, isP1);
  }
  return board;
}

Map<PieceType, int> _parseHand(Map<String, dynamic> json) {
  final result = <PieceType, int>{};
  for (final entry in json.entries) {
    final type = _parsePieceType(entry.key);
    if (type != null) result[type] = entry.value as int;
  }
  return result;
}

PieceType? _parsePieceType(String code) {
  const map = {
    'OU': PieceType.king,   'HI': PieceType.rook,   'KA': PieceType.bishop,
    'KI': PieceType.gold,   'GI': PieceType.silver,  'KE': PieceType.knight,
    'KY': PieceType.lance,  'FU': PieceType.pawn,
    'RY': PieceType.promotedRook,  'UM': PieceType.promotedBishop,
    'NG': PieceType.promotedSilver, 'NK': PieceType.promotedKnight,
    'NY': PieceType.promotedLance,  'TO': PieceType.promotedPawn,
    // 小文字対応（lishogi系）
    'ou': PieceType.king,   'hi': PieceType.rook,   'ka': PieceType.bishop,
    'ki': PieceType.gold,   'gi': PieceType.silver,  'ke': PieceType.knight,
    'ky': PieceType.lance,  'fu': PieceType.pawn,
    'ry': PieceType.promotedRook,  'um': PieceType.promotedBishop,
  };
  return map[code];
}
