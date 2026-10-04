// lib/tutorial_screen.dart — チュートリアル画面

import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'mini_board_widget.dart';
import 'piece.dart';

/// 平手の初期配置（後手=上、先手=下）。
List<List<Piece?>> _startingBoard() {
  final b = List.generate(9, (_) => List<Piece?>.filled(9, null));
  const back = [
    PieceType.lance, PieceType.knight, PieceType.silver, PieceType.gold,
    PieceType.king, PieceType.gold, PieceType.silver, PieceType.knight,
    PieceType.lance,
  ];
  for (var c = 0; c < 9; c++) {
    b[0][c] = Piece(back[c], false);
    b[2][c] = Piece(PieceType.pawn, false);
    b[6][c] = Piece(PieceType.pawn, true);
    b[8][c] = Piece(back[c], true);
  }
  b[1][1] = Piece(PieceType.rook, false);
  b[1][7] = Piece(PieceType.bishop, false);
  b[7][1] = Piece(PieceType.bishop, true);
  b[7][7] = Piece(PieceType.rook, true);
  return b;
}

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _pageCount = 9;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'チュートリアル',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
        children: [
          // ページビュー
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: const [
                _Page1WhatIsShogi(),
                _Page2PieceMovement(),
                _Page3Promotion(),
                _Page4CapturedPieces(),
                _Page5Check(),
                _Page6Controls(),
                _Page7Opening(),
                _Page8Castle(),
                _Page9AppTips(),
              ],
            ),
          ),

          // ドットインジケーター
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pageCount, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i ? Colors.white : Colors.white30,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),

          // ナビゲーションボタン
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _goToPage(_currentPage - 1),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        '前へ',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
                const SizedBox(width: 12),
                if (_currentPage < _pageCount - 1)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _goToPage(_currentPage + 1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '次へ',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
}

// ===== ページ共通レイアウト =====

class _TutorialPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget content;

  const _TutorialPage({
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 60),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Icon(icon, size: 56, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }
}

// ===== ページ1: 将棋とは =====

class _Page1WhatIsShogi extends StatelessWidget {
  const _Page1WhatIsShogi();

  @override
  Widget build(BuildContext context) {
    return _TutorialPage(
      icon: Icons.grid_on,
      title: '将棋とは？',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '将棋は9×9の盤面で2人が交互に駒を動かし、相手の王将を詰ます日本のボードゲームです。',
            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 20),
          // 平手の初期配置（実際の駒・盤と同じ描画）
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: MiniBoardWidget(board: _startingBoard(), showLabels: false),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: Colors.red.shade900.withAlpha(180), label: '後手'),
              const SizedBox(width: 16),
              _LegendDot(color: Colors.blue.shade900.withAlpha(180), label: '先手'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}

// ===== ページ2: 駒の動かし方 =====

class _Page2PieceMovement extends StatelessWidget {
  const _Page2PieceMovement();

  @override
  Widget build(BuildContext context) {
    return _TutorialPage(
      icon: Icons.touch_app,
      title: '駒の選択と移動',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '動かしたい駒をタップして選択します（緑のハイライト）。\n次に移動先のマスをタップすると駒が動きます。',
            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 20),
          // タップジェスチャーのイラスト
          Center(
            child: SizedBox(
              width: 200,
              child: Column(
                children: [
                  // 3x3 グリッドのデモ
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DemoCell(text: '', color: Colors.white12),
                      _DemoCell(text: '↑', color: Colors.green.shade700.withAlpha(180)),
                      _DemoCell(text: '', color: Colors.white12),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DemoCell(text: '←', color: Colors.green.shade700.withAlpha(180)),
                      _DemoCell(text: '歩', color: Colors.green.shade700),
                      _DemoCell(text: '→', color: Colors.green.shade700.withAlpha(180)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DemoCell(text: '', color: Colors.white12),
                      _DemoCell(text: '', color: Colors.white12),
                      _DemoCell(text: '', color: Colors.white12),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.circle,
            iconColor: Colors.green,
            text: '選択された駒は緑でハイライト',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.circle_outlined,
            iconColor: Colors.green,
            text: '移動可能なマスも緑で表示',
          ),
        ],
      ),
    );
  }
}

class _DemoCell extends StatelessWidget {
  final String text;
  final Color color;

  const _DemoCell({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white12),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

// ===== ページ3: 成り =====

class _Page3Promotion extends StatelessWidget {
  const _Page3Promotion();

  @override
  Widget build(BuildContext context) {
    return _TutorialPage(
      icon: Icons.upgrade,
      title: '成り（昇格）',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '駒が相手の陣地（3段目以内）に入ると「成り」を選べます。成ると駒の能力が強化されます。',
            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 24),
          const Text(
            '成りの例',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _PromotionExample(before: '歩', after: 'と', description: '歩兵'),
              _PromotionExample(before: '飛', after: '龍', description: '飛車'),
              _PromotionExample(before: '角', after: '馬', description: '角行'),
              _PromotionExample(before: '銀', after: '全', description: '銀将'),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withAlpha(80)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '金将・王将は成れません',
                    style: TextStyle(color: Colors.amber, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromotionExample extends StatelessWidget {
  final String before;
  final String after;
  final String description;

  const _PromotionExample({
    required this.before,
    required this.after,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white30),
          ),
          child: Center(
            child: Text(
              before,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Icon(Icons.arrow_downward, size: 14, color: Colors.amber),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.amber.shade900.withAlpha(120),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.amber.shade600),
          ),
          child: Center(
            child: Text(
              after,
              style: TextStyle(
                color: Colors.amber.shade300,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}

// ===== ページ4: 持ち駒と打ち =====

class _Page4CapturedPieces extends StatelessWidget {
  const _Page4CapturedPieces();

  @override
  Widget build(BuildContext context) {
    return _TutorialPage(
      icon: Icons.back_hand,
      title: '持ち駒と打ち',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '相手の駒を取ると「持ち駒」になります。\n持ち駒は盤上の空きマスに打つ（置く）ことができます。',
            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 24),
          // 持ち駒エリアのデモ
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '持ち駒エリア',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: ['歩', '歩', '飛', '銀'].map((piece) {
                    return Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.brown.shade700,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Center(
                        child: Text(
                          piece,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.touch_app,
            iconColor: AppTheme.accent,
            text: '持ち駒をタップ → 打てるマスが表示',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.warning_amber,
            iconColor: Colors.amber,
            text: '二歩・打ち歩詰めはできません',
          ),
        ],
      ),
    );
  }
}

// ===== ページ5: 王手と詰み =====

class _Page5Check extends StatelessWidget {
  const _Page5Check();

  @override
  Widget build(BuildContext context) {
    return _TutorialPage(
      icon: Icons.warning_amber,
      title: '王手と詰み',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '相手の王将を取れる状態を「王手」といいます。\n相手が王手を防げなくなった状態が「詰み」=勝利です。',
            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 20),

          // 王手のデモ
          const Text(
            '王手の例',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 160,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DemoCell(text: '', color: Colors.white12),
                      _DemoCell(text: '飛', color: Colors.blue.shade700),
                      _DemoCell(text: '', color: Colors.white12),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DemoCell(text: '', color: Colors.white12),
                      _DemoCell(text: '王', color: Colors.red.shade800),
                      _DemoCell(text: '', color: Colors.white12),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DemoCell(text: '', color: Colors.white12),
                      _DemoCell(text: '', color: Colors.white12),
                      _DemoCell(text: '', color: Colors.white12),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 詰みのデモ
          const Text(
            '詰みの例（逃げ場なし）',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 160,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DemoCell(text: '飛', color: Colors.blue.shade700),
                      _DemoCell(text: '', color: Colors.white12),
                      _DemoCell(text: '飛', color: Colors.blue.shade700),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DemoCell(text: '', color: Colors.white12),
                      _DemoCell(text: '王', color: Colors.red.shade800),
                      _DemoCell(text: '', color: Colors.white12),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DemoCell(text: '金', color: Colors.blue.shade700),
                      _DemoCell(text: '', color: Colors.white12),
                      _DemoCell(text: '金', color: Colors.blue.shade700),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.circle,
            iconColor: Colors.red,
            text: '王手中は王将が赤くハイライト',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.emoji_events,
            iconColor: Colors.amber,
            text: '詰みでゲーム終了・勝利',
          ),
        ],
      ),
    );
  }
}

// ===== ページ6: 操作ガイド =====

class _Page6Controls extends StatelessWidget {
  const _Page6Controls();

  static const _controls = [
    ('💡', '電球アイコン', 'AI分析ヒント'),
    ('👁', '目アイコン', '効きを表示'),
    ('📄', 'リストアイコン', '棋譜表示'),
    ('🔊', '音アイコン', '効果音ON/OFF'),
    ('⚑', '旗アイコン', '投了'),
  ];

  @override
  Widget build(BuildContext context) {
    return _TutorialPage(
      icon: Icons.sports_esports,
      title: 'アプリの操作',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._controls.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      c.$1,
                      style: const TextStyle(fontSize: 20),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.$2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        c.$3,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown.shade600,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text(
                'さあ、対局を始めよう！',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== ページ7: 定跡入門 =====

class _Page7Opening extends StatelessWidget {
  const _Page7Opening();

  @override
  Widget build(BuildContext context) {
    return _TutorialPage(
      icon: Icons.book,
      title: '定跡入門',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '定跡とは、序盤で最善とされる指し手の流れのことです。代表的な定跡を覚えると序盤を安定させられます。',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 16),
          _OpeningCard('矢倉', '居飛車の代表的な定跡。右辺から攻め、玉を左辺に囲う。', '△', Colors.blue.shade700),
          const SizedBox(height: 8),
          _OpeningCard('四間飛車', '振り飛車の基本。飛車を6筋(6八)に振り、美濃囲いと組み合わせる。', '◆', Colors.green.shade700),
          const SizedBox(height: 8),
          _OpeningCard('中飛車', '飛車を5筋（中央）に置き、中央突破を狙う積極的な戦法。', '◎', Colors.orange.shade700),
          const SizedBox(height: 8),
          _OpeningCard('角換わり', '序盤に角を交換する戦法。攻撃的な将棋になりやすい。', '★', Colors.purple.shade700),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withAlpha(60)),
            ),
            child: const Text(
              '💡 効棋のAI対局後に「棋譜解析」機能で序盤の改善点を確認できます',
              style: TextStyle(color: Colors.amber, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpeningCard extends StatelessWidget {
  final String name, desc, symbol;
  final Color color;
  const _OpeningCard(this.name, this.desc, this.symbol, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withAlpha(30),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withAlpha(80)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(symbol, style: TextStyle(color: color, fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
          ],
        )),
      ],
    ),
  );
}

// ===== ページ8: 囲い入門 =====

class _Page8Castle extends StatelessWidget {
  const _Page8Castle();

  @override
  Widget build(BuildContext context) {
    return _TutorialPage(
      icon: Icons.castle,
      title: '囲い入門',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '「囲い」とは王将を守るための陣形です。囲いを作ることで、相手の攻撃に耐えやすくなります。',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 16),
          _CastleCard('美濃囲い', '振り飛車でよく使われる。コンパクトで横からの攻撃に強い。初心者向け。',
              [['金', '銀', ''], ['玉', '', ''], ['', '', '金']], Colors.green),
          const SizedBox(height: 10),
          _CastleCard('矢倉囲い', '居飛車の代表的な囲い。金銀3枚で守り、縦横からの攻撃に強い。',
              [['金', '王', '金'], ['銀', '銀', ''], ['', '', '']], Colors.blue),
          const SizedBox(height: 10),
          _CastleCard('穴熊', '端に王を囲う最も堅い囲いの一つ。序盤に時間がかかるが守りが強固。',
              [['香', '銀', '金'], ['桂', '金', ''], ['王', '', '']], Colors.purple),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.teal.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.teal.withAlpha(60)),
            ),
            child: const Text(
              '💡 「囲いガイド」モードで特定の囲いへの組み方を対局中に表示できます',
              style: TextStyle(color: Colors.tealAccent, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _CastleCard extends StatelessWidget {
  final String name, desc;
  final List<List<String>> grid;
  final Color color;
  const _CastleCard(this.name, this.desc, this.grid, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withAlpha(70)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 3x3 グリッド表示
        SizedBox(
          width: 72,
          height: 72,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
            ),
            itemCount: 9,
            itemBuilder: (_, i) {
              final r = i ~/ 3, c = i % 3;
              final piece = grid[r][c];
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white12, width: 0.5),
                  color: piece.isNotEmpty ? color.withAlpha(40) : Colors.transparent,
                ),
                child: Center(
                  child: Text(piece, style: TextStyle(color: color, fontSize: 9)),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
          ],
        )),
      ],
    ),
  );
}

// ===== ページ9: 効棋の使い方 =====

class _Page9AppTips extends StatelessWidget {
  const _Page9AppTips();

  @override
  Widget build(BuildContext context) {
    return _TutorialPage(
      icon: Icons.tips_and_updates,
      title: '効棋の使い方',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '効棋には将棋を楽しく上達するための機能が揃っています。',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 16),
          _AppTipItem(Icons.smart_toy, Colors.amber, 'AI対局',
              '8段階の難度から選べます。初心者は「入門」から始めましょう。コーチモードで悪手を教えてくれます。'),
          _AppTipItem(Icons.extension, Colors.blue, '詰将棋',
              '1手詰〜7手詰まで多数収録。毎日1問解くだけで終盤力が上がります。'),
          _AppTipItem(Icons.network_check, Colors.green, 'ネット対局',
              '世界中のプレイヤーと対局できます。マナー報告機能で安全な環境を維持。'),
          _AppTipItem(Icons.bar_chart, Colors.purple, '統計・段級位',
              '対局結果が自動記録され、段級位が上がります。週次成長・弱点分析で課題を把握。'),
          _AppTipItem(Icons.history_edu, Colors.teal, '棋譜管理',
              '対局後の棋譜を保存・再生。KIFエクスポートや棋譜シェアも可能です。'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.withAlpha(30), Colors.orange.withAlpha(20)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withAlpha(80)),
            ),
            child: const Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                SizedBox(width: 10),
                Expanded(child: Text(
                  '将棋ウォーズより公平で\nマナーの良い対局環境を目指しています！',
                  style: TextStyle(color: Colors.amber, fontSize: 12, height: 1.5, fontWeight: FontWeight.bold),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppTipItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, desc;
  const _AppTipItem(this.icon, this.color, this.title, this.desc);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            shape: BoxShape.circle,
            border: Border.all(color: color.withAlpha(80)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
          ],
        )),
      ],
    ),
  );
}
