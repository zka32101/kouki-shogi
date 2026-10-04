// lib/tsume_engine.dart — 詰将棋専用探索エンジン
//
// 従来の「固定手順との一致」を廃止し、
// 「王手の連続で後手玉に逃げ道がない」ことを動的に検証する。
//
// ルール:
//   - 攻め方（先手）の手は必ず王手でなければならない（詰将棋ルール）
//   - 受け方（後手）は合法手を全て試みる
//   - 全受け方応手が詰みに至れば攻め手が正解

import 'dart:async';
import 'piece.dart';
import 'logic.dart';

// ───────────────────────────────────────────────────────
// 探索結果
// ───────────────────────────────────────────────────────
class TsumeResult {
  /// 詰みが存在するか
  final bool isMate;
  /// 攻め方の最初の詰み手（null = 詰みなし）
  final AMove? matingMove;
  /// 後手の最善応手（探索の過程で見つかったもの）
  final AMove? bestDefense;

  const TsumeResult({required this.isMate, this.matingMove, this.bestDefense});

  static const no = TsumeResult(isMate: false);
}

// ───────────────────────────────────────────────────────
// 詰め探索専用置換表
// ───────────────────────────────────────────────────────
enum _TsumeTTVal { mate, noMate }

class _TsumeTT {
  final Map<String, (int, _TsumeTTVal)> _table = {}; // hash → (depth, val)
  static const _maxSize = 200000;

  _TsumeTTVal? lookup(String hash, int depth) {
    final e = _table[hash];
    if (e == null || e.$1 < depth) return null;
    return e.$2;
  }

  void store(String hash, int depth, _TsumeTTVal val) {
    if (_table.length < _maxSize) _table[hash] = (depth, val);
  }

  void clear() => _table.clear();

  /// 局面ハッシュ（手番付き）
  static String hash(List<List<Piece?>> b, Map<PieceType, int> p1h,
      Map<PieceType, int> p2h, bool attackerTurn) {
    final buf = StringBuffer();
    buf.writeCharCode(attackerTurn ? 49 : 48);
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p == null) {
          buf.writeCharCode(46);
        } else {
          buf.writeCharCode(p.isPlayer1 ? 65 : 97);
          buf.writeCharCode(p.type.index + 65);
        }
      }
    for (final e in p1h.entries)
      if (e.value > 0) { buf.writeCharCode(e.key.index + 48); buf.write(e.value); }
    buf.writeCharCode(124);
    for (final e in p2h.entries)
      if (e.value > 0) { buf.writeCharCode(e.key.index + 48); buf.write(e.value); }
    return buf.toString();
  }
}

// ───────────────────────────────────────────────────────
// TsumeEngine
// ───────────────────────────────────────────────────────
class TsumeEngine {
  // 探索打ち切り上限（反復深化全体での累計）
  static const _nodeLimit = 300000;
  int _nodes = 0;
  final _tt = _TsumeTT();

  // ── 公開 API ──────────────────────────────────────────

  /// ある手が詰み手かどうかを検証する。
  ///
  /// [board] [p1Hand] [p2Hand]: 現在の局面（手を指す前）
  /// [attackerIsP1]: 攻め方が先手か
  /// [mv]: 検証したい手
  /// [totalRemainingMoves]: この手を含む残り詰め手数（奇数）
  ///
  /// 返値: [TsumeResult] — isMate=true なら有効な詰み手
  Future<TsumeResult> validateMove({
    required List<List<Piece?>> board,
    required Map<PieceType, int> p1Hand,
    required Map<PieceType, int> p2Hand,
    required bool attackerIsP1,
    required AMove mv,
    required int totalRemainingMoves,
  }) async {
    _nodes = 0;
    // 重い探索は非同期で実行（UI ブロック回避）
    return await Future(() => _checkMove(
      board, p1Hand, p2Hand, attackerIsP1, mv, totalRemainingMoves,
    ));
  }

  /// 詰み手を探索する — 反復深化版（1→3→5→depth と深める）
  ///
  /// 返値: [TsumeResult] — isMate=true なら詰みあり
  Future<TsumeResult> findMate({
    required List<List<Piece?>> board,
    required Map<PieceType, int> p1Hand,
    required Map<PieceType, int> p2Hand,
    required bool attackerIsP1,
    required int depth, // 奇数: 1, 3, 5, 7, ...
  }) async {
    _nodes = 0;
    _tt.clear();
    return await Future(() {
      // 反復深化: 1手→3手→…→depth手 と段階的に探索
      for (int d = 1; d <= depth; d += 2) {
        if (_nodes >= _nodeLimit) break;
        final result = _attackerSearch(board, p1Hand, p2Hand, attackerIsP1, d);
        if (result.isMate) return result;
      }
      return TsumeResult.no;
    });
  }

  // ── 内部探索 ──────────────────────────────────────────

  /// 攻め方の番: 詰み手を探す（置換表付き）
  TsumeResult _attackerSearch(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
    bool attackerIsP1,
    int depth,
  ) {
    if (depth <= 0) return TsumeResult.no;
    if (_nodes >= _nodeLimit) return TsumeResult.no;

    // 置換表チェック（攻め方ノード）
    final hash = _TsumeTT.hash(b, p1h, p2h, attackerIsP1);
    final cached = _tt.lookup(hash, depth);
    if (cached == _TsumeTTVal.noMate) return TsumeResult.no;

    final moves = AI.allMoves(b, attackerIsP1, p1h, p2h);

    // 成り・取る手を優先
    moves.sort((a, bm) {
      int sa = (bm.promote ? 2 : 0) + (b[bm.tr][bm.tc] != null ? 1 : 0);
      int sb = (a.promote ? 2 : 0) + (b[a.tr][a.tc] != null ? 1 : 0);
      return sa - sb;
    });

    for (final mv in moves) {
      _nodes++;
      if (_nodes >= _nodeLimit) return TsumeResult.no;
      final result = _checkMove(b, p1h, p2h, attackerIsP1, mv, depth);
      if (result.isMate) {
        _tt.store(hash, depth, _TsumeTTVal.mate);
        return result;
      }
    }
    _tt.store(hash, depth, _TsumeTTVal.noMate);
    return TsumeResult.no;
  }

  /// 1手を適用して詰みかどうかを確認する
  TsumeResult _checkMove(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
    bool attackerIsP1,
    AMove mv,
    int depth,
  ) {
    final defenderIsP1 = !attackerIsP1;
    final next = AI.apply(b, p1h, p2h, mv, attackerIsP1);

    // 詰将棋ルール: 攻め方の手は必ず王手
    if (!GL.inCheck(next.b, defenderIsP1)) return TsumeResult.no;

    final defHand = defenderIsP1 ? next.p1h : next.p2h;
    final atkHand = attackerIsP1 ? next.p1h : next.p2h;

    // depth=1: 即詰みか確認
    if (depth == 1) {
      if (!GL.hasLegalMove(next.b, defenderIsP1, defHand, atkHand)) {
        return TsumeResult(isMate: true, matingMove: mv);
      }
      return TsumeResult.no;
    }

    // depth >= 3: 受け方の全応手が詰みに至るか確認
    final defResult = _defenderSearch(next.b, next.p1h, next.p2h, attackerIsP1, depth - 1);
    if (!defResult.isMate) return TsumeResult.no;

    return TsumeResult(
      isMate: true,
      matingMove: mv,
      bestDefense: defResult.bestDefense,
    );
  }

  /// 受け方の番: 全応手を試す。1手でも逃れがあれば false
  TsumeResult _defenderSearch(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
    bool attackerIsP1,
    int depth,
  ) {
    final defenderIsP1 = !attackerIsP1;
    final defHand = defenderIsP1 ? p1h : p2h;

    // 置換表チェック（受け方ノード）
    final hash = _TsumeTT.hash(b, p1h, p2h, defenderIsP1);
    final cached = _tt.lookup(hash, depth);
    if (cached == _TsumeTTVal.noMate) return TsumeResult.no;
    if (cached == _TsumeTTVal.mate)   return const TsumeResult(isMate: true);

    final atkHand = attackerIsP1 ? p1h : p2h;
    final defenses = GL.hasLegalMove(b, defenderIsP1, defHand, atkHand)
        ? AI.allMoves(b, defenderIsP1, p1h, p2h)
        : <AMove>[];

    if (defenses.isEmpty) {
      _tt.store(hash, depth, _TsumeTTVal.mate);
      return const TsumeResult(isMate: true);
    }

    AMove? bestDef;

    for (final mv in defenses) {
      _nodes++;
      if (_nodes >= _nodeLimit) {
        _tt.store(hash, depth, _TsumeTTVal.noMate);
        return TsumeResult.no;
      }
      final next = AI.apply(b, p1h, p2h, mv, defenderIsP1);
      final attackResult =
          _attackerSearch(next.b, next.p1h, next.p2h, attackerIsP1, depth - 1);
      if (!attackResult.isMate) {
        _tt.store(hash, depth, _TsumeTTVal.noMate);
        return TsumeResult.no;
      }
      bestDef ??= mv;
    }

    _tt.store(hash, depth, _TsumeTTVal.mate);
    return TsumeResult(isMate: true, bestDefense: bestDef);
  }
}

// ───────────────────────────────────────────────────────
// AI 型のエクスポート（logic.dart の AI クラスを使う）
// ───────────────────────────────────────────────────────
// AI.apply と AI.allMoves を外部から呼べるようにするためのエクスポート
// logic.dart では AI クラスに allMoves が static で定義されている
