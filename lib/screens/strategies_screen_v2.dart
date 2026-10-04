// lib/screens/strategies_screen_v2.dart — 手筋学習（YaneuraOu AI評価版）

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../piece.dart';
import '../mini_board_widget.dart';
import '../widgets/tesuji_evaluation_widget.dart';
import '../theme/app_theme.dart';

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

class StrategiesScreenV2 extends StatefulWidget {
  const StrategiesScreenV2({super.key});

  @override
  State<StrategiesScreenV2> createState() => _StrategiesScreenV2State();
}

class _StrategiesScreenV2State extends State<StrategiesScreenV2> {
  _Difficulty? _selectedDifficulty;
  int? _selectedStrategyIndex;
  bool _isEvaluating = false;
  String? _bestMove;
  int? _score;
  int? _winRate;

  List<Map<String, dynamic>> get _strategies => [
    // ── 振り飛車系 ────────────────────────────────────────────
    {
      'name': '四間飛車',
      'description': '飛車を4筋に振る振り飛車の代表格。美濃囲いとの組み合わせで堅い守りを作りながら攻める。初心者から上級者まで幅広く使われる。',
      'difficulty': _Difficulty.beginner,
      'category': '振り飛車',
      'sfen': 'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1',
      'boardBuilder': () => _shikenbishaBoard(),
    },
    {
      'name': '三間飛車',
      'description': '飛車を3筋に振る戦法。石田流と組み合わせると攻撃力が高まる。端攻めや速攻が得意。',
      'difficulty': _Difficulty.intermediate,
      'category': '振り飛車',
      'sfen': 'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1',
      'boardBuilder': () => _sankenbishaBoard(),
    },
    {
      'name': '中飛車',
      'description': '飛車を5筋（中央）に振る戦法。中央から圧力をかけやすく、攻めの形が作りやすい。ゴキゲン中飛車が有名。',
      'difficulty': _Difficulty.intermediate,
      'category': '振り飛車',
      'sfen': 'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1',
      'boardBuilder': () => _nakabishaBoard(),
    },
    {
      'name': '向かい飛車',
      'description': '相手の飛車と同じ筋に飛車を振る戦法。飛車交換を狙いながら積極的に攻める戦型。',
      'difficulty': _Difficulty.beginner,
      'category': '振り飛車',
      'sfen': 'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1',
      'boardBuilder': () => _mukaibishaBoard(),
    },
    // ── 居飛車系 ────────────────────────────────────────────
    {
      'name': '矢倉',
      'description': '金銀4枚で玉を囲う居飛車の代表的な囲い。攻めと守りのバランスが良く、駒組みが丁寧。',
      'difficulty': _Difficulty.intermediate,
      'category': '居飛車',
      'sfen': 'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1',
      'boardBuilder': () => _yaguraBoard(),
    },
    {
      'name': '棒銀',
      'description': '銀将を一直線に前進させ、相手の端や飛車先を突破する攻撃的な戦法。素直な筋で分かりやすい。',
      'difficulty': _Difficulty.beginner,
      'category': '居飛車',
      'sfen': 'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1',
      'boardBuilder': () => _boginBoard(),
    },
    {
      'name': '右四間飛車',
      'description': '右側の飛車を6筋（4筋の逆）に移動させ、銀と組み合わせて急攻撃する戦法。矢倉崩しに効果的。',
      'difficulty': _Difficulty.intermediate,
      'category': '居飛車',
      'sfen': 'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1',
      'boardBuilder': () => _mishikenbishaBoard(),
    },
    // ── 相居飛車 ────────────────────────────────────────────
    {
      'name': '角換わり',
      'description': 'お互いの角を交換する戦法。腰掛け銀・棒銀・早繰り銀など多彩な組み合わせがあり、研究が重要。',
      'difficulty': _Difficulty.advanced,
      'category': '相居飛車',
      'sfen': 'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1',
      'boardBuilder': () => _kakugawariBoard(),
    },
    {
      'name': '相掛かり',
      'description': 'お互いの飛車先の歩を突き合う戦型。飛車の使い方で中盤の展開が変わる。現代的な研究が盛ん。',
      'difficulty': _Difficulty.intermediate,
      'category': '相居飛車',
      'sfen': 'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1',
      'boardBuilder': () => _aiakariBoard(),
    },
    {
      'name': '横歩取り',
      'description': '先手が横歩を取る積極的な戦法。△3三角型・△8五飛型など後手の対応によって変化が多い超急戦。',
      'difficulty': _Difficulty.advanced,
      'category': '相居飛車',
      'sfen': 'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1',
      'boardBuilder': () => _yokofutoriBoard(),
    },
    {
      'name': '雁木',
      'description': '歩を突かずに銀を前進させる戦型。矢倉に組まずに戦うため柔軟性が高く、最近復活して研究が進む。',
      'difficulty': _Difficulty.advanced,
      'category': '相居飛車',
      'sfen': 'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1',
      'boardBuilder': () => _gangiBoard(),
    },
    // ── 対抗形 ────────────────────────────────────────────
    {
      'name': '居飛車穴熊',
      'description': '玉を9九まで入れ、香・金・銀で固める最強の囲い。振り飛車対策として効果的だが、囲いまでの手数が多い。',
      'difficulty': _Difficulty.intermediate,
      'category': '対抗形',
      'sfen': 'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1',
      'boardBuilder': () => _ibishaAnagumaBoard(),
    },
    {
      'name': '急戦対四間飛車',
      'description': '振り飛車に対して囲わずに速攻する戦法。▲4五歩早仕掛け・山田定跡など。素早い攻めで主導権を握る。',
      'difficulty': _Difficulty.intermediate,
      'category': '対抗形',
      'sfen': 'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1',
      'boardBuilder': () => _kyusenShikenBoard(),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F3460),
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text(
          '手筋学習（AI評価版）',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: AppTheme.accent),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 難易度フィルタ
          _buildDifficultyFilter(),
          const SizedBox(height: 20),

          // 手筋リスト
          if (_selectedStrategyIndex == null)
            _buildStrategyList()
          else
            _buildStrategyDetail(),
        ],
      ),
    );
  }

  Widget _buildDifficultyFilter() {
    return Wrap(
      spacing: 8,
      children: _Difficulty.values.map((difficulty) {
        final isSelected = _selectedDifficulty == difficulty;
        return FilterChip(
          label: Text(_DifficultyHelper.label(difficulty)),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _selectedDifficulty = selected ? difficulty : null;
            });
          },
          backgroundColor: _DifficultyHelper.color(difficulty).withOpacity(0.3),
          selectedColor: _DifficultyHelper.color(difficulty),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStrategyList() {
    final filtered = _selectedDifficulty == null
        ? _strategies
        : _strategies
            .where((s) => s['difficulty'] == _selectedDifficulty)
            .toList();

    return Column(
      children: filtered.asMap().entries.map((entry) {
        final idx = entry.key;
        final strategy = entry.value;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedStrategyIndex = idx;
              _bestMove = null;
              _score = null;
              _winRate = null;
            });
          },
          child: Card(
            color: AppTheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          strategy['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color:
                              _DifficultyHelper.color(strategy['difficulty']),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          _DifficultyHelper.label(strategy['difficulty']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strategy['description'],
                    style: TextStyle(color: Colors.grey.shade300, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStrategyDetail() {
    final strategy = _strategies[_selectedStrategyIndex!];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 戻るボタン
        TextButton.icon(
          onPressed: () {
            setState(() {
              _selectedStrategyIndex = null;
              _bestMove = null;
              _score = null;
              _winRate = null;
            });
          },
          icon: const Icon(Icons.arrow_back, color: AppTheme.accent),
          label: const Text(
            '戻る',
            style: TextStyle(color: AppTheme.accent),
          ),
        ),
        const SizedBox(height: 12),

        // 手筋名・説明
        Text(
          strategy['name'],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          strategy['description'],
          style: TextStyle(color: Colors.grey.shade300, fontSize: 14),
        ),
        const SizedBox(height: 20),

        // ボード表示
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(8),
          child: strategy['boardBuilder'](),
        ),
        const SizedBox(height: 20),

        // AI評価ウィジェット
        TesujiEvaluationWidget(
          bestMove: _bestMove,
          score: _score,
          winRate: _winRate,
          isLoading: _isEvaluating,
          onEvaluate: _evaluatePosition,
        ),
      ],
    );
  }

  Future<void> _evaluatePosition() async {
    if (_isEvaluating) return;
    if (_selectedStrategyIndex == null) return;

    setState(() => _isEvaluating = true);

    try {
      final strategy = _strategies[_selectedStrategyIndex!];
      final sfen = strategy['sfen'] as String;

      final callable =
          FirebaseFunctions.instance.httpsCallable('evaluateTesuji');
      final result = await callable.call({'sfen': sfen, 'depth': 20});

      setState(() {
        _bestMove = result.data['bestMove'];
        _score = result.data['score'];
        _winRate = result.data['winRate'];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('評価エラー: $e')),
        );
      }
    } finally {
      setState(() => _isEvaluating = false);
    }
  }

  // ── ボード表示ビルダー ─────────────────────────────────────

  static List<List<Piece?>> _emptyBoard() =>
      List.generate(9, (_) => List<Piece?>.filled(9, null));

  static void _p1(List<List<Piece?>> b, int r, int c, PieceType t) {
    b[r][c] = Piece(t, true);
  }

  static void _p2(List<List<Piece?>> b, int r, int c, PieceType t) {
    b[r][c] = Piece(t, false);
  }

  /// 振り飛車陣形を示す共通レイアウト（先手側のみ）
  static List<List<Piece?>> _baseVibriBoard(int rookCol) {
    final b = _emptyBoard();
    // 先手陣（下3段）
    _p1(b, 8, 8, PieceType.lance);  _p1(b, 8, 7, PieceType.knight);
    _p1(b, 8, 6, PieceType.silver); _p1(b, 8, 4, PieceType.king);
    _p1(b, 8, 3, PieceType.gold);   _p1(b, 8, 2, PieceType.gold);
    _p1(b, 8, 1, PieceType.knight); _p1(b, 8, 0, PieceType.lance);
    _p1(b, 7, rookCol, PieceType.rook);
    _p1(b, 7, 6, PieceType.silver);
    for (int c = 0; c < 9; c++) _p1(b, 6, c, PieceType.pawn);
    // 後手陣（上3段）
    _p2(b, 0, 0, PieceType.lance);  _p2(b, 0, 1, PieceType.knight);
    _p2(b, 0, 2, PieceType.silver); _p2(b, 0, 3, PieceType.gold);
    _p2(b, 0, 4, PieceType.king);   _p2(b, 0, 5, PieceType.gold);
    _p2(b, 0, 6, PieceType.silver); _p2(b, 0, 7, PieceType.knight);
    _p2(b, 0, 8, PieceType.lance);
    _p2(b, 1, 1, PieceType.rook);   _p2(b, 1, 7, PieceType.bishop);
    for (int c = 0; c < 9; c++) _p2(b, 2, c, PieceType.pawn);
    return b;
  }

  Widget _boardWidget(List<List<Piece?>> b, {(int,int)? from, (int,int)? to}) {
    return MiniBoardWidget(
      board: b,
      hintFrom: from,
      hintTo: to,
      showLabels: false,
    );
  }

  Widget _shikenbishaBoard() {
    // 四間飛車: 飛車を4筋(col=5)に
    return _boardWidget(_baseVibriBoard(5));
  }

  Widget _sankenbishaBoard() {
    // 三間飛車: 飛車を3筋(col=6)に
    return _boardWidget(_baseVibriBoard(6));
  }

  Widget _nakabishaBoard() {
    // 中飛車: 飛車を5筋(col=4)に
    return _boardWidget(_baseVibriBoard(4));
  }

  Widget _mukaibishaBoard() {
    // 向かい飛車: 飛車を8筋(col=1)に（後手と同じ筋）
    return _boardWidget(_baseVibriBoard(1));
  }

  Widget _yaguraBoard() {
    final b = _emptyBoard();
    // 先手矢倉形: 8八玉・7八金・8七銀・7七銀
    _p1(b, 8, 8, PieceType.lance);  _p1(b, 8, 7, PieceType.knight);
    _p1(b, 8, 5, PieceType.rook);   _p1(b, 8, 0, PieceType.lance);
    _p1(b, 7, 1, PieceType.king);   _p1(b, 7, 2, PieceType.gold);
    _p1(b, 7, 7, PieceType.bishop);
    _p1(b, 6, 1, PieceType.silver); _p1(b, 6, 2, PieceType.silver);
    // 歩は銀のいる1・2筋以外
    for (int c = 0; c < 9; c++) if (c != 1 && c != 2) _p1(b, 6, c, PieceType.pawn);
    // 後手
    _p2(b, 0, 0, PieceType.lance);  _p2(b, 0, 8, PieceType.lance);
    _p2(b, 0, 4, PieceType.king);   _p2(b, 1, 1, PieceType.rook);
    _p2(b, 1, 7, PieceType.bishop);
    for (int c = 0; c < 9; c++) _p2(b, 2, c, PieceType.pawn);
    return _boardWidget(b);
  }

  Widget _boginBoard() {
    final b = _emptyBoard();
    // 棒銀: 先手銀を4段目まで前進
    _p1(b, 8, 8, PieceType.lance);  _p1(b, 8, 7, PieceType.knight);
    _p1(b, 8, 6, PieceType.gold);   _p1(b, 8, 5, PieceType.king);
    _p1(b, 8, 4, PieceType.gold);   _p1(b, 8, 0, PieceType.lance);
    _p1(b, 7, 8, PieceType.rook);   _p1(b, 7, 7, PieceType.bishop);
    _p1(b, 4, 7, PieceType.silver); // 銀が前進
    for (int c = 0; c < 9; c++) if (c != 7) _p1(b, 6, c, PieceType.pawn);
    _p1(b, 5, 7, PieceType.pawn);
    // 後手
    _p2(b, 0, 0, PieceType.lance);  _p2(b, 0, 8, PieceType.lance);
    _p2(b, 0, 4, PieceType.king);   _p2(b, 1, 1, PieceType.rook);
    _p2(b, 1, 7, PieceType.bishop);
    for (int c = 0; c < 9; c++) _p2(b, 2, c, PieceType.pawn);
    return _boardWidget(b, from: (4, 7), to: (3, 7));
  }

  Widget _mishikenbishaBoard() {
    // 右四間飛車: 飛車を6筋(col=3)に、攻撃形
    final b = _emptyBoard();
    _p1(b, 8, 8, PieceType.lance);  _p1(b, 8, 7, PieceType.knight);
    _p1(b, 8, 1, PieceType.king);   _p1(b, 8, 0, PieceType.lance);
    _p1(b, 7, 1, PieceType.gold);   _p1(b, 7, 2, PieceType.gold);
    _p1(b, 7, 3, PieceType.rook);   _p1(b, 7, 7, PieceType.bishop);
    _p1(b, 6, 1, PieceType.silver); _p1(b, 6, 2, PieceType.silver);
    for (int c = 0; c < 9; c++) if (c > 3) _p1(b, 6, c, PieceType.pawn);
    // 後手矢倉
    _p2(b, 0, 0, PieceType.lance);  _p2(b, 0, 8, PieceType.lance);
    _p2(b, 0, 7, PieceType.king);   _p2(b, 1, 1, PieceType.rook);
    for (int c = 0; c < 9; c++) _p2(b, 2, c, PieceType.pawn);
    return _boardWidget(b);
  }

  Widget _kakugawariBoard() {
    final b = _emptyBoard();
    // 角換わり後の腰掛け銀形
    _p1(b, 8, 8, PieceType.lance);  _p1(b, 8, 7, PieceType.knight);
    _p1(b, 8, 5, PieceType.king);   _p1(b, 8, 4, PieceType.gold);
    _p1(b, 8, 3, PieceType.gold);   _p1(b, 8, 0, PieceType.lance);
    _p1(b, 7, 8, PieceType.rook);
    _p1(b, 5, 5, PieceType.silver); // 腰掛け銀
    for (int c = 0; c < 9; c++) if (c != 5) _p1(b, 6, c, PieceType.pawn);
    _p1(b, 4, 5, PieceType.pawn);
    // 後手
    _p2(b, 0, 0, PieceType.lance);  _p2(b, 0, 8, PieceType.lance);
    _p2(b, 0, 3, PieceType.king);   _p2(b, 1, 1, PieceType.rook);
    _p2(b, 3, 3, PieceType.silver);
    for (int c = 0; c < 9; c++) if (c != 3) _p2(b, 2, c, PieceType.pawn);
    _p2(b, 4, 3, PieceType.pawn);
    return _boardWidget(b);
  }

  Widget _aiakariBoard() {
    final b = _emptyBoard();
    // 相掛かり: お互いの飛車先歩が突き合った形
    _p1(b, 8, 8, PieceType.lance);  _p1(b, 8, 7, PieceType.knight);
    _p1(b, 8, 6, PieceType.silver); _p1(b, 8, 5, PieceType.gold);
    _p1(b, 8, 4, PieceType.king);   _p1(b, 8, 3, PieceType.gold);
    _p1(b, 8, 0, PieceType.lance);
    _p1(b, 7, 8, PieceType.rook);   _p1(b, 7, 7, PieceType.bishop);
    _p1(b, 5, 8, PieceType.pawn);   // 飛車先突き
    for (int c = 0; c < 8; c++) _p1(b, 6, c, PieceType.pawn);
    _p2(b, 0, 0, PieceType.lance);  _p2(b, 0, 8, PieceType.lance);
    _p2(b, 0, 4, PieceType.king);   _p2(b, 1, 1, PieceType.rook);
    _p2(b, 1, 7, PieceType.bishop);
    _p2(b, 3, 0, PieceType.pawn);   // 後手も飛車先突き
    for (int c = 1; c < 9; c++) _p2(b, 2, c, PieceType.pawn);
    return _boardWidget(b);
  }

  Widget _yokofutoriBoard() {
    final b = _emptyBoard();
    // 横歩取り: 先手が3段目の歩を取った形
    _p1(b, 8, 8, PieceType.lance);  _p1(b, 8, 4, PieceType.king);
    _p1(b, 7, 8, PieceType.rook);   _p1(b, 7, 7, PieceType.bishop);
    _p1(b, 3, 6, PieceType.rook);   // 飛車が横歩を取りに行った位置
    _p1(b, 2, 6, PieceType.pawn);   // 横歩
    for (int c = 0; c < 9; c++) if (c != 6) _p1(b, 6, c, PieceType.pawn);
    _p2(b, 0, 0, PieceType.lance);  _p2(b, 0, 8, PieceType.lance);
    _p2(b, 0, 4, PieceType.king);   _p2(b, 1, 1, PieceType.rook);
    _p2(b, 1, 7, PieceType.bishop);
    for (int c = 0; c < 9; c++) if (c != 6) _p2(b, 2, c, PieceType.pawn);
    return _boardWidget(b, from: (3, 6), to: (2, 6));
  }

  Widget _gangiBoard() {
    final b = _emptyBoard();
    // 雁木: 銀2枚を6六・7六に前進、歩は突かない形
    _p1(b, 8, 8, PieceType.lance);  _p1(b, 8, 7, PieceType.knight);
    _p1(b, 8, 4, PieceType.king);   _p1(b, 8, 3, PieceType.gold);
    _p1(b, 8, 0, PieceType.lance);
    _p1(b, 7, 8, PieceType.rook);   _p1(b, 7, 7, PieceType.bishop);
    _p1(b, 7, 4, PieceType.gold);   _p1(b, 7, 3, PieceType.gold);
    _p1(b, 5, 3, PieceType.silver); _p1(b, 5, 2, PieceType.silver); // 銀2枚が前進(row5)
    // 歩は6七・7七筋以外（銀が前進済み）
    for (int c = 0; c < 9; c++) if (c != 2 && c != 3) _p1(b, 6, c, PieceType.pawn);
    _p2(b, 0, 0, PieceType.lance);  _p2(b, 0, 8, PieceType.lance);
    _p2(b, 0, 4, PieceType.king);   _p2(b, 1, 1, PieceType.rook);
    _p2(b, 1, 7, PieceType.bishop);
    for (int c = 0; c < 9; c++) _p2(b, 2, c, PieceType.pawn);
    return _boardWidget(b);
  }

  Widget _ibishaAnagumaBoard() {
    final b = _emptyBoard();
    // 居飛車穴熊: 玉を9九(row8,col0)に収めた形
    _p1(b, 8, 0, PieceType.king);   _p1(b, 8, 1, PieceType.lance);
    _p1(b, 7, 0, PieceType.gold);   _p1(b, 7, 1, PieceType.silver);
    _p1(b, 8, 7, PieceType.knight); _p1(b, 8, 8, PieceType.lance);
    _p1(b, 7, 8, PieceType.rook);   _p1(b, 7, 7, PieceType.bishop);
    _p1(b, 6, 4, PieceType.gold);   _p1(b, 6, 5, PieceType.gold);
    for (int c = 0; c < 9; c++) if (c > 1) _p1(b, 6, c, PieceType.pawn);
    // 後手振り飛車形
    _p2(b, 0, 8, PieceType.lance);  _p2(b, 0, 4, PieceType.king);
    _p2(b, 1, 3, PieceType.rook);   // 四間飛車
    _p2(b, 1, 7, PieceType.bishop);
    for (int c = 0; c < 9; c++) _p2(b, 2, c, PieceType.pawn);
    return _boardWidget(b);
  }

  Widget _kyusenShikenBoard() {
    final b = _emptyBoard();
    // 急戦対四間飛車: ▲4五歩早仕掛け直前
    _p1(b, 8, 8, PieceType.lance);  _p1(b, 8, 7, PieceType.knight);
    _p1(b, 8, 6, PieceType.silver); _p1(b, 8, 5, PieceType.gold);
    _p1(b, 8, 4, PieceType.king);   _p1(b, 8, 3, PieceType.gold);
    _p1(b, 8, 0, PieceType.lance);
    _p1(b, 7, 8, PieceType.rook);   _p1(b, 7, 7, PieceType.bishop);
    _p1(b, 6, 7, PieceType.silver);
    _p1(b, 4, 4, PieceType.pawn);   // ▲4五歩（早仕掛け）
    for (int c = 0; c < 9; c++) if (c != 4 && c != 7) _p1(b, 6, c, PieceType.pawn);
    _p2(b, 0, 8, PieceType.lance);  _p2(b, 0, 4, PieceType.king);
    _p2(b, 1, 3, PieceType.rook);   _p2(b, 1, 7, PieceType.bishop);
    _p2(b, 7, 2, PieceType.silver);
    for (int c = 0; c < 9; c++) if (c != 4) _p2(b, 2, c, PieceType.pawn);
    _p2(b, 4, 4, PieceType.pawn);   // △4三歩と対抗
    return _boardWidget(b, from: (5, 4), to: (4, 4));
  }
}
