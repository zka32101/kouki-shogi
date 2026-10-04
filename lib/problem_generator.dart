// lib/problem_generator.dart
// 盤面から自動的に問題を生成・検証する
// 用途: bookminer抽出SFEN → 詰将棋・手筋・囲い崩し問題に変換

import 'piece.dart';
import 'sfen_parser.dart';
import 'tactics_engine.dart';
import 'tsume_solver.dart';
import 'tesuji_problems.dart';
import 'castle_break_problems.dart';
import 'rule_validator.dart';

class ProblemGenerator {
  /// SFEN盤面から詰将棋問題を生成
  /// 条件: 最初の手が「必ず王手」（詰将棋の定義）
  /// 戻値: 問題が成立すれば TesujiProb、失敗すれば null
  TesujiProb? generateTsumeFromSfen(
    String sfen, {
    required String id,
    required String title,
    int maxDepth = 3,
  }) {
    try {
      final parsed = parseSfen(sfen);
      final board = parsed.board;
      final isP1Turn = parsed.isP1Turn;

      // ★ ルール検証: 将棋の基本ルール違反をチェック ★
      final violations = validateBoard(board);
      if (violations.isNotEmpty) {
        return null; // ルール違反がある盤面は問題として採用しない
      }

      // 詰み判定（最初の手は必ず王手）
      final tsumeDepth = solveTsume(
        board,
        !isP1Turn, // 敵玉が詰まされる
        maxDepth: maxDepth,
        mustGiveCheck: true, // ★必ず王手条件★
      );

      if (tsumeDepth == 0) return null; // 詰まない

      // 正解手を見つける
      final answer = _findFirstCheckMove(board, isP1Turn);
      if (answer == null) return null;

      return TesujiProb(
        id: id,
        title: title,
        category: '詰め',
        explanation: '${tsumeDepth}手詰。最初の手が王手で、後は詰みに向かいます。',
        board: board,
        p1Hand: parsed.p1Hand,
        p2Hand: parsed.p2Hand,
        p1Turn: isP1Turn,
        answer: answer,
        sourceUrl: null,
        sourceTitle: 'Auto-generated from bookminer',
        difficulty: tsumeDepth <= 2 ? '初級' : tsumeDepth <= 4 ? '中級' : '上級',
      );
    } catch (e) {
      return null;
    }
  }

  /// 手筋問題を生成
  /// 条件: 答え手が「王手 OR 駒当たり」
  TesujiProb? generateTesujiFromSfen(
    String sfen, {
    required String id,
    required String title,
    required String category,
  }) {
    try {
      final parsed = parseSfen(sfen);
      final board = parsed.board;
      final isP1Turn = parsed.isP1Turn;

      // ★ ルール検証: 将棋の基本ルール違反をチェック ★
      final violations = validateBoard(board);
      if (violations.isNotEmpty) {
        return null; // ルール違反がある盤面は問題として採用しない
      }

      // 候補手を列挙
      final moves = _allLegalMoves(board, isP1Turn);
      for (final move in moves) {
        final nextBoard = applyMove(board, move, isP1Turn);
        final check = inCheck(nextBoard, !isP1Turn);
        final threat = threatenedEnemyCount(nextBoard, move.tr, move.tc, isP1Turn);

        // カテゴリ別の条件チェック
        bool valid = false;
        switch (category) {
          case '飛車取り':
            final captured = board[move.tr][move.tc]?.baseType;
            valid = captured == PieceType.rook || threat > 0;
            break;
          case '王手金取り':
            valid = check && threat > 0;
            break;
          case '両取り':
            valid = threat >= 2;
            break;
          case '守り':
            final beforeCheck = inCheck(board, isP1Turn);
            valid = beforeCheck && !check;
            break;
          default:
            valid = check || threat > 0;
        }

        if (valid) {
          return TesujiProb(
            id: id,
            title: title,
            category: category,
            explanation: 'Auto-generated: $category problem',
            board: board,
            p1Hand: parsed.p1Hand,
            p2Hand: parsed.p2Hand,
            p1Turn: isP1Turn,
            answer: move,
            sourceUrl: null,
            sourceTitle: 'Auto-generated from bookminer',
            difficulty: '中級',
          );
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 囲い崩し問題を生成
  CastleProb? generateCastleBreakFromSfen(
    String sfen, {
    required String id,
    required String title,
  }) {
    try {
      final parsed = parseSfen(sfen);
      final board = parsed.board;

      // ★ ルール検証: 将棋の基本ルール違反をチェック ★
      final violations = validateBoard(board);
      if (violations.isNotEmpty) {
        return null; // ルール違反がある盤面は問題として採用しない
      }

      // 先手が駒を動かす
      final moves = _allLegalMoves(board, true);
      for (final move in moves) {
        final nextBoard = applyMove(board, move, true);
        final check = inCheck(nextBoard, false);
        final captured = board[move.tr][move.tc]?.baseType;
        final threat = threatenedEnemyCount(nextBoard, move.tr, move.tc, true);

        // 囲い崩し条件: 王手 OR 駒取り OR 脅し
        final valid = check ||
            (captured != null && captured != PieceType.pawn) ||
            threat > 0;

        if (valid) {
          return CastleProb(
            id: id,
            title: title,
            castle: '不明',
            description: 'Auto-generated castle break problem',
            board: board,
            p1Hand: parsed.p1Hand,
            answer: move,
            explanation: 'Find the breakthrough move.',
            sourceUrl: null,
            sourceTitle: 'Auto-generated from bookminer',
            difficulty: 2,
          );
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

/// 最初の王手手を見つける
AMove? _findFirstCheckMove(List<List<Piece?>> board, bool player) {
  final moves = _allLegalMoves(board, player);
  for (final move in moves) {
    if (givesCheck(board, move, player)) {
      return move;
    }
  }
  return null;
}

/// 盤上の全合法移動手を生成（tsume_solver.dart と同じ）
List<AMove> _allLegalMoves(List<List<Piece?>> board, bool player) {
  final moves = <AMove>[];

  for (int fr = 0; fr < 9; fr++) {
    for (int fc = 0; fc < 9; fc++) {
      final p = board[fr][fc];
      if (p == null || p.isPlayer1 != player) continue;

      for (int tr = 0; tr < 9; tr++) {
        for (int tc = 0; tc < 9; tc++) {
          if (board[tr][tc] != null && board[tr][tc]!.isPlayer1 == player) {
            continue;
          }

          if (!canMove(board, fr, fc, tr, tc)) continue;

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
