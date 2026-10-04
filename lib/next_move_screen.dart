// lib/next_move_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'piece.dart';
import 'mini_board_widget.dart';
import 'game_screen.dart' show initShogiBoard;
import 'theme/app_theme.dart';

class NextMoveScreen extends StatefulWidget {
  const NextMoveScreen({Key? key}) : super(key: key);

  @override
  State<NextMoveScreen> createState() => _NextMoveScreenState();
}

class _NMProb {
  final String title;
  final String difficulty;
  final String description;
  final List<List<Piece?>> board;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String? sourceUrl;
  final String? sourceTitle;
  final Map<PieceType, int> p1Hand;
  final Map<PieceType, int> p2Hand;

  const _NMProb({
    required this.title,
    required this.difficulty,
    required this.description,
    required this.board,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.sourceUrl,
    this.sourceTitle,
    this.p1Hand = const {},
    this.p2Hand = const {},
  });
}

List<List<Piece?>> _empty() {
  return List.generate(9, (_) => List.filled(9, null));
}

// 標準初期配置をコピー
List<List<Piece?>> _stdBoard() {
  final src = initShogiBoard();
  return List.generate(9, (r) => List.from(src[r]));
}

// 問1: 角道を開ける — 標準初期配置（▲7六歩を選ぶ）
List<List<Piece?>> _prob1Board() => _stdBoard();

// 問2: 飛車先の歩を突く — ▲7六歩を指した後（7七→7六）
List<List<Piece?>> _prob2Board() {
  final b = _stdBoard();
  b[5][2] = b[6][2]; // ▲7六歩（7七→7六）
  b[6][2] = null;
  return b;
}

// 問3: 玉の囲い方向 — ▲7六歩・▲2六歩を指した後
List<List<Piece?>> _prob3Board() {
  final b = _stdBoard();
  b[5][2] = b[6][2]; b[6][2] = null; // ▲7六歩
  b[5][7] = b[6][7]; b[6][7] = null; // ▲2六歩
  b[3][7] = b[2][7]; b[2][7] = null; // △2四歩
  return b;
}

// 問4: 中飛車への振り方 — ▲7六歩・▲5六歩後、飛をどこに振るか
List<List<Piece?>> _prob4Board() {
  final b = _stdBoard();
  b[5][2] = b[6][2]; b[6][2] = null; // ▲7六歩
  b[5][4] = b[6][4]; b[6][4] = null; // ▲5六歩
  b[3][4] = b[2][4]; b[2][4] = null; // △5四歩
  return b;
}

// 問5: 棒銀の進出 — 2筋の歩を伸ばし右銀を2七まで繰り出した局面
List<List<Piece?>> _prob5Board() {
  final b = _stdBoard();
  b[5][2] = b[6][2]; b[6][2] = null;   // ▲7六歩
  b[5][7] = b[6][7]; b[6][7] = null;   // ▲2六歩
  b[4][7] = b[5][7]; b[5][7] = null;   // ▲2五歩（さらに伸ばす）
  b[6][7] = b[8][6]; b[8][6] = null;   // 右銀を2七へ繰り出す（3九銀→2七）
  b[3][2] = b[2][2]; b[2][2] = null;   // △3三銀
  b[3][6] = b[2][6]; b[2][6] = null;   // △3四歩
  return b;
}

// 問6: 垂れ歩 — 6五の歩を6四に進め、6三歩成を狙う場面
List<List<Piece?>> _prob6Board() {
  final b = _empty();
  // 先手
  b[8][4] = Piece(PieceType.king, true);   // 5九玉
  b[8][3] = Piece(PieceType.gold, true);   // 6九金
  b[8][5] = Piece(PieceType.gold, true);   // 4九金
  b[8][6] = Piece(PieceType.silver, true); // 3九銀
  b[7][1] = Piece(PieceType.bishop, true); // 8八角
  b[8][7] = Piece(PieceType.rook, true);   // 2九飛
  b[6][2] = Piece(PieceType.pawn, true);   // 7七歩
  b[6][4] = Piece(PieceType.pawn, true);   // 5七歩
  b[6][6] = Piece(PieceType.pawn, true);   // 3七歩
  b[6][7] = Piece(PieceType.pawn, true);   // 2七歩
  b[6][8] = Piece(PieceType.pawn, true);   // 1七歩
  b[4][3] = Piece(PieceType.pawn, true);   // 6五歩（6四へ進めて垂れ歩）
  // 後手（6筋・6三/6四は開けておく）
  b[0][4] = Piece(PieceType.king, false);  // 5一玉
  b[1][3] = Piece(PieceType.gold, false);  // 6二金
  b[1][5] = Piece(PieceType.gold, false);  // 4二金
  b[0][2] = Piece(PieceType.silver, false);// 7一銀
  b[1][7] = Piece(PieceType.bishop, false);// 2二角
  b[1][1] = Piece(PieceType.rook, false);  // 8二飛
  b[2][0] = Piece(PieceType.pawn, false);  // 9三歩
  b[2][1] = Piece(PieceType.pawn, false);  // 8三歩
  b[2][2] = Piece(PieceType.pawn, false);  // 7三歩
  b[2][4] = Piece(PieceType.pawn, false);  // 5三歩
  b[2][6] = Piece(PieceType.pawn, false);  // 3三歩
  b[2][8] = Piece(PieceType.pawn, false);  // 1三歩
  return b;
}

// 問7: 桂馬の活用 — 桂で銀に当てる場面
List<List<Piece?>> _prob7Board() {
  final b = _empty();
  // 先手
  b[8][4] = Piece(PieceType.king, true);
  b[8][7] = Piece(PieceType.rook, true);
  b[7][1] = Piece(PieceType.bishop, true);
  b[8][5] = Piece(PieceType.gold, true);
  b[8][3] = Piece(PieceType.gold, true);
  b[8][6] = Piece(PieceType.silver, true);
  b[6][3] = Piece(PieceType.knight, true); // 6七桂（7五に跳ねて6三銀に当てる）
  b[6][0] = Piece(PieceType.pawn, true);
  b[6][1] = Piece(PieceType.pawn, true);
  b[6][2] = Piece(PieceType.pawn, true);
  b[6][4] = Piece(PieceType.pawn, true);
  b[6][6] = Piece(PieceType.pawn, true);
  b[6][7] = Piece(PieceType.pawn, true);
  b[6][8] = Piece(PieceType.pawn, true);
  // 後手
  b[0][4] = Piece(PieceType.king, false);
  b[1][1] = Piece(PieceType.rook, false);
  b[1][7] = Piece(PieceType.bishop, false);
  b[0][5] = Piece(PieceType.gold, false);
  b[0][3] = Piece(PieceType.gold, false);
  b[2][3] = Piece(PieceType.silver, false);
  b[3][2] = Piece(PieceType.pawn, false);
  b[2][4] = Piece(PieceType.pawn, false);
  b[2][6] = Piece(PieceType.pawn, false);
  b[2][8] = Piece(PieceType.pawn, false);
  return b;
}

// 問8: 飛車の活用 — 浮き飛車から歩を取る場面
List<List<Piece?>> _prob8Board() {
  final b = _empty();
  // 先手
  b[8][4] = Piece(PieceType.king, true);
  b[5][7] = Piece(PieceType.rook, true); // 浮き飛車
  b[7][1] = Piece(PieceType.bishop, true);
  b[8][5] = Piece(PieceType.gold, true);
  b[8][3] = Piece(PieceType.gold, true);
  b[8][6] = Piece(PieceType.silver, true);
  b[8][2] = Piece(PieceType.silver, true);
  b[6][0] = Piece(PieceType.pawn, true);
  b[6][1] = Piece(PieceType.pawn, true);
  b[6][2] = Piece(PieceType.pawn, true);
  b[6][4] = Piece(PieceType.pawn, true);
  b[6][6] = Piece(PieceType.pawn, true);
  b[6][8] = Piece(PieceType.pawn, true);
  // 後手
  b[0][3] = Piece(PieceType.king, false);
  b[1][1] = Piece(PieceType.rook, false);
  b[1][7] = Piece(PieceType.bishop, false);
  b[0][4] = Piece(PieceType.gold, false);
  b[0][2] = Piece(PieceType.gold, false);
  b[2][5] = Piece(PieceType.silver, false);
  b[3][7] = Piece(PieceType.pawn, false); // 飛車の前の歩
  b[2][0] = Piece(PieceType.pawn, false);
  b[2][1] = Piece(PieceType.pawn, false);
  b[2][2] = Piece(PieceType.pawn, false);
  b[2][4] = Piece(PieceType.pawn, false);
  b[2][6] = Piece(PieceType.pawn, false);
  b[2][8] = Piece(PieceType.pawn, false);
  return b;
}

// 問9: 角の打ち込み — 角持ち駒で両取りをかける場面
List<List<Piece?>> _prob9Board() {
  final b = _empty();
  // 先手（角を持ち駒として保有、盤上なし）
  b[8][4] = Piece(PieceType.king, true);
  b[8][7] = Piece(PieceType.rook, true);
  b[8][5] = Piece(PieceType.gold, true);
  b[8][3] = Piece(PieceType.gold, true);
  b[8][6] = Piece(PieceType.silver, true);
  b[8][2] = Piece(PieceType.silver, true);
  b[6][0] = Piece(PieceType.pawn, true);
  b[6][1] = Piece(PieceType.pawn, true);
  b[6][3] = Piece(PieceType.pawn, true);
  b[6][4] = Piece(PieceType.pawn, true);
  b[6][6] = Piece(PieceType.pawn, true);
  b[6][8] = Piece(PieceType.pawn, true);
  // 後手: ▲5五角打ちで3三飛(2,6)と6四金(3,3)に両当たり
  b[0][3] = Piece(PieceType.king, false);
  b[2][6] = Piece(PieceType.rook, false);  // 3三飛（5五角のUR対角線上）
  b[3][3] = Piece(PieceType.gold, false);  // 6四金（5五角のUL対角線上）
  b[0][4] = Piece(PieceType.gold, false);
  b[0][2] = Piece(PieceType.silver, false);
  // 4四(3,5)の歩は5五角→3三飛の対角線を塞ぐため置かない
  b[2][0] = Piece(PieceType.pawn, false);
  b[2][1] = Piece(PieceType.pawn, false);
  b[2][2] = Piece(PieceType.pawn, false);
  b[2][4] = Piece(PieceType.pawn, false);
  b[2][8] = Piece(PieceType.pawn, false);
  return b;
}

// 問10: 銀の攻め方 — 銀を前進させる場面
List<List<Piece?>> _prob10Board() {
  final b = _empty();
  // 先手
  b[8][4] = Piece(PieceType.king, true);
  b[8][7] = Piece(PieceType.rook, true);
  b[7][1] = Piece(PieceType.bishop, true);
  b[6][5] = Piece(PieceType.silver, true); // 4七銀（4六へ進出）
  b[8][3] = Piece(PieceType.gold, true);
  b[8][5] = Piece(PieceType.gold, true);
  b[8][6] = Piece(PieceType.silver, true);
  b[6][0] = Piece(PieceType.pawn, true);
  b[6][1] = Piece(PieceType.pawn, true);
  b[6][2] = Piece(PieceType.pawn, true);
  b[6][3] = Piece(PieceType.pawn, true);
  b[6][4] = Piece(PieceType.pawn, true);
  b[6][6] = Piece(PieceType.pawn, true);
  b[6][7] = Piece(PieceType.pawn, true);
  b[6][8] = Piece(PieceType.pawn, true);
  // 後手
  b[0][3] = Piece(PieceType.king, false);
  b[1][1] = Piece(PieceType.rook, false);
  b[1][7] = Piece(PieceType.bishop, false);
  b[0][4] = Piece(PieceType.gold, false);
  b[0][2] = Piece(PieceType.gold, false);
  b[3][4] = Piece(PieceType.silver, false);
  b[3][5] = Piece(PieceType.pawn, false);
  b[2][0] = Piece(PieceType.pawn, false);
  b[2][1] = Piece(PieceType.pawn, false);
  b[2][2] = Piece(PieceType.pawn, false);
  b[2][3] = Piece(PieceType.pawn, false);
  b[2][6] = Piece(PieceType.pawn, false);
  b[2][8] = Piece(PieceType.pawn, false);
  return b;
}

List<List<Piece?>> _prob11Board() {
  final b = _empty();
  b[8][8] = Piece(PieceType.king, false);
  b[6][7] = Piece(PieceType.gold, true);
  b[7][6] = Piece(PieceType.rook, true);
  b[5][8] = Piece(PieceType.silver, true);
  b[3][5] = Piece(PieceType.king, true);
  b[7][8] = Piece(PieceType.gold, false);
  return b;
}

List<List<Piece?>> _prob12Board() {
  final b = _empty();
  b[0][8] = Piece(PieceType.king, false);   // 後手玉 1一
  b[2][7] = Piece(PieceType.silver, true);  // 先手銀 2三（1二を支える）
  b[5][4] = Piece(PieceType.king, true);    // 先手玉 5六
  return b;
}

List<List<Piece?>> _prob13Board() {
  final b = _empty();
  b[0][4] = Piece(PieceType.king, false);
  b[0][5] = Piece(PieceType.gold, false);
  b[0][3] = Piece(PieceType.gold, false);
  b[1][4] = Piece(PieceType.silver, false);
  b[2][7] = Piece(PieceType.rook, true);
  b[5][4] = Piece(PieceType.king, true);
  b[3][6] = Piece(PieceType.gold, true);
  return b;
}

List<List<Piece?>> _prob14Board() {
  final b = _empty();
  b[0][8] = Piece(PieceType.king, false);
  b[1][8] = Piece(PieceType.gold, false);
  b[1][7] = Piece(PieceType.silver, false);
  b[2][7] = Piece(PieceType.rook, true);
  b[1][6] = Piece(PieceType.gold, true);
  b[5][4] = Piece(PieceType.king, true);
  b[3][8] = Piece(PieceType.lance, true);
  return b;
}

List<List<Piece?>> _prob15Board() {
  final b = _empty();
  b[0][4] = Piece(PieceType.king, false);
  b[0][3] = Piece(PieceType.gold, false);
  b[0][5] = Piece(PieceType.gold, false);
  b[1][4] = Piece(PieceType.silver, false);
  b[1][3] = Piece(PieceType.pawn, false);
  b[1][5] = Piece(PieceType.pawn, false);
  b[4][7] = Piece(PieceType.bishop, true);
  b[5][4] = Piece(PieceType.king, true);
  b[5][6] = Piece(PieceType.rook, true); // 3六飛（2五→5二の角道を塞がない位置へ）
  return b;
}

// 問16-30: 新規追加（初級5、中級7、上級3）

// 問16: 歩で塞ぐ — 後手飛の王手を歩を打って受ける
List<List<Piece?>> _prob16Board() {
  final b = _empty();
  b[8][3] = Piece(PieceType.king, true);   // 先手玉 6九(8,3)
  b[8][4] = Piece(PieceType.gold, true);    // 5九金
  b[8][2] = Piece(PieceType.silver, true);  // 7九銀
  b[7][2] = Piece(PieceType.pawn, true);    // 7八歩
  b[0][4] = Piece(PieceType.king, false);   // 後手玉 5一
  b[1][3] = Piece(PieceType.rook, false);   // 後手飛 6二（6筋を直射し先手玉に王手）
  b[2][5] = Piece(PieceType.silver, false); // 後手銀 4三
  b[2][2] = Piece(PieceType.bishop, false); // 後手角 7三
  return b;
}

// 問17: 金を上げる — 玉を固くする動き
List<List<Piece?>> _prob17Board() {
  final b = _stdBoard();
  b[5][2] = b[6][2]; b[6][2] = null;
  b[5][7] = b[6][7]; b[6][7] = null;
  b[5][4] = b[6][4]; b[6][4] = null;
  return b;
}

// 問18: 玉の逃げ道を開ける
List<List<Piece?>> _prob18Board() {
  final b = _empty();
  b[8][4] = Piece(PieceType.king, true);
  b[8][3] = Piece(PieceType.gold, true);
  b[8][5] = Piece(PieceType.gold, true);
  b[7][4] = Piece(PieceType.silver, true);
  b[6][2] = Piece(PieceType.pawn, true);
  b[6][3] = Piece(PieceType.pawn, true);
  b[6][4] = Piece(PieceType.pawn, true);
  b[0][4] = Piece(PieceType.king, false);
  b[1][6] = Piece(PieceType.rook, false);
  return b;
}

// 問19: 銀冠の作り方
List<List<Piece?>> _prob19Board() {
  final b = _stdBoard();
  b[5][2] = b[6][2]; b[6][2] = null;
  b[5][7] = b[6][7]; b[6][7] = null;
  b[3][2] = b[2][2]; b[2][2] = null;
  return b;
}

// 問20: 右銀の活用
List<List<Piece?>> _prob20Board() {
  final b = _empty();
  b[8][4] = Piece(PieceType.king, true);
  b[8][7] = Piece(PieceType.rook, true);
  b[7][1] = Piece(PieceType.bishop, true);
  b[8][5] = Piece(PieceType.gold, true);
  b[8][3] = Piece(PieceType.gold, true);
  b[8][6] = Piece(PieceType.silver, true);
  b[5][2] = Piece(PieceType.silver, true); // 7六銀（7五へ進出して7四歩に当てる）
  b[6][0] = Piece(PieceType.pawn, true);
  b[6][1] = Piece(PieceType.pawn, true);
  b[6][4] = Piece(PieceType.pawn, true);
  b[6][6] = Piece(PieceType.pawn, true);
  b[6][7] = Piece(PieceType.pawn, true);
  b[6][8] = Piece(PieceType.pawn, true);
  b[0][4] = Piece(PieceType.king, false);
  b[3][2] = Piece(PieceType.pawn, false); // 7四歩（銀の進出目標）
  return b;
}

// 問21: 駒の両取り (中級)
// ▲6三銀: 7四(3,2)→6三(2,3)で6二金(1,3)と5四飛(3,4)に両当たり
// (旧版は後手飛車(5四)と先手玉(5九)が同じ5筋に位置し、間を遮る駒もなく
//  先手玉が開始局面から王手を受けている不成立な局面だった。
//  TsumeEngineでの検証により発覚・修正: 5筋に先手歩を配置して遮断)
List<List<Piece?>> _prob21Board() {
  final b = _empty();
  b[8][4] = Piece(PieceType.king, true);
  b[8][7] = Piece(PieceType.rook, true);
  b[3][2] = Piece(PieceType.silver, true);  // 7四（6三に1手で動ける）
  b[8][5] = Piece(PieceType.gold, true);
  b[8][3] = Piece(PieceType.gold, true);
  b[6][4] = Piece(PieceType.pawn, true);    // 4筋を遮断（後手飛車との間）
  b[0][4] = Piece(PieceType.king, false);
  b[1][3] = Piece(PieceType.gold, false);   // 6二金（6三銀の攻撃目標1）
  b[3][4] = Piece(PieceType.rook, false);   // 5四飛（6三銀の攻撃目標2）
  return b;
}

// 問22: 捨て駒で得する
List<List<Piece?>> _prob22Board() {
  final b = _empty();
  b[8][4] = Piece(PieceType.king, true);
  b[7][7] = Piece(PieceType.rook, true);
  b[7][1] = Piece(PieceType.bishop, true);
  b[8][5] = Piece(PieceType.gold, true);
  b[8][3] = Piece(PieceType.gold, true);
  b[5][4] = Piece(PieceType.silver, true);
  b[6][3] = Piece(PieceType.pawn, true);
  b[0][4] = Piece(PieceType.king, false);
  b[2][4] = Piece(PieceType.rook, false);
  b[1][3] = Piece(PieceType.gold, false);
  b[3][5] = Piece(PieceType.pawn, false);
  return b;
}

// 問23: 逃げ場を作る中盤戦
// ▲6四飛: 6六(5,3)→6四(3,3)は同一筋で有効
List<List<Piece?>> _prob23Board() {
  final b = _empty();
  b[8][4] = Piece(PieceType.king, true);
  b[5][3] = Piece(PieceType.rook, true);   // 6六（6四と同じ6筋）
  b[7][1] = Piece(PieceType.bishop, true);
  b[8][5] = Piece(PieceType.gold, true);
  b[8][3] = Piece(PieceType.gold, true);
  b[7][6] = Piece(PieceType.silver, true);
  b[6][2] = Piece(PieceType.pawn, true);
  b[6][4] = Piece(PieceType.pawn, true);
  b[0][4] = Piece(PieceType.king, false);
  b[2][6] = Piece(PieceType.rook, false);
  b[1][7] = Piece(PieceType.bishop, false);
  b[2][5] = Piece(PieceType.silver, false);
  return b;
}

// 問24: 金を使った両取り
// ▲6五金: 5六(5,4)→6五(4,3)で6四飛(3,3)と5五角(4,4)に両当たり
List<List<Piece?>> _prob24Board() {
  final b = _empty();
  b[8][4] = Piece(PieceType.king, true);
  b[8][7] = Piece(PieceType.rook, true);
  b[5][4] = Piece(PieceType.gold, true);   // 5六（6五に1手で動ける）
  b[8][5] = Piece(PieceType.gold, true);
  b[8][3] = Piece(PieceType.gold, true);
  b[6][3] = Piece(PieceType.pawn, true);
  b[0][4] = Piece(PieceType.king, false);
  b[3][3] = Piece(PieceType.rook, false);  // 6四飛（攻撃目標1）
  b[4][4] = Piece(PieceType.bishop, false); // 5五角（攻撃目標2）
  return b;
}

// 問25: 敵陣での駒さばき
List<List<Piece?>> _prob25Board() {
  final b = _empty();
  b[8][4] = Piece(PieceType.king, true);
  b[5][5] = Piece(PieceType.rook, true);
  b[3][2] = Piece(PieceType.knight, true);
  b[8][5] = Piece(PieceType.gold, true);
  b[8][3] = Piece(PieceType.gold, true);
  b[6][4] = Piece(PieceType.pawn, true);
  b[0][4] = Piece(PieceType.king, false);
  b[2][5] = Piece(PieceType.silver, false);
  b[1][3] = Piece(PieceType.gold, false);
  return b;
}

// 問26: 詰みを読む(上級) — 飛車を成り込んで王手（▲5二飛成）
// (旧版は先手飛車(5三)と後手玉(5一)が同じ5筋に位置し、間を遮る駒もなく
//  後手玉が開始局面から王手を受けている不成立な局面だった。
//  TsumeEngineでの検証により発覚・修正: 5二に後手歩を置き、
//  飛車が歩を取りながら成り込んで王手をかける形にした)
List<List<Piece?>> _prob26Board() {
  final b = _empty();
  b[0][4] = Piece(PieceType.king, false);   // 後手玉 5一
  b[0][3] = Piece(PieceType.gold, false);   // 6一金
  b[0][5] = Piece(PieceType.gold, false);   // 4一金
  b[1][4] = Piece(PieceType.pawn, false);   // 5二歩（4筋を遮断・成り込みの取り駒）
  b[2][4] = Piece(PieceType.rook, true);    // 先手飛 5三
  b[8][4] = Piece(PieceType.king, true);    // 先手玉 5九
  return b;
}

// 問27: 受けと攻めの両立 — 飛車を成り込んで王手（▲2二飛成）
List<List<Piece?>> _prob27Board() {
  final b = _empty();
  b[0][6] = Piece(PieceType.king, false);   // 後手玉 3一
  b[0][5] = Piece(PieceType.gold, false);   // 4一金
  b[2][7] = Piece(PieceType.rook, true);    // 先手飛 2三
  b[8][4] = Piece(PieceType.king, true);    // 先手玉 5九
  return b;
}

// 問28: 敵玉を追い詰める — 飛車を走らせて王手（▲2三飛）
// (旧版は先手飛車(2六)と後手玉(2一)が同じ2筋に位置し、間を遮る駒もなく
//  後手玉が開始局面から王手を受けている不成立な局面だった。
//  TsumeEngineでの検証により発覚・修正: 飛車を6三から2三へ横に走らせて
//  王手をかける形にした)
List<List<Piece?>> _prob28Board() {
  final b = _empty();
  b[0][7] = Piece(PieceType.king, false);   // 後手玉 2一
  b[0][6] = Piece(PieceType.gold, false);   // 3一金
  b[2][3] = Piece(PieceType.rook, true);    // 先手飛 6三
  b[8][4] = Piece(PieceType.king, true);    // 先手玉 5九
  return b;
}

// 問29: 詰めロジックの応用 — 9筋の飛車を成り込んで王手（▲9二飛成）
// (旧版は先手飛車(9五)が後手玉(9一)と同じ9筋にあり開始局面から王手を
//  受けていた上、守りの金(8二)自身も斜めに後手玉へ利いており二重に
//  不成立だった。TsumeEngineでの検証により発覚・修正: 飛車を6二から
//  9二へ横に成り込む形にし、金は桂馬に変更して着地点のみを守るようにした)
List<List<Piece?>> _prob29Board() {
  final b = _empty();
  b[0][0] = Piece(PieceType.king, false);   // 後手玉 9一
  b[3][1] = Piece(PieceType.knight, true);  // 8四桂（9二の守り）
  b[1][3] = Piece(PieceType.rook, true);    // 先手飛 6二
  b[8][4] = Piece(PieceType.king, true);    // 先手玉 5九
  return b;
}

// 問30: 複合手筋で勝利へ — 飛車を成り込んで王手（▲2二飛成）
List<List<Piece?>> _prob30Board() {
  final b = _empty();
  b[0][8] = Piece(PieceType.king, false);   // 後手玉 1一
  b[1][6] = Piece(PieceType.gold, false);   // 3二金（守り）
  b[2][7] = Piece(PieceType.rook, true);    // 先手飛 2三
  b[8][4] = Piece(PieceType.king, true);    // 先手玉 5九
  return b;
}

final List<_NMProb> _problems = [
  _NMProb(
    title: '角道を開ける',
    difficulty: '初級',
    description: '先手番。序盤の定跡として、角道を開けるために最善の一手を選んでください。',
    board: _prob1Board(),
    options: ['▲8六歩', '▲7六歩', '▲9六歩', '▲5六歩'],
    correctIndex: 1,
    explanation: '▲7六歩が正解。角道を開ける最も基本的な初手です。角が8八から使えるようになります。',
    sourceUrl: 'https://www.shogi.or.jp',
    sourceTitle: '日本将棋協会',
  ),
  _NMProb(
    title: '飛車先の歩を突く',
    difficulty: '初級',
    description: '先手番。居飛車戦法で飛車先を伸ばし、将来の攻めの形を作りましょう。',
    board: _prob2Board(),
    options: ['▲2六歩', '▲3六歩', '▲1六歩', '▲4六歩'],
    correctIndex: 0,
    explanation: '▲2六歩が正解。飛車先（2筋）の歩を突いて、飛車の働きを活発にします。',
    sourceUrl: 'https://www.shogi.or.jp',
    sourceTitle: '日本将棋協会',
  ),
  _NMProb(
    title: '玉の囲い方向',
    difficulty: '初級',
    description: '先手番。居飛車で玉を安全に囲うため、まず玉をどちらに動かすべきですか？',
    board: _prob3Board(),
    options: ['▲6八玉', '▲5九玉', '▲4八玉', '▲6九玉'],
    correctIndex: 2,
    explanation: '▲4八玉が正解。居飛車の場合、玉は左側（4八→3八→2八）に囲うのが基本です。',
    sourceUrl: 'https://www.shogi.or.jp',
    sourceTitle: '日本将棋協会',
  ),
  _NMProb(
    title: '中飛車への振り方',
    difficulty: '初級',
    description: '先手番（振り飛車）。中飛車の形を作るため、飛車をどこに振りますか？',
    board: _prob4Board(),
    options: ['▲5八飛', '▲3八飛', '▲4八飛', '▲6八飛'],
    correctIndex: 0,
    explanation: '▲5八飛が正解。中飛車は5筋に飛車を置き、中央から攻める戦法です。',
    sourceUrl: 'https://www.shogi.or.jp',
    sourceTitle: '日本将棋協会',
  ),
  _NMProb(
    title: '棒銀の進出',
    difficulty: '初級',
    description: '先手番。棒銀戦法で銀を前進させ、後手の飛車先を攻めるための一手は？',
    board: _prob5Board(),
    options: ['▲2六銀', '▲3七銀', '▲2八銀', '▲1六歩'],
    correctIndex: 0,
    explanation: '▲2六銀が正解。棒銀は銀を2六まで進出させ、後手の守りを突破する戦法です。',
    sourceUrl: 'https://www.shogi.or.jp',
    sourceTitle: '日本将棋協会',
  ),
  _NMProb(
    title: '歩の垂れ',
    difficulty: '中級',
    description: '先手番。相手の守りに歩を「垂れ」て、後で成り込む手筋を使いましょう。',
    board: _prob6Board(),
    options: ['▲6四歩', '▲6五歩', '▲5五歩', '▲7五歩'],
    correctIndex: 0,
    explanation: '▲6四歩が正解。敵陣に歩を垂らして、次に▲6三歩成りを狙う手筋です。',
    sourceUrl: 'https://tsume.glico.com',
    sourceTitle: '将棋パズル',
  ),
  _NMProb(
    title: '桂馬の活用',
    difficulty: '中級',
    description: '先手番。桂馬を活用して後手の銀に圧力をかける最善手を選んでください。',
    board: _prob7Board(),
    options: ['▲7五桂', '▲6四桂', '▲8五桂', '▲5五桂'],
    correctIndex: 0,
    explanation: '▲7五桂が正解。桂は「二段跳び」で相手の守り駒に当たる位置に跳ねるのが基本です。',
    sourceUrl: 'https://tsume.glico.com',
    sourceTitle: '将棋パズル',
  ),
  _NMProb(
    title: '飛車の活用',
    difficulty: '中級',
    description: '先手番。浮き飛車の形から相手の歩に当てるための最善手は何ですか？',
    board: _prob8Board(),
    options: ['▲2四飛', '▲2二飛成', '▲5五飛', '▲2八飛'],
    correctIndex: 0,
    explanation: '▲2四飛が正解。相手の歩に飛車を当てて取り込み、飛車先を突破する手筋です。',
    sourceUrl: 'https://tsume.glico.com',
    sourceTitle: '将棋パズル',
  ),
  _NMProb(
    title: '角の打ち込み',
    difficulty: '中級',
    description: '先手番（角を持ち駒として持っています）。角を打って飛車・金取りの両取りを狙う手は？',
    board: _prob9Board(),
    options: ['▲5五角', '▲4四角', '▲7七角', '▲2二角'],
    correctIndex: 0,
    explanation: '▲5五角が正解。5五に角を打つと、右斜め前の3三飛車と左斜め前の6四金に同時に当たる両取りになります。',
    sourceUrl: 'https://tsume.glico.com',
    sourceTitle: '将棋パズル',
    p1Hand: {PieceType.bishop: 1},
  ),
  _NMProb(
    title: '銀の攻め方',
    difficulty: '中級',
    description: '先手番。銀を使って後手の守りに迫る最善手を選んでください。',
    board: _prob10Board(),
    options: ['▲4六銀', '▲5六銀', '▲3六銀', '▲4八銀'],
    correctIndex: 0,
    explanation: '▲4六銀が正解。銀を斜め前に進めて、後手の銀に当てながら攻勢を強める手です。',
    sourceUrl: 'https://tsume.glico.com',
    sourceTitle: '将棋パズル',
  ),
  _NMProb(
    title: '詰めろをかける',
    difficulty: '上級',
    description: '先手番。後手玉に「詰めろ」（次に詰める形）をかける最善手を選んでください。',
    board: _prob11Board(),
    options: ['▲1六金', '▲2八金', '▲1七金', '▲3七飛'],
    correctIndex: 2,
    explanation: '▲1七金が正解。玉の逃げ道を塞ぎながら詰めろをかける手です。後手は受けが難しくなります。',
    sourceUrl: 'https://shogidb.org',
    sourceTitle: '将棋データベース',
  ),
  _NMProb(
    title: '一手詰め',
    difficulty: '上級',
    description: '先手番。持ち駒の金を使い、1一の後手玉を一手で詰ましてください。',
    board: _prob12Board(),
    options: ['▲1二金', '▲2二金', '▲1三金', '▲2三金'],
    correctIndex: 0,
    explanation: '▲1二金が正解。2三の銀が1二の地点を支えているので玉は金を取れず、逃げ場もなく詰みです。',
    sourceUrl: 'https://shogidb.org',
    sourceTitle: '将棋データベース',
    p1Hand: {PieceType.gold: 1},
  ),
  _NMProb(
    title: '飛車の成り込み',
    difficulty: '上級',
    description: '先手番。飛車を敵陣に成り込んで後手玉に迫る最善手を選んでください。',
    board: _prob13Board(),
    options: ['▲2一飛成', '▲2二飛成', '▲5二飛成', '▲2四飛'],
    correctIndex: 1,
    explanation: '▲2二飛成が正解。飛車を成り込んで竜を作り、後手玉の近くに強力な駒を配置します。',
    sourceUrl: 'https://shogidb.org',
    sourceTitle: '将棋データベース',
  ),
  _NMProb(
    title: '必死の形',
    difficulty: '上級',
    description: '先手番。後手玉に「必死」（どうやっても詰みを逃れられない）をかける手は？',
    board: _prob14Board(),
    options: ['▲1九香', '▲2九飛', '▲1八金打', '▲2八飛'],
    correctIndex: 2,
    explanation: '▲1八金打が正解。玉の逃げ道を金で全て封じる「必死」の手です。後手は受ける手がありません。',
    sourceUrl: 'https://shogidb.org',
    sourceTitle: '将棋データベース',
    p1Hand: {PieceType.gold: 1},
  ),
  _NMProb(
    title: '角で決める',
    difficulty: '上級',
    description: '先手番。角を使って後手玉に王手をかけ、かつ強力な竜を作る最善手は？',
    board: _prob15Board(),
    options: ['▲7三角成', '▲5二角成', '▲6三角成', '▲3二角成'],
    correctIndex: 1,
    explanation: '▲5二角成が正解。角が5二に成ることで後手玉に王手がかかり、馬として強力な攻め駒になります。',
    sourceUrl: 'https://shogidb.org',
    sourceTitle: '将棋データベース',
  ),
  // 新規追加: 問16-30
  _NMProb(
    title: '歩で塞ぐ',
    difficulty: '初級',
    description: '先手番。後手の飛車による王手を歩を打って防いでください。',
    board: _prob16Board(),
    options: ['▲6八歩打', '▲7七歩', '▲6五歩打', '▲5八歩打'],
    correctIndex: 0,
    explanation: '▲6八歩打が正解。6二の後手飛車が6九の先手玉に向かう6筋を歩で遮断します。',
    sourceUrl: 'https://www.shogi.or.jp',
    sourceTitle: '日本将棋協会',
    p1Hand: {PieceType.pawn: 1},
  ),
  _NMProb(
    title: '金を上げる',
    difficulty: '初級',
    description: '先手番。金を上に上げて玉の守りを強化する手筋を選んでください。',
    board: _prob17Board(),
    options: ['▲5八金', '▲4八金', '▲6八金', '▲7八金'],
    correctIndex: 0,
    explanation: '▲5八金が正解。金を上げることで玉の前防御を厚くします。',
    sourceUrl: 'https://www.shogi.or.jp',
    sourceTitle: '日本将棋協会',
  ),
  _NMProb(
    title: '玉の逃げ道を開ける',
    difficulty: '初級',
    description: '先手番。玉が詰まないように逃げ道を作る手を選んでください。',
    board: _prob18Board(),
    options: ['▲6七金', '▲6五銀', '▲6六歩', '▲7五歩'],
    correctIndex: 2,
    explanation: '▲6六歩が正解。歩を進めることで玉に逃げ場を与えます。',
    sourceUrl: 'https://www.shogi.or.jp',
    sourceTitle: '日本将棋協会',
  ),
  _NMProb(
    title: '銀冠の作り方',
    difficulty: '初級',
    description: '先手番。居飛車の代表的な玉の囲い「銀冠」を作るための一手は？',
    board: _prob19Board(),
    options: ['▲4八銀', '▲3七銀', '▲4六銀', '▲3八銀'],
    correctIndex: 0,
    explanation: '▲4八銀が正解。銀冠は金銀で玉を厳重に守る形です。',
    sourceUrl: 'https://www.shogi.or.jp',
    sourceTitle: '日本将棋協会',
  ),
  _NMProb(
    title: '右銀の活用',
    difficulty: '初級',
    description: '先手番。右側の銀を活用して攻撃に参加させる最善手は？',
    board: _prob20Board(),
    options: ['▲7五銀', '▲8五銀', '▲6五銀', '▲7三銀'],
    correctIndex: 0,
    explanation: '▲7五銀が正解。右銀を前に進めて攻撃の駒として機能させます。',
    sourceUrl: 'https://www.shogi.or.jp',
    sourceTitle: '日本将棋協会',
  ),
  _NMProb(
    title: '駒の両取り',
    difficulty: '中級',
    description: '先手番。銀を進めて相手の2つの駒を同時に攻撃する「両取り」の手は？',
    board: _prob21Board(),
    options: ['▲6四銀', '▲5三銀', '▲6三銀', '▲7四銀'],
    correctIndex: 2,
    explanation: '▲6三銀が正解。7四の銀が6三に進み、後手の6二金と5四飛車に同時に当たる「銀の両取り」になります。',
    sourceUrl: 'https://tsume.glico.com',
    sourceTitle: '将棋パズル',
  ),
  _NMProb(
    title: '捨て駒で得する',
    difficulty: '中級',
    description: '先手番。駒を捨てることで相手の重要な防御駒を削除する手を選んでください。',
    board: _prob22Board(),
    options: ['▲4五銀', '▲5五銀', '▲3四銀', '▲4四銀'],
    correctIndex: 1,
    explanation: '▲5五銀が正解。銀を捨てることで後手の防御が崩れます。',
    sourceUrl: 'https://tsume.glico.com',
    sourceTitle: '将棋パズル',
  ),
  _NMProb(
    title: '逃げ場を作る中盤戦',
    difficulty: '中級',
    description: '先手番。6六の浮き飛車を前進させて後手陣を圧迫する最善手は？',
    board: _prob23Board(),
    options: ['▲6四飛', '▲5四飛', '▲6三飛', '▲5三飛'],
    correctIndex: 0,
    explanation: '▲6四飛が正解。6六の飛車を6四に進め、後手陣への圧力を高めながら次の▲6三飛成を狙います。',
    sourceUrl: 'https://tsume.glico.com',
    sourceTitle: '将棋パズル',
  ),
  _NMProb(
    title: '金を使った両取り',
    difficulty: '中級',
    description: '先手番。金を活用して相手の2つの駒に両当たりをかける手は？',
    board: _prob24Board(),
    options: ['▲5五金', '▲6五金', '▲5三金', '▲6三金'],
    correctIndex: 1,
    explanation: '▲6五金が正解。5六の金が6五に進み、後手の6四飛車と5五角に同時に当たる「金の両取り」になります。',
    sourceUrl: 'https://tsume.glico.com',
    sourceTitle: '将棋パズル',
  ),
  _NMProb(
    title: '敵陣での駒さばき',
    difficulty: '中級',
    description: '先手番。敵陣に侵入した駒を活かして攻めを継続する手を選んでください。',
    board: _prob25Board(),
    options: ['▲4四飛', '▲3四飛', '▲4三飛', '▲5四飛'],
    correctIndex: 0,
    explanation: '▲4四飛が正解。敵陣での飛車の動きが重要です。',
    sourceUrl: 'https://tsume.glico.com',
    sourceTitle: '将棋パズル',
  ),
  _NMProb(
    title: '詰みを読む',
    difficulty: '上級',
    description: '先手番。5三の飛車を成り込んで5一の後手玉に王手をかける手は？',
    board: _prob26Board(),
    options: ['▲5四飛', '▲5二飛成', '▲4二飛成', '▲2二飛'],
    correctIndex: 1,
    explanation: '▲5二飛成が正解。飛車を成って竜を作りながら王手をかけ、玉の急所に強力な大駒を効かせます。',
    sourceUrl: 'https://shogidb.org',
    sourceTitle: '将棋データベース',
  ),
  _NMProb(
    title: '受けと攻めの両立',
    difficulty: '上級',
    description: '先手番。2三の飛車を成り込んで3一の後手玉に王手をかける手は？',
    board: _prob27Board(),
    options: ['▲2一飛成', '▲2二飛成', '▲3二飛成', '▲2四飛'],
    correctIndex: 1,
    explanation: '▲2二飛成が正解。飛車を2二に成って竜を作り、斜めの利きで3一の玉に王手をかけます。',
    sourceUrl: 'https://shogidb.org',
    sourceTitle: '将棋データベース',
  ),
  _NMProb(
    title: '敵玉を追い詰める',
    difficulty: '上級',
    description: '先手番。6三の飛車を走らせて2一の後手玉に王手をかける手は？',
    board: _prob28Board(),
    options: ['▲2三飛', '▲1三飛', '▲3三飛', '▲2二飛'],
    correctIndex: 0,
    explanation: '▲2三飛が正解。2筋を飛車で直射して2一の玉に王手をかけ、追い詰めていきます。',
    sourceUrl: 'https://shogidb.org',
    sourceTitle: '将棋データベース',
  ),
  _NMProb(
    title: '詰めロジックの応用',
    difficulty: '上級',
    description: '先手番。6二の飛車を成り込んで9一の後手玉に王手をかける手は？',
    board: _prob29Board(),
    options: ['▲9三飛成', '▲9二飛成', '▲8二飛成', '▲9四飛'],
    correctIndex: 1,
    explanation: '▲9二飛成が正解。飛車を9二に成って竜を作り、9一の玉に王手をかけて端へ追い詰めます。',
    sourceUrl: 'https://shogidb.org',
    sourceTitle: '将棋データベース',
  ),
  _NMProb(
    title: '複合手筋で勝利へ',
    difficulty: '上級',
    description: '先手番。2三の飛車を成り込んで1一の後手玉に王手をかける手は？',
    board: _prob30Board(),
    options: ['▲2三飛成', '▲2二飛成', '▲1二飛成', '▲3二飛成'],
    correctIndex: 1,
    explanation: '▲2二飛成が正解。飛車を2二に成って竜を作り、斜めの利きで1一の玉に王手をかけます。',
    sourceUrl: 'https://shogidb.org',
    sourceTitle: '将棋データベース',
  ),
];

class _NextMoveScreenState extends State<NextMoveScreen> {
  int _current = 0;
  int? _selectedIdx;
  late List<bool> _cleared;
  int _score = 0;
  bool _showResult = false;
  String _selectedDifficulty = 'すべて'; // Filter by difficulty
  late List<_NMProb> _filteredProblems; // Filtered problems list

  @override
  void initState() {
    super.initState();
    _cleared = List.filled(_problems.length, false);
    _filteredProblems = List.from(_problems);
    _loadCleared();
  }

  Future<void> _loadCleared() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (int i = 0; i < _problems.length; i++) {
        _cleared[i] = prefs.getBool('next_move_cleared_$i') ?? false;
      }
    });
  }

  Future<void> _saveCleared(int idx) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('next_move_cleared_$idx', true);
  }

  void _applyDifficultyFilter(String difficulty) {
    setState(() {
      _selectedDifficulty = difficulty;
      if (difficulty == 'すべて') {
        _filteredProblems = List.from(_problems);
      } else {
        _filteredProblems =
            _problems.where((p) => p.difficulty == difficulty).toList();
      }
      _current = 0;
      _selectedIdx = null;
      _score = 0;
      _showResult = false;
    });
  }

  void _selectOption(int idx) {
    if (_selectedIdx != null) return;
    final prob = _filteredProblems[_current];
    // Find the index in original _problems to save correctly
    final originalIdx = _problems.indexOf(prob);
    setState(() {
      _selectedIdx = idx;
      if (idx == prob.correctIndex) {
        _score++;
        _cleared[originalIdx] = true;
        _saveCleared(originalIdx);
      }
    });
  }

  void _nextProblem() {
    if (_current < _filteredProblems.length - 1) {
      setState(() {
        _current++;
        _selectedIdx = null;
      });
    } else {
      setState(() {
        _showResult = true;
      });
    }
  }

  void _restart() {
    setState(() {
      _current = 0;
      _selectedIdx = null;
      _score = 0;
      _showResult = false;
    });
  }

  Color _difficultyColor(String diff) {
    switch (diff) {
      case '初級':
        return Colors.green;
      case '中級':
        return Colors.amber;
      case '上級':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildResultScreen() {
    final total = _filteredProblems.isEmpty ? 1 : _filteredProblems.length;
    final pct = (_score / total * 100).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF0F3460), width: 2),
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Text(
                    '結果',
                    style: TextStyle(
                      color: Color(0xDEFFFFFF),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '$_score / ${_filteredProblems.length}',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '正解率 $pct%',
                    style: const TextStyle(
                      color: Color(0xDEFFFFFF),
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    pct >= 80
                        ? '素晴らしい！'
                        : pct >= 60
                            ? 'よく頑張りました！'
                            : 'もっと練習しましょう！',
                    style: TextStyle(
                      color: pct >= 80
                          ? Colors.green
                          : pct >= 60
                              ? Colors.amber
                              : Colors.red,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _restart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3460),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'もう一度',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyFilter() {
    final difficulties = ['すべて', '初級', '中級', '上級'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '難度で絞り込み',
            style: TextStyle(
              color: Color(0xDEFFFFFF),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: difficulties.map((diff) {
                final isSelected = _selectedDifficulty == diff;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton(
                    onPressed: () => _applyDifficultyFilter(diff),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected
                          ? _difficultyColor(diff)
                          : const Color(0xFF0F3460),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      diff,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemScreen() {
    // 選択した難易度に該当する問題が無い場合、_filteredProblems[_current] は
    // RangeErrorでクラッシュするため、フィルタUIだけ残して空表示にする。
    if (_filteredProblems.isEmpty || _current >= _filteredProblems.length) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDifficultyFilter(),
            const SizedBox(height: 48),
            const Center(
              child: Text(
                'この難易度の問題はありません',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    final prob = _filteredProblems[_current];
    final answered = _selectedIdx != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDifficultyFilter(),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '問 ${_current + 1} / ${_filteredProblems.length}',
                      style: const TextStyle(
                        color: Color(0xDEFFFFFF),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '正解: $_score',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _current / _filteredProblems.length,
                    backgroundColor: const Color(0xFF0F3460),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.amber),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0F3460), width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        prob.title,
                        style: const TextStyle(
                          color: Color(0xDEFFFFFF),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _difficultyColor(prob.difficulty)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _difficultyColor(prob.difficulty),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        prob.difficulty,
                        style: TextStyle(
                          color: _difficultyColor(prob.difficulty),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  prob.description,
                  style: const TextStyle(
                    color: Color(0xDEFFFFFF),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: MiniBoardWidget(
                    board: prob.board,
                    showLabels: true,
                    size: 280,
                    p1Hand: prob.p1Hand,
                    p2Hand: prob.p2Hand,
                  ),
                ),
                const SizedBox(height: 20),
                Column(
                  children: List.generate(prob.options.length, (i) {
                    Color btnColor = const Color(0xFF0F3460);
                    Color textColor = const Color(0xDEFFFFFF);
                    IconData? icon;

                    if (answered) {
                      if (i == prob.correctIndex) {
                        btnColor = Colors.green.shade800;
                        textColor = Colors.white;
                        icon = Icons.check_circle_outline;
                      } else if (i == _selectedIdx) {
                        btnColor = Colors.red.shade800;
                        textColor = Colors.white;
                        icon = Icons.cancel_outlined;
                      } else {
                        btnColor = const Color(0xFF0A2744);
                        textColor = Colors.grey;
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: answered ? null : () => _selectOption(i),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: btnColor,
                            foregroundColor: textColor,
                            disabledBackgroundColor: btnColor,
                            disabledForegroundColor: textColor,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.centerLeft,
                          ),
                          child: Row(
                            children: [
                              if (icon != null) ...[
                                Icon(icon, size: 20, color: textColor),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  '${String.fromCharCode(65 + i)}. ${prob.options[i]}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textColor,
                                    fontWeight:
                                        i == prob.correctIndex && answered
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                if (answered) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1628),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedIdx == prob.correctIndex
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _selectedIdx == prob.correctIndex
                                  ? Icons.lightbulb_outline
                                  : Icons.info_outline,
                              color: _selectedIdx == prob.correctIndex
                                  ? Colors.green
                                  : Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _selectedIdx == prob.correctIndex
                                  ? '正解！'
                                  : '不正解',
                              style: TextStyle(
                                color: _selectedIdx == prob.correctIndex
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          prob.explanation,
                          style: const TextStyle(
                            color: Color(0xDEFFFFFF),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextProblem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _current < _filteredProblems.length - 1
                            ? '次の問題　→'
                            : '結果を見る　→',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        foregroundColor: Colors.white,
        title: const Text(
          '次の一手',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _showResult ? _buildResultScreen() : _buildProblemScreen(),
    );
  }
}