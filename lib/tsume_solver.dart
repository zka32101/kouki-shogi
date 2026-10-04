// lib/tsume_solver.dart
// 詰め手数を自動解くソルバー（1-5手詰用）
// 使用: final depth = solveTsume(board, matedIs P1, maxDepth: 5);
// 戻値: N手詰なら N、詰みでなければ 0

import 'piece.dart';
import 'tactics_engine.dart';

/// 詰め手数を求める（反復深化探索）
/// matedIsP1=詰まされるプレイヤー（true=先手）
/// maxDepth=探索限度（デフォ3手）
/// mustGiveCheck=最初の手が必ず王手を与える（詰将棋用）
/// 戻値: 詰む手数（0=詰まない）
int solveTsume(
  List<List<Piece?>> board,
  bool matedIsP1,
  {int maxDepth = 3, bool mustGiveCheck = false}
) {
  // 既に詰んでいるか確認
  if (isCheckmate(board, matedIsP1)) return 0;

  // 反復深化: 1手詰 → 2手詰 → ... と試す
  for (int d = 1; d <= maxDepth; d++) {
    if (mustGiveCheck) {
      if (_canMateWithFirstCheck(board, matedIsP1, d)) {
        return d;
      }
    } else {
      if (_canMateInExactly(board, matedIsP1, d)) {
        return d;
      }
    }
  }
  return 0;
}

/// 最初の手が「必ず王手」という条件で、敵方がN手で詰ませられるか
/// （詰将棋は初手が王手である必要がある）
bool _canMateWithFirstCheck(
  List<List<Piece?>> board,
  bool matedIsP1,
  int depthRemaining,
) {
  if (depthRemaining == 0) {
    return isCheckmate(board, matedIsP1);
  }

  final attacker = !matedIsP1;
  final allMoves = _allLegalMoves(board, attacker);

  for (final move in allMoves) {
    // ★必ず王手★
    if (!givesCheck(board, move, attacker)) continue;

    final nextBoard = applyMove(board, move, attacker);

    // 以降は通常の詰み探索
    if (_canMateInExactly(nextBoard, matedIsP1, depthRemaining - 1)) {
      return true;
    }
  }

  return false;
}

/// 敵方がN手で確実に詰ませられるか（最短詰み探索）
bool _canMateInExactly(
  List<List<Piece?>> board,
  bool matedIsP1,
  int depthRemaining,
) {
  if (depthRemaining == 0) {
    return isCheckmate(board, matedIsP1);
  }

  final attacker = !matedIsP1; // 攻撃側

  // 攻撃側の全合法手を列挙
  final allMoves = _allLegalMoves(board, attacker);

  // 「全ての守りに勝つ手」が存在するか
  for (final move in allMoves) {
    // 王手以外は詰めに関係ない
    if (!givesCheck(board, move, attacker)) continue;

    final nextBoard = applyMove(board, move, attacker);

    // この手を打った後、相手が詰むかどうか
    if (_canMateInExactly(nextBoard, matedIsP1, depthRemaining - 1)) {
      return true; // この手で詰ませられる可能性がある
    }
  }

  return false;
}

/// 盤上の全合法移動手を生成
List<AMove> _allLegalMoves(List<List<Piece?>> board, bool player) {
  final moves = <AMove>[];

  // 盤上の駒を動かす
  for (int fr = 0; fr < 9; fr++) {
    for (int fc = 0; fc < 9; fc++) {
      final p = board[fr][fc];
      if (p == null || p.isPlayer1 != player) continue;

      // このマスから動かせる全マスへ
      for (int tr = 0; tr < 9; tr++) {
        for (int tc = 0; tc < 9; tc++) {
          if (board[tr][tc] != null && board[tr][tc]!.isPlayer1 == player) {
            continue; // 自分の駒が行き先にある
          }

          // 移動が合法か確認
          if (!canMove(board, fr, fc, tr, tc)) continue;

          // 成るべき手を列挙
          final mustPromote = p.mustPromote(tr);
          if (mustPromote) {
            moves.add(AMove(
              fr: fr,
              fc: fc,
              tr: tr,
              tc: tc,
              promote: true,
            ));
          } else if (p.canPromote) {
            // 成る手と成らない手の両方
            moves.add(AMove(
              fr: fr,
              fc: fc,
              tr: tr,
              tc: tc,
              promote: false,
            ));
            moves.add(AMove(
              fr: fr,
              fc: fc,
              tr: tr,
              tc: tc,
              promote: true,
            ));
          } else {
            // 成れない駒
            moves.add(AMove(
              fr: fr,
              fc: fc,
              tr: tr,
              tc: tc,
              promote: false,
            ));
          }
        }
      }
    }
  }

  return moves;
}
