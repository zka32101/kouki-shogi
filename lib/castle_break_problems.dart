// lib/castle_break_problems.dart
// 囲い崩し道場の問題データ（純Dart・Flutter非依存）。
// 後手の囲いは「先手囲いの点対称ミラー」で正しく配置し、
// 崩しの一手は tool/validate_tactics.dart で合法性・手筋成立を検証する。
//
// 座標規約: board[row][col]  筋 = 9 - col, 段 = row + 1
//   先手(p1=true) 前進=row減少, 敵陣=row 0..2 / 後手 前進=row増加, 敵陣=row 6..8
import 'piece.dart';

class CastleProb {
  final String id;
  final String title;
  final String castle; // 美濃|矢倉|穴熊|居飛車穴熊
  final String description;
  final List<List<Piece?>> board;
  final Map<PieceType, int> p1Hand;
  final AMove answer;
  final String explanation;
  final String? sourceUrl;
  final String? sourceTitle;
  final int difficulty; // 1=初級 2=中級 3=上級

  const CastleProb({
    required this.id,
    required this.title,
    required this.castle,
    required this.description,
    required this.board,
    this.p1Hand = const {},
    required this.answer,
    required this.explanation,
    this.sourceUrl,
    this.sourceTitle,
    required this.difficulty,
  });
}

List<List<Piece?>> _empty() =>
    List.generate(9, (_) => List<Piece?>.filled(9, null));

const _src = 'https://www.shogi.or.jp/';
const _srcName = '日本将棋連盟';

// 後手の美濃囲い（先手2八美濃の点対称＝8二玉）
void _goteMino(List<List<Piece?>> b) {
  b[1][1] = const Piece(PieceType.king, false); // 玉 8二
  b[1][2] = const Piece(PieceType.gold, false); // 金 7二
  b[2][2] = const Piece(PieceType.silver, false); // 銀 7三
  b[0][0] = const Piece(PieceType.lance, false); // 香 9一
  b[2][0] = const Piece(PieceType.pawn, false); // 歩 9三
  b[2][1] = const Piece(PieceType.pawn, false); // 歩 8三
  b[2][3] = const Piece(PieceType.pawn, false); // 歩 6三
}

List<CastleProb> buildCastleProblems() {
  final list = <CastleProb>[];

  // ===== 美濃 ① 玉頭の銀 =====
  {
    final b = _empty();
    _goteMino(b);
    b[8][1] = const Piece(PieceType.king, true); // 先手玉 8九
    b[3][2] = const Piece(PieceType.silver, true); // 先手銀 7四
    list.add(CastleProb(
      id: 'mino_1',
      title: '美濃①：玉頭の銀',
      castle: '美濃',
      description: '美濃囲いの急所、玉頭に狙いをつけよう。先手番、最善の一手は？',
      board: b,
      answer: const AMove(fr: 3, fc: 2, tr: 2, tc: 1),
      explanation: '▲8三銀。美濃囲いの急所である玉頭に銀をぶつける王手。△同玉・△同金のいずれで応じても玉の固さが崩れ、寄せの糸口になります。',
      sourceUrl: _src, sourceTitle: _srcName, difficulty: 1,
    ));
  }

  // ===== 美濃 ② 刺し違えの桂 =====
  {
    final b = _empty();
    _goteMino(b);
    b[8][1] = const Piece(PieceType.king, true); // 先手玉 8九
    b[3][1] = const Piece(PieceType.knight, true); // 先手桂 8四
    list.add(CastleProb(
      id: 'mino_2',
      title: '美濃②：刺し違えの桂',
      castle: '美濃',
      description: '桂を跳ねて美濃の金を狙おう。先手番、最善の一手は？',
      board: b,
      answer: const AMove(fr: 3, fc: 1, tr: 1, tc: 2, promote: true),
      explanation: '▲7二桂成。桂を跳ねて金を取りながら王手。△同玉と取らせれば美濃は裸になります。桂を金と刺し違える美濃崩しの手筋です。',
      sourceUrl: _src, sourceTitle: _srcName, difficulty: 2,
    ));
  }

  // 後手の矢倉囲い（先手8八金矢倉の点対称＝2二玉）。金の連結を外した形。
  void goteYagura(List<List<Piece?>> b) {
    b[1][7] = const Piece(PieceType.king, false); // 玉 2二
    b[0][6] = const Piece(PieceType.gold, false); // 金 3一
    b[2][5] = const Piece(PieceType.gold, false); // 金 4三
    b[2][6] = const Piece(PieceType.silver, false); // 銀 3三
    b[2][7] = const Piece(PieceType.pawn, false); // 歩 2三
    b[2][8] = const Piece(PieceType.pawn, false); // 歩 1三
  }

  // ===== 矢倉 ① 玉頭の銀 =====
  {
    final b = _empty();
    goteYagura(b);
    b[8][7] = const Piece(PieceType.king, true); // 先手玉 2九
    b[3][6] = const Piece(PieceType.silver, true); // 先手銀 3四
    list.add(CastleProb(
      id: 'yagura_1',
      title: '矢倉①：玉頭の銀',
      castle: '矢倉',
      description: '矢倉の玉頭2三に狙いをつけよう。先手番、最善の一手は？',
      board: b,
      answer: const AMove(fr: 3, fc: 6, tr: 2, tc: 7),
      explanation: '▲2三銀。矢倉の玉頭に銀を捨てる急所の一手。△同玉と引きずり出して囲いを乱します。矢倉崩しの基本となる攻めです。',
      sourceUrl: _src, sourceTitle: _srcName, difficulty: 1,
    ));
  }

  // ===== 矢倉 ② 腹の銀（金を取る） =====
  {
    final b = _empty();
    goteYagura(b);
    b[8][7] = const Piece(PieceType.king, true); // 先手玉 2九
    b[3][4] = const Piece(PieceType.silver, true); // 先手銀 5四
    list.add(CastleProb(
      id: 'yagura_2',
      title: '矢倉②：腹の銀',
      castle: '矢倉',
      description: '連結の外れた金を狙おう。先手番、最善の一手は？',
      board: b,
      answer: const AMove(fr: 3, fc: 4, tr: 2, tc: 5),
      explanation: '▲4三銀。矢倉の腹、守りの金にぶつけて取ります。金と銀の連結を外された矢倉は急速にもろくなります。',
      sourceUrl: _src, sourceTitle: _srcName, difficulty: 2,
    ));
  }

  // 後手の穴熊（1一玉・2二金・1二銀の片穴熊。上辺の金は連結なし）
  void goteAnaguma(List<List<Piece?>> b) {
    b[0][8] = const Piece(PieceType.king, false); // 玉 1一
    b[1][8] = const Piece(PieceType.silver, false); // 銀 1二
    b[1][7] = const Piece(PieceType.gold, false); // 金 2二
    b[0][6] = const Piece(PieceType.gold, false); // 金 3一
    b[2][6] = const Piece(PieceType.pawn, false); // 歩 3三
    b[2][7] = const Piece(PieceType.pawn, false); // 歩 2三
    b[2][8] = const Piece(PieceType.pawn, false); // 歩 1三
  }

  // ===== 穴熊 ① 金を取る馬作り =====
  {
    final b = _empty();
    goteAnaguma(b);
    b[8][0] = const Piece(PieceType.king, true); // 先手玉 9九
    b[3][3] = const Piece(PieceType.bishop, true); // 先手角 6四
    list.add(CastleProb(
      id: 'anaguma_1',
      title: '穴熊①：金をはがす馬作り',
      castle: '穴熊',
      description: '穴熊の上辺の金を角で狙おう。先手番、最善の一手は？',
      board: b,
      answer: const AMove(fr: 3, fc: 3, tr: 0, tc: 6, promote: true),
      explanation: '▲3一角成。上辺の金を角で取って馬を作ります。守りの金をはがすのが穴熊崩しの第一歩。馬は穴熊攻めの主役です。',
      sourceUrl: _src, sourceTitle: _srcName, difficulty: 2,
    ));
  }

  // ===== 穴熊 ② 刺し違えの桂 =====
  {
    final b = _empty();
    goteAnaguma(b);
    b[8][0] = const Piece(PieceType.king, true); // 先手玉 9九
    b[3][8] = const Piece(PieceType.knight, true); // 先手桂 1四
    list.add(CastleProb(
      id: 'anaguma_2',
      title: '穴熊②：刺し違えの桂',
      castle: '穴熊',
      description: '桂を跳ねて穴熊の金を狙おう。先手番、最善の一手は？',
      board: b,
      answer: const AMove(fr: 3, fc: 8, tr: 1, tc: 7, promote: true),
      explanation: '▲2二桂成。桂を跳ねて金を取りながら王手。△同玉と取らせて穴熊の守りを一枚はがします。桂を金と刺し違える崩しの手筋です。',
      sourceUrl: _src, sourceTitle: _srcName, difficulty: 3,
    ));
  }

  // 後手の居飛車穴熊（1一玉・2二銀・3二金・3一金。堅陣）
  void goteIbisha(List<List<Piece?>> b) {
    b[0][8] = const Piece(PieceType.king, false); // 玉 1一
    b[1][7] = const Piece(PieceType.silver, false); // 銀 2二
    b[1][6] = const Piece(PieceType.gold, false); // 金 3二
    b[0][6] = const Piece(PieceType.gold, false); // 金 3一
    b[2][6] = const Piece(PieceType.pawn, false); // 歩 3三
    b[2][7] = const Piece(PieceType.pawn, false); // 歩 2三
    b[2][8] = const Piece(PieceType.pawn, false); // 歩 1三
  }

  // ===== 居飛車穴熊 ① 端の香成 =====
  {
    final b = _empty();
    goteIbisha(b);
    b[8][0] = const Piece(PieceType.king, true); // 先手玉 9九
    b[5][8] = const Piece(PieceType.lance, true); // 先手香 1六
    list.add(CastleProb(
      id: 'ibisha_1',
      title: '居飛車穴熊①：端の香成',
      castle: '居飛車穴熊',
      description: '堅い穴熊は端が急所。香で端を攻めよう。先手番、最善の一手は？',
      board: b,
      answer: const AMove(fr: 5, fc: 8, tr: 2, tc: 8, promote: true),
      explanation: '▲1三香成。居飛車穴熊の端を香で攻め、成香で2二の銀に迫ります。堅い穴熊も端からなら崩せます。',
      sourceUrl: _src, sourceTitle: _srcName, difficulty: 2,
    ));
  }

  // ===== 居飛車穴熊 ② 玉頭の銀 =====
  {
    final b = _empty();
    goteIbisha(b);
    b[8][0] = const Piece(PieceType.king, true); // 先手玉 9九
    b[3][6] = const Piece(PieceType.silver, true); // 先手銀 3四
    list.add(CastleProb(
      id: 'ibisha_2',
      title: '居飛車穴熊②：玉頭の銀',
      castle: '居飛車穴熊',
      description: '穴熊の玉頭2三に銀を打ち込もう。先手番、最善の一手は？',
      board: b,
      answer: const AMove(fr: 3, fc: 6, tr: 2, tc: 7),
      explanation: '▲2三銀。穴熊の玉頭に銀を捨て、3二の金と2二の銀の両方に圧力をかけます。守りの金銀をはがして突破口を開きます。',
      sourceUrl: _src, sourceTitle: _srcName, difficulty: 3,
    ));
  }

  return list;
}
