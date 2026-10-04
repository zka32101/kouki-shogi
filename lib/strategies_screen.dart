// lib/strategies_screen.dart — 戦法（開き方）説明

import 'package:flutter/material.dart';
import 'piece.dart';
import 'mini_board_widget.dart';
import 'utils/shogi_data_validator.dart';
import 'theme/app_theme.dart';

enum _Difficulty { beginner, intermediate, advanced }

class _DifficultyHelper {
  static String label(_Difficulty difficulty) {
    switch (difficulty) {
      case _Difficulty.beginner:
        return '初級';
      case _Difficulty.intermediate:
        return '中級';
      case _Difficulty.advanced:
        return '上級';
    }
  }

  static Color color(_Difficulty difficulty) {
    switch (difficulty) {
      case _Difficulty.beginner:
        return Colors.green;
      case _Difficulty.intermediate:
        return Colors.orange;
      case _Difficulty.advanced:
        return Colors.red;
    }
  }
}

class StrategiesScreen extends StatefulWidget {
  const StrategiesScreen({super.key});

  @override
  State<StrategiesScreen> createState() => _StrategiesScreenState();
}

class _StrategiesScreenState extends State<StrategiesScreen> {
  _Difficulty? _selectedDifficulty;

  List<Map<String, dynamic>> get _strategies => [
    // 既存戦法
    {
      'name': '角換わり',
      'description': 'お互いの角を交換する戦法。中盤の戦いが複雑になる傾向があります。',
      'memo': 'この戦法は高度なテクニックが必要で、プロの将棋でもよく使われます。',
      'difficulty': _Difficulty.advanced,
      'sourceTitle': '将棋研究',
      'sourceUrl': 'https://www.shougi.jp/learn/strategy/',
      'boardBuilder': () => _kakugawariBoard(),
      'highlights': const {(1, 7), (7, 1)},
    },
    {
      'name': '相掛かり',
      'description': 'お互いが同じ方向に飛車を置く戦法。力強い攻撃になりやすいです。',
      'memo': 'シンプルながら奥が深く、初心者から上級者まで愛用される戦法です。',
      'difficulty': _Difficulty.beginner,
      'sourceTitle': '将棋講座.com',
      'sourceUrl': 'https://xn--pet04dr1n5x9a.com/strategy/',
      'boardBuilder': () => _aiakariBoard(),
      'highlights': const {(1, 1), (7, 7)},
    },
    {
      'name': '四間飛車（先手）',
      'description': '先手が飛車を6筋（6八）に振る基本の振飛車。玉を右の美濃囲いに収め、攻守のバランスが良い。',
      'memo': '攻守バランスが良く、多くの対局で見られる振飛車の代表格です。',
      'difficulty': _Difficulty.intermediate,
      'sourceTitle': '',
      'boardBuilder': () => _shikenbishaBoard(),
      'highlights': const {(7, 3)},
    },
    {
      'name': '四間飛車（後手）',
      'description': '後手が飛車を4二に振る四間飛車。先手の6八と左右が逆になります。',
      'memo': '後手番での振飛車は居飛車穴熊対策として有力です。',
      'difficulty': _Difficulty.intermediate,
      'sourceTitle': '',
      'boardBuilder': () => _shikenbishaLeftBoard(),
      'highlights': const {(1, 5)},
    },
    {
      'name': '三間飛車（先手）',
      'description': '飛車を7筋（7八）に振る戦法。攻撃的なスタイルが特徴で、石田流にも発展する。',
      'memo': '急戦もできる攻撃的な振飛車です。',
      'difficulty': _Difficulty.intermediate,
      'sourceTitle': '将棋研究',
      'sourceUrl': 'https://www.shougi.jp/learn/strategy/',
      'boardBuilder': () => _sankenbishaBoard(),
      'highlights': const {(7, 2)},
    },
    {
      'name': '三間飛車（後手）',
      'description': '後手が飛車を3二に振る三間飛車。石田流など多彩な変化があります。',
      'memo': '石田流三間飛車は積極的な攻めが持ち味です。',
      'difficulty': _Difficulty.intermediate,
      'sourceTitle': '将棋研究',
      'sourceUrl': 'https://www.shougi.jp/learn/strategy/',
      'boardBuilder': () => _sankenbishaLeftBoard(),
      'highlights': const {(1, 6)},
    },
    // 新規戦法
    {
      'name': '横歩取り',
      'description': '後手の3四歩を先手飛車が取りに行く攻撃的な戦法。複雑な変化が特徴。',
      'memo': 'プロ将棋でも採用される高度な戦法です。',
      'difficulty': _Difficulty.advanced,
      'sourceTitle': '将棋研究',
      'sourceUrl': 'https://www.shougi.jp/learn/strategy/',
      'boardBuilder': () => _yokofuBoard(),
      'highlights': const {(3, 6)},
    },
    {
      'name': '相振飛車',
      'description': '先手も後手も飛車を振る戦法。ここでは両者が三間飛車に構えた形。',
      'memo': '振飛車同士の対抗形は独特の魅力があります。',
      'difficulty': _Difficulty.intermediate,
      'sourceTitle': '',
      'boardBuilder': () => _aivibrBoard(),
      'highlights': const {(1, 6), (7, 2)},
    },
    {
      'name': '中飛車',
      'description': '飛車を5筋に持つ戦法。柔軟な対応が可能。',
      'memo': '現代将棋で注目度が高い戦法です。',
      'difficulty': _Difficulty.intermediate,
      'sourceTitle': '将棋講座.com',
      'sourceUrl': 'https://xn--pet04dr1n5x9a.com/strategy/',
      'boardBuilder': () => _nakabishaBoard(),
      'highlights': const {(7, 4)},
    },
    {
      'name': '居角',
      'description': '角を初期位置に置いたまま戦う戦法。初心者向け。',
      'memo': '基本的な形を学ぶのに最適です。',
      'difficulty': _Difficulty.beginner,
      'sourceTitle': '将棋講座.com',
      'sourceUrl': 'https://xn--pet04dr1n5x9a.com/strategy/',
      'boardBuilder': () => _iokakuBoard(),
      'highlights': const {(7, 1), (1, 7)},
    },
    {
      'name': '石田流',
      'description': '三間飛車の一種で、急戦的な変化が豊富。複雑な思考が必要。',
      'memo': '古くから使われている由緒ある戦法です。',
      'difficulty': _Difficulty.advanced,
      'sourceTitle': '将棋研究',
      'sourceUrl': 'https://www.shougi.jp/learn/strategy/',
      'boardBuilder': () => _ishidaryuBoard(),
      'highlights': const {(5, 2), (4, 2)},
    },
    {
      'name': '向かい飛車',
      'description': '飛車を8筋（8八）に振り、相手の飛車と正面から向かい合う振り飛車。角を7七に上がってから振るのがコツ。',
      'memo': '相手の飛車先を直接受け止め、8筋での殴り合いを狙う個性的な戦法です。',
      'difficulty': _Difficulty.intermediate,
      'sourceTitle': '将棋研究',
      'sourceUrl': 'https://www.shougi.jp/learn/strategy/',
      'boardBuilder': () => _mukaibishaBoard(),
      'highlights': const {(7, 1)},
    },
    {
      'name': '棒銀',
      'description': '飛車先の歩を伸ばし、銀を2七→2六と真っ直ぐ繰り出して相手の飛車先を突破する居飛車の基本戦法。',
      'memo': '攻め方が分かりやすく、初心者が最初に覚える攻撃戦法として最適です。',
      'difficulty': _Difficulty.beginner,
      'sourceTitle': '将棋講座.com',
      'sourceUrl': 'https://xn--pet04dr1n5x9a.com/strategy/',
      'boardBuilder': () => _boginBoard(),
      'highlights': const {(6, 7)},
    },
    {
      'name': '右四間飛車',
      'description': '居飛車のまま飛車を4筋（4八）に据え、玉の反対側の4筋から一気に攻める戦法。振り飛車の四間（6八）とは別物。',
      'memo': '攻撃力が高く、対振り飛車・対矢倉どちらでも使える人気の急戦策です。',
      'difficulty': _Difficulty.intermediate,
      'sourceTitle': '将棋研究',
      'sourceUrl': 'https://www.shougi.jp/learn/strategy/',
      'boardBuilder': () => _migishikenBoard(),
      'highlights': const {(7, 5)},
    },
  ];

  List<Map<String, dynamic>> get _filteredStrategies {
    return _strategies.where((strategy) {
      if (_selectedDifficulty != null &&
          strategy['difficulty'] != _selectedDifficulty) {
        return false;
      }
      return true;
    }).toList();
  }

  // ---- Board position helpers ----

  List<List<Piece?>> _baseBoard({bool includeBishops = true}) {
    final b = List.generate(9, (_) => List<Piece?>.filled(9, null));
    // 後手（上）初期配置
    b[0][0] = const Piece(PieceType.lance, false);
    b[0][1] = const Piece(PieceType.knight, false);
    b[0][2] = const Piece(PieceType.silver, false);
    b[0][3] = const Piece(PieceType.gold, false);
    b[0][4] = const Piece(PieceType.king, false);
    b[0][5] = const Piece(PieceType.gold, false);
    b[0][6] = const Piece(PieceType.silver, false);
    b[0][7] = const Piece(PieceType.knight, false);
    b[0][8] = const Piece(PieceType.lance, false);
    b[1][1] = const Piece(PieceType.rook, false);   // 後手飛車 8二
    if (includeBishops) b[1][7] = const Piece(PieceType.bishop, false);  // 後手角 2二
    for (int c = 0; c < 9; c++) { b[2][c] = const Piece(PieceType.pawn, false); }
    // 先手（下）初期配置
    b[8][0] = const Piece(PieceType.lance, true);
    b[8][1] = const Piece(PieceType.knight, true);
    b[8][2] = const Piece(PieceType.silver, true);
    b[8][3] = const Piece(PieceType.gold, true);
    b[8][4] = const Piece(PieceType.king, true);
    b[8][5] = const Piece(PieceType.gold, true);
    b[8][6] = const Piece(PieceType.silver, true);
    b[8][7] = const Piece(PieceType.knight, true);
    b[8][8] = const Piece(PieceType.lance, true);
    b[7][7] = const Piece(PieceType.rook, true);    // 先手飛車 2八
    if (includeBishops) b[7][1] = const Piece(PieceType.bishop, true);  // 先手角 8八
    for (int c = 0; c < 9; c++) { b[6][c] = const Piece(PieceType.pawn, true); }
    return b;
  }

  List<List<Piece?>> _kakugawariBoard() {
    // 角換わり: 両角が交換済み（持ち駒）— 角のマスは空
    // _baseBoard(false)で飛車は既に正しい位置に置かれる
    return _baseBoard(includeBishops: false);
  }

  List<List<Piece?>> _aiakariBoard() {
    // 相掛かり: 飛車は初期位置のまま、歩を少し動かした形
    return _baseBoard();
  }

  List<List<Piece?>> _yokofuBoard() {
    // 横歩取り: 後手の3四歩を先手飛車が3四で取った形（▲3四飛）
    final b = _baseBoard();
    b[2][6] = null;                              // 後手3筋歩は3四へ進み飛車に取られて消える
    b[7][7] = null;                              // 先手飛車を2八から移動
    b[3][6] = const Piece(PieceType.rook, true); // ▲3四飛（横歩を取った形）
    return b;
  }

  List<List<Piece?>> _shikenbishaLeftBoard() {
    // 四間飛車(後手): 後手飛車を4二 (row=1, col=5) へ振る
    final b = _baseBoard();
    b[1][1] = null;                               // 後手飛車を8二から移動
    b[1][5] = const Piece(PieceType.rook, false); // 後手4二へ
    return b;
  }

  List<List<Piece?>> _sankenbishaLeftBoard() {
    // 三間飛車(後手): 後手飛車を3二 (row=1, col=6) へ振る
    final b = _baseBoard();
    b[1][1] = null;
    b[1][6] = const Piece(PieceType.rook, false); // 後手3二へ
    return b;
  }

  List<List<Piece?>> _shikenbishaBoard() {
    // 四間飛車: 先手飛車を6八 (row=7, col=3) に振る
    final b = _baseBoard();
    b[7][7] = null;                                    // 2八から飛車を除去
    b[7][3] = const Piece(PieceType.rook, true);       // 6八に飛車
    return b;
  }

  List<List<Piece?>> _sankenbishaBoard() {
    // 三間飛車: 先手飛車を7八 (row=7, col=2) に振る
    final b = _baseBoard();
    b[7][7] = null;                                    // 2八から飛車を除去
    b[7][2] = const Piece(PieceType.rook, true);       // 7八に飛車
    return b;
  }

  List<List<Piece?>> _aivibrBoard() {
    // 相振飛車: 先手も後手も三間飛車に振った形
    final b = _baseBoard();
    b[1][1] = null;
    b[1][6] = const Piece(PieceType.rook, false); // 後手3二へ（三間）
    b[7][7] = null;
    b[7][2] = const Piece(PieceType.rook, true);  // 先手7八へ（三間）
    return b;
  }

  List<List<Piece?>> _nakabishaBoard() {
    // 中飛車: 先手飛車を5筋（row=7, col=4）に移動
    final b = _baseBoard();
    b[7][7] = null;
    b[7][4] = const Piece(PieceType.rook, true);
    return b;
  }

  List<List<Piece?>> _iokakuBoard() {
    // 居角: 角を初期位置に置いたまま戦う（通常配置）
    return _baseBoard();
  }

  List<List<Piece?>> _ishidaryuBoard() {
    // 石田流: 三間飛車から飛車を7六に浮き、7五歩を突いた本組の形
    final b = _baseBoard();
    b[7][7] = null;                              // 飛車を2八から移動
    b[6][2] = null;                              // 7七歩は7五まで伸びる
    b[4][2] = const Piece(PieceType.pawn, true); // ▲7五歩
    b[5][2] = const Piece(PieceType.rook, true); // ▲7六飛（浮き飛車）
    return b;
  }

  List<List<Piece?>> _mukaibishaBoard() {
    // 向かい飛車: 角を7七に上がってから飛車を8八(8筋)に振る
    final b = _baseBoard();
    b[7][1] = null;                                 // 角を8八から移動
    b[6][2] = const Piece(PieceType.bishop, true);  // ▲7七角（8八を空ける）
    b[7][7] = null;                                 // 飛車を2八から移動
    b[7][1] = const Piece(PieceType.rook, true);    // ▲8八飛（向かい飛車）
    return b;
  }

  List<List<Piece?>> _boginBoard() {
    // 棒銀: 飛車先の歩を伸ばし、右銀を2七へ繰り出した居飛車の攻め形
    final b = _baseBoard();
    b[6][7] = null;                                 // 2七歩を2六へ
    b[5][7] = const Piece(PieceType.pawn, true);    // ▲2六歩
    b[8][6] = null;                                 // 3九銀を繰り出す
    b[6][7] = const Piece(PieceType.silver, true);  // ▲2七銀（棒銀）
    return b;
  }

  List<List<Piece?>> _migishikenBoard() {
    // 右四間飛車: 居飛車のまま飛車を4八(右の4筋)に据えて4筋から攻める
    final b = _baseBoard();
    b[7][7] = null;                                 // 2八から飛車を移動
    b[7][5] = const Piece(PieceType.rook, true);    // ▲4八飛（右四間飛車）
    return b;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('戦法（開き方）'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: '戻る',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle('戦法とは'),
          _StrategyItem(
            '戦法の基本',
            'ゲームの序盤に、特定の手順で駒を動かし、優位な立場を作る作戦のことを「戦法」と呼びます。相手の対抗手段を読みながら戦いを進めます。',
          ),
          const SizedBox(height: 20),
          _SectionTitle('フィルター'),
          // 難度フィルター
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '難度',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _FilterChip(
                      label: '全て',
                      isSelected: _selectedDifficulty == null,
                      onPressed: () => setState(() => _selectedDifficulty = null),
                    ),
                    ..._Difficulty.values.map((d) {
                      return _FilterChip(
                        label: _DifficultyHelper.label(d),
                        isSelected: _selectedDifficulty == d,
                        color: _DifficultyHelper.color(d),
                        onPressed: () => setState(
                          () => _selectedDifficulty =
                              _selectedDifficulty == d ? null : d,
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          _SectionTitle('戦法一覧 (${_filteredStrategies.length}件)'),
          if (_filteredStrategies.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'マッチする戦法がありません',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ..._filteredStrategies.map((strategy) {
              final board = (strategy['boardBuilder'] as Function)();
              return _DetailedStrategy(
                strategy['name'] as String,
                strategy['description'] as String,
                strategy['memo'] as String,
                board,
                difficulty: strategy['difficulty'] as _Difficulty,
                highlights: strategy['highlights'] as Set<(int, int)>,
              );
            }),
          const SizedBox(height: 20),
          _SectionTitle('戦法選びのコツ'),
          _TipItem(
            '自分のスタイルに合わせる',
            '攻撃的なのか防御的なのか、得意なスタイルで戦法を選びましょう。',
          ),
          _TipItem(
            '相手の動きを読む',
            '相手がどの戦法を選んでくるか予測することが重要です。',
          ),
          _TipItem(
            '練習を重ねる',
            '同じ戦法を何度も練習することで、その戦法の強さを引き出せます。',
          ),
          _TipItem(
            'バリエーションを学ぶ',
            '戦法には様々な応手があります。複数のバリエーションを学びましょう。',
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _StrategyItem extends StatelessWidget {
  final String title;
  final String description;
  const _StrategyItem(this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.brown.shade600,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Text(
                '⚔️',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
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

class _DetailedStrategy extends StatelessWidget {
  final String name;
  final String description;
  final String memo;
  final List<List<Piece?>> board;
  final Set<(int, int)> highlights;
  final _Difficulty difficulty;

  const _DetailedStrategy(
    this.name,
    this.description,
    this.memo,
    this.board, {
    this.highlights = const {},
    required this.difficulty,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: const Border(left: BorderSide(color: AppTheme.accent, width: 4)),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー: 名前 + 難度バッジ
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _DifficultyHelper.color(difficulty).withOpacity(0.3),
                    border: Border.all(
                      color: _DifficultyHelper.color(difficulty),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _DifficultyHelper.label(difficulty),
                    style: TextStyle(
                      color: _DifficultyHelper.color(difficulty),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: MiniBoardWidget(
                board: board,
                highlightSquares: highlights,
                size: 220,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0D3C66),
                borderRadius: BorderRadius.circular(3),
              ),
              padding: const EdgeInsets.all(8),
              child: Text(
                '💡 $memo',
                style: const TextStyle(
                  color: Colors.lightBlue,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 盤面検証ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showValidationResult(context),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('盤面を検証'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showValidationResult(BuildContext context) {
    final result = ShogiDataValidator.validateBoardData(board);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(
              result.isValid ? Icons.check_circle : Icons.error_outline,
              color: result.isValid ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(
              '盤面検証結果',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                result.summary,
                style: TextStyle(
                  color: result.isValid ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (result.p1PieceCount != null) ...[
                const SizedBox(height: 12),
                Text(
                  '駒数: 先手 ${result.p1PieceCount}枚 / 後手 ${result.p2PieceCount}枚',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'エラー内容:',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                ...result.errors.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $e',
                    style: const TextStyle(color: Colors.red, fontSize: 11),
                  ),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final String title;
  final String description;
  const _TipItem(this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Text(
                '✓',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onPressed;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.accent;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? effectiveColor.withOpacity(0.3)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? effectiveColor : Colors.white30,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? effectiveColor : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
