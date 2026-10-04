// lib/services/lishogi_service.dart
// lishogi.org パズルAPI + SFEN/USI パーサー

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../piece.dart';
import '../logic.dart';

// ── lishogi パズルモデル ─────────────────────────────────────

class LishogiPuzzle {
  final String id;
  final int rating;
  final List<String> solution; // USI 形式の正解手順
  final String initialSfen;    // 開始局面 (SFEN)
  final bool isPlayer1Turn;    // true = 先手番
  final List<String> themes;

  const LishogiPuzzle({
    required this.id,
    required this.rating,
    required this.solution,
    required this.initialSfen,
    required this.isPlayer1Turn,
    required this.themes,
  });
}

// ── ボード状態 ────────────────────────────────────────────────

class PuzzleBoardState {
  final List<List<Piece?>> board;
  final Map<PieceType, int> p1Hand;
  final Map<PieceType, int> p2Hand;
  final bool isPlayer1Turn;

  const PuzzleBoardState({
    required this.board,
    required this.p1Hand,
    required this.p2Hand,
    required this.isPlayer1Turn,
  });
}

// ── SFEN パーサー ─────────────────────────────────────────────

class SfenParser {
  static const _pieceMap = {
    'k': PieceType.king,
    'r': PieceType.rook,
    'b': PieceType.bishop,
    'g': PieceType.gold,
    's': PieceType.silver,
    'n': PieceType.knight,
    'l': PieceType.lance,
    'p': PieceType.pawn,
  };

  static const _promotedMap = {
    'r': PieceType.promotedRook,
    'b': PieceType.promotedBishop,
    's': PieceType.promotedSilver,
    'n': PieceType.promotedKnight,
    'l': PieceType.promotedLance,
    'p': PieceType.promotedPawn,
  };

  /// SFEN文字列から PuzzleBoardState を生成する。
  /// SFEN形式: "{board} {color} {hand} {moveCount}"
  static PuzzleBoardState? parse(String sfen) {
    try {
      final parts = sfen.trim().split(' ');
      if (parts.length < 3) return null;

      final boardStr = parts[0];
      final colorStr = parts[1];
      final handStr = parts[2];

      final board = _parseBoard(boardStr);
      if (board == null) return null;

      final isP1Turn = colorStr == 'b';
      final (p1Hand, p2Hand) = _parseHand(handStr);

      return PuzzleBoardState(
        board: board,
        p1Hand: p1Hand,
        p2Hand: p2Hand,
        isPlayer1Turn: isP1Turn,
      );
    } catch (_) {
      return null;
    }
  }

  static List<List<Piece?>>? _parseBoard(String boardStr) {
    final ranks = boardStr.split('/');
    if (ranks.length != 9) return null;

    final board = List.generate(9, (_) => List<Piece?>.filled(9, null));

    for (int rankIdx = 0; rankIdx < 9; rankIdx++) {
      final rank = ranks[rankIdx];
      int colIdx = 0;
      int i = 0;

      while (i < rank.length && colIdx < 9) {
        final ch = rank[i];

        if (ch == '+') {
          i++;
          if (i >= rank.length) break;
          final next = rank[i].toLowerCase();
          final baseType = _promotedMap[next];
          if (baseType != null) {
            final isP1 = rank[i] == rank[i].toUpperCase();
            board[rankIdx][colIdx] = Piece(baseType, isP1);
            colIdx++;
          }
          i++;
        } else if (RegExp(r'[1-9]').hasMatch(ch)) {
          colIdx += int.parse(ch);
          i++;
        } else if (RegExp(r'[a-zA-Z]').hasMatch(ch)) {
          final lower = ch.toLowerCase();
          final type = _pieceMap[lower];
          if (type != null) {
            final isP1 = ch == ch.toUpperCase();
            board[rankIdx][colIdx] = Piece(type, isP1);
            colIdx++;
          }
          i++;
        } else {
          i++;
        }
      }
    }

    return board;
  }

  static (Map<PieceType, int>, Map<PieceType, int>) _parseHand(String hand) {
    final p1Hand = <PieceType, int>{};
    final p2Hand = <PieceType, int>{};

    if (hand == '-') return (p1Hand, p2Hand);

    int i = 0;
    while (i < hand.length) {
      int count = 1;
      // 数字を読む
      if (RegExp(r'[0-9]').hasMatch(hand[i])) {
        int j = i;
        while (j < hand.length && RegExp(r'[0-9]').hasMatch(hand[j])) j++;
        count = int.parse(hand.substring(i, j));
        i = j;
      }
      if (i >= hand.length) break;

      final ch = hand[i];
      final lower = ch.toLowerCase();
      final type = _pieceMap[lower];
      if (type != null) {
        final isP1 = ch == ch.toUpperCase();
        final map = isP1 ? p1Hand : p2Hand;
        map[type] = (map[type] ?? 0) + count;
      }
      i++;
    }

    return (p1Hand, p2Hand);
  }
}

// ── USI 手パーサー ────────────────────────────────────────────

class UsiMove {
  final int fr, fc, tr, tc; // -1 = drop
  final PieceType? drop;
  final bool promote;

  const UsiMove({
    required this.fr,
    required this.fc,
    required this.tr,
    required this.tc,
    this.drop,
    this.promote = false,
  });
}

class UsiParser {
  static const _pieceMap = {
    'R': PieceType.rook,
    'B': PieceType.bishop,
    'G': PieceType.gold,
    'S': PieceType.silver,
    'N': PieceType.knight,
    'L': PieceType.lance,
    'P': PieceType.pawn,
  };

  /// USI 形式の手を内部座標に変換する。
  /// 例: "7g7f" → board move, "P*5e" → drop
  static UsiMove? parse(String usi) {
    try {
      if (usi.length >= 4 && usi[1] == '*') {
        // Drop: "{piece}*{file}{rank}"
        final pieceChar = usi[0].toUpperCase();
        final type = _pieceMap[pieceChar];
        if (type == null) return null;

        final toFile = int.parse(usi[2]); // 1-9
        final toRankChar = usi[3];         // a-i
        final toRow = toRankChar.codeUnitAt(0) - 'a'.codeUnitAt(0);
        final toCol = 9 - toFile;

        return UsiMove(fr: -1, fc: -1, tr: toRow, tc: toCol, drop: type);
      }

      if (usi.length >= 4) {
        // Board move: "{file}{rank}{file}{rank}+?"
        final fromFile = int.parse(usi[0]);
        final fromRankChar = usi[1];
        final toFile = int.parse(usi[2]);
        final toRankChar = usi[3];
        final promote = usi.length > 4 && usi[4] == '+';

        final fromRow = fromRankChar.codeUnitAt(0) - 'a'.codeUnitAt(0);
        final fromCol = 9 - fromFile;
        final toRow = toRankChar.codeUnitAt(0) - 'a'.codeUnitAt(0);
        final toCol = 9 - toFile;

        return UsiMove(
          fr: fromRow,
          fc: fromCol,
          tr: toRow,
          tc: toCol,
          promote: promote,
        );
      }
    } catch (_) {}
    return null;
  }

  /// UsiMove を KifuMove に変換する（棋譜記録用）
  static KifuMove toKifuMove(UsiMove usi, List<List<Piece?>> board,
      Map<PieceType, int> p1Hand, Map<PieceType, int> p2Hand,
      bool isP1, int moveNum) {
    if (usi.drop != null) {
      final file = 9 - usi.tc;
      final rank = usi.tr + 1;
      final kanjis = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];
      final note = '$file${kanjis[rank - 1]}${pieceLabel(usi.drop!)}打';
      return KifuMove(
        moveNum, isP1, note,
        fr: -1, fc: -1, tr: usi.tr, tc: usi.tc, drop: usi.drop,
      );
    }

    final piece = board[usi.fr][usi.fc];
    final pLabel = piece?.label ?? '';
    final file = 9 - usi.tc;
    final rank = usi.tr + 1;
    final kanjis = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];
    final suffix = usi.promote ? '成' : '';
    final note = '$file${kanjis[rank - 1]}$pLabel$suffix';

    return KifuMove(
      moveNum, isP1, note,
      fr: usi.fr, fc: usi.fc, tr: usi.tr, tc: usi.tc, promote: usi.promote,
    );
  }
}

// ── lishogi API クライアント ─────────────────────────────────

class LishogiService {
  static const _baseUrl = 'https://lishogi.org';
  static const _timeout = Duration(seconds: 10);

  /// 今日のデイリーパズルを取得する
  static Future<LishogiPuzzle?> fetchDailyPuzzle() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/puzzle/daily');
      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(_timeout);

      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return _parsePuzzle(json);
    } catch (_) {
      return null;
    }
  }

  /// ランダムなパズルを取得する
  static Future<LishogiPuzzle?> fetchRandomPuzzle() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/puzzle/next');
      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(_timeout);

      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return _parsePuzzle(json);
    } catch (_) {
      return null;
    }
  }

  static LishogiPuzzle? _parsePuzzle(Map<String, dynamic> json) {
    try {
      final puzzleData = json['puzzle'] as Map<String, dynamic>;
      final id = puzzleData['id'] as String? ?? '';
      final rating = puzzleData['rating'] as int? ?? 1500;
      final themes = (puzzleData['themes'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      // 正解手順 (USI形式)
      final solutionRaw = puzzleData['solution'] as List?;
      final solution = solutionRaw?.map((e) => e.toString()).toList() ?? [];

      // 開始局面 SFEN
      // lishogi は puzzle.initialSfen または game から取得
      String? sfen = puzzleData['initialSfen'] as String?;
      if (sfen == null) {
        // ゲームデータから初期局面を再構築（フォールバック）
        final gameData = json['game'] as Map<String, dynamic>?;
        sfen = gameData?['initialFen'] as String? ??
               gameData?['initialSfen'] as String?;
      }

      if (sfen == null || solution.isEmpty) return null;

      // 手番を SFEN から取得
      final sfenParts = sfen.split(' ');
      final isP1Turn = sfenParts.length >= 2 && sfenParts[1] == 'b';

      return LishogiPuzzle(
        id: id,
        rating: rating,
        solution: solution,
        initialSfen: sfen,
        isPlayer1Turn: isP1Turn,
        themes: themes,
      );
    } catch (_) {
      return null;
    }
  }

  /// パズルの最初のボード状態を取得する
  static PuzzleBoardState? parsePuzzleBoard(LishogiPuzzle puzzle) {
    return SfenParser.parse(puzzle.initialSfen);
  }

  /// USI 解答手を KifuMove に変換し、盤面を適用した状態を返す
  static (KifuMove, PuzzleBoardState)? applyUsiMove(
    String usiStr,
    PuzzleBoardState state,
    bool isP1,
    int moveNum,
  ) {
    final usi = UsiParser.parse(usiStr);
    if (usi == null) return null;

    final move = UsiParser.toKifuMove(
      usi, state.board, state.p1Hand, state.p2Hand, isP1, moveNum,
    );

    final newBoard = GL.copy(state.board);
    final newP1Hand = Map<PieceType, int>.from(state.p1Hand);
    final newP2Hand = Map<PieceType, int>.from(state.p2Hand);

    try {
      GL.applyKifuMove(newBoard, newP1Hand, newP2Hand, move);
    } catch (_) {
      return null;
    }

    return (
      move,
      PuzzleBoardState(
        board: newBoard,
        p1Hand: newP1Hand,
        p2Hand: newP2Hand,
        isPlayer1Turn: !isP1,
      ),
    );
  }
}
