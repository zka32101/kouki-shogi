// lib/joseki_screen.dart — 定跡ガイド画面
import 'package:flutter/material.dart';
import 'mini_board_widget.dart';
import 'piece.dart';
import 'theme/app_theme.dart';

// ─────────────────────────────────────────────
// データ構造
// ─────────────────────────────────────────────

class _JosekiStep {
  final String move;
  final String comment;
  final List<List<Piece?>> board;
  final (int, int)? fromCell;
  final (int, int)? toCell;

  const _JosekiStep({
    required this.move,
    required this.comment,
    required this.board,
    this.fromCell,
    this.toCell,
  });
}

class _Joseki {
  final String name;
  final String overview;
  final Color color;
  final IconData icon;
  final List<_JosekiStep> steps;
  final String? sourceUrl;
  final String? sourceTitle;
  final String difficulty; // '初級'|'中級'|'上級'

  const _Joseki({
    required this.name,
    required this.overview,
    required this.color,
    required this.icon,
    required this.steps,
    this.sourceUrl,
    this.sourceTitle,
    required this.difficulty,
  });
}

// ─────────────────────────────────────────────
// 盤面ビルダーユーティリティ
// ─────────────────────────────────────────────

/// 将棋の初期配置を返す（row=0 が上＝後手側、row=8 が下＝先手側）
List<List<Piece?>> _initialBoard() {
  final b = List.generate(9, (_) => List<Piece?>.filled(9, null, growable: false));

  // 後手（isPlayer1=false, 上側, row 0-2）
  b[0][0] = const Piece(PieceType.lance,  false);
  b[0][1] = const Piece(PieceType.knight, false);
  b[0][2] = const Piece(PieceType.silver, false);
  b[0][3] = const Piece(PieceType.gold,   false);
  b[0][4] = const Piece(PieceType.king,   false);
  b[0][5] = const Piece(PieceType.gold,   false);
  b[0][6] = const Piece(PieceType.silver, false);
  b[0][7] = const Piece(PieceType.knight, false);
  b[0][8] = const Piece(PieceType.lance,  false);
  b[1][1] = const Piece(PieceType.rook,   false);  // 8二飛
  b[1][7] = const Piece(PieceType.bishop, false);  // 2二角
  for (int c = 0; c < 9; c++) b[2][c] = const Piece(PieceType.pawn, false);

  // 先手（isPlayer1=true, 下側, row 6-8）
  for (int c = 0; c < 9; c++) b[6][c] = const Piece(PieceType.pawn, true);
  b[7][1] = const Piece(PieceType.bishop, true);   // 8八角
  b[7][7] = const Piece(PieceType.rook,   true);   // 2八飛
  b[8][0] = const Piece(PieceType.lance,  true);
  b[8][1] = const Piece(PieceType.knight, true);
  b[8][2] = const Piece(PieceType.silver, true);
  b[8][3] = const Piece(PieceType.gold,   true);
  b[8][4] = const Piece(PieceType.king,   true);
  b[8][5] = const Piece(PieceType.gold,   true);
  b[8][6] = const Piece(PieceType.silver, true);
  b[8][7] = const Piece(PieceType.knight, true);
  b[8][8] = const Piece(PieceType.lance,  true);

  return b;
}

/// ディープコピー
List<List<Piece?>> _copyBoard(List<List<Piece?>> src) =>
    List.generate(9, (r) => List<Piece?>.from(src[r]));

/// 盤上移動（colFile: 列 0-indexed 右から、rankRow: 段 0-indexed 上から）
/// 将棋の筋: 9筋→col=0, 1筋→col=8
/// 将棋の段: 一段→row=0(後手側), 九段→row=8(先手側)
/// 先手の▲7六歩: col=2(7筋), row=5(六段) ← row=6(七段)
List<List<Piece?>> _move(
  List<List<Piece?>> board,
  int fromRow, int fromCol,
  int toRow,   int toCol,
) {
  final b = _copyBoard(board);
  b[toRow][toCol] = b[fromRow][fromCol];
  b[fromRow][fromCol] = null;
  return b;
}

// ─────────────────────────────────────────────
// 将棋の座標変換ヘルパー
// row = 段 - 1  (一段=0, 九段=8) ← 後手は上(0), 先手は下(8)
// col = 9 - 筋  (9筋=0, 1筋=8)
// ─────────────────────────────────────────────
int _r(int dan) => dan - 1;      // 段→row
int _c(int suji) => 9 - suji;    // 筋→col

// ─────────────────────────────────────────────
// 相矢倉 の盤面ステップ
// (旧版は「▲7七銀」が7九(8,2)→7七(6,2)へ2マス直進する、銀将には
//  存在しない不正な移動形だった。TsumeEngineでの検証により発覚・修正:
//  7九→7八→7七の2手に分けて正しい移動形にした)
// ─────────────────────────────────────────────
List<_JosekiStep> _yagaraSteps() {
  final b0 = _initialBoard();

  // 1手目: ▲7六歩 (7筋の歩を六段へ)
  final b1 = _move(b0, _r(7), _c(7), _r(6), _c(7));

  // 2手目: △8四歩
  final b2 = _move(b1, _r(3), _c(8), _r(4), _c(8));

  // 3手目: ▲6六歩（角道を止めて矢倉模様に）
  final b3b = _move(b2, _r(7), _c(6), _r(6), _c(6));

  // 4手目: △3四歩
  final b4 = _move(b3b, _r(3), _c(3), _r(4), _c(3));

  // 5手目: ▲7八銀 (先手左銀 7九 → 7八: row8,col2 → row7,col2、前へ1マス)
  final b5a = _move(b4, 8, 2, 7, 2);

  // 6手目: ▲7七銀 (7八 → 7七: row7,col2 → row6,col2、前へ1マス)
  final b5b = _move(b5a, 7, 2, 6, 2);

  // 7手目: △7七角成 はないので矢倉継続: △8五歩
  final b6 = _move(b5b, _r(4), _c(8), _r(5), _c(8));

  return [
    _JosekiStep(
      move: '初期配置',
      comment: '対局開始時の配置。双方の陣形を確認しましょう。',
      board: b0,
    ),
    _JosekiStep(
      move: '▲7六歩',
      comment: '先手の初手。角道を開けて飛車・角の活用を目指します。矢倉の第一歩。',
      board: b1,
      fromCell: (_r(7), _c(7)),
      toCell: (_r(6), _c(7)),
    ),
    _JosekiStep(
      move: '△8四歩',
      comment: '後手の応手。飛車先の歩を突いて圧力をかけます。矢倉への誘いを受ける形。',
      board: b2,
      fromCell: (_r(3), _c(8)),
      toCell: (_r(4), _c(8)),
    ),
    _JosekiStep(
      move: '▲6六歩',
      comment: '角道を止める重要な一手。この歩突きで矢倉模様を確定させます。',
      board: b3b,
      fromCell: (_r(7), _c(6)),
      toCell: (_r(6), _c(6)),
    ),
    _JosekiStep(
      move: '△3四歩',
      comment: '後手も角道を開けます。双方が矢倉を目指す相矢倉の出だし。',
      board: b4,
      fromCell: (_r(3), _c(3)),
      toCell: (_r(4), _c(3)),
    ),
    _JosekiStep(
      move: '▲7八銀',
      comment: '銀を繰り出して矢倉囲いへ。次に7七を目指します。',
      board: b5a,
      fromCell: (8, 2),
      toCell: (7, 2),
    ),
    _JosekiStep(
      move: '▲7七銀',
      comment: 'さらに銀を進めます。この銀が矢倉の要となります。',
      board: b5b,
      fromCell: (7, 2),
      toCell: (6, 2),
    ),
    _JosekiStep(
      move: '△8五歩',
      comment: '後手が飛車先を伸ばして攻勢を主張。先手は矢倉完成を急ぎます。',
      board: b6,
      fromCell: (_r(4), _c(8)),
      toCell: (_r(5), _c(8)),
    ),
    _JosekiStep(
      move: '以降の方針',
      comment:
          '先手は▲6七金→▲6八金→▲7九角→▲7八金と矢倉を完成させます。\n'
          '後手も同様の手順で矢倉を組み上げ、中盤の戦いへ。\n'
          '矢倉囲いは守備力が高く持久戦向きの囲いです。',
      board: b6,
    ),
  ];
}

// ─────────────────────────────────────────────
// 四間飛車 の盤面ステップ
// ─────────────────────────────────────────────
List<_JosekiStep> _shikenbishaSteps() {
  final b0 = _initialBoard();

  // ▲7六歩
  final b1 = _move(b0, 6, 2, 5, 2);
  // △8四歩
  final b2 = _move(b1, 2, 1, 3, 1);
  // ▲6六歩
  final b3 = _move(b2, 6, 3, 5, 3);
  // △6二銀: 後手の銀(row0,col6=3九位置... 後手右銀はrow0,col6) → row1,col3
  // 後手配置: row0=[lance,knight,silver,gold,king,gold,silver,knight,lance]
  //                 col: 0      1      2     3    4    5     6      7      8
  // △6二銀: 後手の右銀(row0,col6) → 六二(row1,col3)
  final b4 = _move(b3, 0, 2, 1, 3);
  // ▲6八飛: 先手飛車(row7,col7) → 六八(row7,col3)
  final b5 = _move(b4, 7, 7, 7, 3);
  // △6四歩: 後手の6筋歩(row2,col3) → row3,col3
  final b6 = _move(b5, 2, 3, 3, 3);
  // ▲7八銀: 先手左銀(row8,col2) → 七八(row7,col2)
  final b7 = _move(b6, 8, 2, 7, 2);

  return [
    _JosekiStep(
      move: '初期配置',
      comment: '四間飛車は先手が飛車を6筋（6八）に振る「振り飛車」の代表戦法です。',
      board: b0,
    ),
    _JosekiStep(
      move: '▲7六歩',
      comment: '初手。角道を開けながら、次の▲6六歩への布石を打ちます。',
      board: b1,
      fromCell: (6, 2),
      toCell: (5, 2),
    ),
    _JosekiStep(
      move: '△8四歩',
      comment: '後手の応手。居飛車で対抗する場合の典型的な手です。',
      board: b2,
      fromCell: (2, 1),
      toCell: (3, 1),
    ),
    _JosekiStep(
      move: '▲6六歩',
      comment: '角道を止めて四間飛車を明示。振り飛車の意思表示です。',
      board: b3,
      fromCell: (6, 3),
      toCell: (5, 3),
    ),
    _JosekiStep(
      move: '△6二銀',
      comment: '後手が銀を繰り出して対抗。居飛車側は囲いを目指します。',
      board: b4,
      fromCell: (0, 2),
      toCell: (1, 3),
    ),
    _JosekiStep(
      move: '▲6八飛',
      comment: '飛車を6筋（6八）に振る四間飛車の核心。以降は美濃囲いを目指します。',
      board: b5,
      fromCell: (7, 7),
      toCell: (7, 3),
    ),
    _JosekiStep(
      move: '△6四歩',
      comment: '後手の6筋の歩を突いて中央への影響力を高めます。',
      board: b6,
      fromCell: (2, 3),
      toCell: (3, 3),
    ),
    _JosekiStep(
      move: '▲7八銀',
      comment: '銀を上がって美濃囲いへの第一歩。次に▲6七銀→▲5八金→▲4八玉と進みます。',
      board: b7,
      fromCell: (8, 2),
      toCell: (7, 2),
    ),
    _JosekiStep(
      move: '以降の方針',
      comment:
          '先手は▲6七銀→▲5八金→▲4八玉→▲3八玉→▲2八玉→▲3八銀と美濃囲いを完成。\n'
          '飛車が4筋にいることで相手の飛車先に強く、守りの鉄壁が魅力。\n'
          '中盤は5筋・6筋から積極的に攻めていきましょう。',
      board: b7,
    ),
  ];
}

// ─────────────────────────────────────────────
// 棒銀 の盤面ステップ
// ─────────────────────────────────────────────
List<_JosekiStep> _boginSteps() {
  final b0 = _initialBoard();

  // ▲7六歩
  final b1 = _move(b0, 6, 2, 5, 2);
  // △8四歩
  final b2 = _move(b1, 2, 1, 3, 1);
  // ▲2六歩: 先手2筋歩(row6,col7) → row5,col7
  final b3 = _move(b2, 6, 7, 5, 7);
  // △8五歩: 後手8筋(row3,col1) → row4,col1
  final b4 = _move(b3, 3, 1, 4, 1);
  // ▲7七角: 先手角(row7,col1=8八) → 七七(row6,col2)
  // _initialBoard()修正後、角はrow7,col1(8八)にある。斜めに1マス: row6,col2
  final b5 = _move(b4, 7, 1, 6, 2);
  // △3四歩: 後手3筋歩(row2,col6) → row3,col6
  final b6 = _move(b5, 2, 6, 3, 6);
  // ▲8八銀: 先手右銀(row8,col6)... 実は棒銀では7九銀を使う
  // ▲8八銀: 7九銀(row8,col1)は桂馬。実際の銀はcol2とcol6
  // 先手左銀(row8,col2) → 8八(row7,col1)... 棒銀では2筋に銀を繰る
  // 棒銀は右銀を3七→2六と進める。先手右銀=row8,col6 → 7八へ
  // 簡略化: 先手右銀を一つ上へ
  final b7 = _move(b6, 8, 6, 7, 6);
  // ▲7七銀: ← これが棒銀の核心? 違う。棒銀は3七銀→2六銀→2五銀と進む
  // より正確なステップにするため: ▲3八銀: 先手左銀(row8,col6)...
  // 先手の銀: 左銀=col2(7九位置), 右銀=col6(3九位置)
  // 棒銀: 3九銀(row8,col6) → 3八銀(row7,col6) → 2七銀(row6,col7) → 2六銀と進む
  // b7はすでに右銀をrow7,col6へ移動済み

  // ▲2五歩: 先手2筋歩をさらに進める(row5,col7) → row4,col7
  final b8 = _move(b7, 5, 7, 4, 7);

  return [
    _JosekiStep(
      move: '初期配置',
      comment: '棒銀は銀将を素早く前線に送り込む速攻戦法です。シンプルで分かりやすい攻め筋が魅力。',
      board: b0,
    ),
    _JosekiStep(
      move: '▲7六歩',
      comment: '初手。角道を開けます。棒銀でも角の活用は重要です。',
      board: b1,
      fromCell: (6, 2),
      toCell: (5, 2),
    ),
    _JosekiStep(
      move: '△8四歩',
      comment: '後手の飛車先の歩突き。居飛車の標準的な応手です。',
      board: b2,
      fromCell: (2, 1),
      toCell: (3, 1),
    ),
    _JosekiStep(
      move: '▲2六歩',
      comment: '先手が2筋の歩を突きます。棒銀は2筋・3筋への銀の進出が狙いです。',
      board: b3,
      fromCell: (6, 7),
      toCell: (5, 7),
    ),
    _JosekiStep(
      move: '△8五歩',
      comment: '後手が飛車先をさらに伸ばします。先手は角で受けることになります。',
      board: b4,
      fromCell: (3, 1),
      toCell: (4, 1),
    ),
    _JosekiStep(
      move: '▲7七角',
      comment: '角を上がって後手の8筋を間接的に受けます。飛車先を受けつつ陣形を整えます。',
      board: b5,
      fromCell: (7, 1),
      toCell: (6, 2),
    ),
    _JosekiStep(
      move: '△3四歩',
      comment: '後手が角道を開けます。双方の駒組みが本格化します。',
      board: b6,
      fromCell: (2, 6),
      toCell: (3, 6),
    ),
    _JosekiStep(
      move: '▲3八銀',
      comment: '銀を前線へ。この銀を2六→2五→2四と進める「棒銀」の攻撃が始まります。',
      board: b7,
      fromCell: (8, 6),
      toCell: (7, 6),
    ),
    _JosekiStep(
      move: '▲2五歩',
      comment: '歩を突いて銀の通路を作ります。次に▲2六銀→▲2五銀と進む攻撃の布石。',
      board: b8,
      fromCell: (5, 7),
      toCell: (4, 7),
    ),
    _JosekiStep(
      move: '以降の方針',
      comment:
          '先手は▲2六銀→▲2五銀と進んで2筋に攻撃をかけます。\n'
          '銀と歩を組み合わせた単純明快な攻めが棒銀の魅力。\n'
          '相手が受けを誤ると一気に突破できます。初心者にもおすすめの戦法です。',
      board: b8,
    ),
  ];
}

// ─────────────────────────────────────────────
// 角換わり の盤面ステップ
// ─────────────────────────────────────────────
List<_JosekiStep> _kakugawariSteps() {
  final b0 = _initialBoard();

  // ▲7六歩
  final b1 = _move(b0, 6, 2, 5, 2);
  // △8四歩
  final b2 = _move(b1, 2, 1, 3, 1);
  // ▲2六歩
  final b3 = _move(b2, 6, 7, 5, 7);
  // △8五歩
  final b4 = _move(b3, 3, 1, 4, 1);
  // ▲7七角: 先手角(row7,col1=8八) → row6,col2(7七)
  final b5 = _move(b4, 7, 1, 6, 2);
  // △3四歩
  final b6 = _move(b5, 2, 6, 3, 6);
  // ▲8八銀: 先手左銀(row8,col2) → row7,col1
  final b7 = _move(b6, 8, 2, 7, 1);
  // △7七角成: 後手角(row1,col7=2二) → 7七(row6,col2) で成り取り
  // _initialBoard()修正後、後手角はrow1,col7(2二)にある。7七角成: 後手角が先手角を取る (row6,col2)
  final b8 = _move(b7, 1, 7, 6, 2);
  // 角成: 後手の角を成角に変える
  final b8b = _copyBoard(b8);
  b8b[6][2] = const Piece(PieceType.promotedBishop, false);

  // ▲同銀: 先手銀(row7,col1) → row6,col2 で後手角を取る
  final b9 = _move(b8b, 7, 1, 6, 2);
  // 先手銀に変える
  final b9b = _copyBoard(b9);
  b9b[6][2] = const Piece(PieceType.silver, true);

  // △同銀... ではなく先手が角を手に入れ: △2二銀: 後手右銀を移動
  // 後手右銀(row0,col6) → row1,col6(2二)
  final b10 = _move(b9b, 0, 6, 1, 6);

  return [
    _JosekiStep(
      move: '初期配置',
      comment: '角換わりは双方が角を交換し合う戦法。独特の中盤戦が展開されます。',
      board: b0,
    ),
    _JosekiStep(
      move: '▲7六歩',
      comment: '初手。角道を開けます。この後も角道を保ち続けることがポイント。',
      board: b1,
      fromCell: (6, 2),
      toCell: (5, 2),
    ),
    _JosekiStep(
      move: '△8四歩',
      comment: '後手も飛車先を突きます。角換わりへの誘い。',
      board: b2,
      fromCell: (2, 1),
      toCell: (3, 1),
    ),
    _JosekiStep(
      move: '▲2六歩',
      comment: '先手も飛車先を突いて相居飛車の構えを取ります。',
      board: b3,
      fromCell: (6, 7),
      toCell: (5, 7),
    ),
    _JosekiStep(
      move: '△8五歩',
      comment: '後手が飛車先をさらに伸ばします。これに対し角で受けます。',
      board: b4,
      fromCell: (3, 1),
      toCell: (4, 1),
    ),
    _JosekiStep(
      move: '▲7七角',
      comment: '先手が角を上がって受けます。これが角換わりへの誘いになります。',
      board: b5,
      fromCell: (7, 1),
      toCell: (6, 2),
    ),
    _JosekiStep(
      move: '△3四歩',
      comment: '後手が角道を開けます。これで双方の角が向かい合う角換わり必至の形に。',
      board: b6,
      fromCell: (2, 6),
      toCell: (3, 6),
    ),
    _JosekiStep(
      move: '▲8八銀',
      comment: '銀を上がって角換わりに備えます。△7七角成▲同銀の交換が狙い。',
      board: b7,
      fromCell: (8, 2),
      toCell: (7, 1),
    ),
    _JosekiStep(
      move: '△7七角成',
      comment: '後手が角を成って先手の角を取ります。角換わりの決定的な瞬間！',
      board: b8b,
      fromCell: (1, 7),
      toCell: (6, 2),
    ),
    _JosekiStep(
      move: '▲同銀',
      comment: '先手の銀で後手の角(成角)を取り返します。これで角の交換が完了。',
      board: b9b,
      fromCell: (7, 1),
      toCell: (6, 2),
    ),
    _JosekiStep(
      move: '以降の方針',
      comment:
          '双方が角を持ち合った状態から中盤戦へ。\n'
          '先手は手持ちの角を活用して攻めを構築します。\n'
          '角換わりは戦型の幅が広く、腰掛け銀・棒銀など様々な攻め方があります。\n'
          '角の打ち込みが勝負の分かれ目になることが多い戦法です。',
      board: b9b,
    ),
  ];
}

// ─────────────────────────────────────────────
// 美濃囲い の盤面ステップ
// ─────────────────────────────────────────────
List<_JosekiStep> _minoSteps() {
  final b0 = _initialBoard();

  // ▲7六歩
  final b1 = _move(b0, 6, 2, 5, 2);
  // ▲6八飛: 先手飛車(row7,col7) → 六八(row7,col3)
  final b2 = _move(b1, 7, 7, 7, 3);
  // ▲4八玉: 先手玉(row8,col4) → 四八(row7,col5)
  final b3 = _move(b2, 8, 4, 7, 5);
  // ▲3八玉: 四八玉(row7,col5) → 三八(row7,col6)
  final b4 = _move(b3, 7, 5, 7, 6);
  // ▲2八玉: 三八玉(row7,col6) → 二八(row7,col7)
  final b5 = _move(b4, 7, 6, 7, 7);
  // ▲3八銀: 先手右銀(row8,col6) → 三八(row7,col6)
  final b6 = _move(b5, 8, 6, 7, 6);
  // ▲5八金左: 先手左金(row8,col3=6九) → 五八(row7,col4)
  final b7 = _move(b6, 8, 3, 7, 4);

  return [
    _JosekiStep(
      move: '初期配置',
      comment: '美濃囲いは振り飛車で最もよく使われる囲いです。コンパクトで堅い守りが特徴。',
      board: b0,
    ),
    _JosekiStep(
      move: '▲7六歩',
      comment: '初手。振り飛車でも角道を開けることが多いです。',
      board: b1,
      fromCell: (6, 2),
      toCell: (5, 2),
    ),
    _JosekiStep(
      move: '▲6八飛',
      comment: '飛車を6筋に振ります。四間飛車の出だし。美濃囲いへの第一歩です。',
      board: b2,
      fromCell: (7, 7),
      toCell: (7, 3),
    ),
    _JosekiStep(
      move: '▲4八玉',
      comment: '玉を美濃囲いへ向けて移動開始。玉を左辺へ寄せていきます。',
      board: b3,
      fromCell: (8, 4),
      toCell: (7, 5),
    ),
    _JosekiStep(
      move: '▲3八玉',
      comment: '玉がさらに左辺へ。美濃囲いの玉の定位置に近づいています。',
      board: b4,
      fromCell: (7, 5),
      toCell: (7, 6),
    ),
    _JosekiStep(
      move: '▲2八玉',
      comment: '玉が端へ到達。美濃囲いの玉の位置です。次に金・銀で囲みます。',
      board: b5,
      fromCell: (7, 6),
      toCell: (7, 7),
    ),
    _JosekiStep(
      move: '▲3八銀',
      comment: '銀を玉の隣に配置。美濃囲いの骨格が見えてきました。',
      board: b6,
      fromCell: (8, 6),
      toCell: (7, 6),
    ),
    _JosekiStep(
      move: '▲5八金左',
      comment: '左の金を5八へ寄せて美濃囲いが完成。玉2八・銀3八・金5八の形です。',
      board: b7,
      fromCell: (8, 3),
      toCell: (7, 4),
    ),
    _JosekiStep(
      move: '以降の方針',
      comment:
          '右金も▲4八金と足せば本美濃囲いの完成形になります。\n'
          '美濃囲いは玉頭が薄いですが横からの攻めに強い形です。\n'
          '飛車が6筋にいることで中央から右辺へ広く睨みをきかせます。\n'
          '振り飛車の攻めは5筋・4筋からのカウンターが主体です。',
      board: b7,
    ),
  ];
}

// ─────────────────────────────────────────────
// 中飛車 の盤面ステップ
// ─────────────────────────────────────────────
List<_JosekiStep> _nakabishaSteps() {
  final b0 = _initialBoard();

  // ▲5六歩: 先手5筋歩(row6,col4) → row5,col4
  final b1 = _move(b0, 6, 4, 5, 4);
  // ▲5八飛: 先手飛車(row7,col7) → 五八(row7,col4)
  final b2 = _move(b1, 7, 7, 7, 4);
  // △8四歩: 後手8筋歩(row2,col1) → row3,col1
  final b3 = _move(b2, 2, 1, 3, 1);
  // ▲5五歩: 5六歩(row5,col4) → row4,col4
  final b4 = _move(b3, 5, 4, 4, 4);
  // ▲4八玉: 先手玉(row8,col4) → 四八(row7,col5)
  final b5 = _move(b4, 8, 4, 7, 5);
  // △8五歩: 後手8筋歩(row3,col1) → row4,col1
  final b6 = _move(b5, 3, 1, 4, 1);
  // ▲7六歩: 先手7筋歩(row6,col2) → row5,col2
  final b7 = _move(b6, 6, 2, 5, 2);
  // ▲7七角: 先手角(row7,col1) → row6,col2
  final b8 = _move(b7, 7, 1, 6, 2);

  return [
    _JosekiStep(
      move: '初期配置',
      comment: '中飛車は飛車を5筋に振る戦法。中央を制圧する積極的な作戦です。',
      board: b0,
    ),
    _JosekiStep(
      move: '▲5六歩',
      comment: '中飛車への第一歩。5筋の歩を突いて飛車道を開けます。',
      board: b1,
      fromCell: (6, 4),
      toCell: (5, 4),
    ),
    _JosekiStep(
      move: '▲5八飛',
      comment: '飛車を中央5筋に振ります。中飛車の核心！中央からの攻めが狙いです。',
      board: b2,
      fromCell: (7, 7),
      toCell: (7, 4),
    ),
    _JosekiStep(
      move: '△8四歩',
      comment: '後手の標準的な応手。居飛車で対抗します。',
      board: b3,
      fromCell: (2, 1),
      toCell: (3, 1),
    ),
    _JosekiStep(
      move: '▲5五歩',
      comment: '早くも5筋の歩を進めます。中央制圧の意思表示！相手の角道を牽制します。',
      board: b4,
      fromCell: (5, 4),
      toCell: (4, 4),
    ),
    _JosekiStep(
      move: '▲4八玉',
      comment: '玉を安全な場所へ移動開始。攻めながら囲いを組む中飛車らしい手順です。',
      board: b5,
      fromCell: (8, 4),
      toCell: (7, 5),
    ),
    _JosekiStep(
      move: '△8五歩',
      comment: '後手が飛車先を伸ばして圧力をかけます。',
      board: b6,
      fromCell: (3, 1),
      toCell: (4, 1),
    ),
    _JosekiStep(
      move: '▲7六歩',
      comment: '角道を開けます。▲7七角と上がる準備。中飛車でも角の活用は重要です。',
      board: b7,
      fromCell: (6, 2),
      toCell: (5, 2),
    ),
    _JosekiStep(
      move: '▲7七角',
      comment: '角を上がって後手の8筋を受けます。中飛車の形が整ってきました。',
      board: b8,
      fromCell: (7, 1),
      toCell: (6, 2),
    ),
    _JosekiStep(
      move: '以降の方針',
      comment:
          '先手は▲6八銀→▲5七銀と銀を中央に配置して5筋の攻めを強化。\n'
          '5五の歩が中央での主導権を握る鍵になります。\n'
          '相手が5筋を無視すると▲5四歩の突き捨てから猛攻が始まります。\n'
          '中飛車はスピーディーな攻めが魅力の積極的な戦法です。',
      board: b8,
    ),
  ];
}

// ─────────────────────────────────────────────
// 雁木 の盤面ステップ
// ─────────────────────────────────────────────
List<_JosekiStep> _gangiSteps() {
  final b0 = _initialBoard();

  // ▲7六歩: 先手7筋歩(row6,col2) → row5,col2
  final b1 = _move(b0, 6, 2, 5, 2);
  // △8四歩: 後手8筋歩(row2,col1) → row3,col1
  final b2 = _move(b1, 2, 1, 3, 1);
  // ▲6六歩: 先手6筋歩(row6,col3) → row5,col3
  final b3 = _move(b2, 6, 3, 5, 3);
  // △3四歩: 後手3筋歩(row2,col6) → row3,col6
  final b4 = _move(b3, 2, 6, 3, 6);
  // ▲7八銀: 先手左銀(row8,col2=7九) → 七八(row7,col2) [1段ずつ]
  final b5 = _move(b4, 8, 2, 7, 2);
  // △6二銀: 後手左銀(row0,col2=7一) → 六二(row1,col3) [斜め1マス、合法]
  final b6 = _move(b5, 0, 2, 1, 3);
  // ▲7七銀: 先手左銀(row7,col2=7八) → 七七(row6,col2) [1段ずつ]
  final b7 = _move(b6, 7, 2, 6, 2);
  // △5二金右: 後手右金(row0,col5=4一) → 五二(row1,col4) [斜め1マス]
  final b8 = _move(b7, 0, 5, 1, 4);
  // ▲6八金: 先手左金(row8,col3=6九) → 六八(row7,col3) [1段]
  final b9 = _move(b8, 8, 3, 7, 3);
  // △4一玉: 後手玉(row0,col4=5一) → 四一(row0,col5) [横1マス]
  // ※b8で後手右金(0,5)が移動済みなので(0,5)は空
  final b10 = _move(b9, 0, 4, 0, 5);
  // ▲6七金: 先手左金(row7,col3=6八) → 六七(row6,col3) [1段]
  final b11 = _move(b10, 7, 3, 6, 3);
  // △3二玉: 後手玉(row0,col5=4一) → 三二(row1,col6) [斜め1マス]
  final b12 = _move(b11, 0, 5, 1, 6);
  // ▲4八銀: 先手右銀(row8,col6=3九) → 四八(row7,col5) [斜め1マス]
  final b13 = _move(b12, 8, 6, 7, 5);
  // △7四歩: 後手7筋歩(row2,col2=7三) → 七四(row3,col2)
  final b14 = _move(b13, 2, 2, 3, 2);
  // ▲5八金: 先手右金(row8,col5=4九) → 五八(row7,col4) [斜め1マス]
  final b15 = _move(b14, 8, 5, 7, 4);

  return [
    _JosekiStep(
      move: '初期配置',
      comment: '雁木は居飛車の囲いの一つ。金銀を高く組み上げた独特の形が特徴です。',
      board: b0,
    ),
    _JosekiStep(
      move: '▲7六歩',
      comment: '初手。角道を開けます。雁木でも基本の一手。',
      board: b1,
      fromCell: (6, 2),
      toCell: (5, 2),
    ),
    _JosekiStep(
      move: '△8四歩',
      comment: '後手の飛車先突き。居飛車同士の対抗形です。',
      board: b2,
      fromCell: (2, 1),
      toCell: (3, 1),
    ),
    _JosekiStep(
      move: '▲6六歩',
      comment: '雁木の特徴的な一手。角道を止めて独自の囲いを目指します。',
      board: b3,
      fromCell: (6, 3),
      toCell: (5, 3),
    ),
    _JosekiStep(
      move: '△3四歩',
      comment: '後手も角道を開けます。双方の囲い組みが始まります。',
      board: b4,
      fromCell: (2, 6),
      toCell: (3, 6),
    ),
    _JosekiStep(
      move: '▲7八銀',
      comment: '銀を1段上げます。7九→7八と銀を繰り出す雁木の準備。',
      board: b5,
      fromCell: (8, 2),
      toCell: (7, 2),
    ),
    _JosekiStep(
      move: '△6二銀',
      comment: '後手も銀を活用。7一の銀を6二へ斜め前進。相雁木の展開になりやすい局面です。',
      board: b6,
      fromCell: (0, 2),
      toCell: (1, 3),
    ),
    _JosekiStep(
      move: '▲7七銀',
      comment: '銀を7七へ。雁木囲いでは銀を高く上げることが最大の特徴です。',
      board: b7,
      fromCell: (7, 2),
      toCell: (6, 2),
    ),
    _JosekiStep(
      move: '△5二金右',
      comment: '後手の右金を前に出します。後手も囲いを整えます。',
      board: b8,
      fromCell: (0, 5),
      toCell: (1, 4),
    ),
    _JosekiStep(
      move: '▲6八金',
      comment: '先手の左金を6八へ。雁木の金の立ち上がりが始まります。',
      board: b9,
      fromCell: (8, 3),
      toCell: (7, 3),
    ),
    _JosekiStep(
      move: '△4一玉',
      comment: '後手の玉を安全地帯へ移動。4一に玉を寄ります。',
      board: b10,
      fromCell: (0, 4),
      toCell: (0, 5),
    ),
    _JosekiStep(
      move: '▲6七金',
      comment: '金を上がって雁木の形を作ります。金銀が高い位置に並ぶ雁木の特徴！',
      board: b11,
      fromCell: (7, 3),
      toCell: (6, 3),
    ),
    _JosekiStep(
      move: '△3二玉',
      comment: '後手の玉が3二へ。囲いの完成に向けて玉を移動します。',
      board: b12,
      fromCell: (0, 5),
      toCell: (1, 6),
    ),
    _JosekiStep(
      move: '▲4八銀',
      comment: '右銀を4八へ活用の準備。雁木は両銀を使いこなす囲いです。',
      board: b13,
      fromCell: (8, 6),
      toCell: (7, 5),
    ),
    _JosekiStep(
      move: '△7四歩',
      comment: '後手が7筋を突いて反撃の足がかりを作ります。',
      board: b14,
      fromCell: (2, 2),
      toCell: (3, 2),
    ),
    _JosekiStep(
      move: '▲5八金',
      comment: '右金も繰り出します。金銀4枚が上部に展開する雁木の完成形に近づきます。',
      board: b15,
      fromCell: (8, 5),
      toCell: (7, 4),
    ),
    _JosekiStep(
      move: '以降の方針',
      comment:
          '雁木は▲5八金▲6七金▲7七銀▲6六銀と金銀を高く構える囲いです。\n'
          '上部に厚みを築き、相手の攻めを正面から受け止めます。\n'
          '近年プロの間でも再評価されている現代的な囲いです。\n'
          '矢倉に対して雁木で挑む「対矢倉雁木」が特に有名です。',
      board: b15,
    ),
  ];
}

// ─────────────────────────────────────────────
// 急戦右四間飛車 の盤面ステップ (初級レベル)
// ─────────────────────────────────────────────
List<_JosekiStep> _kyushoku4kanSteps() {
  final b0 = _initialBoard();

  // ▲7六歩
  final b1 = _move(b0, 6, 2, 5, 2);
  // △8四歩
  final b2 = _move(b1, 2, 1, 3, 1);
  // ▲6六歩
  final b3 = _move(b2, 6, 3, 5, 3);
  // △3四歩
  final b4 = _move(b3, 2, 6, 3, 6);
  // ▲6八飛: 先手飛車を右に振る（右四間）
  final b5 = _move(b4, 7, 7, 7, 5);
  // △8五歩
  final b6 = _move(b5, 3, 1, 4, 1);
  // ▲7七銀
  final b7 = _move(b6, 8, 2, 7, 2);

  return [
    _JosekiStep(
      move: '初期配置',
      comment: '急戦右四間飛車は先手が飛車を右に振り、早期に攻め合う戦法です。',
      board: b0,
    ),
    _JosekiStep(
      move: '▲7六歩',
      comment: '初手。角道を開けます。',
      board: b1,
      fromCell: (6, 2),
      toCell: (5, 2),
    ),
    _JosekiStep(
      move: '△8四歩',
      comment: '後手の飛車先突き。',
      board: b2,
      fromCell: (2, 1),
      toCell: (3, 1),
    ),
    _JosekiStep(
      move: '▲6六歩',
      comment: '角道を止めます。',
      board: b3,
      fromCell: (6, 3),
      toCell: (5, 3),
    ),
    _JosekiStep(
      move: '△3四歩',
      comment: '後手も角道を開けます。',
      board: b4,
      fromCell: (2, 6),
      toCell: (3, 6),
    ),
    _JosekiStep(
      move: '▲6八飛',
      comment: '飛車を右に振る（右四間）。これが急戦右四間の特徴！',
      board: b5,
      fromCell: (7, 7),
      toCell: (7, 5),
    ),
    _JosekiStep(
      move: '△8五歩',
      comment: '後手が飛車先を伸ばします。',
      board: b6,
      fromCell: (3, 1),
      toCell: (4, 1),
    ),
    _JosekiStep(
      move: '▲7七銀',
      comment: '銀を上がって飛車をサポート。以降は銀と飛車を活用した攻めを目指します。',
      board: b7,
      fromCell: (8, 2),
      toCell: (7, 2),
    ),
    _JosekiStep(
      move: '以降の方針',
      comment:
          '先手は▲7六飛と飛車を進めて、右側から強力な攻めを仕掛けます。\n'
          '右四間は現代的で初心者にも分かりやすい戦法です。\n'
          'テンポの良い攻めが決まると爽快感があります。',
      board: b7,
    ),
  ];
}

// ─────────────────────────────────────────────
// 三間飛車 の盤面ステップ (中級レベル)
// ─────────────────────────────────────────────
List<_JosekiStep> _sankenbishaSteps() {
  final b0 = _initialBoard();

  // ▲7六歩
  final b1 = _move(b0, 6, 2, 5, 2);
  // △8四歩
  final b2 = _move(b1, 2, 1, 3, 1);
  // ▲6六歩
  final b3 = _move(b2, 6, 3, 5, 3);
  // △3四歩
  final b4 = _move(b3, 2, 6, 3, 6);
  // ▲7八飛: 先手飛車を7筋(7八)に振る（三間）
  final b5 = _move(b4, 7, 7, 7, 2);
  // △8五歩
  final b6 = _move(b5, 3, 1, 4, 1);
  // ▲7七角
  final b7 = _move(b6, 7, 1, 6, 2);
  // △6二銀: 後手左銀を移動
  final b8 = _move(b7, 0, 2, 1, 3);
  // ▲4八玉（美濃囲いへ）
  final b9 = _move(b8, 8, 4, 7, 5);

  return [
    _JosekiStep(
      move: '初期配置',
      comment: '三間飛車は飛車を7筋（7八）に振る振り飛車。石田流にも発展する攻撃的な戦法です。',
      board: b0,
    ),
    _JosekiStep(
      move: '▲7六歩',
      comment: '初手。角道を開けます。',
      board: b1,
      fromCell: (6, 2),
      toCell: (5, 2),
    ),
    _JosekiStep(
      move: '△8四歩',
      comment: '後手の飛車先突き。',
      board: b2,
      fromCell: (2, 1),
      toCell: (3, 1),
    ),
    _JosekiStep(
      move: '▲6六歩',
      comment: '角道を止めます。',
      board: b3,
      fromCell: (6, 3),
      toCell: (5, 3),
    ),
    _JosekiStep(
      move: '△3四歩',
      comment: '後手も角道を開けます。',
      board: b4,
      fromCell: (2, 6),
      toCell: (3, 6),
    ),
    _JosekiStep(
      move: '▲7八飛',
      comment: '飛車を7筋（7八）に振る三間飛車。四間飛車より左側に配置され、より攻撃的です。',
      board: b5,
      fromCell: (7, 7),
      toCell: (7, 2),
    ),
    _JosekiStep(
      move: '△8五歩',
      comment: '後手が飛車先を伸ばします。',
      board: b6,
      fromCell: (3, 1),
      toCell: (4, 1),
    ),
    _JosekiStep(
      move: '▲7七角',
      comment: '角を上がって守りを整えます。',
      board: b7,
      fromCell: (7, 1),
      toCell: (6, 2),
    ),
    _JosekiStep(
      move: '△6二銀',
      comment: '後手も銀を活用します。',
      board: b8,
      fromCell: (0, 2),
      toCell: (1, 3),
    ),
    _JosekiStep(
      move: '▲4八玉',
      comment: '玉を右へ動かし、美濃囲いへの第一歩。次に▲3八玉→▲2八玉と囲います。',
      board: b9,
      fromCell: (8, 4),
      toCell: (7, 5),
    ),
    _JosekiStep(
      move: '以降の方針',
      comment:
          '先手は▲3八玉→▲2八玉→▲3八銀と進めて美濃囲いを完成させます。\n'
          '三間飛車は7筋に飛車があるため、石田流への組み換えも狙えます。\n'
          '攻撃と守備のバランスが取れた現代的な振り飛車です。',
      board: b9,
    ),
  ];
}

// ─────────────────────────────────────────────
// 向飛車 の盤面ステップ (上級レベル)
// ─────────────────────────────────────────────
List<_JosekiStep> _mukaiBishaSteps() {
  final b0 = _initialBoard();

  // ▲7六歩
  final b1 = _move(b0, 6, 2, 5, 2);
  // △8四歩
  final b2 = _move(b1, 2, 1, 3, 1);
  // ▲6六歩: 角道を止める
  final b3 = _move(b2, 6, 3, 5, 3);
  // △8五歩
  final b4 = _move(b3, 3, 1, 4, 1);
  // ▲7七角: 先に角を上がって8八を空ける
  final b5b = _move(b4, 7, 1, 6, 2);
  // △3四歩
  final b6 = _move(b5b, 2, 6, 3, 6);
  // ▲8八飛: 飛車を8筋(8八)に振る（向飛車＝後手飛車と向かい合う）
  final b7 = _move(b6, 7, 7, 7, 1);
  // △6二銀
  final b8 = _move(b7, 0, 2, 1, 3);
  // ▲7八銀
  final b9 = _move(b8, 8, 2, 7, 2);
  // △8六歩: 後手が飛車に圧力
  final b10 = _move(b9, 4, 1, 5, 1);

  return [
    _JosekiStep(
      move: '初期配置',
      comment: '向飛車は飛車を8筋（8八）に振り、相手の飛車と向かい合う振り飛車。上級向けの戦法です。',
      board: b0,
    ),
    _JosekiStep(
      move: '▲7六歩',
      comment: '初手。角道を開けます。',
      board: b1,
      fromCell: (6, 2),
      toCell: (5, 2),
    ),
    _JosekiStep(
      move: '△8四歩',
      comment: '後手の飛車先突き。',
      board: b2,
      fromCell: (2, 1),
      toCell: (3, 1),
    ),
    _JosekiStep(
      move: '▲6六歩',
      comment: '角道を止めて振り飛車の意思表示。向飛車は相手の角道を意識します。',
      board: b3,
      fromCell: (6, 3),
      toCell: (5, 3),
    ),
    _JosekiStep(
      move: '△8五歩',
      comment: '後手が飛車先を伸ばします。',
      board: b4,
      fromCell: (3, 1),
      toCell: (4, 1),
    ),
    _JosekiStep(
      move: '▲7七角',
      comment: '先に角を7七へ上がり、8八の地点を空けます。',
      board: b5b,
      fromCell: (7, 1),
      toCell: (6, 2),
    ),
    _JosekiStep(
      move: '△3四歩',
      comment: '後手も角道を開けます。',
      board: b6,
      fromCell: (2, 6),
      toCell: (3, 6),
    ),
    _JosekiStep(
      move: '▲8八飛',
      comment: '飛車を8筋（8八）へ振る向飛車！後手の飛車と正面から向かい合います。',
      board: b7,
      fromCell: (7, 7),
      toCell: (7, 1),
    ),
    _JosekiStep(
      move: '△6二銀',
      comment: '後手が銀を活用します。',
      board: b8,
      fromCell: (0, 2),
      toCell: (1, 3),
    ),
    _JosekiStep(
      move: '▲7八銀',
      comment: '銀を7八へ上がり、玉の囲いを準備します。',
      board: b9,
      fromCell: (8, 2),
      toCell: (7, 2),
    ),
    _JosekiStep(
      move: '△8六歩',
      comment: '後手が飛車に圧力をかけます。向飛車は8筋でぶつかり合う激しい戦いに。',
      board: b10,
      fromCell: (4, 1),
      toCell: (5, 1),
    ),
    _JosekiStep(
      move: '以降の方針',
      comment:
          '向飛車は飛車の効率が悪く、高度な読みが要求される難しい戦法です。\n'
          'プロでも使い手は限定されています。\n'
          '奇襲的な狙いで意外性がある戦法として知られています。',
      board: b10,
    ),
  ];
}

// ─────────────────────────────────────────────
// 石田流 の盤面ステップ
// ─────────────────────────────────────────────
// (旧版は「▲6七銀」が7九(8,2)→6七(6,3)へ2マス斜めに動く、将棋の銀将には
//  存在しない不正な移動形だった上、「▲7六飛」も7八(7,2)→7六(5,2)の
//  移動途中である7七(6,2)に既に自分の角が動いた後で、飛車が自分の角を
//  飛び越えてしまう不成立な手順だった。TsumeEngineでの検証により発覚・
//  修正: 飛車を角より先に7六へ進め、銀は7九→6八→6七の2手に分けて
//  正しい移動形にした)
List<_JosekiStep> _ishidaSteps() {
  final b0 = _initialBoard();

  // ▲7六歩
  final b1 = _move(b0, 6, 2, 5, 2);
  // ▲7五歩: 先手7筋歩(row5,col2) → row4,col2
  final b2 = _move(b1, 5, 2, 4, 2);
  // △8四歩: 後手8筋歩(row2,col1) → row3,col1
  final b3 = _move(b2, 2, 1, 3, 1);
  // ▲7八飛: 先手飛車(row7,col7) → 七八(row7,col2)
  final b4 = _move(b3, 7, 7, 7, 2);
  // △8五歩: 後手8筋歩(row3,col1) → row4,col1
  final b5 = _move(b4, 3, 1, 4, 1);
  // ▲7六飛: 七八飛(row7,col2) → 七六(row5,col2)（角が7七へ動く前に進めておく）
  final b6 = _move(b5, 7, 2, 5, 2);
  // ▲7七角: 先手角(row7,col1) → row6,col2
  final b7 = _move(b6, 7, 1, 6, 2);
  // ▲6六歩: 先手6筋歩(row6,col3) → row5,col3
  final b8 = _move(b7, 6, 3, 5, 3);
  // ▲6八銀: 先手左銀(row8,col2) → 六八(row7,col3)（斜め前へ1マス）
  final b9 = _move(b8, 8, 2, 7, 3);
  // ▲6七銀: 六八銀(row7,col3) → 六七(row6,col3)（前へ1マス）
  final b10 = _move(b9, 7, 3, 6, 3);

  return [
    _JosekiStep(
      move: '初期配置',
      comment: '石田流は飛車を7筋に振り、歩を7五まで進める攻撃的な振り飛車です。',
      board: b0,
    ),
    _JosekiStep(
      move: '▲7六歩',
      comment: '初手。石田流は7筋を中心に展開します。',
      board: b1,
      fromCell: (6, 2),
      toCell: (5, 2),
    ),
    _JosekiStep(
      move: '▲7五歩',
      comment: '2手目で早くも7五へ歩を突きます。これが石田流の特徴！積極的な歩の前進。',
      board: b2,
      fromCell: (5, 2),
      toCell: (4, 2),
    ),
    _JosekiStep(
      move: '△8四歩',
      comment: '後手の飛車先突き。石田流への対応を探ります。',
      board: b3,
      fromCell: (2, 1),
      toCell: (3, 1),
    ),
    _JosekiStep(
      move: '▲7八飛',
      comment: '飛車を7筋に振ります。歩が7五にいることで飛車の活用度が増します。',
      board: b4,
      fromCell: (7, 7),
      toCell: (7, 2),
    ),
    _JosekiStep(
      move: '△8五歩',
      comment: '後手が飛車先を伸ばします。先手は角で受ける必要があります。',
      board: b5,
      fromCell: (3, 1),
      toCell: (4, 1),
    ),
    _JosekiStep(
      move: '▲7六飛',
      comment: '飛車を7六まで前進！7五の歩と連携した強力な陣形を作ります。',
      board: b6,
      fromCell: (7, 2),
      toCell: (5, 2),
    ),
    _JosekiStep(
      move: '▲7七角',
      comment: '角を上がって後手の8筋を止めます。石田流でも角は重要な守り駒。',
      board: b7,
      fromCell: (7, 1),
      toCell: (6, 2),
    ),
    _JosekiStep(
      move: '▲6六歩',
      comment: '角道を止めます。銀の繰り出しを準備します。',
      board: b8,
      fromCell: (6, 3),
      toCell: (5, 3),
    ),
    _JosekiStep(
      move: '▲6八銀',
      comment: '銀を斜め前へ繰り出します。次に6七を目指します。',
      board: b9,
      fromCell: (8, 2),
      toCell: (7, 3),
    ),
    _JosekiStep(
      move: '▲6七銀',
      comment: '銀を中央に進めて飛車をサポート。「石田流本組」の完成です。',
      board: b10,
      fromCell: (7, 3),
      toCell: (6, 3),
    ),
    _JosekiStep(
      move: '以降の方針',
      comment:
          '石田流本組は7五歩・7六飛・6七銀が揃った最強の攻撃陣形です。\n'
          '▲7四歩の突き捨てから▲7三飛成を狙います。\n'
          '相手の対応次第で角や銀を絡めた多彩な攻めが可能。\n'
          '攻撃力の高い戦法ですが玉の囲いも忘れずに組みましょう。',
      board: b10,
    ),
  ];
}

// ─────────────────────────────────────────────
// 定跡データ一覧
// ─────────────────────────────────────────────
final List<_Joseki> _josekiList = [
  // 初級定跡 (3問)
  _Joseki(
    name: '棒銀',
    overview: '銀将を素早く2筋に進める速攻戦法。\n'
        'シンプルながら鋭い攻めが特徴で初心者に人気。\n'
        '▲2六歩→▲3八銀→▲2六銀→▲2五銀と進みます。\n'
        '相手の受けが間違えると一気に突破できる破壊力。\n'
        '覚えやすく実戦で使いやすい優れた戦法です。',
    color: Colors.blueGrey,
    icon: Icons.arrow_upward,
    steps: _boginSteps(),
    sourceTitle: 'YouTube: 初心者向け将棋講座',
    sourceUrl: 'https://www.youtube.com/results?search_query=将棋+棒銀',
    difficulty: '初級',
  ),
  _Joseki(
    name: '四間飛車',
    overview: '先手が飛車を6筋（6八）に振る「振り飛車」の代表戦法。\n'
        '美濃囲いで守りを固め、相手の攻めを受け流します。\n'
        '駒組みの完成形が分かりやすく初心者にもおすすめ。\n'
        '飛車を振った後は▲7七銀→▲6七銀と銀を活用します。\n'
        'カウンター攻撃が決まったときの爽快感が魅力です。',
    color: Colors.blue,
    icon: Icons.swap_horiz,
    steps: _shikenbishaSteps(),
    sourceTitle: 'YouTube: 将棋初級者講座',
    sourceUrl: 'https://www.youtube.com/results?search_query=将棋+四間飛車',
    difficulty: '初級',
  ),
  _Joseki(
    name: '急戦右四間飛車',
    overview: '先手が飛車を右に振り、早期に攻め合う現代的な戦法。\n'
        '四間飛車より左に飛車があり、攻撃性が高い形です。\n'
        'テンポの良い駒組みで初心者にも分かりやすい。\n'
        '▲7六飛と飛車を前進させて強力な攻めを狙います。\n'
        '現代将棋で最も人気のある定跡の一つです。',
    color: AppTheme.accent,
    icon: Icons.trending_up,
    steps: _kyushoku4kanSteps(),
    sourceTitle: 'YouTube: 新しい振り飛車戦法',
    sourceUrl: 'https://www.youtube.com/results?search_query=将棋+右四間飛車',
    difficulty: '初級',
  ),
  // 中級定跡 (6問)
  _Joseki(
    name: '相矢倉',
    overview: '双方が矢倉囲いを組み上げる持久戦型の代表格。\n'
        '守備力の高い矢倉囲いで長期戦を制します。\n'
        '序盤は▲7六歩△8四歩▲6六歩から始まり、\n'
        '金銀を組み上げていく手順が特徴的です。\n'
        '終盤まで接戦になりやすく、深い読みが要求される戦法です。',
    color: Colors.amber,
    icon: Icons.castle,
    steps: _yagaraSteps(),
    sourceTitle: 'YouTube: 矢倉講座',
    sourceUrl: 'https://www.youtube.com/results?search_query=将棋+矢倉定跡',
    difficulty: '中級',
  ),
  _Joseki(
    name: '角換わり',
    overview: '序盤に双方が角を交換し合う戦法。\n'
        '角を持ち合った中盤戦から独特の攻防が生まれます。\n'
        '▲7七角△同角成▲同銀で角の交換が行われます。\n'
        '腰掛け銀や棒銀など様々な攻め方に発展します。\n'
        '角の打ち込みが勝負の分かれ目になる奥深い戦法です。',
    color: Colors.purple,
    icon: Icons.change_circle,
    steps: _kakugawariSteps(),
    sourceTitle: '将棋.com: 角換わり講座',
    sourceUrl: 'https://www.shogi.com/joseki/',
    difficulty: '中級',
  ),
  _Joseki(
    name: '美濃囲い',
    overview: '振り飛車で最も多用される堅固な囲い。\n'
        '玉を端に寄せて金銀3枚で守る守備形です。\n'
        '▲4八玉→▲3八玉→▲2八玉と玉を移動させます。\n'
        '横からの攻めに強く持久戦での安定感が抜群。\n'
        '四間飛車・三間飛車・中飛車全てに応用できます。',
    color: Colors.teal,
    icon: Icons.shield,
    steps: _minoSteps(),
    sourceTitle: 'YouTube: 振り飛車講座',
    sourceUrl: 'https://www.youtube.com/results?search_query=将棋+美濃囲い',
    difficulty: '中級',
  ),
  _Joseki(
    name: '中飛車',
    overview: '飛車を中央5筋に配置する積極的な振り飛車。\n'
        '▲5六歩→▲5八飛と素早く中央を制圧します。\n'
        '5五の歩が相手の角道を遮断する重要な役割を担います。\n'
        '攻撃的で覚えやすく初中級者にも人気の戦法。\n'
        '近年プロでも「ゴキゲン中飛車」として大人気です。',
    color: Colors.orange,
    icon: Icons.center_focus_strong,
    steps: _nakabishaSteps(),
    sourceTitle: 'YouTube: ゴキゲン中飛車講座',
    sourceUrl: 'https://www.youtube.com/results?search_query=将棋+ゴキゲン中飛車',
    difficulty: '中級',
  ),
  _Joseki(
    name: '三間飛車',
    overview: '飛車を7筋（7八）に振る振り飛車。四間飛車より攻撃的。\n'
        '7筋に飛車があり、石田流など積極的な攻めに発展します。\n'
        '攻撃と守備のバランスが取れた現代的な戦法です。\n'
        '美濃囲いで玉を固め、飛車をサポート。\n'
        '戦型の幅広さと攻撃力が魅力です。',
    color: Colors.indigo,
    icon: Icons.compare_arrows,
    steps: _sankenbishaSteps(),
    sourceTitle: 'YouTube: 三間飛車完全講座',
    sourceUrl: 'https://www.youtube.com/results?search_query=将棋+三間飛車',
    difficulty: '中級',
  ),
  // 上級定跡 (3問)
  _Joseki(
    name: '雁木',
    overview: '金銀を高く組み上げる居飛車の囲い。\n'
        '▲6七金▲7七銀が雁木の特徴的な配置です。\n'
        '上部への厚みが強く、相手の攻めを受け止めます。\n'
        '矢倉崩しの切り札として近年プロ間で人気急上昇。\n'
        'シンプルで攻守に優れた現代将棋の最先端戦法です。',
    color: Colors.green,
    icon: Icons.account_balance,
    steps: _gangiSteps(),
    sourceTitle: 'ニコニコ動画: プロ棋戦解説',
    sourceUrl: 'https://www.nicovideo.jp/search/将棋',
    difficulty: '上級',
  ),
  _Joseki(
    name: '石田流',
    overview: '7五歩・7八飛・7六飛と飛車を前線に出す攻撃的振り飛車。\n'
        '「石田流本組」は最強の攻撃陣形とも呼ばれます。\n'
        '▲7五歩▲7八飛▲7六飛が石田流の基本形です。\n'
        '飛車・銀・角が連動した多彩な攻めが魅力。\n'
        '攻めっ気満点で観戦しても楽しい戦法です。',
    color: Colors.red,
    icon: Icons.speed,
    steps: _ishidaSteps(),
    sourceTitle: '将棋世界: 定跡特集',
    sourceUrl: 'https://www.nikkei.com/shogi/',
    difficulty: '上級',
  ),
  _Joseki(
    name: '向飛車',
    overview: '飛車を最端の9筋に振る最も個性的な振り飛車。\n'
        '上級向けの難しい戦法で、プロでも使い手は限定的。\n'
        '飛車の効率が悪く、高度な読みが要求されます。\n'
        '奇襲的な狙いで意外性がある戦法として知られています。\n'
        'スタイリッシュな棋風を求める棋士に愛用されます。',
    color: Colors.pink,
    icon: Icons.star,
    steps: _mukaiBishaSteps(),
    sourceTitle: '棋譜でーたべーす: 向飛車定跡',
    sourceUrl: 'https://kishibetabase.com/',
    difficulty: '上級',
  ),
];

// ─────────────────────────────────────────────
// 一覧ページ
// ─────────────────────────────────────────────

class JosekiScreen extends StatefulWidget {
  const JosekiScreen({super.key});

  @override
  State<JosekiScreen> createState() => _JosekiScreenState();
}

class _JosekiScreenState extends State<JosekiScreen> {
  String? _selectedDifficulty; // null = すべて, '初級', '中級', '上級'

  static const _bg = AppTheme.bg;

  List<_Joseki> get _filteredJoseki {
    if (_selectedDifficulty == null) {
      return _josekiList;
    }
    return _josekiList.where((j) => j.difficulty == _selectedDifficulty).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text(
          '定跡ガイド',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '難度で絞り込む',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _DifficultyButton(
                      label: 'すべて',
                      isSelected: _selectedDifficulty == null,
                      onTap: () => setState(() => _selectedDifficulty = null),
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    _DifficultyButton(
                      label: '初級',
                      isSelected: _selectedDifficulty == '初級',
                      onTap: () => setState(() => _selectedDifficulty = '初級'),
                      color: Colors.lightGreen,
                    ),
                    const SizedBox(width: 8),
                    _DifficultyButton(
                      label: '中級',
                      isSelected: _selectedDifficulty == '中級',
                      onTap: () => setState(() => _selectedDifficulty = '中級'),
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _DifficultyButton(
                      label: '上級',
                      isSelected: _selectedDifficulty == '上級',
                      onTap: () => setState(() => _selectedDifficulty = '上級'),
                      color: Colors.redAccent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '戦型を選んでください (${_filteredJoseki.length}件)',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  final crossCount = constraints.maxWidth > 600 ? 2 : 1;
                  return _filteredJoseki.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.layers_clear,
                                color: Colors.white30,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'この難度の定跡はありません',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossCount,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: crossCount == 2 ? 2.2 : 3.0,
                          ),
                          itemCount: _filteredJoseki.length,
                          itemBuilder: (ctx, i) => _JosekiCard(
                            joseki: _filteredJoseki[i],
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    _JosekiDetailPage(joseki: _filteredJoseki[i]),
                              ),
                            ),
                          ),
                        );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _DifficultyButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(60) : Colors.white10,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? color : Colors.white24,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.white54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

Color _getDifficultyColor(String difficulty) {
  switch (difficulty) {
    case '初級':
      return Colors.lightGreen;
    case '中級':
      return Colors.orange;
    case '上級':
      return Colors.redAccent;
    default:
      return Colors.white70;
  }
}

class _JosekiCard extends StatelessWidget {
  final _Joseki joseki;
  final VoidCallback onTap;

  const _JosekiCard({required this.joseki, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: joseki.color.withAlpha(80),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: joseki.color.withAlpha(30),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: joseki.color.withAlpha(40),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                joseki.icon,
                color: joseki.color,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          joseki.name,
                          style: TextStyle(
                            color: joseki.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _getDifficultyColor(joseki.difficulty).withAlpha(40),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _getDifficultyColor(joseki.difficulty),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          joseki.difficulty,
                          style: TextStyle(
                            color: _getDifficultyColor(joseki.difficulty),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${joseki.steps.length} ステップ',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: joseki.color.withAlpha(180),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 詳細ページ
// ─────────────────────────────────────────────

class _JosekiDetailPage extends StatefulWidget {
  final _Joseki joseki;

  const _JosekiDetailPage({required this.joseki});

  @override
  State<_JosekiDetailPage> createState() => _JosekiDetailPageState();
}

class _JosekiDetailPageState extends State<_JosekiDetailPage> {
  int _stepIndex = 0;

  static const _bg = AppTheme.bg;
  static const _cardBg = AppTheme.surface;

  _JosekiStep get _currentStep => widget.joseki.steps[_stepIndex];
  int get _totalSteps => widget.joseki.steps.length;

  void _prev() {
    if (_stepIndex > 0) setState(() => _stepIndex--);
  }

  void _next() {
    if (_stepIndex < _totalSteps - 1) setState(() => _stepIndex++);
  }

  @override
  Widget build(BuildContext context) {
    final joseki = widget.joseki;
    final step = _currentStep;
    final color = joseki.color;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _cardBg,
        title: Text(
          joseki.name,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          return isWide
              ? _buildWideLayout(context, joseki, step, color)
              : _buildNarrowLayout(context, joseki, step, color);
        }),
      ),
    );
  }

  Widget _buildNarrowLayout(
    BuildContext context,
    _Joseki joseki,
    _JosekiStep step,
    Color color,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BoardSection(
            step: step,
            color: color,
            stepIndex: _stepIndex,
            totalSteps: _totalSteps,
          ),
          const SizedBox(height: 8),
          _NavButtons(
            stepIndex: _stepIndex,
            totalSteps: _totalSteps,
            color: color,
            onPrev: _prev,
            onNext: _next,
          ),
          const SizedBox(height: 16),
          _CommentCard(step: step, color: color),
          const SizedBox(height: 16),
          _OverviewCard(joseki: joseki, color: color),
          const SizedBox(height: 16),
          _StepList(
            joseki: joseki,
            currentIndex: _stepIndex,
            color: color,
            onTap: (i) => setState(() => _stepIndex = i),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    _Joseki joseki,
    _JosekiStep step,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左カラム: 盤面 + ナビ
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _BoardSection(
                  step: step,
                  color: color,
                  stepIndex: _stepIndex,
                  totalSteps: _totalSteps,
                ),
                const SizedBox(height: 16),
                _CommentCard(step: step, color: color),
                const SizedBox(height: 16),
                _NavButtons(
                  stepIndex: _stepIndex,
                  totalSteps: _totalSteps,
                  color: color,
                  onPrev: _prev,
                  onNext: _next,
                ),
              ],
            ),
          ),
        ),
        // 右カラム: 概要 + 手順一覧
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
            child: Column(
              children: [
                _OverviewCard(joseki: joseki, color: color),
                const SizedBox(height: 16),
                _StepList(
                  joseki: joseki,
                  currentIndex: _stepIndex,
                  color: color,
                  onTap: (i) => setState(() => _stepIndex = i),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// サブウィジェット
// ─────────────────────────────────────────────

class _OverviewCard extends StatelessWidget {
  final _Joseki joseki;
  final Color color;

  const _OverviewCard({required this.joseki, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withAlpha(60), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(joseki.icon, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${joseki.name}とは',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(joseki.difficulty).withAlpha(40),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _getDifficultyColor(joseki.difficulty),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      joseki.difficulty,
                      style: TextStyle(
                        color: _getDifficultyColor(joseki.difficulty),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                joseki.overview,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.7,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BoardSection extends StatelessWidget {
  final _JosekiStep step;
  final Color color;
  final int stepIndex;
  final int totalSteps;

  const _BoardSection({
    required this.step,
    required this.color,
    required this.stepIndex,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                step.move,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withAlpha(80)),
                ),
                child: Text(
                  '$stepIndex / ${totalSteps - 1}手',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalSteps > 1 ? stepIndex / (totalSteps - 1) : 0.0,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: AspectRatio(
                aspectRatio: 1,
                child: MiniBoardWidget(
                  board: step.board,
                  showLabels: true,
                  lastMoveFrom: step.fromCell,
                  lastMoveTo: step.toCell,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepList extends StatelessWidget {
  final _Joseki joseki;
  final int currentIndex;
  final Color color;
  final ValueChanged<int> onTap;

  const _StepList({
    required this.joseki,
    required this.currentIndex,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(40), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(
              '手順一覧',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          ...joseki.steps.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            final isCurrent = i == currentIndex;
            return InkWell(
              onTap: () => onTap(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isCurrent ? color.withAlpha(40) : Colors.transparent,
                  border: Border(
                    left: BorderSide(
                      color: isCurrent ? color : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isCurrent ? color : Colors.white12,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$i',
                        style: TextStyle(
                          color: isCurrent ? Colors.black87 : Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.move,
                        style: TextStyle(
                          color: isCurrent ? color : Colors.white70,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final _JosekiStep step;
  final Color color;

  const _CommentCard({required this.step, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              step.comment,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButtons extends StatelessWidget {
  final int stepIndex;
  final int totalSteps;
  final Color color;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _NavButtons({
    required this.stepIndex,
    required this.totalSteps,
    required this.color,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final canPrev = stepIndex > 0;
    final canNext = stepIndex < totalSteps - 1;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canPrev ? onPrev : null,
            icon: const Icon(Icons.arrow_back_ios, size: 14),
            label: const Text('前の手'),
            style: ElevatedButton.styleFrom(
              backgroundColor: canPrev ? color.withAlpha(60) : Colors.white12,
              foregroundColor: canPrev ? color : Colors.white30,
              disabledBackgroundColor: Colors.white12,
              disabledForegroundColor: Colors.white30,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: canPrev ? color.withAlpha(120) : Colors.transparent,
                ),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            '${stepIndex + 1} / $totalSteps',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canNext ? onNext : null,
            icon: const Text('次の手'),
            label: const Icon(Icons.arrow_forward_ios, size: 14),
            style: ElevatedButton.styleFrom(
              backgroundColor: canNext ? color.withAlpha(60) : Colors.white12,
              foregroundColor: canNext ? color : Colors.white30,
              disabledBackgroundColor: Colors.white12,
              disabledForegroundColor: Colors.white30,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: canNext ? color.withAlpha(120) : Colors.transparent,
                ),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}
