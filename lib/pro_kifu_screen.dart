// lib/pro_kifu_screen.dart — プロ棋譜閲覧画面

import 'dart:async';
import 'package:flutter/material.dart';
import 'piece.dart';
import 'mini_board_widget.dart';
import 'theme/app_theme.dart';

// ===== 初期盤面生成 =====
List<List<Piece?>> _buildInitBoard() {
  final b = List<List<Piece?>>.generate(
    9,
    (_) => List<Piece?>.filled(9, null, growable: false),
  );
  void s(int r, int c, PieceType t, bool p1) => b[r][c] = Piece(t, p1);

  // 後手（P2）上部
  s(0, 0, PieceType.lance, false);
  s(0, 1, PieceType.knight, false);
  s(0, 2, PieceType.silver, false);
  s(0, 3, PieceType.gold, false);
  s(0, 4, PieceType.king, false);
  s(0, 5, PieceType.gold, false);
  s(0, 6, PieceType.silver, false);
  s(0, 7, PieceType.knight, false);
  s(0, 8, PieceType.lance, false);
  s(1, 1, PieceType.rook, false);
  s(1, 7, PieceType.bishop, false);
  for (int c = 0; c < 9; c++) {
    s(2, c, PieceType.pawn, false);
  }

  // 先手（P1）下部
  s(8, 0, PieceType.lance, true);
  s(8, 1, PieceType.knight, true);
  s(8, 2, PieceType.silver, true);
  s(8, 3, PieceType.gold, true);
  s(8, 4, PieceType.king, true);
  s(8, 5, PieceType.gold, true);
  s(8, 6, PieceType.silver, true);
  s(8, 7, PieceType.knight, true);
  s(8, 8, PieceType.lance, true);
  s(7, 7, PieceType.rook, true);
  s(7, 1, PieceType.bishop, true);
  for (int c = 0; c < 9; c++) {
    s(6, c, PieceType.pawn, true);
  }

  return b;
}

// ===== _ProGame データクラス =====
class _ProGame {
  final String title;
  final String p1;
  final String p2;
  final int year;
  final String event;
  final String description;
  final List<String> moves;
  final String result;
  final List<_MoveComment> comments;

  const _ProGame({
    required this.title,
    required this.p1,
    required this.p2,
    required this.year,
    required this.event,
    required this.description,
    required this.moves,
    required this.result,
    this.comments = const [],
  });
}

class _MoveComment {
  final int moveIndex; // 0-based index into moves list
  final String comment;
  const _MoveComment(this.moveIndex, this.comment);
}

// ===== 有名棋譜データ（8局） =====
final List<_ProGame> _proGames = [
  // 1. 藤井聡太デビュー局 (2016年 加古川青流戦)
  _ProGame(
    title: '藤井聡太 棋士デビュー局',
    p1: '藤井聡太（四段）',
    p2: '加藤一二三（九段）',
    year: 2016,
    event: '第2回加古川青流戦',
    description:
        '14歳2ヶ月でプロデビューした藤井聡太四段（当時）が、伝説の棋士・加藤一二三九段と対局した歴史的一局。'
        '最年少プロデビュー記録を持つ藤井が、将棋界の生きる伝説に勝利した。この局は現代将棋史に残る名勝負として語り継がれている。',
    result: '先手勝ち',
    moves: [
      '▲7六歩', '△8四歩', '▲6八銀', '△3四歩', '▲6六歩', '△6二銀',
      '▲5六歩', '△5四歩', '▲4八銀', '△4二銀', '▲5八金右', '△3二金',
      '▲6七金', '△4一玉', '▲7八金', '△5二金', '▲6九玉', '△3三銀',
      '▲7九玉', '△3一角', '▲3六歩', '△4四歩', '▲3七銀', '△4三金右',
      '▲6八角', '△2四歩', '▲3五歩', '△同歩', '▲同銀', '△4五歩',
      '▲2四銀', '△2二角', '▲3三銀成', '△同桂', '▲1一角成', '△4六歩',
      '▲同歩', '△4五桂', '▲4七金', '△3七桂成', '▲同金', '△4六歩',
      '▲同金', '△3五角', '▲2一馬', '△3七角成', '▲4五金', '△4六歩',
      '▲3四金', '△4七歩成', '▲同玉', '△4六歩', '▲5八玉', '△4七歩成',
      '▲4九玉', '△3八馬', '▲5八玉', '△4八と', '▲6九玉', '△5八と',
      '▲7九玉', '△6八と', '▲8八玉', '△7八と', '▲9七玉', '△8七と',
      '▲同玉', '△7八銀', '▲9六玉', '△8七銀成', '▲9五玉', '△8六馬',
      '▲9四玉', '△9三歩', '▲同玉', '△9二歩', '▲8四玉', '△8三歩',
      '▲同玉', '△8二歩', '▲9三玉', '△9二歩', '▲同玉', '△9一歩',
      '▲8三玉', '△8二歩', '▲同玉', '△7二金', '▲9三玉', '△9二歩',
    ],
    comments: [
      _MoveComment(0, '▲7六歩 — 矢倉を目指す出だし'),
      _MoveComment(26, '▲3五歩 — 仕掛け！加古川の反撃を誘う積極的な一手'),
      _MoveComment(34, '▲1一角成 — 馬を作り優位を確立'),
    ],
  ),

  // 2. 大山康晴 vs 升田幸三 伝説の名局
  _ProGame(
    title: '大山康晴 vs 升田幸三 名局',
    p1: '升田幸三（八段）',
    p2: '大山康晴（名人）',
    year: 1958,
    event: '第17期名人戦 第5局',
    description:
        '昭和将棋界最大のライバル関係を誇る升田幸三と大山康晴の激突。升田は「升田式石田流」など多くの戦法を創案した天才。'
        'この局では升田の独創的な指し回しが光り、戦後将棋の発展に大きく貢献した歴史的名局。',
    result: '先手勝ち',
    moves: [
      '▲7六歩', '△3四歩', '▲7五歩', '△8四歩', '▲7八飛', '△6二銀',
      '▲4八玉', '△4二玉', '▲3八玉', '△3二玉', '▲2八玉', '△2二玉',
      '▲3八銀', '△3二銀', '▲7六飛', '△8四飛', '▲7四歩', '△同歩',
      '▲同飛', '△7三歩', '▲7六飛', '△7四飛', '▲同飛', '△同歩',
      '▲8二角成', '△同銀', '▲7一飛', '△4二角', '▲7三飛成', '△6四角',
      '▲6三龍', '△同銀', '▲同角成', '△5四桂', '▲8二馬', '△4六桂',
      '▲5九金', '△5八桂成', '▲同金', '△4六桂', '▲4八金', '△5八桂成',
      '▲同金', '△4六桂', '▲3九玉', '△3八桂成', '▲同玉', '△2六桂',
      '▲2七玉', '△1八桂成', '▲1六玉', '△1五歩', '▲同玉', '△1四香',
      '▲2四玉', '△2三金', '▲3五玉', '△3四金', '▲4六玉', '△5四桂',
      '▲5七玉', '△6六桂', '▲6八玉', '△7八桂成', '▲同玉', '△6六桂',
      '▲6七玉', '△6五桂', '▲7七玉', '△8八金', '▲6六玉', '△6五金',
    ],
    comments: [
      _MoveComment(2, '▲7五歩 — 升田式石田流の特徴的な出だし'),
      _MoveComment(4, '▲7八飛 — 飛車を7筋に振る石田流の完成'),
      _MoveComment(24, '▲8二角成 — 大駒交換を強行する激しい手'),
    ],
  ),

  // 3. 羽生善治 永世七冠達成局
  _ProGame(
    title: '羽生善治 永世七冠達成',
    p1: '羽生善治（竜王）',
    p2: '佐藤康光（棋王）',
    year: 2017,
    event: '第30期竜王戦 第5局',
    description:
        '羽生善治が将棋史上初となる「永世七冠」を達成した歴史的一局。'
        '7つのタイトル全ての永世称号を獲得するという前人未踏の偉業を成し遂げ、翌年には国民栄誉賞を受賞。'
        '相手の佐藤康光棋王も元名人・棋聖の実力者で、この勝利の価値はさらに高い。',
    result: '先手勝ち',
    moves: [
      '▲2六歩', '△3四歩', '▲2五歩', '△3三角', '▲7六歩', '△4四歩',
      '▲4八銀', '△3二銀', '▲6八玉', '△4二飛', '▲7八玉', '△6二玉',
      '▲5八金右', '△7二玉', '▲3六歩', '△4三銀', '▲3七桂', '△5四銀',
      '▲2四歩', '△同歩', '▲同飛', '△2三歩', '▲2六飛', '△1四歩',
      '▲1六歩', '△4五歩', '▲4六歩', '△同歩', '▲同銀', '△4四銀',
      '▲3五歩', '△同歩', '▲同角', '△3四歩', '▲4六角', '△4五歩',
      '▲6八角', '△4四銀', '▲1五歩', '△同歩', '▲1三歩', '△同桂',
      '▲1五香', '△同香', '▲2四飛', '△2三歩', '▲2一飛成', '△4六歩',
      '▲1一龍', '△4七歩成', '▲4一龍', '△4八と', '▲5九金', '△5九と',
      '▲5一龍', '△4九と', '▲6九銀', '△5九と', '▲同銀', '△3九角成',
      '▲4九飛', '△2九馬', '▲4四飛', '△3三桂', '▲4一飛成', '△5一金',
      '▲3一龍', '△4一金', '▲2一龍', '△5一金引', '▲4一角', '△6一玉',
      '▲5二角成', '△7一玉', '▲6一馬',
    ],
    comments: [
      _MoveComment(0, '▲2六歩 — 角換わりを目指す'),
      _MoveComment(38, '▲1五歩 — 端攻めを見せる重要な一手'),
      _MoveComment(46, '▲2一飛成 — 龍を作り優勢を拡大'),
      _MoveComment(70, '▲5二角成 — 詰めろの角。羽生の終盤力炸裂'),
    ],
  ),

  // 4. 藤井聡太 初タイトル戦（棋聖戦2020）
  _ProGame(
    title: '藤井聡太 初タイトル奪取',
    p1: '藤井聡太（七段）',
    p2: '渡辺明（棋聖）',
    year: 2020,
    event: '第91期棋聖戦 第4局',
    description:
        '17歳11ヶ月、史上最年少でタイトルを獲得した歴史的一局。相手の渡辺明は三冠（棋聖・王位・棋王）を保持する強豪。'
        '藤井の対局中の読みの深さと終盤の正確さが際立ち、将棋界に新時代の到来を告げた。',
    result: '先手勝ち',
    moves: [
      '▲2六歩', '△8四歩', '▲2五歩', '△8五歩', '▲7六歩', '△3二金',
      '▲7七角', '△3四歩', '▲8八銀', '△7七角成', '▲同銀', '△2二銀',
      '▲3八金', '△3三銀', '▲9六歩', '△9四歩', '▲3六歩', '△6二銀',
      '▲3七桂', '△6四歩', '▲4六角', '△4四銀', '▲2四歩', '△同歩',
      '▲同角', '△2三歩', '▲3五角', '△4三金', '▲4六歩', '△3二玉',
      '▲4五歩', '△5四銀', '▲4四歩', '△同金', '▲同角', '△4三歩',
      '▲6八角', '△4四歩', '▲3五桂', '△4二玉', '▲4三歩', '△同玉',
      '▲4四歩', '△3二玉', '▲4三歩成', '△同玉', '▲4四歩', '△3二玉',
      '▲5六桂', '△4三銀', '▲4三歩成', '△同銀', '▲4四歩', '△同銀',
      '▲4三銀', '△3三玉', '▲3四銀成', '△同玉', '▲4五金', '△3三玉',
      '▲3四金', '△2二玉', '▲2三歩', '△1二玉', '▲2二歩成', '△同玉',
      '▲2三歩', '△1二玉', '▲2二銀', '△1一玉', '▲3二角成',
    ],
    comments: [
      _MoveComment(6, '▲7七角 — 相掛かりから角換わりへ'),
      _MoveComment(20, '▲4六角 — 積極的に角を活用'),
      _MoveComment(38, '▲3五桂 — 攻めを加速する桂跳ね'),
      _MoveComment(54, '▲4三銀 — 決定打！渡辺の守りを崩す'),
    ],
  ),

  // 5. 中原誠 vs 大山康晴 黄金世代の激突
  _ProGame(
    title: '中原誠 vs 大山康晴 王将戦',
    p1: '大山康晴（九段）',
    p2: '中原誠（名人）',
    year: 1973,
    event: '第22期王将戦 第6局',
    description:
        '昭和将棋界を代表する二大巨人の対決。50代の大山が20代の中原に挑んだ「世代を超えた名勝負」として有名。'
        '大山の粘り強い受けと中原のダイナミックな攻めが激突し、将棋ファンを魅了した。',
    result: '後手勝ち',
    moves: [
      '▲7六歩', '△3四歩', '▲6六歩', '△8四歩', '▲6八飛', '△6二銀',
      '▲3八銀', '△4二玉', '▲3九玉', '△3二玉', '▲2八玉', '△2二玉',
      '▲1八香', '△1二香', '▲1九玉', '△1一玉', '▲2八銀', '△2二銀',
      '▲5六歩', '△5四歩', '▲5七銀', '△5三銀', '▲6七銀', '△4四銀',
      '▲7七桂', '△4三金', '▲6五歩', '△3三角', '▲6六銀', '△5五銀',
      '▲同銀', '△同角', '▲7八銀', '△3三角', '▲6六銀', '△5五歩',
      '▲同銀', '△5四歩', '▲6六銀', '△5五歩', '▲同銀', '△同角',
      '▲6四歩', '△同歩', '▲6五桂', '△5六角', '▲7八飛', '△7六角',
      '▲5三桂成', '△同金', '▲6四飛', '△6三歩', '▲6八飛', '△5四金',
      '▲6五桂', '△5三金', '▲7三桂成', '△同桂', '▲6四角', '△4二銀',
      '▲8二角成', '△5五桂', '▲7九飛', '△4七桂成', '▲同金', '△3六角',
      '▲4六歩', '△5四角成', '▲4八金', '△5八桂', '▲3八金', '△4六桂成',
    ],
    comments: [
      _MoveComment(4, '▲6八飛 — 中飛車に振る大山の得意戦法'),
      _MoveComment(26, '▲6五歩 — 仕掛け！大山らしい厚みの将棋'),
      _MoveComment(48, '▲6四飛 — 飛車が捌けて攻め合い'),
    ],
  ),

  // 6. 羽生善治 vs 佐藤康光 「魂の一手」
  _ProGame(
    title: '羽生善治 魂の一手 棋聖戦',
    p1: '羽生善治（棋聖）',
    p2: '佐藤康光（七段）',
    year: 1997,
    event: '第68期棋聖戦 第4局',
    description:
        '「魂の一手」と称された羽生の5二銀が有名な一局。終盤の際どい局面で放たれたこの一手は、'
        '後に「20世紀最高の一手」と評されることになる。羽生と佐藤の魂を賭けた真剣勝負。',
    result: '先手勝ち',
    moves: [
      '▲7六歩', '△8四歩', '▲2六歩', '△8五歩', '▲7七角', '△3四歩',
      '▲8八銀', '△3二金', '▲7八金', '△7七角成', '▲同銀', '△4二銀',
      '▲2五歩', '△3三銀', '▲3八金', '△2二銀', '▲3六歩', '△6二銀',
      '▲4六歩', '△6四歩', '▲4七金', '△6三銀', '▲3七桂', '△7四銀',
      '▲6八玉', '△6二玉', '▲7八玉', '△7二玉', '▲2四歩', '△同歩',
      '▲同角', '△2三歩', '▲4六角', '△3二金', '▲3五歩', '△同歩',
      '▲同角', '△3四歩', '▲4六角', '△7三角', '▲3七角', '△4六角',
      '▲同金', '△8五桂', '▲8六銀', '△7七桂成', '▲同桂', '△8五桂',
      '▲6六銀', '△7七桂成', '▲同金', '△4六角', '▲6七金', '△8五角',
      '▲7六銀', '△4六歩', '▲同歩', '△4七歩', '▲5八銀', '△4八歩成',
      '▲4九銀', '△5八と', '▲同玉', '△4七銀', '▲6七玉', '△4九銀成',
      '▲5二銀',
    ],
    comments: [
      _MoveComment(0, '▲7六歩 — 角換わりを志向'),
      _MoveComment(43, '▲8六銀 — 桂馬の攻めを受ける'),
      _MoveComment(66, '▲5二銀！！ — 「魂の一手」！攻防の妙手。後に20世紀最高の一手と称される'),
    ],
  ),

  // 7. 藤井聡太 AI超えの一手（王位戦2021）
  _ProGame(
    title: '藤井聡太 AI超えの一手',
    p1: '藤井聡太（叡王）',
    p2: '豊島将之（竜王）',
    year: 2021,
    event: '第62期王位戦 第4局',
    description:
        '藤井聡太が放った▲4一銀が世界中を驚かせた一局。最強のAIでも指し手として示さなかったこの手は、'
        '「人間がAIを超えた」と話題になった。この局の勝利で藤井は二冠を確定させた。',
    result: '先手勝ち',
    moves: [
      '▲2六歩', '△3四歩', '▲7六歩', '△4四歩', '▲4八銀', '△4二飛',
      '▲6八玉', '△6二玉', '▲7八玉', '△7二玉', '▲5六歩', '△8二玉',
      '▲5七銀', '△3二銀', '▲2五歩', '△3三角', '▲3六歩', '△4三銀',
      '▲3七桂', '△5四銀', '▲4六銀', '△4五歩', '▲3五歩', '△同歩',
      '▲同角', '△4六歩', '▲同歩', '△3六歩', '▲4四角', '△3二飛',
      '▲3六飛', '△3五歩', '▲3四飛', '△3一飛', '▲3五飛', '△3四歩',
      '▲同飛', '△3三歩', '▲3七飛', '△6四角', '▲4五歩', '△3七角成',
      '▲同桂', '△3四飛', '▲3六歩', '△7四飛', '▲2六角', '△7五飛',
      '▲同角', '△4八角', '▲5九金左', '△3七角成', '▲5八金', '△4八馬',
      '▲5七金', '△3八馬', '▲4八飛', '△同馬', '▲4九銀', '△3九馬',
      '▲4一銀',
    ],
    comments: [
      _MoveComment(4, '▲4八銀 — 四間飛車対策の出だし'),
      _MoveComment(20, '▲4六銀 — 積極的に銀を前進'),
      _MoveComment(60, '▲4一銀！！ — AI超えの衝撃的な一手！最強AIも読まなかった妙手'),
    ],
  ),

  // 8. 木村義雄 vs 坂田三吉 昭和の名勝負
  _ProGame(
    title: '木村義雄 vs 坂田三吉 伝説の対局',
    p1: '坂田三吉（名人）',
    p2: '木村義雄（八段）',
    year: 1937,
    event: '実力制名人戦前夜祭記念対局',
    description:
        '「浪速の剣客」坂田三吉と後の永世名人・木村義雄の歴史的一局。'
        '独学で将棋を学んだ坂田は60歳を超えてなお第一線で活躍し、その情熱は今も多くの人々を感動させている。'
        'この対局は昭和将棋史の金字塔として後世に語り継がれている。',
    result: '先手勝ち',
    moves: [
      '▲7六歩', '△3四歩', '▲2六歩', '△8四歩', '▲2五歩', '△8五歩',
      '▲7八金', '△3二金', '▲2四歩', '△同歩', '▲同飛', '△2三歩',
      '▲3四飛', '△8六歩', '▲同歩', '△同飛', '▲3三飛成', '△同桂',
      '▲8七歩', '△8二飛', '▲2二角成', '△同銀', '▲4五角', '△2四銀',
      '▲6三角成', '△8七飛成', '▲9八金', '△5二金左', '▲5二馬', '△同玉',
      '▲3三飛', '△4二玉', '▲3二飛成', '△同銀', '▲5三角', '△4一玉',
      '▲3二角成', '△同玉', '▲4三金', '△2一玉', '▲3二金', '△1一玉',
      '▲2二銀', '△1二玉', '▲1三銀成', '△同玉', '▲1一龍', '△1二香',
      '▲2二龍', '△2一桂', '▲1五歩', '△同歩', '▲1四歩', '△1二玉',
      '▲1三歩成', '△同玉', '▲2三龍', '△1四玉', '▲1三龍',
    ],
    comments: [
      _MoveComment(8, '▲2四歩 — 飛車先突破を狙う強攻'),
      _MoveComment(12, '▲3四飛 — 飛車を大胆に転回'),
      _MoveComment(16, '▲3三飛成 — 龍を作りながら攻勢'),
      _MoveComment(20, '▲2二角成 — 角成で攻め駒を投入'),
    ],
  ),
];

// ===== ProKifuScreen (一覧) =====
class ProKifuScreen extends StatefulWidget {
  const ProKifuScreen({super.key});

  @override
  State<ProKifuScreen> createState() => _ProKifuScreenState();
}

class _ProKifuScreenState extends State<ProKifuScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<_ProGame> get _filteredGames {
    if (_searchQuery.isEmpty) return _proGames;
    final q = _searchQuery.toLowerCase();
    return _proGames.where((g) {
      return g.title.toLowerCase().contains(q) ||
          g.p1.toLowerCase().contains(q) ||
          g.p2.toLowerCase().contains(q) ||
          g.event.toLowerCase().contains(q) ||
          g.year.toString().contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final games = _filteredGames;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        foregroundColor: Colors.white,
        title: const Text(
          'プロ棋譜閲覧',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '棋士名・棋戦名で検索',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                prefixIcon:
                    Icon(Icons.search, color: Colors.white.withOpacity(0.6)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ),
      ),
      body: games.isEmpty
          ? Center(
              child: Text(
                '該当する棋譜が見つかりません',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: games.length,
              itemBuilder: (context, i) {
                final g = games[i];
                return _GameCard(
                  game: g,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _ProKifuDetailScreen(game: g),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ===== ゲームカード =====
class _GameCard extends StatelessWidget {
  final _ProGame game;
  final VoidCallback onTap;

  const _GameCard({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1E1E30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      game.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: game.result.startsWith('先手')
                          ? const Color(0xFF1A4A8A)
                          : const Color(0xFF8A1A1A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      game.result,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.emoji_events,
                      color: Color(0xFFFFD700), size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      game.event,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    '${game.year}年',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _PlayerChip(name: game.p1, isP1: true),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      'vs',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4), fontSize: 12),
                    ),
                  ),
                  _PlayerChip(name: game.p2, isP1: false),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                game.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.format_list_numbered,
                          size: 13, color: Colors.white.withOpacity(0.4)),
                      const SizedBox(width: 4),
                      Text(
                        '${game.moves.length}手',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4), fontSize: 12),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        '詳細を見る',
                        style:
                            TextStyle(color: Colors.blue.shade300, fontSize: 12),
                      ),
                      Icon(Icons.chevron_right,
                          size: 16, color: Colors.blue.shade300),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final String name;
  final bool isP1;
  const _PlayerChip({required this.name, required this.isP1});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isP1
            ? Colors.blue.withOpacity(0.15)
            : Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isP1
              ? Colors.blue.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: isP1 ? Colors.blue.shade200 : Colors.red.shade200,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ===== 詳細・棋譜再生画面 =====
class _ProKifuDetailScreen extends StatefulWidget {
  final _ProGame game;
  const _ProKifuDetailScreen({super.key, required this.game});

  @override
  State<_ProKifuDetailScreen> createState() => _ProKifuDetailScreenState();
}

class _ProKifuDetailScreenState extends State<_ProKifuDetailScreen> {
  int _currentMove = 0; // 0=開始局面, N=N手目まで表示
  bool _isPlaying = false;
  Timer? _timer;
  final ScrollController _moveListController = ScrollController();

  List<String> get moves => widget.game.moves;
  int get totalMoves => moves.length;

  Map<int, String> get _commentMap =>
      {for (final c in widget.game.comments) c.moveIndex: c.comment};

  @override
  void dispose() {
    _timer?.cancel();
    _moveListController.dispose();
    super.dispose();
  }

  void _stepForward() {
    if (_currentMove < totalMoves) {
      setState(() => _currentMove++);
      _scrollToCurrentMove();
    } else {
      _stopPlay();
    }
  }

  void _stepBack() {
    if (_currentMove > 0) {
      setState(() => _currentMove--);
      _scrollToCurrentMove();
    }
  }

  void _goToStart() {
    setState(() => _currentMove = 0);
    _scrollToCurrentMove();
  }

  void _goToEnd() {
    setState(() => _currentMove = totalMoves);
    _scrollToCurrentMove();
  }

  void _startPlay() {
    if (_currentMove >= totalMoves) setState(() => _currentMove = 0);
    setState(() => _isPlaying = true);
    _timer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (_currentMove < totalMoves) {
        _stepForward();
      } else {
        _stopPlay();
      }
    });
  }

  void _stopPlay() {
    _timer?.cancel();
    setState(() => _isPlaying = false);
  }

  void _scrollToCurrentMove() {
    if (!_moveListController.hasClients) return;
    final idx = _currentMove > 0 ? _currentMove - 1 : 0;
    const rowHeight = 36.0;
    final offset = (idx ~/ 2) * rowHeight;
    _moveListController.animateTo(
      offset.clamp(0.0, _moveListController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  String get _currentMoveLabel {
    if (_currentMove == 0) return '開始局面';
    if (_currentMove >= totalMoves) return '終局 (${totalMoves}手)';
    return '${_currentMove}手目: ${moves[_currentMove - 1]}';
  }

  String? get _currentComment {
    if (_currentMove == 0) return null;
    return _commentMap[_currentMove - 1];
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final board = _buildInitBoard();
    final commentMap = _commentMap;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        foregroundColor: Colors.white,
        title: Text(
          game.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 免責表示：本画面の棋譜・解説は学習用に作成した架空の対局例
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade300),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '※本画面の棋譜・解説は学習用に作成した架空の対局例であり、実際の棋士の対局を再現したものではありません。',
                      style: TextStyle(color: Colors.red.shade200, fontSize: 11, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),

            // 対局情報ヘッダー
            _InfoHeader(game: game),
            const SizedBox(height: 16),

            // 説明
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFFFD700).withOpacity(0.3), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Color(0xFFFFD700), size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'この局について',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    game.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 盤面表示（初期局面固定）
            Center(
              child: Column(
                children: [
                  _TurnLabel(name: game.p2, isP1: false),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 300,
                    height: 300,
                    child: MiniBoardWidget(
                      board: board,
                      showLabels: true,
                      size: 300,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _TurnLabel(name: game.p1, isP1: true),
                ],
              ),
            ),

            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, size: 14, color: Colors.blue.shade300),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '表示は平手初期局面です。棋譜をKIF形式でインポートすると実際の局面を再現できます。',
                      style:
                          TextStyle(color: Colors.blue.shade200, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 現在の手の表示
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A40),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    _currentMoveLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_currentComment != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFFFFD700).withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star,
                              color: Color(0xFFFFD700), size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _currentComment!,
                              style: TextStyle(
                                color: Colors.yellow.shade100,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 進行バー
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFFFFD700),
                inactiveTrackColor: Colors.white.withOpacity(0.1),
                thumbColor: const Color(0xFFFFD700),
                overlayColor: const Color(0xFFFFD700).withOpacity(0.1),
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: _currentMove.toDouble(),
                min: 0,
                max: totalMoves.toDouble(),
                divisions: totalMoves > 0 ? totalMoves : 1,
                onChanged: (v) {
                  _stopPlay();
                  setState(() => _currentMove = v.round());
                  _scrollToCurrentMove();
                },
              ),
            ),

            // 再生コントロール
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ControlButton(
                    icon: Icons.skip_previous, onTap: _goToStart, tooltip: '最初'),
                const SizedBox(width: 8),
                _ControlButton(
                    icon: Icons.navigate_before,
                    onTap: _stepBack,
                    tooltip: '前の手',
                    size: 32),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _isPlaying ? _stopPlay : _startPlay,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withOpacity(0.4),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.black87,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _ControlButton(
                    icon: Icons.navigate_next,
                    onTap: _stepForward,
                    tooltip: '次の手',
                    size: 32),
                const SizedBox(width: 8),
                _ControlButton(
                    icon: Icons.skip_next, onTap: _goToEnd, tooltip: '最後'),
              ],
            ),

            const SizedBox(height: 24),

            // 棋譜リスト
            _buildMoveList(commentMap),
          ],
        ),
      ),
    );
  }

  Widget _buildMoveList(Map<int, String> commentMap) {
    final pairs = <List<String>>[];
    for (int i = 0; i < moves.length; i += 2) {
      final pair = [moves[i]];
      if (i + 1 < moves.length) pair.add(moves[i + 1]);
      pairs.add(pair);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '棋譜',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          height: 280,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2A),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          ),
          child: ListView.builder(
            controller: _moveListController,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: pairs.length,
            itemBuilder: (context, i) {
              final moveNumSente = i * 2 + 1;
              final moveNumGote = i * 2 + 2;
              final senteActive = _currentMove == moveNumSente;
              final goteActive = _currentMove == moveNumGote;
              final hasSenteComment =
                  commentMap.containsKey(moveNumSente - 1);
              final hasGoteComment = pairs[i].length > 1 &&
                  commentMap.containsKey(moveNumGote - 1);

              return Container(
                height: 36,
                decoration: BoxDecoration(
                  color: (senteActive || goteActive)
                      ? const Color(0xFFFFD700).withOpacity(0.1)
                      : (i % 2 == 0
                          ? Colors.transparent
                          : Colors.white.withOpacity(0.02)),
                ),
                child: Row(
                  children: [
                    // 手数
                    SizedBox(
                      width: 40,
                      child: Center(
                        child: Text(
                          '$moveNumSente.',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 11),
                        ),
                      ),
                    ),
                    // 先手の手
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          _stopPlay();
                          setState(() => _currentMove = moveNumSente);
                          _scrollToCurrentMove();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: senteActive
                                ? const Color(0xFFFFD700).withOpacity(0.2)
                                : null,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pairs[i][0],
                                  style: TextStyle(
                                    color: senteActive
                                        ? const Color(0xFFFFD700)
                                        : Colors.white.withOpacity(0.85),
                                    fontWeight: senteActive
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (hasSenteComment)
                                const Icon(Icons.star,
                                    size: 10, color: Color(0xFFFFD700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // 後手の手
                    if (pairs[i].length > 1)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _stopPlay();
                            setState(() => _currentMove = moveNumGote);
                            _scrollToCurrentMove();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: goteActive
                                  ? const Color(0xFFFFD700).withOpacity(0.2)
                                  : null,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    pairs[i][1],
                                    style: TextStyle(
                                      color: goteActive
                                          ? const Color(0xFFFFD700)
                                          : Colors.white.withOpacity(0.85),
                                      fontWeight: goteActive
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (hasGoteComment)
                                  const Icon(Icons.star,
                                      size: 10, color: Color(0xFFFFD700)),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      const Expanded(child: SizedBox()),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.star, size: 12, color: Color(0xFFFFD700)),
            const SizedBox(width: 4),
            Text(
              '= 注目の一手あり',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

// ===== 補助ウィジェット =====

class _InfoHeader extends StatelessWidget {
  final _ProGame game;
  const _InfoHeader({required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('先手',
                        style: TextStyle(color: Colors.blue, fontSize: 11)),
                    Text(
                      game.p1,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  const Text('vs',
                      style:
                          TextStyle(color: Colors.white54, fontSize: 14)),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: game.result.startsWith('先手')
                          ? Colors.blue.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      game.result,
                      style: TextStyle(
                        color: game.result.startsWith('先手')
                            ? Colors.blue.shade200
                            : Colors.red.shade200,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('後手',
                        style: TextStyle(color: Colors.red, fontSize: 11)),
                    Text(
                      game.p2,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _InfoChip(
                  icon: Icons.emoji_events,
                  label: game.event,
                  color: const Color(0xFFFFD700)),
              _InfoChip(
                  icon: Icons.calendar_today,
                  label: '${game.year}年',
                  color: Colors.blue.shade300),
              _InfoChip(
                  icon: Icons.format_list_numbered,
                  label: '${game.moves.length}手',
                  color: Colors.green.shade300),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(color: color.withOpacity(0.9), fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TurnLabel extends StatelessWidget {
  final String name;
  final bool isP1;
  const _TurnLabel({required this.name, required this.isP1});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: isP1 ? Colors.blue : Colors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          isP1 ? '▲ $name（先手）' : '△ $name（後手）',
          style: TextStyle(
            color: isP1 ? Colors.blue.shade200 : Colors.red.shade200,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final double size;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A40),
            shape: BoxShape.circle,
            border:
                Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Icon(icon, color: Colors.white70, size: size),
        ),
      ),
    );
  }
}
