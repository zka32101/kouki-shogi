// lib/joseki_drill_screen.dart — 定跡インタラクティブ練習
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'piece.dart';
import 'mini_board_widget.dart';
import 'theme/app_theme.dart';

// ── 定跡の1手 ──────────────────────────────────────────────
class DrillStep {
  final String label;       // 「▲7六歩」など
  final String comment;
  final int fromRow, fromCol; // 移動元
  final int toRow,   toCol;   // 移動先
  final bool isP1;            // true=先手番（ユーザーが指す）
  final bool promote;

  const DrillStep({
    required this.label,
    required this.comment,
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
    required this.isP1,
    this.promote = false,
  });
}

// ── 定跡データ ──────────────────────────────────────────────
class JosekiDrill {
  final String name;
  final String description;
  final Color color;
  final IconData icon;
  final String difficulty; // '入門' '初級' '中級'
  final List<DrillStep> steps;

  const JosekiDrill({
    required this.name,
    required this.description,
    required this.color,
    required this.icon,
    required this.difficulty,
    required this.steps,
  });
}

// ── 盤面ユーティリティ ──────────────────────────────────────
List<List<Piece?>> _initialBoard() {
  final b = List.generate(9, (_) => List<Piece?>.filled(9, null));
  b[0][0] = const Piece(PieceType.lance,  false);
  b[0][1] = const Piece(PieceType.knight, false);
  b[0][2] = const Piece(PieceType.silver, false);
  b[0][3] = const Piece(PieceType.gold,   false);
  b[0][4] = const Piece(PieceType.king,   false);
  b[0][5] = const Piece(PieceType.gold,   false);
  b[0][6] = const Piece(PieceType.silver, false);
  b[0][7] = const Piece(PieceType.knight, false);
  b[0][8] = const Piece(PieceType.lance,  false);
  b[1][1] = const Piece(PieceType.rook,   false);
  b[1][7] = const Piece(PieceType.bishop, false);
  for (int c = 0; c < 9; c++) b[2][c] = const Piece(PieceType.pawn, false);
  for (int c = 0; c < 9; c++) b[6][c] = const Piece(PieceType.pawn, true);
  b[7][1] = const Piece(PieceType.bishop, true);
  b[7][7] = const Piece(PieceType.rook,   true);
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

List<List<Piece?>> _applyStep(List<List<Piece?>> board, DrillStep step) {
  final b = List.generate(9, (r) => List<Piece?>.from(board[r]));
  final piece = b[step.fromRow][step.fromCol];
  if (piece == null) return b;
  b[step.toRow][step.toCol] = step.promote
      ? Piece(piece.promotedType, piece.isPlayer1)
      : piece;
  b[step.fromRow][step.fromCol] = null;
  return b;
}

// ── 定跡一覧データ ──────────────────────────────────────────
final List<JosekiDrill> drills = [
  // ──────────── 相矢倉 ─────────────────────
  JosekiDrill(
    name: '相矢倉',
    description: '双方が矢倉囲いを目指す持久戦の代表定跡。初段を目指す人の必修科目。',
    color: Colors.indigo,
    icon: Icons.security,
    difficulty: '初級',
    steps: [
      DrillStep(label: '▲7六歩', comment: '角道を開ける初手。矢倉・居飛車の第一歩。', fromRow: 6, fromCol: 2, toRow: 5, toCol: 2, isP1: true),
      DrillStep(label: '△8四歩', comment: '後手が飛車先を突く。居飛車を示す手。', fromRow: 2, fromCol: 1, toRow: 3, toCol: 1, isP1: false),
      DrillStep(label: '▲6八銀', comment: '左銀を6八に上げて矢倉の準備。', fromRow: 8, fromCol: 2, toRow: 7, toCol: 3, isP1: true),
      DrillStep(label: '△3四歩', comment: '後手も角道を開けて矢倉に応じる。', fromRow: 2, fromCol: 6, toRow: 3, toCol: 6, isP1: false),
      DrillStep(label: '▲6六歩', comment: '角道を止めて矢倉を宣言。この手で戦型が決まる。', fromRow: 6, fromCol: 3, toRow: 5, toCol: 3, isP1: true),
      DrillStep(label: '△6二銀', comment: '後手も銀を上がって囲いの準備を始める。', fromRow: 0, fromCol: 2, toRow: 1, toCol: 3, isP1: false),
      DrillStep(label: '▲5六歩', comment: '5筋の歩を突いて中央を主張。', fromRow: 6, fromCol: 4, toRow: 5, toCol: 4, isP1: true),
      DrillStep(label: '△5四歩', comment: '後手も中央に歩を突いて対抗。', fromRow: 2, fromCol: 4, toRow: 3, toCol: 4, isP1: false),
      DrillStep(label: '▲5八金右', comment: '右金が5八に移動。矢倉の金銀配置を整える。', fromRow: 8, fromCol: 5, toRow: 7, toCol: 4, isP1: true),
      DrillStep(label: '△4二銀', comment: '後手も左銀を上がって矢倉の準備。', fromRow: 0, fromCol: 6, toRow: 1, toCol: 5, isP1: false),
      DrillStep(label: '△3二金', comment: '後手も金を上がって矢倉囲いの準備。', fromRow: 0, fromCol: 5, toRow: 1, toCol: 6, isP1: false),
      DrillStep(label: '▲6七銀', comment: '6八の銀を繰り替えて矢倉の銀の配置を完成させる。', fromRow: 7, fromCol: 3, toRow: 6, toCol: 3, isP1: true),
      DrillStep(label: '△4一玉', comment: '後手の玉が4一に寄る。矢倉囲いへの入城準備。', fromRow: 0, fromCol: 4, toRow: 0, toCol: 5, isP1: false),
      DrillStep(label: '▲7九角', comment: '角を7九に引いて矢倉城の形を整える。', fromRow: 7, fromCol: 1, toRow: 8, toCol: 2, isP1: true),
      DrillStep(label: '△7四歩', comment: '後手が7筋の歩を突いて攻めの準備。', fromRow: 2, fromCol: 2, toRow: 3, toCol: 2, isP1: false),
      DrillStep(label: '▲6八玉', comment: '玉が6八へ。矢倉囲いへ向けて入城開始。', fromRow: 8, fromCol: 4, toRow: 7, toCol: 3, isP1: true),
      DrillStep(label: '▲7八玉', comment: '玉が7八へ。矢倉への道中。', fromRow: 7, fromCol: 3, toRow: 7, toCol: 2, isP1: true),
      DrillStep(label: '▲8八玉', comment: '玉が8八に入城！矢倉囲いへ！', fromRow: 7, fromCol: 2, toRow: 7, toCol: 1, isP1: true),
      DrillStep(label: '△7三桂', comment: '後手の桂が跳ねる。7筋攻めの布石。', fromRow: 0, fromCol: 1, toRow: 2, toCol: 2, isP1: false),
      DrillStep(label: '▲7七桂', comment: '桂馬を7七に跳ねて、玉が8九へ入城するスペースを作る。', fromRow: 8, fromCol: 1, toRow: 6, toCol: 2, isP1: true),
      DrillStep(label: '▲8九玉', comment: '玉が8九に入城。矢倉囲い完成！', fromRow: 7, fromCol: 1, toRow: 8, toCol: 1, isP1: true),
      DrillStep(label: '△3一角', comment: '後手の角が3一に引いて矢倉の構えを整える。', fromRow: 1, fromCol: 7, toRow: 0, toCol: 6, isP1: false),
      DrillStep(label: '▲9八香', comment: '端香を9八に上げて玉頭を補強。矢倉囲いの仕上げ。', fromRow: 8, fromCol: 0, toRow: 7, toCol: 0, isP1: true),
    ],
  ),
  // ──────────── 四間飛車美濃囲い ──────────
  JosekiDrill(
    name: '四間飛車美濃囲い',
    description: '後手が飛車を4筋に振り美濃囲いで固める人気の振り飛車戦法。堅固な守りが特徴。',
    color: Colors.teal,
    icon: Icons.flight,
    difficulty: '入門',
    steps: [
      DrillStep(label: '▲7六歩', comment: '先手が角道を開ける。後手の振り飛車を見届けよう。', fromRow: 6, fromCol: 2, toRow: 5, toCol: 2, isP1: true),
      DrillStep(label: '△4二飛', comment: '後手が飛車を4筋（四二）に振る。四間飛車の出だし！', fromRow: 1, fromCol: 1, toRow: 1, toCol: 5, isP1: false),
      DrillStep(label: '△3二銀', comment: '銀を3二に上がる。美濃囲いの銀の出発点。', fromRow: 0, fromCol: 6, toRow: 1, toCol: 6, isP1: false),
      DrillStep(label: '△5二金左', comment: '左の金を5二に上がる。美濃囲いの金の位置。', fromRow: 0, fromCol: 3, toRow: 1, toCol: 4, isP1: false),
      DrillStep(label: '△6二玉', comment: '玉が6二に移動。美濃囲いへの入城が始まる。', fromRow: 0, fromCol: 4, toRow: 1, toCol: 3, isP1: false),
      DrillStep(label: '△7二玉', comment: '玉がさらに7二へ。端に向かって逃げる。', fromRow: 1, fromCol: 3, toRow: 1, toCol: 2, isP1: false),
      DrillStep(label: '△8二玉', comment: '玉が8二に入城。美濃囲いの玉の最終位置。', fromRow: 1, fromCol: 2, toRow: 1, toCol: 1, isP1: false),
      DrillStep(label: '△7二銀', comment: '銀が7二に上がって美濃囲い完成！玉を銀と金で守る堅固な形。', fromRow: 0, fromCol: 2, toRow: 1, toCol: 2, isP1: false),
    ],
  ),
  // ──────────── 棒銀 ───────────────────────
  JosekiDrill(
    name: '棒銀',
    description: '銀を一直線に2筋へ進め飛車と連携して攻める。シンプルで威力抜群の攻撃戦法。',
    color: Colors.orange,
    icon: Icons.trending_up,
    difficulty: '入門',
    steps: [
      DrillStep(label: '▲7六歩', comment: '初手。角道を開ける。', fromRow: 6, fromCol: 2, toRow: 5, toCol: 2, isP1: true),
      DrillStep(label: '△8四歩', comment: '後手も飛車先を突く。', fromRow: 2, fromCol: 1, toRow: 3, toCol: 1, isP1: false),
      DrillStep(label: '▲2六歩', comment: '2筋の歩を突く。棒銀の準備開始。', fromRow: 6, fromCol: 7, toRow: 5, toCol: 7, isP1: true),
      DrillStep(label: '△8五歩', comment: '後手が飛車先を伸ばす。', fromRow: 3, fromCol: 1, toRow: 4, toCol: 1, isP1: false),
      DrillStep(label: '▲2五歩', comment: '歩をさらに2五へ。銀の通り道を作る。', fromRow: 5, fromCol: 7, toRow: 4, toCol: 7, isP1: true),
      DrillStep(label: '△3二金', comment: '後手が金を上げて2筋を守る。', fromRow: 0, fromCol: 5, toRow: 1, toCol: 6, isP1: false),
      DrillStep(label: '▲7八金', comment: '金を7八に上げて囲いを補強。', fromRow: 8, fromCol: 3, toRow: 7, toCol: 2, isP1: true),
      DrillStep(label: '△3四歩', comment: '後手が角道を開ける。', fromRow: 2, fromCol: 6, toRow: 3, toCol: 6, isP1: false),
      DrillStep(label: '▲3八銀', comment: '銀を3八へ。棒銀の銀が動き始める！', fromRow: 8, fromCol: 6, toRow: 7, toCol: 6, isP1: true),
      DrillStep(label: '△6二銀', comment: '後手が銀を上げて守りを固める。', fromRow: 0, fromCol: 2, toRow: 1, toCol: 3, isP1: false),
      DrillStep(label: '▲2七銀', comment: '銀が2七に進出。飛車の横に並ぶ棒銀の形！', fromRow: 7, fromCol: 6, toRow: 6, toCol: 7, isP1: true),
      DrillStep(label: '△4一玉', comment: '後手の玉が4一に寄る。', fromRow: 0, fromCol: 4, toRow: 0, toCol: 5, isP1: false),
      DrillStep(label: '▲2六銀', comment: '銀が2六に前進。いよいよ攻撃態勢！', fromRow: 6, fromCol: 7, toRow: 5, toCol: 7, isP1: true),
      DrillStep(label: '▲2四歩', comment: '歩を2四へ突く。棒銀の攻撃開始！後手の対応を迫る。', fromRow: 4, fromCol: 7, toRow: 3, toCol: 7, isP1: true),
      DrillStep(label: '▲2五銀', comment: '銀が2五に進出。飛車・歩・銀の三段攻撃が完成！', fromRow: 5, fromCol: 7, toRow: 4, toCol: 7, isP1: true),
    ],
  ),
  // ──────────── 角かわり腰掛銀 ─────────────
  JosekiDrill(
    name: '角かわり腰掛銀',
    description: '角を交換し合う現代的な定跡。腰掛銀で中央を制圧する高度な戦法。',
    color: Colors.deepPurple,
    icon: Icons.swap_horiz,
    difficulty: '中級',
    steps: [
      DrillStep(label: '▲7六歩', comment: '角道を開ける初手。', fromRow: 6, fromCol: 2, toRow: 5, toCol: 2, isP1: true),
      DrillStep(label: '△8四歩', comment: '後手が飛車先を突く。', fromRow: 2, fromCol: 1, toRow: 3, toCol: 1, isP1: false),
      DrillStep(label: '▲2六歩', comment: '飛車先を突いて角換わりへの第一歩。', fromRow: 6, fromCol: 7, toRow: 5, toCol: 7, isP1: true),
      DrillStep(label: '△8五歩', comment: '後手が飛車先を伸ばす。', fromRow: 3, fromCol: 1, toRow: 4, toCol: 1, isP1: false),
      DrillStep(label: '▲7七角', comment: '角を7七に上げる。後手の角交換に備える重要な一手。', fromRow: 7, fromCol: 1, toRow: 6, toCol: 2, isP1: true),
      DrillStep(label: '△3四歩', comment: '後手が角道を開けて角換わりに応じる。', fromRow: 2, fromCol: 6, toRow: 3, toCol: 6, isP1: false),
      DrillStep(label: '▲8八銀', comment: '銀を8八に上げて角を守る。', fromRow: 8, fromCol: 2, toRow: 7, toCol: 1, isP1: true),
      DrillStep(label: '△7七角成', comment: '後手が角を7七に成り込む。角の交換！', fromRow: 1, fromCol: 7, toRow: 6, toCol: 2, promote: true, isP1: false),
      DrillStep(label: '▲同銀', comment: '銀で後手の馬を取る。これが角換わりの基本形。', fromRow: 7, fromCol: 1, toRow: 6, toCol: 2, isP1: true),
      DrillStep(label: '△2二銀', comment: '後手が銀を2二に上げて角打ちに備える。', fromRow: 0, fromCol: 6, toRow: 1, toCol: 7, isP1: false),
      DrillStep(label: '▲4八銀', comment: '左の銀を4八へ。腰掛銀に向けて動き始める。', fromRow: 8, fromCol: 6, toRow: 7, toCol: 5, isP1: true),
      DrillStep(label: '△3二金', comment: '後手も金を上げて守りを整える。', fromRow: 0, fromCol: 5, toRow: 1, toCol: 6, isP1: false),
      DrillStep(label: '▲6八玉', comment: '玉を6八に移動。囲いへの準備。', fromRow: 8, fromCol: 4, toRow: 7, toCol: 3, isP1: true),
      DrillStep(label: '△4一玉', comment: '後手の玉も寄って入城準備。', fromRow: 0, fromCol: 4, toRow: 0, toCol: 5, isP1: false),
      DrillStep(label: '▲3六歩', comment: '3筋の歩を突いて銀の進路を開ける。', fromRow: 6, fromCol: 6, toRow: 5, toCol: 6, isP1: true),
      DrillStep(label: '△6二銀', comment: '後手も銀を上げて腰掛銀の準備。', fromRow: 0, fromCol: 2, toRow: 1, toCol: 3, isP1: false),
      DrillStep(label: '▲3七銀', comment: '銀が3七に出る。腰掛銀への第一歩！', fromRow: 7, fromCol: 5, toRow: 6, toCol: 6, isP1: true),
      DrillStep(label: '△5二金', comment: '後手も金を5二に上げて陣形を整える。', fromRow: 0, fromCol: 3, toRow: 1, toCol: 4, isP1: false),
      DrillStep(label: '▲5六銀', comment: '銀が5六に腰掛ける。腰掛銀完成！中央を制圧する強力な形。', fromRow: 6, fromCol: 6, toRow: 5, toCol: 4, isP1: true),
    ],
  ),
  // ──────────── ゴキゲン中飛車 ─────────────
  JosekiDrill(
    name: 'ゴキゲン中飛車',
    description: '後手が5筋に飛車を振る現代的な戦法。積極的に攻める後手番の必殺技。',
    color: Colors.redAccent,
    icon: Icons.bolt,
    difficulty: '初級',
    steps: [
      DrillStep(label: '▲7六歩', comment: '角道を開ける初手。', fromRow: 6, fromCol: 2, toRow: 5, toCol: 2, isP1: true),
      DrillStep(label: '△3四歩', comment: '後手が角道を開ける。ゴキゲン中飛車の準備。', fromRow: 2, fromCol: 6, toRow: 3, toCol: 6, isP1: false),
      DrillStep(label: '▲5六歩', comment: '5筋の歩を突く。後手の中飛車を封じにいく。', fromRow: 6, fromCol: 4, toRow: 5, toCol: 4, isP1: true),
      DrillStep(label: '△8四歩', comment: '後手が飛車先を突く。', fromRow: 2, fromCol: 1, toRow: 3, toCol: 1, isP1: false),
      DrillStep(label: '▲5八飛', comment: '飛車を5筋に振る。先手も中飛車で対抗！', fromRow: 7, fromCol: 7, toRow: 7, toCol: 4, isP1: true),
      DrillStep(label: '△8五歩', comment: '後手が8筋を伸ばす。', fromRow: 3, fromCol: 1, toRow: 4, toCol: 1, isP1: false),
      DrillStep(label: '▲7七角', comment: '角を上げて後手の8五歩を受ける。', fromRow: 7, fromCol: 1, toRow: 6, toCol: 2, isP1: true),
      DrillStep(label: '△6二銀', comment: '後手が銀を上げて囲いの準備。', fromRow: 0, fromCol: 2, toRow: 1, toCol: 3, isP1: false),
      DrillStep(label: '▲4八玉', comment: '玉を4八に移動。穴熊か美濃囲いへの第一歩。', fromRow: 8, fromCol: 4, toRow: 7, toCol: 5, isP1: true),
      DrillStep(label: '△4二玉', comment: '後手の玉も動く。互いに囲いへ向かう。', fromRow: 0, fromCol: 4, toRow: 1, toCol: 5, isP1: false),
      DrillStep(label: '▲3八玉', comment: '玉が3八へ。端に向けて入城中。', fromRow: 7, fromCol: 5, toRow: 7, toCol: 6, isP1: true),
      DrillStep(label: '△3二玉', comment: '後手の玉も3二へ。美濃囲いへ向かう。', fromRow: 1, fromCol: 5, toRow: 1, toCol: 6, isP1: false),
      DrillStep(label: '▲2八玉', comment: '玉が2八に入城。飛車がいた場所へ。', fromRow: 7, fromCol: 6, toRow: 7, toCol: 7, isP1: true),
      DrillStep(label: '△5二金右', comment: '後手の右金が5二に上がる。美濃囲いの完成が近づく。', fromRow: 0, fromCol: 5, toRow: 1, toCol: 4, isP1: false),
    ],
  ),
];

// ── 定跡一覧画面 ─────────────────────────────────────────
class JosekiDrillScreen extends StatefulWidget {
  const JosekiDrillScreen({super.key});

  @override
  State<JosekiDrillScreen> createState() => _JosekiDrillScreenState();
}

class _JosekiDrillScreenState extends State<JosekiDrillScreen> {
  Map<String, int> _bestScores = {}; // 定跡名→最高手数

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _bestScores = {
        for (final d in drills)
          d.name: prefs.getInt('joseki_drill_${d.name}') ?? 0,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('定跡練習', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.surface,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _TipCard(),
          const SizedBox(height: 16),
          ...drills.map((d) {
            final best = _bestScores[d.name] ?? 0;
            final total = d.steps.where((s) => s.isP1).length;
            return _DrillCard(
              drill: d,
              bestSteps: best,
              totalSteps: total,
              onComplete: (score) async {
                final prefs = await SharedPreferences.getInstance();
                final key   = 'joseki_drill_${d.name}';
                final prev  = prefs.getInt(key) ?? 0;
                if (score > prev) {
                  await prefs.setInt(key, score);
                  if (mounted) {
                    setState(() => _bestScores[d.name] = score);
                  }
                }
              },
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withAlpha(80)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '先手（あなた）の番の時、盤面の駒をタップして定跡の手を指してみよう。',
              style: TextStyle(color: Colors.amber, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrillCard extends StatelessWidget {
  final JosekiDrill drill;
  final int bestSteps;
  final int totalSteps;
  final Future<void> Function(int) onComplete;

  const _DrillCard({
    required this.drill,
    required this.bestSteps,
    required this.totalSteps,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final completed = bestSteps >= totalSteps;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final result = await Navigator.push<int>(
            context,
            MaterialPageRoute(builder: (_) => _DrillPlayScreen(drill: drill)),
          );
          if (result != null && result > 0) {
            await onComplete(result);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [drill.color.withAlpha(40), drill.color.withAlpha(20)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: completed
                  ? Colors.amber.withAlpha(160)
                  : drill.color.withAlpha(100),
              width: completed ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: drill.color.withAlpha(60),
                  shape: BoxShape.circle,
                ),
                child: completed
                    ? const Icon(Icons.check_circle, color: Colors.amber, size: 28)
                    : Icon(drill.icon, color: drill.color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          drill.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: drill.color.withAlpha(60),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            drill.difficulty,
                            style: TextStyle(color: drill.color, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      drill.description,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '$totalSteps手の定跡',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        if (bestSteps > 0) ...[
                          const SizedBox(width: 10),
                          Text(
                            '最高: $bestSteps/$totalSteps',
                            style: TextStyle(
                              color: completed ? Colors.amber : Colors.green.shade300,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 定跡練習プレイ画面 ──────────────────────────────────────
class _DrillPlayScreen extends StatefulWidget {
  final JosekiDrill drill;
  const _DrillPlayScreen({required this.drill});

  @override
  State<_DrillPlayScreen> createState() => _DrillPlayScreenState();
}

class _DrillPlayScreenState extends State<_DrillPlayScreen>
    with SingleTickerProviderStateMixin {
  late List<List<Piece?>> _board;
  int _stepIdx = 0;
  (int, int)? _selected;
  Set<(int, int)> _movableCells = {};

  // フィードバック
  bool _showCorrect = false;
  bool _showWrong = false;
  int _wrongCount = 0;
  bool _showHint = false;
  bool _completed = false;
  int _correctCount = 0; // ユーザーが正解した先手手数

  // アニメーション
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _board = _initialBoard();
    _shakeCtrl = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  DrillStep? get _currentStep {
    if (_stepIdx >= widget.drill.steps.length) return null;
    return widget.drill.steps[_stepIdx];
  }

  bool get _isUserTurn {
    final s = _currentStep;
    return s != null && s.isP1;
  }

  void _onCellTap(int row, int col) {
    if (!_isUserTurn || _showCorrect || _showWrong || _completed) return;
    final step = _currentStep!;

    if (_selected == null) {
      // 先手の駒を選択
      final piece = _board[row][col];
      if (piece != null && piece.isPlayer1) {
        setState(() {
          _selected = (row, col);
          // ヒント表示中は正解マスをハイライト
          if (_showHint) {
            _movableCells = {(step.toRow, step.toCol)};
          } else {
            _movableCells = {(step.toRow, step.toCol)}; // 合法手を計算する代わりに正解のみ（簡略）
          }
        });
      }
    } else {
      final sel = _selected!;
      if (sel == (row, col)) {
        setState(() { _selected = null; _movableCells = {}; });
        return;
      }
      // 別の先手駒をクリック
      final piece = _board[row][col];
      if (piece != null && piece.isPlayer1) {
        setState(() { _selected = (row, col); });
        return;
      }

      // 移動先タップ → 正解判定
      if (sel.$1 == step.fromRow && sel.$2 == step.fromCol &&
          row == step.toRow && col == step.toCol) {
        _onCorrect();
      } else {
        _onWrong();
      }
    }
  }

  void _onCorrect() {
    HapticFeedback.mediumImpact();
    final step = _currentStep!;
    setState(() {
      _board = _applyStep(_board, step);
      _selected = null;
      _movableCells = {};
      _showCorrect = true;
      _showWrong = false;
      _wrongCount = 0;
      _showHint = false;
      _correctCount++;
    });
    // 正解アニメーション後に後手番を自動実行
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _showCorrect = false;
        _stepIdx++;
      });
      _runAutoSteps();
    });
  }

  void _onWrong() {
    HapticFeedback.vibrate();
    _shakeCtrl.forward(from: 0);
    setState(() {
      _showWrong = true;
      _wrongCount++;
      _selected = null;
      _movableCells = {};
    });
    if (_wrongCount >= 2) {
      setState(() => _showHint = true);
    }
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showWrong = false);
    });
  }

  // 後手番（相手）の手を自動で進める
  Future<void> _runAutoSteps() async {
    while (_stepIdx < widget.drill.steps.length &&
        !widget.drill.steps[_stepIdx].isP1) {
      final step = widget.drill.steps[_stepIdx];
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() {
        _board = _applyStep(_board, step);
        _stepIdx++;
      });
    }
    // 全ステップ終了
    if (_stepIdx >= widget.drill.steps.length) {
      setState(() => _completed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _currentStep;
    final totalUserSteps = widget.drill.steps.where((s) => s.isP1).length;
    final progress = totalUserSteps == 0 ? 1.0 : (_correctCount / totalUserSteps).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(widget.drill.name, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.surface,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Text(
              '$_correctCount/$totalUserSteps',
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: _completed ? _buildComplete(totalUserSteps) : _buildPlay(step, progress),
    );
  }

  Widget _buildPlay(DrillStep? step, double progress) {
    return Column(
      children: [
        // 進捗バー
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white12,
          valueColor: AlwaysStoppedAnimation<Color>(widget.drill.color),
          minHeight: 4,
        ),
        const SizedBox(height: 8),

        // 番手表示
        if (step != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _showCorrect
                  ? Colors.green.withAlpha(40)
                  : _showWrong
                      ? Colors.red.withAlpha(40)
                      : step.isP1
                          ? Colors.blue.withAlpha(30)
                          : Colors.red.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _showCorrect
                    ? Colors.green
                    : _showWrong
                        ? Colors.red
                        : step.isP1
                            ? Colors.blue.shade400
                            : Colors.red.shade400,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _showCorrect
                      ? Icons.check_circle
                      : _showWrong
                          ? Icons.cancel
                          : step.isP1
                              ? Icons.person
                              : Icons.computer,
                  color: _showCorrect
                      ? Colors.green
                      : _showWrong
                          ? Colors.red
                          : step.isP1
                              ? Colors.blue.shade300
                              : Colors.red.shade300,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _showCorrect
                        ? '正解！  ${step.label}'
                        : _showWrong
                            ? '違います。もう一度試してみよう'
                            : step.isP1
                                ? 'あなたの番。${step.label} を指してみよう'
                                : '${step.label}（相手が指しています）',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

        // 盤面
        Expanded(
          child: Center(
            child: LayoutBuilder(builder: (ctx, cs) {
              final size = (cs.maxWidth < cs.maxHeight
                      ? cs.maxWidth * 0.95
                      : cs.maxHeight * 0.95)
                  .clamp(100.0, 420.0);
              final labelFrac = 0.05;
              final boardSize  = size * (1 - labelFrac);
              final cellSize   = boardSize / 9;

              return AnimatedBuilder(
                animation: _shakeAnim,
                builder: (ctx2, child) {
                  final shake = _shakeCtrl.isAnimating
                      ? 6 * (0.5 - (_shakeAnim.value - _shakeAnim.value.round()).abs())
                      : 0.0;
                  return Transform.translate(
                    offset: Offset(shake, 0),
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTapDown: (details) {
                    // ラベル領域（左side）を除いたボード座標に変換
                    final labelSize = size * labelFrac;
                    final dx = details.localPosition.dx - labelSize;
                    final dy = details.localPosition.dy;
                    final c = (dx / cellSize).floor();
                    final r = (dy / cellSize).floor();
                    if (r >= 0 && r <= 8 && c >= 0 && c <= 8) {
                      _onCellTap(r, c);
                    }
                  },
                  child: MiniBoardWidget(
                    board: _board,
                    size: size,
                    showLabels: true,
                    lastMoveFrom: _selected,
                    moveDots: _movableCells,
                    hintFrom: _showHint && step != null && step.isP1
                        ? (step.fromRow, step.fromCol)
                        : null,
                    hintTo: _showHint && step != null && step.isP1
                        ? (step.toRow, step.toCol)
                        : null,
                  ),
                ),
              );
            }),
          ),
        ),

        // コメント
        if (step != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _showCorrect ? step.comment : (step.isP1 ? '先手の正しい手を指してください' : step.comment),
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            ),
          ),

        // ヒントボタン
        if (_isUserTurn && !_showHint)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextButton.icon(
              onPressed: () => setState(() => _showHint = true),
              icon: const Icon(Icons.lightbulb_outline, size: 16),
              label: const Text('ヒントを見る'),
              style: TextButton.styleFrom(foregroundColor: Colors.amber),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildComplete(int totalSteps) {
    final pct = totalSteps > 0 ? (_correctCount / totalSteps * 100).round() : 100;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              pct >= 100 ? Icons.emoji_events : Icons.school,
              color: pct >= 100 ? Colors.amber : Colors.blue.shade300,
              size: 72,
            ),
            const SizedBox(height: 20),
            Text(
              pct >= 100 ? '完璧！' : '練習完了',
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.drill.name}の定跡を$_correctCount/$totalSteps手マスターしました',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '正解率: $pct%',
              style: TextStyle(
                color: pct >= 100 ? Colors.amber : Colors.white54,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _board = _initialBoard();
                      _stepIdx = 0;
                      _selected = null;
                      _movableCells = {};
                      _showCorrect = false;
                      _showWrong = false;
                      _wrongCount = 0;
                      _showHint = false;
                      _completed = false;
                      _correctCount = 0;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('もう一度'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.drill.color,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _correctCount),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('戻る'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
