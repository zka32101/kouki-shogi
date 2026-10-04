// lib/tsume_builtin_problems.dart
// tsume_screen.dart に埋め込まれていた内蔵詰将棋問題データを純Dartファイルへ分離。
// tsume_screen.dart は flutter/material.dart 等に依存するため `dart run` では
// コンパイルできず、tool/validate_tsume_screen.dart から検証できなかった。
// このファイルは piece.dart / logic.dart のみに依存する純Dartのため検証可能。

import 'piece.dart';
import 'logic.dart';

class TsumeProb {
  final String title;
  final int moves;
  final List<List<Piece?>> board;
  final Map<PieceType, int> p1Hand;
  final Map<PieceType, int> p2Hand;
  final bool p1Turn;
  // 手順: 偶数インデックス(0,2,4)=先手の手、奇数インデックス(1,3)=後手の応手
  final List<AMove> solution;
  final String explanation;

  const TsumeProb({
    required this.title,
    required this.moves,
    required this.board,
    required this.p1Hand,
    required this.p2Hand,
    // ignore: unused_element_parameter
  this.p1Turn = true,
    required this.solution,
    this.explanation = '',
  });
}

List<List<Piece?>> _empty() =>
    List.generate(9, (_) => List<Piece?>.filled(9, null));

List<TsumeProb> buildTsumeProblems({bool skipStartPositionFilter = false}) {
  final list = <TsumeProb>[];

  // ===== 1手詰め ① =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[0][1] = Piece(PieceType.silver, true);
    b[2][1] = Piece(PieceType.gold, true);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '1手詰め ①',
      moves: 1,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 2, fc: 1, tr: 1, tc: 0),
      ],
      explanation: '金を8三から9二へ進めて王手。玉は金を取ろうとしても、金は8一の銀に守られていて取れません。8一の銀も金に守られ、8二には金の利きがあるため、玉に逃げ場はなく詰みです。',
    ));
  }

  // ===== 1手詰め ② =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);
    b[2][8] = Piece(PieceType.gold, true);
    b[4][4] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '1手詰め ②',
      moves: 1,
      board: b,
      p1Hand: {PieceType.gold: 1},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 1, tc: 7, drop: PieceType.gold),
      ],
      explanation: '持ち駒の金を 2二 に打つ。玉の逃げ場は 2一 / 2二 / 1二 の3マスのみで、いずれも打った金自身、または盤上の 1三 の金によって守られているため、詰み。',
    ));
  }

  // ===== 1手詰め ③ =====
  // 先手龍で王手・詰め
  // (旧版は龍・金が共に開始局面から後手玉に王手をかけてしまう不正な局面だった。
  //  TsumeEngineでの検証により発覚・修正: 龍は斜め1マスで5二に踏み込み、
  //  桂馬が5二を紐付けする形に変更)
  // 後手玉 5一(0,4)、先手龍 4三(2,3)、先手桂 4四(3,3)
  // 手順: 龍 4三→5二(1,4)で王手（龍の八方効きで四方封鎖、桂が5二を守る）
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);          // 後手玉 5一(0,4)
    b[8][4] = Piece(PieceType.king, true);            // 先手玉 5九(8,4)
    b[2][3] = Piece(PieceType.promotedRook, true);   // 先手龍 4三(2,3)
    b[3][3] = Piece(PieceType.knight, true);          // 先手桂 4四(3,3) ← 5二を守る
    list.add(TsumeProb(
      title: '1手詰め ③',
      moves: 1,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 2, fc: 3, tr: 1, tc: 4), // 龍 4三→5二(斜め、王手・詰み)
      ],
      explanation: '龍を4三から斜めに5二へ踏み込んで王手。龍が隣接する8マス全てを利き、桂馬が5二を守っているため取られず詰み。',
    ));
  }

  // ===== 1手詰め ④ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[2][3] = Piece(PieceType.bishop, true);
    b[3][2] = Piece(PieceType.knight, true);
    b[5][3] = Piece(PieceType.promotedRook, true);
    b[8][4] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '1手詰め ④',
      moves: 1,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 5, fc: 3, tr: 5, tc: 0),
      ],
      explanation: '龍(6六=6六)を9筋の9六へ移動。9筋が開通し9一の後手玉に王手。玉の逃げ場を検証: 9二は龍の乗る9筋上にあり依然王手放置になるため不可。8一は6三の角の利き(斜め二マス)が支配。8二は7四の桂の利きが支配。よって後手玉は合駒も抵抗もできず詰み。',
    ));
  }

  // ===== 1手詰め ⑤ =====
  // 持ち駒の銀を打って詰める
  // (旧版は金・飛が共に開始局面から王手をかけてしまう不正な局面だった。
  //  TsumeEngineでの検証により発覚・修正)
  // 後手玉 9一(0,8)、先手金 7三(2,7) ← 8二・9二を守る、先手銀 8三(1,6) ← 8一を守る
  // (金・銀だけで開始局面から後手玉の全逃げ場を封鎖してしまい、王手はして
  //  いないものの合法手が無い＝終端状態になっていたため、後手に歩を持たせて
  //  開始局面に合法手を残した)
  // 手順: 銀 8二(1,7)打ち
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);   // 後手玉 9一(0,8)
    b[8][8] = Piece(PieceType.king, true);    // 先手玉 9九(8,8)
    b[2][7] = Piece(PieceType.gold, true);    // 先手金 7三(2,7) ← 8二・9二を守る
    b[1][6] = Piece(PieceType.silver, true);  // 先手銀 8三(1,6) ← 8一を守る
    b[4][4] = Piece(PieceType.pawn, false);   // 後手歩（開始局面が終端状態になるのを防ぐ）
    list.add(TsumeProb(
      title: '1手詰め ⑤',
      moves: 1,
      board: b,
      p1Hand: {PieceType.silver: 1},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 1, tc: 7, drop: PieceType.silver), // 銀 8二打ち(王手・詰み)
      ],
      explanation: '持ち駒の銀を8二に打って王手をかけます。8一は銀が、9二は金が守っているため詰み。',
    ));
  }

  // ===== 1手詰め ⑥ =====
  // (旧版は馬・金2枚・銀の全てが開始局面から王手をかけてしまう不正な局面
  //  だった。TsumeEngineでの検証により発覚・修正)
  // 後手玉 5一(0,4)、先手馬 5三(2,4)、先手金 7二(1,2) ← 4一・4二を守る、
  // 先手桂 3四(3,6) ← 6二を守る
  // 手順: 馬 5三→6二(1,5)で王手（馬の八方効きで四方封鎖、桂が6二を守る）
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);           // 後手玉 5一(0,4)
    b[8][4] = Piece(PieceType.king, true);             // 先手玉 5九(8,4)
    b[2][4] = Piece(PieceType.promotedBishop, true);   // 先手馬 5三(2,4)
    b[1][2] = Piece(PieceType.gold, true);             // 先手金 7二(1,2) ← 4一・4二を守る
    b[3][6] = Piece(PieceType.knight, true);           // 先手桂 3四(3,6) ← 6二を守る
    list.add(TsumeProb(
      title: '1手詰め ⑥',
      moves: 1,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 2, fc: 4, tr: 1, tc: 5), // 馬 5三→6二(斜め、王手・詰み)
      ],
      explanation: '馬を5三から斜めに6二へ踏み込んで王手。馬が隣接8マスを利き、桂馬が6二を守っているため取られず詰み。',
    ));
  }

  // ===== 1手詰め ⑦ =====
  // 持ち駒の金を打って端玉を詰める
  // (旧版は金・飛が共に開始局面から王手をかけてしまう不正な局面だった。
  //  TsumeEngineでの検証により発覚・修正: 桂馬1枚で打った金を守る形に変更)
  // 後手玉 1一(0,0)、先手桂 2四(3,1) ← 1二を守る
  // 手順: 金 1二(1,0)打ち（金自身が2一・2二を利き、桂が金を守るため詰み）
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);   // 後手玉 1一(0,0)
    b[8][8] = Piece(PieceType.king, true);    // 先手玉 9九(8,8)
    b[3][1] = Piece(PieceType.knight, true);  // 先手桂 2四(3,1) ← 1二を守る
    list.add(TsumeProb(
      title: '1手詰め ⑦',
      moves: 1,
      board: b,
      p1Hand: {PieceType.gold: 1},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 1, tc: 0, drop: PieceType.gold), // 金 1二打ち(王手・詰み)
      ],
      explanation: '持ち駒の金を1二に打って王手をかけます。金自身が2一・2二を塞ぎ、桂馬が金を守っているため詰み。',
    ));
  }

  // ===== 3手詰め ① =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][1] = Piece(PieceType.pawn, false);
    b[0][2] = Piece(PieceType.king, false);
    b[1][1] = Piece(PieceType.lance, false);
    b[1][3] = Piece(PieceType.pawn, false);
    b[2][2] = Piece(PieceType.pawn, false);
    b[2][5] = Piece(PieceType.knight, true);
    b[3][5] = Piece(PieceType.knight, true);
    b[4][2] = Piece(PieceType.rook, true);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '3手詰め ①',
      moves: 3,
      board: b,
      p1Hand: {PieceType.gold: 1},
      p2Hand: {},
      solution: [
        AMove(fr: 4, fc: 2, tr: 2, tc: 2),
        AMove(fr: 0, fc: 2, tr: 0, tc: 3),
        AMove(fr: -1, fc: -1, tr: 1, tc: 4, drop: PieceType.gold),
      ],
      explanation: '飛で後手歩を取りながら王手（column2に沿った縦の利き）。後手玉（7一）の逃げ場は、（8一）は自身の歩、（8二）は自身の香、（6二）は自身の歩で塞がれており、（7二）は飛の利きで塞がっているため、唯一の逃げ場である（6一）へしか移動できない。最後に金を（5二）に打つと、（6一）への王手（金の斜め前）となり、逃げ場（7一）/（7二）は飛の縦利き、（5一）は桂（4三）の利き、（6二）は自身の歩で塞がり、（5二）の金自体も桂（4四）に守られているため後手玉はどこにも動けず、合駒も利かない隣接王手のため詰み。',
    ));
  }

  // ===== 3手詰め ② =====
  // 龍で後手歩を取り王手→後手玉2一に逃げ→角(馬)成りで詰み
  // 後手玉 1一(0,0)、先手龍 1六(5,0)、先手金 3三(2,2)、先手角 2三(2,1)、後手歩 1四(3,0)
  // 手順:
  //   1. 龍 1六→1四(後手歩取り、縦で王手)
  //   2. 後手玉 1一→2一(0,1)逃げ(唯一の逃げ: 1二は龍縦・2二は金斜め封鎖)
  //   3. 角 2三→3二成(1,2)、王手。2一の逃げ道は
  //      1一=龍の縦利き、3一=馬の縦利き、2二=金と馬の利きで全て封鎖、
  //      馬自体も金が守っているため取れず、詰み。
  // (以前は3手目に龍を1一へ寄せる手を解として登録していたが、
  //  1一の龍は無防備で王が取れてしまい実際には詰んでいなかった。
  //  TsumeEngine.findMate による検証で不成立と判明したため、
  //  角を追加して正しく詰む形に修正した)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);          // 後手玉 1一(0,0)
    b[8][8] = Piece(PieceType.king, true);            // 先手玉 9九(8,8)
    b[5][0] = Piece(PieceType.promotedRook, true);   // 先手龍 1六(5,0)
    b[2][2] = Piece(PieceType.gold, true);            // 先手金 3三(2,2)
    b[2][1] = Piece(PieceType.bishop, true);          // 先手角 2三(2,1)
    b[3][0] = Piece(PieceType.pawn, false);           // 後手歩 1四(3,0) ← 龍の王手を遮断
    list.add(TsumeProb(
      title: '3手詰め ②',
      moves: 3,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 5, fc: 0, tr: 3, tc: 0),  // 龍 1六→1四(後手歩取り、縦で王手)
        AMove(fr: 0, fc: 0, tr: 0, tc: 1),  // 後手玉 1一→2一(0,1)逃げ
        AMove(fr: 2, fc: 1, tr: 1, tc: 2, promote: true),  // 角 2三→3二成(1,2)、詰み
      ],
      explanation: '龍で後手歩を取りながら王手。後手玉は2一に逃げるしかなく、角が3二に成って馬になると、金と龍の利きで全逃げ道が塞がれ詰みです。',
    ));
  }

  // ===== 3手詰め ③ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);
    b[2][3] = Piece(PieceType.rook, true);
    b[3][5] = Piece(PieceType.knight, true);
    b[8][0] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '3手詰め ③',
      moves: 3,
      board: b,
      p1Hand: {PieceType.gold: 1},
      p2Hand: {},
      solution: [
        AMove(fr: 2, fc: 3, tr: 2, tc: 8),
        AMove(fr: 0, fc: 8, tr: 0, tc: 7),
        AMove(fr: -1, fc: -1, tr: 1, tc: 6, drop: PieceType.gold),
      ],
      explanation: '飛を横に9七へ進めて王手（8一の縦筋を利かせる）。後手玉は8二には行けず（飛が縦に利く）、逃げ場は8一の隣の7一のみ。玉が7一へ逃げたところに、持ち駒の金を6二に打って王手。金自身の利きで6一・7二を、飛の利きで8一を、桂馬の守りで6二の金自体が取られないようにして、全ての逃げ道が塞がり詰み。',
    ));
  }

  // ===== 3手詰め ④ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);
    b[1][7] = Piece(PieceType.pawn, false);
    b[1][8] = Piece(PieceType.pawn, false);
    b[4][6] = Piece(PieceType.knight, true);
    b[8][4] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '3手詰め ④',
      moves: 3,
      board: b,
      p1Hand: {PieceType.gold: 1},
      p2Hand: {},
      solution: [
        AMove(fr: 4, fc: 6, tr: 2, tc: 7),
        AMove(fr: 0, fc: 8, tr: 0, tc: 7),
        AMove(fr: -1, fc: -1, tr: 0, tc: 6, drop: PieceType.gold),
      ],
      explanation: 'Redesigned as a fresh but same-flavor board (checking-knight + gold-drop mate) using a corner king position instead of the original center-file setup, since every variant of the original geometry (rook checking from an adjacent-to-king square) is provably unfixable: promoting that rook into a Dragon King always seals both diagonal flight squares of the king simultaneously, and any defender added to make the rook capture-proof also makes the Dragon King\'s instant mate legal, producing a guaranteed 1-move cook. Center-file knight-check variants had the mirror problem: a stray Gold could be hand-dropped adjacent to the king and, riding its own wide 3-square forward arc plus whatever knight was defending it, complete an instant mate on its own regardless of the intended line.\\n\\nFinal design: Gote king is placed in the corner （1一）. Two Gote pawns wall off （2二） and （1二） by occupation (not by attack), so those squares can never be legal king escapes nor legal Gold-drop squares — this sidesteps the whole \'defended square + adjacent Gold drop = instant mate\' failure mode entirely, since occupation-based blocking carries no exploitable defended-square side effect. Move 1: Sente Knight （3五）->（2三） delivers check on （1一）; the king\'s only escapes, （2二） and （1二）, are blocked by its own pawns, so it is forced to （2一）. Move 2: King （1一）->（2一）. Move 3: Sente drops Gold at （3一）, checking （2一）; （1一） is covered by the knight at （2三）, （3二） is covered by the gold itself, and （2二）/（1二） remain blocked by the gote pawns — checkmate, and the gold at （3一） is itself defended by the knight so it cannot be captured.\\n\\nVerified with the project\'s TsumeEngine: SOLUTION_OK (all sente moves are check, final position is checkmate) and NO_COOK_CONFIRMED (exhaustive depth-1 search over all legal sente moves, including every promotion option, found no mate shorter than 3 moves).',
    ));
  }

  // ===== 3手詰め ⑤ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[2][2] = Piece(PieceType.silver, true);
    b[3][0] = Piece(PieceType.gold, true);
    b[3][4] = Piece(PieceType.rook, true);
    b[4][1] = Piece(PieceType.knight, true);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '3手詰め ⑤',
      moves: 3,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 3, fc: 4, tr: 0, tc: 4),
        AMove(fr: 0, fc: 0, tr: 1, tc: 0),
        AMove(fr: 3, fc: 0, tr: 2, tc: 0),
      ],
      explanation: '飛を5一（0,4）へ縦に進めて1段目全体に王手。玉は9二（1,0）にしか逃げられません（9二の隣接マスは銀と飛でふさがれています）。金を9三（2,0）へ進めて再度王手。金は桂馬（8五, （8五））に守られているため玉は取れず、金・飛・銀の利きで9二周囲の全ての逃げ場が塞がれ詰みとなります。',
    ));
  }

  // ===== 3手詰め ⑥ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);
    b[1][5] = Piece(PieceType.promotedBishop, true);
    b[2][8] = Piece(PieceType.knight, true);
    b[3][6] = Piece(PieceType.gold, true);
    b[8][0] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '3手詰め ⑥',
      moves: 3,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 1, fc: 5, tr: 2, tc: 6),
        AMove(fr: 0, fc: 8, tr: 1, tc: 8),
        AMove(fr: 3, fc: 6, tr: 2, tc: 7),
      ],
      explanation: '馬を7三に進めて斜めに9一の後手玉へ遠見の王手。玉は9二には桂馬の利きで、8二には馬の利きでどちらも逃げられず、唯一合法な8一へ逃げる。金が7二に進んで斜めに王手し、玉に合法手がなくなり詰み。桂馬が9二への逃げ道を封じる役割を担っている。',
    ));
  }

  // ===== 3手詰め ⑦ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);
    b[2][2] = Piece(PieceType.knight, true);
    b[2][4] = Piece(PieceType.pawn, false);
    b[2][7] = Piece(PieceType.knight, true);
    b[3][5] = Piece(PieceType.knight, true);
    b[3][6] = Piece(PieceType.knight, true);
    b[6][4] = Piece(PieceType.rook, true);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '3手詰め ⑦',
      moves: 3,
      board: b,
      p1Hand: {PieceType.silver: 1},
      p2Hand: {},
      solution: [
        AMove(fr: 6, fc: 4, tr: 2, tc: 4, promote: true),
        AMove(fr: 0, fc: 4, tr: 0, tc: 5),
        AMove(fr: -1, fc: -1, tr: 1, tc: 5, drop: PieceType.silver),
      ],
      explanation: '飛を4筋を上がって6二から2四へ、後手の歩を取りながら成り、龍にして王手（龍の斜め利きが3三・3五に届き、直前の1三・1五を押さえ、縦の利きで1四も押さえるため、玉は2五（コード上0,5）にしか逃げられません）。後手玉は5二（0,5）に逃げるほかなく、そこへ持ち駒の銀を1五（1,5）に打って王手。銀の直進の利きで2四（0,4）と隣接する1四(0,4への通し)は龍が、2六（0,6)は桂馬（2三）が、1六（3二）は桂馬（4四）が塞ぎ、銀自身は桂馬（3四）に守られているため銀を取ることもできず、詰みとなります。',
    ));
  }

  // ===== 5手詰め ① =====
  // (Workflow並列エージェント第2ラウンドがTsumeEngineで余詰みなし・行き所のない駒なしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[1][1] = Piece(PieceType.pawn, false);
    b[4][1] = Piece(PieceType.knight, true);
    b[5][0] = Piece(PieceType.knight, true);
    b[5][1] = Piece(PieceType.knight, true);
    b[5][2] = Piece(PieceType.knight, true);
    b[8][3] = Piece(PieceType.rook, true);
    list.add(TsumeProb(
      title: '5手詰め ①',
      moves: 5,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 8, fc: 3, tr: 0, tc: 3),
        AMove(fr: 0, fc: 0, tr: 1, tc: 0),
        AMove(fr: 5, fc: 2, tr: 3, tc: 1),
        AMove(fr: 1, fc: 0, tr: 2, tc: 1),
        AMove(fr: 0, fc: 3, tr: 2, tc: 3),
      ],
      explanation: '後手玉は1一（0,0）、自分の歩が2二（1,1）にあり退路を1つ塞いでいる。①飛を1四（6一）へ進めて1段目を制圧する横王手。玉は1一段の逃げ場を失い、2一（9二）へ強制的に逃げる。②その2一の玉に対し、桂を（7六）から（8四）へ跳ねて王手（桂は敵陣の外なので成りの選択肢がなく、成り由来のクックが生じない）。玉の周囲は先に配置した3頭の桂（（8五）（9六）（8六））と自分の歩がすべての逃げ場（2二・2三・3一・3二・3三）を塞いでおり、唯一の合法手である3二（8三）へ逃げるほかない。③最後に飛を（6一）から（6三）へ横に運び、2段目を通して3二の玉に王手。3二の周囲8マスはすでに歩・3頭の桂によってすべて塞がれており（桂で王手した桂自身も別の桂に守られていて取れない）、合法手が一切ないため詰み。',
    ));
  }

  // ===== 5手詰め ② =====
  // (Workflow並列エージェント第2ラウンドがTsumeEngineで余詰みなし・行き所のない駒なしを自己検証して再設計)
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);
    b[1][4] = Piece(PieceType.pawn, false);
    b[2][2] = Piece(PieceType.gold, true);
    b[3][4] = Piece(PieceType.knight, true);
    b[3][7] = Piece(PieceType.knight, true);
    b[3][8] = Piece(PieceType.knight, true);
    b[4][7] = Piece(PieceType.knight, true);
    b[4][8] = Piece(PieceType.knight, true);
    b[8][4] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '5手詰め ②',
      moves: 5,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 2, fc: 2, tr: 1, tc: 3),
        AMove(fr: 0, fc: 4, tr: 0, tc: 5),
        AMove(fr: 4, fc: 7, tr: 2, tc: 6),
        AMove(fr: 0, fc: 5, tr: 0, tc: 6),
        AMove(fr: 4, fc: 8, tr: 2, tc: 7),
      ],
      explanation: '後手玉は5一（中央寄り）で、自陣の歩が4一に置かれ前方を塞いでいます。①金が7三から6二へ進んで王手（玉は5一から4一へは行けず、唯一の逃げ場である5二へ）。②桂馬が2四から3二へ跳んで王手（桂馬の利きが4一と5一の斜めを押さえ、玉は唯一残る4二への逃げ場に移動）※実際の逃げ場は6一。③最後に別の桂馬が2三から3三へ跳んで王手をかけ、残る全ての逃げ場（5一・7一・6一・6二・7二）が金・他の桂馬2枚によってすべて塞がれており、詰みとなります。桂馬3枚と金1枚が周囲の逃げ道を分担して封鎖する構成です。',
    ));
  }

  // ===== 5手詰め ③ =====
  // (Workflow並列エージェント第2ラウンドがTsumeEngineで余詰みなし・行き所のない駒なしを自己検証して再設計)
  {
    final b = _empty();
    b[0][6] = Piece(PieceType.king, false);
    b[1][5] = Piece(PieceType.pawn, false);
    b[1][7] = Piece(PieceType.pawn, false);
    b[1][8] = Piece(PieceType.pawn, false);
    b[2][3] = Piece(PieceType.pawn, true);
    b[2][4] = Piece(PieceType.knight, true);
    b[4][3] = Piece(PieceType.rook, true);
    b[4][7] = Piece(PieceType.knight, true);
    b[8][4] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '5手詰め ③',
      moves: 5,
      board: b,
      p1Hand: {PieceType.gold: 1},
      p2Hand: {},
      solution: [
        AMove(fr: 4, fc: 3, tr: 4, tc: 6),
        AMove(fr: 0, fc: 6, tr: 0, tc: 7),
        AMove(fr: 4, fc: 7, tr: 2, tc: 8),
        AMove(fr: 0, fc: 7, tr: 0, tc: 8),
        AMove(fr: -1, fc: -1, tr: 0, tc: 7, drop: PieceType.gold),
      ],
      explanation: 'Completely redesigned from scratch (new board, new pieces, new solution) per the prior round\'s recommendation, rather than patching the old corner-king geometry.\n\nSetup: Gote king starts at （3一） — not a corner, and given two of its own pawns at （4二） and （2二） that wall off its own escape squares (plus a third pawn at （1二） that walls off the eventual corner). Sente has Rook （6五）, a blocking Pawn （6三） directly above the rook\'s own start square (this is essential — an empty file under the rook lets it slide all the way to the back rank and promote into a Dragon King for an accidental mate-in-1, so the blocker pawn is load-bearing), a static Knight （5三）, a second Knight （2五）, and one Gold in hand.\n\n1. Rook （6五）->（3五）: check along the file. King\'s neighbors （4一）/（4二） are blocked by the static Knight and the gote pawn; （3二） is on the rook\'s file; （2二） is blocked by a gote pawn. Only （2一） is legal.\n2. King （3一）->（2一） (forced).\n3. Knight （2五）->（1三）: check on （2一） (a knight attacks two squares two rows back diagonally). Landing on （1三） rather than （3三） is important — landing on （3三） would sit on the rook\'s own file and block its own check, and the alternate landing （1三） had to be checked against the gote pawn at （1二） being able to capture it, which is why the pawn stays at （1二） rather than a square that could capture the knight. King\'s neighbors （3一）/（3二） are covered by the rook\'s file, （2二）/（1二） are blocked by gote pawns, leaving only （1一）.\n4. King （2一）->（1一） (forced).\n5. Gold drop at （2一）: checks the king directly. （2一） is defended by the Knight sitting at （1三） (so the king cannot capture it), while （2二） and （1二） remain blocked by gote\'s own pawns. No legal reply — checkmate.\n\nVerified with the project\'s TsumeEngine (tool script run against H:\\マイドライブ\\apps\\shogi_app\\lib\\logic.dart / tsume_engine.dart): START_OK (gote not in check and has a legal move at the start), NO_DEAD_PIECES, SOLUTION_OK (every sente move is check and gote has no legal move after move 5), and NO_COOK_CONFIRMED (exhaustive engine search at depth 1 and depth 3 found no shorter forced mate).',
    ));
  }

  // ===== 5手詰め ④ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '5手詰め ④',
      moves: 5,
      board: b,
      p1Hand: {PieceType.rook: 1, PieceType.gold: 2},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 2, tc: 0, drop: PieceType.rook),
        AMove(fr: 0, fc: 0, tr: 0, tc: 1),
        AMove(fr: 2, fc: 0, tr: 2, tc: 1, promote: true),
        AMove(fr: 0, fc: 1, tr: 0, tc: 0),
        AMove(fr: -1, fc: -1, tr: 0, tc: 1, drop: PieceType.gold),
      ],
      explanation: '後手玉は9一（盤面（9一））の一隅。1手目、飛車を9三（9三）へ打って王手（縦の利きで9一を睨む）。2手目、玉は8一（8一）へ逃げるほかない（9二・9一への復帰はいずれも次の飛車の利きに入るため不可）。3手目、飛車が9二（8三）へ寄って成り、竜王とする（王手）。4手目、玉は9一（9一）へ戻るしかない（8二・8一は竜の利き）。5手目、持ち駒の金を8一（8一）に打って詰み——玉のどの逃げ場（8一・8二・9二）も竜と金の利きで塞がれており、金は竜に守られているため取ることもできない。盤上の駒は両玉のみとし、飛車と金2枚をすべて持ち駒からの補充とすることで、原題にあった「桂馬などの余剰駒」を排除しつつ、王手の連続性のみで詰みを強制する構成にした。',
    ));
  }

  // ===== 5手詰め ⑤ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[3][1] = Piece(PieceType.knight, true);
    b[3][2] = Piece(PieceType.knight, true);
    b[4][3] = Piece(PieceType.knight, true);
    b[4][4] = Piece(PieceType.knight, true);
    b[5][3] = Piece(PieceType.rook, true);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '5手詰め ⑤',
      moves: 5,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 5, fc: 3, tr: 5, tc: 0),
        AMove(fr: 0, fc: 0, tr: 0, tc: 1),
        AMove(fr: 4, fc: 3, tr: 2, tc: 2),
        AMove(fr: 0, fc: 1, tr: 0, tc: 2),
        AMove(fr: 4, fc: 4, tr: 2, tc: 3),
      ],
      explanation: '飛(5三)を9筋(5一…盤面表記では列0)へ寄せて王手。玉は8一（8一）へ逃げるほかない。次に桂(4三)が7三（7三）へ跳んで王手し、玉は7一（7一）へ追われる。最後にもう一枚の桂(4四)が7四（6三）へ跳んで王手し、周囲がすべて味方の桂(8四・8五相当の（8四）（7四）)で塞がれているため詰み。',
    ));
  }

  // ===== 5手詰め ⑥ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);
    b[2][4] = Piece(PieceType.promotedRook, true);
    b[3][5] = Piece(PieceType.knight, true);
    b[4][8] = Piece(PieceType.gold, true);
    b[8][0] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '5手詰め ⑥',
      moves: 5,
      board: b,
      p1Hand: {},
      p2Hand: {},
      solution: [
        AMove(fr: 2, fc: 4, tr: 2, tc: 8),
        AMove(fr: 0, fc: 8, tr: 0, tc: 7),
        AMove(fr: 2, fc: 8, tr: 2, tc: 7),
        AMove(fr: 0, fc: 7, tr: 0, tc: 6),
        AMove(fr: 2, fc: 7, tr: 1, tc: 6),
      ],
      explanation: '龍で横に連続王手して後手玉を端から追い出し、最後に龍が7二（内部座標で行1列6）に入って詰めます。金が9四（内部座標で行4列8）から逃げ道を塞いでいます。修正版では元図にあった先手の銀（3一、内部座標3一）を削除しました。この銀は正解手順では一度も動かず、実は龍の1回目の王手（2,4→2,8）で後手玉が2,7に逃げた直後、銀が1,7へ動くだけで即詰み（3手詰め）になってしまう「余詰め」の原因でした。銀を除去してもその他の駒（龍・桂・金・王）だけで元の5手の攻め筋・詰み形はそのまま成立します。',
    ));
  }


  // ===== 追加問題 (⑧以降) =====
  _buildExtraProblems(list);

  if (skipStartPositionFilter) return list;

  // 開始局面で後手玉がすでに王手または詰みの問題を除外
  list.retainWhere((p) =>
      !GL.inCheck(p.board, false) &&
      GL.hasLegalMove(p.board, false, p.p2Hand, p.p1Hand));
  return list;
}

/// 追加の詰将棋問題（21問→33問）
void _buildExtraProblems(List<TsumeProb> list) {
  // ── 1手詰め ⑧ ─────────────────────────────
  // 後手玉9一(0,8), 先手金7二(1,6), 持ち駒:金1
  // 手順: 金8二(1,7)打ち → step(-1,1)=(0,8)=9一✓
  // 逃げ場: 8一→金(1,6)step(-1,1)=(0,7)✓封鎖 / 9二→打った金step(0,1)=(1,8)✓封鎖 / 8二→打った金を取ると金(1,6)step(0,1)=(1,7)✓違法手
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king,  false); // 後手玉 9一
    b[8][0] = Piece(PieceType.king,  true);  // 先手玉 1九
    b[1][6] = Piece(PieceType.gold,  true);  // 先手金 7二
    list.add(TsumeProb(
      title: '1手詰め ⑧', moves: 1, board: b,
      p1Hand: {PieceType.gold: 1}, p2Hand: {},
      solution: [AMove(fr: -1, fc: -1, tr: 1, tc: 7, drop: PieceType.gold)],
      explanation: '金を8二に打って9一に王手。8一は7二の金が、9二と8二は打った金が封鎖しています。',
    ));
  }

  // ── 1手詰め ⑨ ─────────────────────────────
  // 後手玉1一(0,0), 先手龍3二(1,2), 持ち駒:銀1
  // 手順: 銀1二(1,0)打ち → step(-1,0)=(0,0)=1一✓
  // 逃げ場: 2一→龍step(-1,-1)=(0,1)✓ / 1二→取ると龍slide(0,-1)=(1,1),(1,0)✓違法手 / 2二→龍slide(0,-1)=(1,1)✓
  // (旧版は龍が開始局面で既に後手玉の全逃げ場を封鎖しており、王手はしていない
  //  ものの後手に合法手が無い＝開始局面が既に終端状態という不正な局面だった。
  //  TsumeEngineでの検証により発覚・修正: 後手に歩を1枚持たせ、
  //  開始局面で合法手が存在するようにした)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king,         false); // 後手玉 1一
    b[8][8] = Piece(PieceType.king,         true);  // 先手玉 9九
    b[1][2] = Piece(PieceType.promotedRook, true);  // 先手龍 3二
    b[0][1] = Piece(PieceType.pawn,         false); // 後手歩 2一（開始局面が終端状態になるのを防ぐ）
    list.add(TsumeProb(
      title: '1手詰め ⑨', moves: 1, board: b,
      p1Hand: {PieceType.silver: 1}, p2Hand: {},
      solution: [AMove(fr: -1, fc: -1, tr: 1, tc: 0, drop: PieceType.silver)],
      explanation: '銀を1二に打って1一に王手。2一は龍の斜め効き、1二は銀を取ると龍の横効き、2二は龍の横効きで封鎖されています。',
    ));
  }

  // ===== 1手詰め ⑩ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[1][0] = Piece(PieceType.pawn, false);
    b[2][1] = Piece(PieceType.gold, true);
    b[2][3] = Piece(PieceType.bishop, true);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '1手詰め ⑩',
      moves: 1,
      board: b,
      p1Hand: {PieceType.bishop: 1},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 2, tc: 2, drop: PieceType.bishop),
      ],
      explanation: '角を3三に打って斜めに1一へ王手。逃げ場所は（8一）が既存の角（6三）の利き、（8二）が金（8三）の利きで塞がれ、（9二）は後手自身の歩で移動不可のため、詰み。',
    ));
  }

  // ── 3手詰め ⑧ ─────────────────────────────
  // 飛成り→後手玉4一逃げ→金打ち詰め
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king,   false); // 後手玉 5一
    b[1][4] = Piece(PieceType.silver, false); // 後手銀 5二(飛縦を止める)
    b[3][4] = Piece(PieceType.rook,   true);  // 先手飛 5四
    b[2][2] = Piece(PieceType.gold,   true);  // 先手金 3三(3二・4二封鎖)
    b[8][8] = Piece(PieceType.king,   true);  // 先手玉 9九
    list.add(TsumeProb(
      title: '3手詰め ⑧', moves: 3, board: b,
      p1Hand: {PieceType.gold: 1}, p2Hand: {},
      solution: [
        AMove(fr: 3, fc: 4, tr: 1, tc: 4, promote: true), // 飛→5二成(後手銀取り龍) 王手
        AMove(fr: 0, fc: 4, tr: 0, tc: 3),                // 後手玉 5一→4一逃げ
        AMove(fr: -1, fc: -1, tr: 1, tc: 3, drop: PieceType.gold), // 金4二打ち 詰み
      ],
      explanation: '飛が後手銀を取りながら成って龍に。後手玉は4一に逃げるしかなく、金を4二に打って詰み。龍・金の協力が鍵。',
    ));
  }

  // ===== 3手詰め ⑨ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[2][2] = Piece(PieceType.knight, true);
    b[3][0] = Piece(PieceType.gold, true);
    b[3][2] = Piece(PieceType.knight, true);
    b[4][1] = Piece(PieceType.knight, true);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '3手詰め ⑨',
      moves: 3,
      board: b,
      p1Hand: {PieceType.bishop: 1},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 1, tc: 1, drop: PieceType.bishop),
        AMove(fr: 0, fc: 0, tr: 1, tc: 0),
        AMove(fr: 3, fc: 0, tr: 2, tc: 0),
      ],
      explanation: '後手玉は9一の隅。1手目、角を9二相当の（8二）に打って斜めから王手（2二・8八方向）。玉は9一のまま角を取ることはできない（（8二）は桂馬（7四）が利かせて守っているため）。唯一の逃げ場は（9二）（8一相当）のみ：（8一）は桂馬（7三）が跳び利かせて塞ぎ、（8二）は角を取ると桂馬に取り返されるので実質逃げられない。2手目、玉は（9二）へ移動。3手目、金を（9四）から（9三）へ進めて王手。金は（9二）（王手）に加え（8二）・（8三）を制し、金自体も桂馬（8五）に守られているため玉は取れず、（9一）は角、（8一）は桂馬（7三）、（8二）は角＋桂馬（7四）により全て塞がれており詰み。',
    ));
  }

  // ── 3手詰め ⑩ ─────────────────────────────
  // 龍横移動で後手銀取り王手→玉1一逃げ→香打ち詰め
  // 後手玉2一(0,1), 後手銀3一(0,2)で龍の横を止める
  // 先手龍4一(0,3): 横(0,2)=後手銀止→出発点王手なし ✓
  // 先手銀2三(2,1): step(-1,-1)=(1,0)=1二, step(-1,0)=(1,1)=2二を封鎖
  {
    final b = _empty();
    b[0][1] = Piece(PieceType.king,         false); // 後手玉 2一
    b[0][2] = Piece(PieceType.silver,       false); // 後手銀 3一(龍の横を止める)
    b[8][8] = Piece(PieceType.king,         true);  // 先手玉 9九
    b[0][3] = Piece(PieceType.promotedRook, true);  // 先手龍 4一
    b[2][1] = Piece(PieceType.silver,       true);  // 先手銀 2三(1二・2二封鎖)
    list.add(TsumeProb(
      title: '3手詰め ⑩', moves: 3, board: b,
      p1Hand: {PieceType.lance: 1}, p2Hand: {},
      solution: [
        AMove(fr: 0, fc: 3, tr: 0, tc: 2),                            // 龍 4一→3一(後手銀取り) 王手
        AMove(fr: 0, fc: 1, tr: 0, tc: 0),                            // 後手玉 2一→1一逃げ
        AMove(fr: -1, fc: -1, tr: 2, tc: 0, drop: PieceType.lance),   // 香 1三打ち 詰み
      ],
      explanation: '龍が後手銀を取りながら2一の後手玉に横王手。玉は1一に逃げるしかなく、香を1三に打って詰み。龍の横効きと香の縦効きの合わせ技。',
    ));
  }

  // ── 1手詰め ⑪ ─────────────────────────────
  // (旧版は飛・金が共に開始局面から王手をかける不正な局面な上、解答手も
  //  後手玉のマスへ直接移動する不成立な手だった。TsumeEngineでの検証により
  //  発覚・修正: 飛を横から9二へ成り込む形に変更)
  // 後手玉9一(0,8), 先手飛6二(1,3), 先手金7三(2,7) ← 9二を守る
  // 手順: 飛 6二→9二(1,8)成り 王手（龍の八方効きで8一・8二を封鎖、金が龍を守る）
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);  // 後手玉 9一
    b[8][0] = Piece(PieceType.king, true);   // 先手玉 1九
    b[1][3] = Piece(PieceType.rook, true);   // 先手飛 6二
    b[2][7] = Piece(PieceType.gold, true);   // 先手金 7三 ← 9二を守る
    list.add(TsumeProb(
      title: '1手詰め ⑪', moves: 1, board: b,
      p1Hand: {}, p2Hand: {},
      solution: [AMove(fr: 1, fc: 3, tr: 1, tc: 8, promote: true)], // 飛→9二成
      explanation: '飛車を6二から9二へ横に成り込み、龍王にして後手玉に王手。龍が隣接8マスを利き、金が龍を守るため詰み。',
    ));
  }

  // ── 1手詰め ⑫ ─────────────────────────────
  // (旧版は馬・金2枚が全て開始局面から王手をかけてしまう不正な局面だった。
  //  TsumeEngineでの検証により発覚・修正)
  // 後手玉5一(0,4), 先手馬4三(2,3), 先手桂3六(3,5) ← 5二を守る
  // 手順: 馬 4三→5二(1,4) 王手（馬の八方効きで四方封鎖、桂が5二を守る）
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);           // 後手玉 5一
    b[8][4] = Piece(PieceType.king, true);            // 先手玉 5九
    b[2][3] = Piece(PieceType.promotedBishop, true);  // 先手馬 4三
    b[3][5] = Piece(PieceType.knight, true);          // 先手桂 3六 ← 5二を守る
    list.add(TsumeProb(
      title: '1手詰め ⑫', moves: 1, board: b,
      p1Hand: {}, p2Hand: {},
      solution: [AMove(fr: 2, fc: 3, tr: 1, tc: 4)], // 馬 4三→5二 王手
      explanation: '馬を4三から斜めに5二へ踏み込んで王手。馬が隣接8マスを利き、桂馬が5二を守るため取られず詰み。',
    ));
  }

  // ===== 3手詰め ⑪ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[1][2] = Piece(PieceType.silver, true);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '3手詰め ⑪',
      moves: 3,
      board: b,
      p1Hand: {PieceType.gold: 2},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 0, tc: 1, drop: PieceType.gold),
        AMove(fr: 0, fc: 0, tr: 1, tc: 0),
        AMove(fr: -1, fc: -1, tr: 2, tc: 1, drop: PieceType.gold),
      ],
      explanation: '金を（8一）（1一の隣の2一相当）に打って王手。玉の逃げ場は（9二）の一マスのみなので、玉はそこへ逃げる。続けてもう一枚の金を（8三）に打つと、1一の銀の利きでこの金は取られず、玉の全ての逃げ場(（9一）は最初の金、（8二）と（9三）は今打った金、（8一）と（8三）自体は銀の利きで防御)が塞がれ詰み。',
    ));
  }

  // ===== 3手詰め ⑫ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][8] = Piece(PieceType.king, false);
    b[1][7] = Piece(PieceType.lance, true);
    b[2][6] = Piece(PieceType.silver, true);
    b[3][7] = Piece(PieceType.gold, true);
    b[3][8] = Piece(PieceType.gold, true);
    b[8][0] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '3手詰め ⑫',
      moves: 3,
      board: b,
      p1Hand: {PieceType.knight: 1},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 2, tc: 7, drop: PieceType.knight),
        AMove(fr: 0, fc: 8, tr: 1, tc: 8),
        AMove(fr: 3, fc: 8, tr: 2, tc: 8),
      ],
      explanation: 'Redesigned as a fresh 3-move mate (kept the theme: knight drop forces the cornered king out, then a piece delivers mate) since patching the original piece set could not avoid the cook.\n\nOriginal cook: with the given pieces, sente\'s gold at  could move directly to , checking the still-cornered king and, by itself (defended by the dragon), covering all three of the corner king\'s flight squares — mate in 1, without needing the knight drop at all (or via the promotedRook/gold combo more generally). This is a structural property of a defended gold delivering a diagonal check to a corner king (it always covers all 3 corner flight squares), so no small patch of the original board reliably fixes it — a fresh layout was built instead.\n\nNew board: Gote king at （1一） [1一]. Sente: Lance at （2二） [2二] (attacks only vertically along its own file, so it sits diagonally adjacent to the king without itself giving check, and covers square （2一）); Silver at （3三） [3三] (defends the lance at （2二） so the king cannot safely capture it); two Golds at （2四） and （1四） [4二, 4一] (one moves to （1三） for the final mate, the other stays put purely to defend that landing square). Sente hand: knight ×1.\n\nSolution:\n1. Sente drops knight at （2三） [3二] — check (knight attacks （3一） and （1一）); king\'s only safe square is （1二） [2一] since （2一） is covered by the lance and （2二） is occupied by the (defended) lance.\n2. Gote king moves （1一）→（1二） (forced).\n3. Sente\'s gold at （1四） moves to （1三） [3一] — check via straight-forward move. All of king\'s neighbor squares are now covered: （2一） by the lance, （1一） by the knight, （2二） by the lance (defended by silver and by the moved gold), （2三） by the knight itself (defended by both golds), （1三） by the moved gold itself (defended by the stationary gold at （2四）, whose line only fully "arrives" there but the key point is it directly attacks （1三）). Checkmate.\n\nVerified with the project\'s TsumeEngine (H:\\マイドライブ\\apps\\shogi_app\\lib\\tsume_engine.dart): the claimed 3-move solution is confirmed as a valid checkmate (SOLUTION_OK), every sente move is check, and no shorter mate exists at depth 1 (NO_COOK_CONFIRMED). All 5 board pieces plus the hand knight are load-bearing (no dead/removable pieces): lance blocks/covers （2一）, silver defends the lance, the moving gold delivers the final check and defends the knight\'s square, the stationary gold defends the final gold\'s landing square, and the knight delivers the forcing first check.',
    ));
  }

  // ===== 5手詰め ⑦ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[4][3] = Piece(PieceType.knight, true);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '5手詰め ⑦',
      moves: 5,
      board: b,
      p1Hand: {PieceType.rook: 1, PieceType.gold: 1},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 2, tc: 0, drop: PieceType.rook),
        AMove(fr: 0, fc: 0, tr: 0, tc: 1),
        AMove(fr: 2, fc: 0, tr: 2, tc: 1, promote: true),
        AMove(fr: 0, fc: 1, tr: 0, tc: 0),
        AMove(fr: -1, fc: -1, tr: 0, tc: 1, drop: PieceType.gold),
      ],
      explanation: '飛を2一に打って王手。後手玉は1二（8一）へ逃げるほかない（1一へ行くと飛の効きの列で取れず、王手放置になる分岐は後述）。次に飛を2二へ成って竜にしながら王手（列2の利きと竜の斜め一マスの利きで1一・2一・2二周辺を制圧）。玉は1一（9一）に戻るしかない。最後に金を1二（8一）に打つ。金は1一・1二(自マス)・2二を制圧し、竜が1二・2二・2一を後方支援しているため、玉はどこにも逃げられず、金も竜に守られていて取れない。詰み。',
    ));
  }

  // ===== 5手詰め ⑧ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '5手詰め ⑧',
      moves: 5,
      board: b,
      p1Hand: {PieceType.bishop: 1, PieceType.gold: 1, PieceType.rook: 1},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 2, tc: 2, drop: PieceType.bishop),
        AMove(fr: 0, fc: 0, tr: 1, tc: 0),
        AMove(fr: -1, fc: -1, tr: 1, tc: 1, drop: PieceType.gold),
        AMove(fr: 1, fc: 0, tr: 2, tc: 0),
        AMove(fr: -1, fc: -1, tr: 0, tc: 0, drop: PieceType.rook),
      ],
      explanation: '角打ち(2二)で王手をかけ後手玉を1一へ誘い、金打ち(1一)でさらに追い込む。玉が2一へ逃げたところへ飛車を打って(1一)王手をかける（1一に空いた元の玉の位置）。角が1一/3一への利き、金が2一への退路（金の後退の利き）を止め、飛車が1列・1筋（列0）全体を制圧して詰み。角・金・飛車の打ち込みだけで後手玉を丸裸のまま追い詰める展開。',
    ));
  }

  // ── 1手詰め ⑬ ─────────────────────────────
  // (旧版は銀が開始局面から王手をかけてしまう不正な局面だった。
  //  TsumeEngineでの検証により発覚・修正)
  // 後手玉3一(0,2), 持ち駒金、先手飛4二(1,3) ← 2二・3二を守る、
  // 先手金5二(1,4) ← 4一を守る、先手銀1二(1,0) ← 2一を守る
  // (これらの駒だけで開始局面から後手玉の全逃げ場を封鎖してしまい、王手は
  //  していないものの合法手が無い＝終端状態になっていたため、後手に歩を
  //  持たせて開始局面に合法手を残した)
  {
    final b = _empty();
    b[0][2] = Piece(PieceType.king,   false); // 後手玉 3一
    b[8][8] = Piece(PieceType.king,   true);  // 先手玉 9九
    b[1][3] = Piece(PieceType.rook,   true);  // 先手飛 4二 ← 2二・3二を守る
    b[1][4] = Piece(PieceType.gold,   true);  // 先手金 5二 ← 4一を守る
    b[1][0] = Piece(PieceType.silver, true);  // 先手銀 1二 ← 2一を守る
    b[4][4] = Piece(PieceType.pawn,   false); // 後手歩（開始局面が終端状態になるのを防ぐ）
    list.add(TsumeProb(
      title: '1手詰め ⑬', moves: 1, board: b,
      p1Hand: {PieceType.gold: 1}, p2Hand: {},
      solution: [AMove(fr: -1, fc: -1, tr: 0, tc: 1, drop: PieceType.gold)], // 金2一打ち
      explanation: '金を2一に打って3一の後手玉に王手。4一は金、2二・3二は飛、2一は銀に守られており詰み。',
    ));
  }

  // ===== 3手詰め ⑬ =====
  // (Workflow並列エージェント第2ラウンドがTsumeEngineで余詰みなし・行き所のない駒なしを自己検証して再設計)
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);
    b[1][4] = Piece(PieceType.pawn, false);
    b[2][7] = Piece(PieceType.knight, true);
    b[3][3] = Piece(PieceType.lance, true);
    b[3][5] = Piece(PieceType.knight, true);
    b[5][5] = Piece(PieceType.bishop, true);
    b[8][0] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '3手詰め ⑬',
      moves: 3,
      board: b,
      p1Hand: {PieceType.gold: 1},
      p2Hand: {},
      solution: [
        AMove(fr: 5, fc: 5, tr: 3, tc: 7),
        AMove(fr: 0, fc: 4, tr: 0, tc: 5),
        AMove(fr: -1, fc: -1, tr: 0, tc: 4, drop: PieceType.gold),
      ],
      explanation: '角を4六から2四へ進めて王手。玉が4一へ逃げたところに、持ち駒の金を5一に打って詰みです。',
    ));
  }

  // ===== 5手詰め ⑨ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][0] = Piece(PieceType.king, false);
    b[3][3] = Piece(PieceType.knight, true);
    b[4][3] = Piece(PieceType.knight, true);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '5手詰め ⑨',
      moves: 5,
      board: b,
      p1Hand: {PieceType.pawn: 1, PieceType.gold: 1},
      p2Hand: {},
      solution: [
        AMove(fr: -1, fc: -1, tr: 1, tc: 0, drop: PieceType.pawn),
        AMove(fr: 0, fc: 0, tr: 0, tc: 1),
        AMove(fr: 4, fc: 3, tr: 2, tc: 2),
        AMove(fr: 0, fc: 1, tr: 0, tc: 2),
        AMove(fr: -1, fc: -1, tr: 1, tc: 2, drop: PieceType.gold),
      ],
      explanation: '歩を9二（9二）に打って王手し後手玉を9一→8一（8一）へ追い、8三（6四）にいた桂が6五（7三）へ跳んで王手、玉は7一（7一）へ。最後に金を7二（7二）に打って詰み。手順自体は原案と同一。',
    ));
  }


  // ── 1手詰め ⑭ ─────────────────────────────
  // (旧版は飛が開始局面から王手をかけている上、解答の打ち場所に既に銀が
  //  存在する二重に不正な局面だった。TsumeEngineでの検証により発覚・修正:
  //  飛・銀を削除し金1枚だけで詰む形に簡略化)
  // 後手玉9九(8,8), 先手金8八(7,7)
  {
    final b = _empty();
    b[8][8] = Piece(PieceType.king,  false); // 後手玉 9九
    b[0][0] = Piece(PieceType.king,  true);  // 先手玉 1一
    b[7][7] = Piece(PieceType.gold,  true);  // 先手金 8八
    list.add(TsumeProb(
      title: '1手詰め ⑭', moves: 1, board: b,
      p1Hand: {PieceType.gold: 1}, p2Hand: {},
      solution: [AMove(fr: -1, fc: -1, tr: 7, tc: 8, drop: PieceType.gold)], // 金9八打ち
      explanation: '金を9八に打って9九の後手玉に王手。8八の金と打った金が互いに守り合い、8八金の利きで8九も封鎖されるため詰み。',
    ));
  }

  // ===== 3手詰め ⑭ =====
  // (Workflow並列エージェントがTsumeEngineで余詰みなしを自己検証して再設計)
  {
    final b = _empty();
    b[0][4] = Piece(PieceType.king, false);
    b[1][4] = Piece(PieceType.pawn, false);
    b[2][3] = Piece(PieceType.promotedPawn, true);
    b[2][7] = Piece(PieceType.knight, true);
    b[3][4] = Piece(PieceType.knight, true);
    b[3][7] = Piece(PieceType.knight, true);
    b[8][8] = Piece(PieceType.king, true);
    list.add(TsumeProb(
      title: '3手詰め ⑭',
      moves: 3,
      board: b,
      p1Hand: {PieceType.gold: 1},
      p2Hand: {},
      solution: [
        AMove(fr: 2, fc: 3, tr: 1, tc: 3),
        AMove(fr: 0, fc: 4, tr: 0, tc: 5),
        AMove(fr: -1, fc: -1, tr: 1, tc: 5, drop: PieceType.gold),
      ],
      explanation: 'と金を6二（6二）へ進めて斜めに5一（5一）の後手玉へ王手。玉は6一（4一）に逃げるが、6二（4二）に金を打つと金自身の利きと桂の守りで全逃げ道が塞がり詰み。と金と金の連携。',
    ));
  }
}

// ===== 内蔵詰将棋問題の検証（tool/validate_tsume_screen.dart から呼び出す） =====
// 手筋・囲い崩し(tool/validate_tactics.dart)と異なり、この画面の詰将棋は
// 手打ちの座標データを直接 List に埋め込んでいるため、これまで自動検証の
// 対象外だった（tsume_extra.json のみ検証済み）。TsumeEngine と同じ考え方で
// 解答手順通りに進めて本当に詰み（合法手なし）になるかを確認する。
List<String> validateBuiltinTsumeProblems() {
  final errs = <String>[];
  final problems = buildTsumeProblems();
  for (final p in problems) {
    try {
      var board = List.generate(9, (r) => List<Piece?>.from(p.board[r]));
      var p1h = Map<PieceType, int>.from(p.p1Hand);
      var p2h = Map<PieceType, int>.from(p.p2Hand);
      bool moverIsP1 = true;
      for (int i = 0; i < p.solution.length; i++) {
        final mv = p.solution[i];
        final r = AI.apply(board, p1h, p2h, mv, moverIsP1);
        board = r.b;
        p1h = r.p1h;
        p2h = r.p2h;
        moverIsP1 = !moverIsP1;
        if (i.isEven && !GL.inCheck(board, false)) {
          errs.add('[${p.title}] 手${i + 1}: 先手の手が王手になっていない');
        }
      }
      if (GL.hasLegalMove(board, false, p2h, p1h)) {
        errs.add('[${p.title}] 解答後に後手玉が詰んでいない（合法手が残っている）');
      }
    } catch (e) {
      errs.add('[${p.title}] 検証中に例外: $e');
    }
  }
  return errs;
}
