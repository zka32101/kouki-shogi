import 'package:flutter_test/flutter_test.dart';
import 'package:shogi_app/logic.dart';
import 'package:shogi_app/piece.dart';

List<List<Piece?>> _empty() =>
    List.generate(9, (_) => List<Piece?>.filled(9, null));

void main() {
  group('GL.initialBoard', () {
    test('places 40 pieces, 20 per side, kings on the back rank', () {
      final b = GL.initialBoard();
      var p1Count = 0, p2Count = 0;
      for (final row in b) {
        for (final p in row) {
          if (p == null) continue;
          p.isPlayer1 ? p1Count++ : p2Count++;
        }
      }
      expect(p1Count, 20);
      expect(p2Count, 20);
      expect(GL.kingPos(b, true), (8, 4));
      expect(GL.kingPos(b, false), (0, 4));
    });
  });

  group('GL.pseudo / GL.legal — basic movement', () {
    test('a pawn moves exactly one square forward', () {
      final b = GL.initialBoard();
      expect(GL.pseudo(b, 6, 4), [(5, 4)]);
    });

    test('a knight has its two forward-jump destinations from the start', () {
      final b = GL.initialBoard();
      // p1 knights start at (8,1) and (8,7); both are boxed in at game start.
      expect(GL.pseudo(b, 8, 1), isEmpty);
    });

    test('legal excludes a move that would expose one\'s own king (pin)', () {
      final b = _empty();
      // p1 king at (8,4); p1 rook at (5,4) pinned by p2 rook at (0,4) along
      // the file. Moving the p1 rook sideways must be illegal.
      b[8][4] = const Piece(PieceType.king, true);
      b[5][4] = const Piece(PieceType.rook, true);
      b[0][4] = const Piece(PieceType.rook, false);
      // Sideways is pseudo-legal for a rook, but must be filtered out.
      expect(GL.pseudo(b, 5, 4), contains((5, 3)));
      expect(GL.legal(b, 5, 4), isNot(contains((5, 3))));
      // Staying on the file (blocking/capturing along the pin line) stays legal.
      expect(GL.legal(b, 5, 4), contains((4, 4)));
    });
  });

  group('GL.inCheck', () {
    test('detects a rook check along an open file', () {
      final b = _empty();
      b[8][4] = const Piece(PieceType.king, true);
      b[0][4] = const Piece(PieceType.rook, false);
      expect(GL.inCheck(b, true), isTrue);
    });

    test('no check when the line is blocked', () {
      final b = _empty();
      b[8][4] = const Piece(PieceType.king, true);
      b[4][4] = const Piece(PieceType.pawn, true);
      b[0][4] = const Piece(PieceType.rook, false);
      expect(GL.inCheck(b, true), isFalse);
    });
  });

  group('GL.hasLegalMove — checkmate', () {
    test('a cornered king with no escape, block, or capture is mate', () {
      final b = _empty();
      // p2 king cornered at (0,0). p1 rook (8,0) covers the file (escape to
      // (1,0) and the check itself). p1 rook (0,8) covers the back rank
      // (escape to (0,1) and the check itself). p1 bishop (8,8) covers the
      // long diagonal (escape to (1,1) and the check itself).
      b[0][0] = const Piece(PieceType.king, false);
      b[8][0] = const Piece(PieceType.rook, true);
      b[0][8] = const Piece(PieceType.rook, true);
      b[8][8] = const Piece(PieceType.bishop, true);
      b[8][4] = const Piece(PieceType.king, true);

      expect(GL.inCheck(b, false), isTrue);
      expect(GL.hasLegalMove(b, false, {}, {}), isFalse);
    });

    test('the same cornered king escapes if one covering piece is removed',
        () {
      final b = _empty();
      b[0][0] = const Piece(PieceType.king, false);
      b[8][0] = const Piece(PieceType.rook, true);
      b[0][8] = const Piece(PieceType.rook, true);
      // Bishop covering (1,1) removed — the king can flee there.
      b[8][4] = const Piece(PieceType.king, true);

      expect(GL.hasLegalMove(b, false, {}, {}), isTrue);
    });
  });

  group('GL.dropSquares — 二歩 (nifu)', () {
    test('excludes the file of an existing unpromoted pawn, allows others',
        () {
      final b = _empty();
      b[8][4] = const Piece(PieceType.king, true);
      b[0][4] = const Piece(PieceType.king, false);
      b[6][3] = const Piece(PieceType.pawn, true);
      final squares =
          GL.dropSquares(b, PieceType.pawn, true, {PieceType.pawn: 1}, {});
      expect(squares.where((s) => s.$2 == 3), isEmpty);
      expect(squares.where((s) => s.$2 == 0), isNotEmpty);
    });
  });

  group('GL.dropSquares — 打ち歩詰め (pawn-drop mate)', () {
    test('excludes a pawn drop that would itself deliver checkmate', () {
      final b = _empty();
      b[0][0] = const Piece(PieceType.king, false);
      // Knight covers (1,0) — the square a king-captures-the-pawn escape
      // would land on — without itself checking the king from (3,1).
      b[3][1] = const Piece(PieceType.knight, true);
      // Rook covers (1,1) and (0,1) along file 1, without reaching (0,0).
      b[2][1] = const Piece(PieceType.rook, true);
      b[8][4] = const Piece(PieceType.king, true);

      final squares =
          GL.dropSquares(b, PieceType.pawn, true, {PieceType.pawn: 1}, {});
      expect(squares, isNot(contains((1, 0))));
    });

    test('allows the same drop once the escape-by-capture square is '
        'undefended', () {
      final b = _empty();
      b[0][0] = const Piece(PieceType.king, false);
      // No knight this time: capturing the dropped pawn now escapes check.
      b[2][1] = const Piece(PieceType.rook, true);
      b[8][4] = const Piece(PieceType.king, true);

      final squares =
          GL.dropSquares(b, PieceType.pawn, true, {PieceType.pawn: 1}, {});
      expect(squares, contains((1, 0)));
    });
  });

  group('RepetitionChecker', () {
    test('declares repetition only on the 4th occurrence of a position', () {
      final checker = RepetitionChecker();
      final b = GL.initialBoard();
      final results = List.generate(
        4,
        (_) => checker.record(b, {}, {}, true),
      );
      expect(results, [false, false, false, true]);
    });

    test('records whether the repeated position was already in check', () {
      final checker = RepetitionChecker();
      final b = _empty();
      b[8][4] = const Piece(PieceType.king, true);
      b[0][4] = const Piece(PieceType.rook, false);
      for (var i = 0; i < 4; i++) {
        checker.record(b, {}, {}, true);
      }
      expect(checker.isConsecutiveCheck(b, {}, {}, true), isTrue);
    });
  });

  group('NyugyokuChecker', () {
    test('scores major pieces at 5 and minor pieces at 1, kings excluded',
        () {
      final b = _empty();
      b[8][4] = const Piece(PieceType.king, true);
      b[7][7] = const Piece(PieceType.rook, true);
      b[6][0] = const Piece(PieceType.pawn, true);
      final (p1, p2) = NyugyokuChecker.calcScores(b, {}, {PieceType.bishop: 1});
      expect(p1, 5 + 1); // board rook (5) + board pawn (1); king excluded
      expect(p2, 5); // bishop in hand
    });

    test('入玉 requires the king to have entered the far 3 ranks', () {
      final farEnough = _empty();
      farEnough[2][4] = const Piece(PieceType.king, true);
      expect(NyugyokuChecker.isNyugyoku(farEnough, true), isTrue);

      final notYet = _empty();
      notYet[3][4] = const Piece(PieceType.king, true);
      expect(NyugyokuChecker.isNyugyoku(notYet, true), isFalse);
    });
  });

  group('Piece promotion rules', () {
    test('a pawn must promote on reaching the far rank, not before', () {
      const p1Pawn = Piece(PieceType.pawn, true);
      expect(p1Pawn.mustPromote(0), isTrue);
      expect(p1Pawn.mustPromote(1), isFalse);
      const p2Pawn = Piece(PieceType.pawn, false);
      expect(p2Pawn.mustPromote(8), isTrue);
      expect(p2Pawn.mustPromote(7), isFalse);
    });

    test('a knight must promote on either of the far two ranks', () {
      const p1Knight = Piece(PieceType.knight, true);
      expect(p1Knight.mustPromote(1), isTrue);
      expect(p1Knight.mustPromote(0), isTrue);
      expect(p1Knight.mustPromote(2), isFalse);
    });

    test('king and gold can never promote', () {
      expect(const Piece(PieceType.king, true).canPromote, isFalse);
      expect(const Piece(PieceType.gold, true).canPromote, isFalse);
    });
  });
}
