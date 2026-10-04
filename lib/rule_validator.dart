// lib/rule_validator.dart
// 将棋のルール検証（盤面妥当性チェック）

import 'piece.dart';

class RuleViolation {
  final String type; // 'pawn_on_edge', 'lance_on_edge', 'knight_on_edge_or_adjacent'
  final String description;
  final int row;
  final int col;

  RuleViolation({
    required this.type,
    required this.description,
    required this.row,
    required this.col,
  });

  @override
  String toString() => '[$row,$col] $description';
}

/// 盤面のルール違反をチェック
/// 返り値: 違反リスト（空 = OK）
List<RuleViolation> validateBoard(List<List<Piece?>> board) {
  final violations = <RuleViolation>[];

  for (int row = 0; row < 9; row++) {
    for (int col = 0; col < 9; col++) {
      final piece = board[row][col];
      if (piece == null) continue;

      // 先手（P1）の駒
      if (piece.isPlayer1) {
        // 先手の歩は1段目（row=0）に配置禁止
        if (piece.type == PieceType.pawn && row == 0) {
          violations.add(RuleViolation(
            type: 'pawn_on_edge',
            description: '先手の歩が1段目にいます',
            row: row,
            col: col,
          ));
        }

        // 先手の香車は1段目（row=0）に配置禁止
        if (piece.type == PieceType.lance && row == 0) {
          violations.add(RuleViolation(
            type: 'lance_on_edge',
            description: '先手の香車が1段目にいます',
            row: row,
            col: col,
          ));
        }

        // 先手の桂馬は1,2段目（row=0,1）に配置禁止（row=2からは跳べるため合法）
        if (piece.type == PieceType.knight && (row == 0 || row == 1)) {
          violations.add(RuleViolation(
            type: 'knight_on_edge_or_adjacent',
            description: '先手の桂馬が敵陣（1～2段目）にいます',
            row: row,
            col: col,
          ));
        }
      } else {
        // 後手（P2）の駒
        // 後手の歩は9段目（row=8）に配置禁止
        if (piece.type == PieceType.pawn && row == 8) {
          violations.add(RuleViolation(
            type: 'pawn_on_edge',
            description: '後手の歩が9段目にいます',
            row: row,
            col: col,
          ));
        }

        // 後手の香車は9段目（row=8）に配置禁止
        if (piece.type == PieceType.lance && row == 8) {
          violations.add(RuleViolation(
            type: 'lance_on_edge',
            description: '後手の香車が9段目にいます',
            row: row,
            col: col,
          ));
        }

        // 後手の桂馬は8,9段目（row=7,8）に配置禁止（row=6からは跳べるため合法）
        if (piece.type == PieceType.knight && (row == 7 || row == 8)) {
          violations.add(RuleViolation(
            type: 'knight_on_edge_or_adjacent',
            description: '後手の桂馬が敵陣（8～9段目）にいます',
            row: row,
            col: col,
          ));
        }
      }
    }
  }

  // 二歩チェック（同じ筋に同じ手番の歩が2枚以上）
  for (int col = 0; col < 9; col++) {
    int p1Pawns = 0, p2Pawns = 0;
    int p1Row = -1, p2Row = -1;
    for (int row = 0; row < 9; row++) {
      final piece = board[row][col];
      if (piece == null || piece.type != PieceType.pawn) continue;
      if (piece.isPlayer1) {
        p1Pawns++;
        p1Row = row;
      } else {
        p2Pawns++;
        p2Row = row;
      }
    }
    if (p1Pawns >= 2) {
      violations.add(RuleViolation(
        type: 'nifu',
        description: '先手の歩が${9 - col}筋に2枚以上あります（二歩）',
        row: p1Row,
        col: col,
      ));
    }
    if (p2Pawns >= 2) {
      violations.add(RuleViolation(
        type: 'nifu',
        description: '後手の歩が${9 - col}筋に2枚以上あります（二歩）',
        row: p2Row,
        col: col,
      ));
    }
  }

  return violations;
}

/// ボード全体が有効か判定（簡易版）
bool isBoardValid(List<List<Piece?>> board) {
  return validateBoard(board).isEmpty;
}
