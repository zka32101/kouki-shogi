// lib/tactics_engine.dart
// 手筋・囲い崩し問題の「作成条件」を保証するための共通エンジン。
// 駒の利き・移動合法性・王手判定を正確に計算する。
//
// 座標規約: board[row][col]
//   row=0 が一段目(上端=後手陣) / row=8 が九段目(下端=先手陣)
//   col=0 が9筋(右端) / col=8 が1筋(左端)   → 筋 = 9 - col, 段 = row + 1
//   先手(isPlayer1=true): 前進=row減少, 敵陣=row 0..2
//   後手(isPlayer1=false): 前進=row増加, 敵陣=row 6..8
import 'piece.dart';

List<List<Piece?>> cloneBoard(List<List<Piece?>> b) =>
    List.generate(9, (r) => List<Piece?>.from(b[r]));

/// 先手視点の移動デルタ (前進 = row -1)。後手は row 成分を反転して使う。
/// steps = 単発移動, slides = 滑り移動。
({List<List<int>> steps, List<List<int>> slides}) _deltas(PieceType t) {
  switch (t) {
    case PieceType.pawn:
      return (steps: [
        [-1, 0]
      ], slides: const []);
    case PieceType.lance:
      return (steps: const [], slides: [
        [-1, 0]
      ]);
    case PieceType.knight:
      return (steps: [
        [-2, -1],
        [-2, 1]
      ], slides: const []);
    case PieceType.silver:
      return (steps: [
        [-1, -1],
        [-1, 0],
        [-1, 1],
        [1, -1],
        [1, 1]
      ], slides: const []);
    case PieceType.gold:
    case PieceType.promotedSilver:
    case PieceType.promotedKnight:
    case PieceType.promotedLance:
    case PieceType.promotedPawn:
      return (steps: [
        [-1, -1],
        [-1, 0],
        [-1, 1],
        [0, -1],
        [0, 1],
        [1, 0]
      ], slides: const []);
    case PieceType.king:
      return (steps: [
        [-1, -1],
        [-1, 0],
        [-1, 1],
        [0, -1],
        [0, 1],
        [1, -1],
        [1, 0],
        [1, 1]
      ], slides: const []);
    case PieceType.bishop:
      return (steps: const [], slides: [
        [-1, -1],
        [-1, 1],
        [1, -1],
        [1, 1]
      ]);
    case PieceType.rook:
      return (steps: const [], slides: [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1]
      ]);
    case PieceType.promotedBishop: // 馬
      return (steps: [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1]
      ], slides: [
        [-1, -1],
        [-1, 1],
        [1, -1],
        [1, 1]
      ]);
    case PieceType.promotedRook: // 龍
      return (steps: [
        [-1, -1],
        [-1, 1],
        [1, -1],
        [1, 1]
      ], slides: [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1]
      ]);
  }
}

bool _inBounds(int r, int c) => r >= 0 && r < 9 && c >= 0 && c < 9;

/// (r,c) の駒が「攻撃しているマス」の集合。
/// 滑り駒は最初の駒で止まるが、その駒のマス自体は攻撃対象として含む
/// （自駒含む = 利きの計算用）。空マスならその駒は存在しない扱い。
Set<(int, int)> threatSquares(List<List<Piece?>> b, int r, int c) {
  final p = b[r][c];
  if (p == null) return {};
  final d = _deltas(p.type);
  final s = p.isPlayer1 ? 1 : -1; // 後手は row 成分反転
  final out = <(int, int)>{};
  for (final st in d.steps) {
    final nr = r + st[0] * s, nc = c + st[1];
    if (_inBounds(nr, nc)) out.add((nr, nc));
  }
  for (final sl in d.slides) {
    int nr = r + sl[0] * s, nc = c + sl[1];
    while (_inBounds(nr, nc)) {
      out.add((nr, nc));
      if (b[nr][nc] != null) break; // 駒で止まる（そのマスは攻撃対象）
      nr += sl[0] * s;
      nc += sl[1];
    }
  }
  return out;
}

/// (fr,fc)→(tr,tc) の盤上移動が幾何学的に合法か（遮蔽・自駒考慮）。
bool canMove(List<List<Piece?>> b, int fr, int fc, int tr, int tc) {
  if (!_inBounds(fr, fc) || !_inBounds(tr, tc)) return false;
  final p = b[fr][fc];
  if (p == null) return false;
  final dest = b[tr][tc];
  if (dest != null && dest.isPlayer1 == p.isPlayer1) return false; // 自駒は取れない
  return threatSquares(b, fr, fc).contains((tr, tc));
}

/// 手を適用した新しい盤面を返す（移動・打ち・成りを処理）。
List<List<Piece?>> applyMove(List<List<Piece?>> b, AMove m, bool moverIsP1) {
  final nb = cloneBoard(b);
  if (m.drop != null) {
    nb[m.tr][m.tc] = Piece(m.drop!, moverIsP1);
    return nb;
  }
  final p = nb[m.fr][m.fc];
  if (p == null) return nb;
  Piece placed = p;
  if (m.promote && p.canPromote) {
    placed = Piece(p.promotedType, p.isPlayer1);
  }
  nb[m.tr][m.tc] = placed;
  nb[m.fr][m.fc] = null;
  return nb;
}

(int, int)? findKing(List<List<Piece?>> b, bool isP1) {
  for (int r = 0; r < 9; r++) {
    for (int c = 0; c < 9; c++) {
      final p = b[r][c];
      if (p != null && p.isPlayer1 == isP1 && p.type == PieceType.king) {
        return (r, c);
      }
    }
  }
  return null;
}

/// (tr,tc) が byP1 側の駒に攻撃されているか。
bool isAttackedBy(List<List<Piece?>> b, int tr, int tc, bool byP1) {
  for (int r = 0; r < 9; r++) {
    for (int c = 0; c < 9; c++) {
      final p = b[r][c];
      if (p == null || p.isPlayer1 != byP1) continue;
      if (threatSquares(b, r, c).contains((tr, tc))) return true;
    }
  }
  return false;
}

/// kingIsP1 側の玉が王手されているか。
bool inCheck(List<List<Piece?>> b, bool kingIsP1) {
  final k = findKing(b, kingIsP1);
  if (k == null) return false;
  return isAttackedBy(b, k.$1, k.$2, !kingIsP1);
}

/// moverIsP1 が m を指した後、相手玉が attackedKingIsP1 視点で王手になっているか。
bool givesCheck(List<List<Piece?>> b, AMove m, bool moverIsP1) {
  final nb = applyMove(b, m, moverIsP1);
  return inCheck(nb, !moverIsP1);
}

/// matedIsP1 側が詰んでいるか（盤上の駒移動のみで王手を解除できないか）。
/// ※ 持ち駒による合い駒は考慮しない（問題側で相手の持ち駒を空にしておく）。
bool isCheckmate(List<List<Piece?>> b, bool matedIsP1) {
  if (!inCheck(b, matedIsP1)) return false;
  for (int r = 0; r < 9; r++) {
    for (int c = 0; c < 9; c++) {
      final p = b[r][c];
      if (p == null || p.isPlayer1 != matedIsP1) continue;
      for (final (tr, tc) in threatSquares(b, r, c)) {
        final dest = b[tr][tc];
        if (dest != null && dest.isPlayer1 == matedIsP1) continue; // 自駒
        final nb = applyMove(b, AMove(fr: r, fc: c, tr: tr, tc: tc), matedIsP1);
        if (!inCheck(nb, matedIsP1)) return false; // 逃れる手がある
      }
    }
  }
  return true;
}

/// moverIsP1 が指した手で、(tr,tc) に置いた駒が相手の駒を何枚攻撃しているか
/// （対象の駒種を valuableTypes で限定可能）。
int threatenedEnemyCount(
  List<List<Piece?>> b,
  int tr,
  int tc,
  bool moverIsP1, {
  Set<PieceType>? valuableBaseTypes,
}) {
  final threats = threatSquares(b, tr, tc);
  int n = 0;
  for (final (r, c) in threats) {
    final p = b[r][c];
    if (p == null || p.isPlayer1 == moverIsP1) continue;
    if (p.type == PieceType.king) continue;
    if (valuableBaseTypes != null && !valuableBaseTypes.contains(p.baseType)) {
      continue;
    }
    n++;
  }
  return n;
}
