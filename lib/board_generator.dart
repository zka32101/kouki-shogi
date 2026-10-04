// lib/board_generator.dart
// 実戦的な局面をランダムに生成
// 用途: 問題の自動生成に使用する盤面を提供

import 'dart:math';
import 'piece.dart';
import 'rule_validator.dart';

class BoardGenerator {
  final Random _random = Random();

  /// 実戦的な「玉が危ない局面」を生成（詰め問題用）
  /// 後手玉が敵陣で、攻撃されやすい形
  List<List<Piece?>> generateDangerousPosition() {
    final board = _emptyBoard();

    // 後手玉を敵陣に配置
    board[_random.nextInt(3)][_random.nextInt(9)] =
        const Piece(PieceType.king, false);

    // 先手玉を安全な位置に
    board[8][_random.nextInt(9)] = const Piece(PieceType.king, true);

    // 攻撃駒（大駒）を配置
    _addAttackPieces(board);

    // 守り駒を配置
    _addDefensePieces(board);

    // ★ ルール検証: 将棋の基本ルール違反をチェック ★
    final violations = validateBoard(board);
    if (violations.isNotEmpty) {
      // ルール違反があれば再試行（再帰）
      return generateDangerousPosition();
    }

    return board;
  }

  /// 手筋問題用の局面を生成
  /// 「駒が取れそう」な配置
  List<List<Piece?>> generateTacticsPosition() {
    final board = _emptyBoard();

    // 両玉を配置
    board[0][_random.nextInt(9)] = const Piece(PieceType.king, false);
    board[8][_random.nextInt(9)] = const Piece(PieceType.king, true);

    // 後手の大駒を配置（狙われやすく）
    if (_random.nextBool()) {
      board[_random.nextInt(7) + 1][_random.nextInt(9)] =
          const Piece(PieceType.rook, false);
    } else {
      board[_random.nextInt(7) + 1][_random.nextInt(9)] =
          const Piece(PieceType.bishop, false);
    }

    // 先手の攻撃駒
    final startRow = _random.nextInt(7) + 2;
    if (_random.nextBool()) {
      board[startRow][_random.nextInt(9)] = const Piece(PieceType.rook, true);
    } else {
      board[startRow][_random.nextInt(9)] = const Piece(PieceType.bishop, true);
    }

    // 周辺の駒を配置
    _addMiscPieces(board);

    // ★ ルール検証: 将棋の基本ルール違反をチェック ★
    final violations = validateBoard(board);
    if (violations.isNotEmpty) {
      // ルール違反があれば再試行（再帰）
      return generateTacticsPosition();
    }

    return board;
  }

  /// 囲い崩し問題用の局面を生成
  /// 後手が囲いを構成した配置
  List<List<Piece?>> generateCastlePosition() {
    final board = _emptyBoard();

    // 後手玉（美濃囲い風）
    board[1][1] = const Piece(PieceType.king, false);
    board[1][2] = const Piece(PieceType.gold, false);
    board[2][2] = const Piece(PieceType.silver, false);
    board[0][0] = const Piece(PieceType.lance, false);
    board[2][0] = const Piece(PieceType.pawn, false);
    board[2][1] = const Piece(PieceType.pawn, false);
    board[2][3] = const Piece(PieceType.pawn, false);

    // 先手玉
    board[8][_random.nextInt(9)] = const Piece(PieceType.king, true);

    // 先手の攻撃駒
    if (_random.nextBool()) {
      board[_random.nextInt(5) + 3][_random.nextInt(9)] =
          const Piece(PieceType.rook, true);
    } else {
      board[_random.nextInt(5) + 3][_random.nextInt(9)] =
          const Piece(PieceType.bishop, true);
    }

    // ★ ルール検証: 将棋の基本ルール違反をチェック ★
    final violations = validateBoard(board);
    if (violations.isNotEmpty) {
      // ルール違反があれば再試行（再帰）
      return generateCastlePosition();
    }

    return board;
  }

  // =================== 内部ヘルパー ===================

  List<List<Piece?>> _emptyBoard() =>
      List.generate(9, (_) => List<Piece?>.filled(9, null));

  void _addAttackPieces(List<List<Piece?>> board) {
    final types = [PieceType.rook, PieceType.bishop, PieceType.knight];
    for (int i = 0; i < 2; i++) {
      final type = types[_random.nextInt(types.length)];
      int r, c;
      do {
        r = _random.nextInt(6) + 2;
        c = _random.nextInt(9);
      } while (board[r][c] != null);
      board[r][c] = Piece(type, true);
    }
  }

  void _addDefensePieces(List<List<Piece?>> board) {
    for (int i = 0; i < 3; i++) {
      int r, c;
      do {
        r = _random.nextInt(2);
        c = _random.nextInt(9);
      } while (board[r][c] != null);
      board[r][c] = const Piece(PieceType.pawn, false);
    }
  }

  void _addMiscPieces(List<List<Piece?>> board) {
    // 周辺の歩を追加
    for (int i = 0; i < 4; i++) {
      int r, c;
      do {
        r = _random.nextInt(9);
        c = _random.nextInt(9);
      } while (board[r][c] != null);
      board[r][c] = Piece(
        _random.nextBool() ? PieceType.pawn : PieceType.pawn,
        _random.nextBool(),
      );
    }
  }
}
