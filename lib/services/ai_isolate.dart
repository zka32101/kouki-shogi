// lib/services/ai_isolate.dart
// AIをIsolate（別スレッド）で実行し、UIをブロックしないラッパー
// compute() は Dart 3.7+ で Isolate.run() に実装されており、
// Map<String, dynamic> のような送受信可能な型なら問題なく動作する。

import 'package:flutter/foundation.dart';
import '../logic.dart';
import '../piece.dart';
import '../ai_personality.dart';

// ─────────────────────────────────────────────
// エンコード / デコード ヘルパー
// ─────────────────────────────────────────────

/// 盤面 → flat int リスト（81要素）
/// null=0, P1=type.index+1, P2=-(type.index+1)
List<int> _encodeBoard(List<List<Piece?>> b) {
  final out = List<int>.filled(81, 0);
  for (int r = 0; r < 9; r++) {
    for (int c = 0; c < 9; c++) {
      final p = b[r][c];
      if (p == null) continue;
      final v = p.type.index + 1;
      out[r * 9 + c] = p.isPlayer1 ? v : -v;
    }
  }
  return out;
}

List<List<Piece?>> _decodeBoard(List<int> raw) {
  final b = List.generate(9, (_) => List<Piece?>.filled(9, null));
  for (int r = 0; r < 9; r++) {
    for (int c = 0; c < 9; c++) {
      final v = raw[r * 9 + c];
      if (v == 0) continue;
      final isP1 = v > 0;
      final type = PieceType.values[(v.abs()) - 1];
      b[r][c] = Piece(type, isP1);
    }
  }
  return b;
}

/// 持ち駒 → 駒種ごとの枚数リスト（PieceType.values.length 要素）
List<int> _encodeHand(Map<PieceType, int> h) {
  final out = List<int>.filled(PieceType.values.length, 0);
  h.forEach((t, n) => out[t.index] = n);
  return out;
}

Map<PieceType, int> _decodeHand(List<int> raw) {
  final h = <PieceType, int>{};
  for (int i = 0; i < raw.length; i++) {
    if (raw[i] > 0) h[PieceType.values[i]] = raw[i];
  }
  return h;
}

// ─────────────────────────────────────────────
// トップレベル関数（compute() に渡す）
// ─────────────────────────────────────────────

/// bestMoveTimed をIsolate内で実行
Map<String, dynamic>? _workerBest(Map<String, dynamic> p) {
  final b   = _decodeBoard((p['board'] as List).cast<int>());
  final p1h = _decodeHand((p['p1h'] as List).cast<int>());
  final p2h = _decodeHand((p['p2h'] as List).cast<int>());
  final aiIsP1  = p['aiIsP1'] as bool;
  final budgetMs = p['budgetMs'] as int;

  // パーソナリティ復元
  if (p['hasPers'] as bool) {
    AI.setPersonality(
      AiPersonality(
        attackBias:  (p['attackBias']  as num).toDouble(),
        defenceBias: (p['defenceBias'] as num).toDouble(),
        greedBias:   (p['greedBias']   as num).toDouble(),
        depthBonus:  p['depthBonus'] as int,
        dialogues:   {},
      ),
      aiIsP1: p['persAiIsP1'] as bool,
    );
  } else {
    AI.setPersonality(null);
  }

  final mv = AI.bestMoveTimed(
    b, p1h, p2h, aiIsP1,
    budget: Duration(milliseconds: budgetMs),
  );
  return mv?.toJson();
}

/// topMovesTimed をIsolate内で実行
/// 返値: [{move: {...}, score: int}, ...]
List<Map<String, dynamic>> _workerTop(Map<String, dynamic> p) {
  final b   = _decodeBoard((p['board'] as List).cast<int>());
  final p1h = _decodeHand((p['p1h'] as List).cast<int>());
  final p2h = _decodeHand((p['p2h'] as List).cast<int>());
  final aiIsP1  = p['aiIsP1'] as bool;
  final budgetMs = p['budgetMs'] as int;
  final n       = p['n'] as int;

  if (p['hasPers'] as bool) {
    AI.setPersonality(
      AiPersonality(
        attackBias:  (p['attackBias']  as num).toDouble(),
        defenceBias: (p['defenceBias'] as num).toDouble(),
        greedBias:   (p['greedBias']   as num).toDouble(),
        depthBonus:  p['depthBonus'] as int,
        dialogues:   {},
      ),
      aiIsP1: p['persAiIsP1'] as bool,
    );
  } else {
    AI.setPersonality(null);
  }

  final results = AI.topMovesTimed(
    b, p1h, p2h, aiIsP1,
    n: n,
    budget: Duration(milliseconds: budgetMs),
  );
  return results
      .map((r) => {'move': r.$1.toJson(), 'score': r.$2})
      .toList();
}

/// findMate をIsolate内で実行
Map<String, dynamic>? _workerMate(Map<String, dynamic> p) {
  final b   = _decodeBoard((p['board'] as List).cast<int>());
  final p1h = _decodeHand((p['p1h'] as List).cast<int>());
  final p2h = _decodeHand((p['p2h'] as List).cast<int>());
  final attackerIsP1 = p['aiIsP1'] as bool;
  final maxDepth     = p['maxDepth'] as int;
  AI.setPersonality(null);
  final mv = AI.findMate(b, p1h, p2h, attackerIsP1, maxDepth: maxDepth);
  return mv?.toJson();
}

// ─────────────────────────────────────────────
// 公開 API
// ─────────────────────────────────────────────

class AiIsolate {
  /// AIの最善手をIsolateで計算して返す。
  /// [personality] が null の場合はデフォルト評価関数を使用。
  static Future<AMove?> bestMoveTimed(
    List<List<Piece?>> board,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
    bool aiIsP1, {
    Duration budget = const Duration(milliseconds: 900),
    AiPersonality? personality,
    bool persAiIsP1 = true,
  }) async {
    final params = <String, dynamic>{
      'board':    _encodeBoard(board),
      'p1h':      _encodeHand(p1Hand),
      'p2h':      _encodeHand(p2Hand),
      'aiIsP1':   aiIsP1,
      'budgetMs': budget.inMilliseconds,
      'hasPers':  personality != null,
      'attackBias':  personality?.attackBias  ?? 1.0,
      'defenceBias': personality?.defenceBias ?? 1.0,
      'greedBias':   personality?.greedBias   ?? 1.0,
      'depthBonus':  personality?.depthBonus  ?? 0,
      'persAiIsP1': persAiIsP1,
    };
    final result = await compute(_workerBest, params);
    return result != null ? AMove.fromJson(result) : null;
  }

  /// 上位 N 手をIsolateで計算して返す。
  static Future<List<(AMove, int)>> topMovesTimed(
    List<List<Piece?>> board,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
    bool aiIsP1, {
    int n = 3,
    Duration budget = const Duration(milliseconds: 600),
    AiPersonality? personality,
    bool persAiIsP1 = true,
  }) async {
    final params = <String, dynamic>{
      'board':    _encodeBoard(board),
      'p1h':      _encodeHand(p1Hand),
      'p2h':      _encodeHand(p2Hand),
      'aiIsP1':   aiIsP1,
      'n':        n,
      'budgetMs': budget.inMilliseconds,
      'hasPers':  personality != null,
      'attackBias':  personality?.attackBias  ?? 1.0,
      'defenceBias': personality?.defenceBias ?? 1.0,
      'greedBias':   personality?.greedBias   ?? 1.0,
      'depthBonus':  personality?.depthBonus  ?? 0,
      'persAiIsP1': persAiIsP1,
    };
    final raw = await compute(_workerTop, params);
    return raw.map((e) {
      final mv    = AMove.fromJson(e['move'] as Map<String, dynamic>);
      final score = e['score'] as int;
      return (mv, score);
    }).toList();
  }

  /// 詰み手をIsolateで探索して返す（詰みなし → null）。
  /// [maxDepth] 手詰めまでを探す。
  static Future<AMove?> findMate(
    List<List<Piece?>> board,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
    bool attackerIsP1, {
    int maxDepth = 9,
  }) async {
    final params = <String, dynamic>{
      'board':      _encodeBoard(board),
      'p1h':        _encodeHand(p1Hand),
      'p2h':        _encodeHand(p2Hand),
      'aiIsP1':     attackerIsP1,
      'maxDepth':   maxDepth,
    };
    final result = await compute(_workerMate, params);
    return result != null ? AMove.fromJson(result) : null;
  }
}
