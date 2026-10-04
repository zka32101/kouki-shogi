// lib/castle_break_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'piece.dart';
import 'mini_board_widget.dart';
import 'castle_break_problems.dart';
import 'theme/app_theme.dart';

typedef _CBProb = CastleProb;

List<_CBProb> _buildProblems() => buildCastleProblems();

// ──────────────────────────────────────────────
// Main Screen
// ──────────────────────────────────────────────
class CastleBreakScreen extends StatefulWidget {
  const CastleBreakScreen({super.key});

  @override
  State<CastleBreakScreen> createState() => _CastleBreakScreenState();
}

class _CastleBreakScreenState extends State<CastleBreakScreen>
    with SingleTickerProviderStateMixin {
  static const _bg = AppTheme.bg;
  static const _appBarColor = AppTheme.surface;

  late final List<_CBProb> _problems;
  final Set<String> _cleared = {};
  late TabController _tabController;

  final List<String> _castles = ['美濃', '矢倉', '穴熊', '居飛車穴熊'];

  @override
  void initState() {
    super.initState();
    _problems = _buildProblems();
    _tabController = TabController(length: 4, vsync: this);
    _loadProgress();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final cleared = <String>{};
    for (final p in _problems) {
      if (prefs.getBool('castle_break_${p.id}') == true) {
        cleared.add(p.id);
      }
    }
    if (mounted) setState(() => _cleared.addAll(cleared));
  }

  List<_CBProb> _probsForCastle(String castle) =>
      _problems.where((p) => p.castle == castle).toList();

  void _openSolveView(BuildContext context, _CBProb prob) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SolveScreen(
          prob: prob,
          isCleared: _cleared.contains(prob.id),
          onCleared: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('castle_break_${prob.id}', true);
            if (mounted) setState(() => _cleared.add(prob.id));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _appBarColor,
        title: const Text(
          '囲い崩し道場',
          style: TextStyle(
            color: Color(0xDEFFFFFF),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xDEFFFFFF)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          tabs: _castles.map((c) => Tab(text: c)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _castles.map((castle) {
          final probs = _probsForCastle(castle);
          return _CastleTabView(
            castle: castle,
            problems: probs,
            cleared: _cleared,
            onTapProblem: (p) => _openSolveView(context, p),
          );
        }).toList(),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Tab View (problem list for one castle type)
// ──────────────────────────────────────────────
class _CastleTabView extends StatefulWidget {
  final String castle;
  final List<_CBProb> problems;
  final Set<String> cleared;
  final void Function(_CBProb) onTapProblem;

  const _CastleTabView({
    required this.castle,
    required this.problems,
    required this.cleared,
    required this.onTapProblem,
  });

  @override
  State<_CastleTabView> createState() => _CastleTabViewState();
}

class _CastleTabViewState extends State<_CastleTabView> {
  int _selectedDifficulty = 0; // 0=全て, 1=初級, 2=中級, 3=上級

  List<_CBProb> get _filteredProblems {
    var filtered = widget.problems;

    // Difficulty filter
    if (_selectedDifficulty > 0) {
      filtered = filtered.where((p) => p.difficulty == _selectedDifficulty).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CastleHeader(castle: widget.castle),
        const SizedBox(height: 12),

        // Difficulty Filter
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F3460).withAlpha(150),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '難度選択',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _DifficultyChip(
                    label: '全て',
                    value: 0,
                    selected: _selectedDifficulty == 0,
                    onTap: () => setState(() => _selectedDifficulty = 0),
                  ),
                  _DifficultyChip(
                    label: '初級',
                    value: 1,
                    selected: _selectedDifficulty == 1,
                    onTap: () => setState(() => _selectedDifficulty = 1),
                  ),
                  _DifficultyChip(
                    label: '中級',
                    value: 2,
                    selected: _selectedDifficulty == 2,
                    onTap: () => setState(() => _selectedDifficulty = 2),
                  ),
                  _DifficultyChip(
                    label: '上級',
                    value: 3,
                    selected: _selectedDifficulty == 3,
                    onTap: () => setState(() => _selectedDifficulty = 3),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Problem count
        Text(
          '${_filteredProblems.length}問を表示',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 8),

        // Problem list
        ..._filteredProblems.map((p) => _ProblemCard(
              prob: p,
              isCleared: widget.cleared.contains(p.id),
              onTap: () => widget.onTapProblem(p),
            )),
      ],
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  final String label;
  final int value;
  final bool selected;
  final VoidCallback onTap;

  const _DifficultyChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.transparent,
      selectedColor: Colors.amber.shade600,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
        fontSize: 12,
      ),
      side: BorderSide(
        color: selected ? Colors.amber : Colors.white30,
      ),
    );
  }
}

class _CastleHeader extends StatelessWidget {
  final String castle;
  const _CastleHeader({required this.castle});

  String get _description {
    switch (castle) {
      case '美濃':
        return '美濃囲いは端攻めや桂馬の跳ねが有効。急所の6二金を狙え！';
      case '矢倉':
        return '矢倉は4五歩や3五歩からの攻めが基本。角銀を活かそう！';
      case '穴熊':
        return '穴熊は桂頭攻めが急所。端から崩す攻めも効果的！';
      case '居飛車穴熊':
        return '居飛車穴熊は飛車と角の連携で崩す。桂香の活用も重要！';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F3460).withAlpha(180),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$castle囲い崩し',
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _description,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ProblemCard extends StatelessWidget {
  final _CBProb prob;
  final bool isCleared;
  final VoidCallback onTap;

  const _ProblemCard({
    required this.prob,
    required this.isCleared,
    required this.onTap,
  });

  String get _difficultyLabel {
    switch (prob.difficulty) {
      case 1:
        return '初級';
      case 2:
        return '中級';
      case 3:
        return '上級';
      default:
        return '';
    }
  }

  Color get _difficultyColor {
    switch (prob.difficulty) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F3460).withAlpha(200),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCleared
                  ? Colors.green.withAlpha(180)
                  : Colors.white.withAlpha(30),
            ),
          ),
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
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Difficulty badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _difficultyColor.withAlpha(150),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _difficultyLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isCleared) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '正解済',
                        style: TextStyle(
                          color: Color(0xDEFFFFFF),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                prob.description.split('\n').first,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Solve Screen
// ──────────────────────────────────────────────
class _SolveScreen extends StatefulWidget {
  final _CBProb prob;
  final bool isCleared;
  final Future<void> Function() onCleared;

  const _SolveScreen({
    required this.prob,
    required this.isCleared,
    required this.onCleared,
  });

  @override
  State<_SolveScreen> createState() => _SolveScreenState();
}

class _SolveScreenState extends State<_SolveScreen> {
  static const _bg = AppTheme.bg;
  static const _appBarColor = AppTheme.surface;

  (int, int)? _selectedFrom;
  int _lives = 3;
  bool _showHint = false;
  bool _solved = false;
  String? _feedback;

  // 盤面管理（正解手の適用表示用）
  late List<List<Piece?>> _currentBoard;
  final bool _p1Turn = true; // 先手番（常に先手の一手を問う）
  int _moveCount = 0;

  @override
  void initState() {
    super.initState();
    // 初期盤面をコピー
    _currentBoard = List.generate(9, (r) => List<Piece?>.from(widget.prob.board[r]));
  }

  (int, int)? get _hintFrom =>
      _showHint ? (widget.prob.answer.fr, widget.prob.answer.fc) : null;
  (int, int)? get _hintTo =>
      _showHint ? (widget.prob.answer.tr, widget.prob.answer.tc) : null;

  void _onCellTap(int row, int col) {
    if (_solved) return;

    final board = _currentBoard;
    final piece = board[row][col];

    // Nothing selected: try to select a 先手 piece
    if (_selectedFrom == null) {
      if (piece != null && piece.isPlayer1 == _p1Turn) {
        setState(() {
          _selectedFrom = (row, col);
          _feedback = null;
        });
      }
      return;
    }

    final (fr, fc) = _selectedFrom!;

    // Tap same cell → deselect
    if (fr == row && fc == col) {
      setState(() => _selectedFrom = null);
      return;
    }

    // Tap another 先手 piece → reselect
    if (piece != null && piece.isPlayer1) {
      setState(() {
        _selectedFrom = (row, col);
        _feedback = null;
      });
      return;
    }

    // 一手判定：正解の一手かどうかのみを評価する（崩しの急所を当てる問題）
    final ans = widget.prob.answer;
    final correct =
        ans.fr == fr && ans.fc == fc && ans.tr == row && ans.tc == col;
    if (correct) {
      _handleCorrect();
    } else {
      _handleWrong();
    }
  }

  void _handleCorrect() {
    HapticFeedback.mediumImpact();

    // 正解の手を盤面に適用して結果を表示
    final ans = widget.prob.answer;
    final moving = _currentBoard[ans.fr][ans.fc];
    if (moving != null) {
      final placed = ans.promote && moving.canPromote
          ? Piece(moving.promotedType, moving.isPlayer1)
          : moving;
      _currentBoard[ans.tr][ans.tc] = placed;
      _currentBoard[ans.fr][ans.fc] = null;
    }
    _moveCount++;

    setState(() {
      _solved = true;
      _selectedFrom = null;
      _feedback = '正解！${widget.prob.explanation}';
    });
    widget.onCleared();
  }

  void _handleWrong() {
    HapticFeedback.vibrate();
    final newLives = _lives - 1;
    setState(() {
      _lives = newLives;
      _selectedFrom = null;
      _feedback = newLives > 0 ? '違います。もう一度試してみよう。' : 'ヒントを表示します！';
      if (newLives <= 0) _showHint = true;
    });
  }

  Widget _buildLives() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('残り: ', style: TextStyle(color: Colors.white70, fontSize: 14)),
        ...List.generate(3, (i) {
          return Text(
            i < _lives ? '❤️' : '🖤',
            style: const TextStyle(fontSize: 16),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final prob = widget.prob;
    final screenW = MediaQuery.of(context).size.width;
    final boardSize = screenW - 32.0;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _appBarColor,
        title: Text(
          prob.title,
          style: const TextStyle(
            color: Color(0xDEFFFFFF),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xDEFFFFFF)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Problem description
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F3460).withAlpha(200),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withAlpha(60)),
              ),
              child: Text(
                prob.description,
                style: const TextStyle(color: Color(0xDEFFFFFF), fontSize: 14, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),

            // Lives
            if (!_solved && !widget.isCleared)
              Center(child: _buildLives()),

            const SizedBox(height: 12),

            // Board with tap detection
            GestureDetector(
              onTapUp: (details) {
                if (_solved) return;
                final labelFraction = 0.05;
                final labelSize = boardSize * labelFraction;
                final boardPixels = boardSize - labelSize;
                final cellSize = boardPixels / 9;
                final x = details.localPosition.dx - labelSize;
                final y = details.localPosition.dy - labelSize;
                if (x < 0 || y < 0) return;
                final col = (x / cellSize).floor();
                final row = (y / cellSize).floor();
                if (row >= 0 && row < 9 && col >= 0 && col < 9) {
                  _onCellTap(row, col);
                }
              },
              child: Center(
                child: SizedBox(
                  width: boardSize,
                  height: boardSize,
                  child: MiniBoardWidget(
                    board: _currentBoard,
                    size: boardSize,
                    showLabels: true,
                    currentIsP1: _solved ? null : _p1Turn,
                    lastMoveFrom: _selectedFrom,
                    lastMoveTo: _solved
                        ? (prob.answer.tr, prob.answer.tc)
                        : null,
                    hintFrom: _hintFrom,
                    hintTo: _hintTo,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Hint toggle button (visible after first wrong attempt)
            if (!_solved && _lives < 3)
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _showHint = !_showHint),
                  icon: Icon(
                    _showHint ? Icons.lightbulb : Icons.lightbulb_outline,
                    color: Colors.amber,
                  ),
                  label: Text(
                    _showHint ? 'ヒント非表示' : 'ヒントを見る',
                    style: const TextStyle(color: Colors.amber),
                  ),
                ),
              ),

            // Feedback message
            if (_feedback != null)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _solved
                        ? Colors.green.shade800.withAlpha(220)
                        : Colors.red.shade800.withAlpha(200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _feedback!,
                    style: const TextStyle(
                      color: Color(0xDEFFFFFF),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Already cleared badge
            if (widget.isCleared && !_solved)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700.withAlpha(200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '正解済みの問題です',
                    style: TextStyle(
                      color: Color(0xDEFFFFFF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Explanation (shown after solving or if already cleared)
            if (_solved || widget.isCleared) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F3460).withAlpha(220),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withAlpha(120)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '解説',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
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
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F3460),
                    foregroundColor: Colors.amber,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('問題一覧に戻る'),
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
