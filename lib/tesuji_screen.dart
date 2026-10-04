// lib/tesuji_screen.dart — 手筋トレーニング画面
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'piece.dart';
import 'mini_board_widget.dart';
import 'tesuji_problems.dart';
import 'strategy_map_screen.dart';
import 'study_calendar_screen.dart';
import 'theme/app_theme.dart';

typedef _TesujiProb = TesujiProb;

final List<TesujiProb> _problems = buildTesujiProblems();

const List<String> _baseCategories = [
  '全て', '飛車取り', '王手金取り', '両取り', '守り', '詰め', '捨て駒', '手筋テクニック'
];
const String _reviewCategory = '復習';

// ===== 統計管理 =====
class _Stats {
  static String _keyCorrect(String id) => 'tesuji_correct_$id';
  static String _keyWrong(String id) => 'tesuji_wrong_$id';
  static const _keyStreak = 'tesuji_streak';

  static Future<({int current, int best})> loadStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyStreak);
    if (raw == null) return (current: 0, best: 0);
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return (current: (m['current'] as int?) ?? 0, best: (m['best'] as int?) ?? 0);
  }

  static Future<void> recordResult({
    required String id,
    required int wrongInSession,
    required bool solved,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (wrongInSession > 0) {
      final prev = prefs.getInt(_keyWrong(id)) ?? 0;
      await prefs.setInt(_keyWrong(id), prev + wrongInSession);
    }
    if (solved) {
      final prev = prefs.getInt(_keyCorrect(id)) ?? 0;
      await prefs.setInt(_keyCorrect(id), prev + 1);
    }
    // ストリーク更新：初回一発正解のみ加算、ミスがあればリセット
    final s = await loadStreak();
    int cur = s.current;
    int best = s.best;
    if (solved && wrongInSession == 0) {
      cur++;
      if (cur > best) best = cur;
    } else if (wrongInSession > 0) {
      cur = 0;
    }
    await prefs.setString(_keyStreak, jsonEncode({'current': cur, 'best': best}));
  }
}

// ===== 詳細画面からの戻り値 =====
class _ProbResult {
  final bool solved;
  final int wrongInSession;
  const _ProbResult({required this.solved, required this.wrongInSession});
}

// ===== メイン画面 =====
class TesujiScreen extends StatefulWidget {
  const TesujiScreen({super.key});

  @override
  State<TesujiScreen> createState() => _TesujiScreenState();
}

class _TesujiScreenState extends State<TesujiScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Set<String> _cleared = {};
  Map<String, int> _correct = {};
  Map<String, int> _wrong = {};
  int _currentStreak = 0;
  int _bestStreak = 0;

  List<String> get _categories => [..._baseCategories, _reviewCategory];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final cleared = <String>{};
    final correct = <String, int>{};
    final wrong = <String, int>{};
    for (final p in _problems) {
      if (prefs.getBool('tesuji_cleared_${p.id}') == true) cleared.add(p.id);
      correct[p.id] = prefs.getInt('tesuji_correct_${p.id}') ?? 0;
      wrong[p.id] = prefs.getInt('tesuji_wrong_${p.id}') ?? 0;
    }
    final streak = await _Stats.loadStreak();
    if (!mounted) return;
    setState(() {
      _cleared = cleared;
      _correct = correct;
      _wrong = wrong;
      _currentStreak = streak.current;
      _bestStreak = streak.best;
    });
  }

  Future<void> _onResult(String id, int wrongCount, bool solved) async {
    await _Stats.recordResult(id: id, wrongInSession: wrongCount, solved: solved);
    if (solved) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tesuji_cleared_$id', true);
      StudyCalendarScreen.recordActivity('tesuji');
    }
    await _loadStats();
  }

  List<_TesujiProb> _filtered(String category) {
    if (category == '全て') return _problems;
    if (category == _reviewCategory) {
      final review = _problems.where((p) => (_wrong[p.id] ?? 0) > 0).toList();
      review.sort((a, b) => (_wrong[b.id] ?? 0).compareTo(_wrong[a.id] ?? 0));
      return review;
    }
    return _problems.where((p) => p.category == category).toList();
  }

  void _showAnalysis() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _AnalysisSheet(
        problems: _problems,
        correct: _correct,
        wrong: _wrong,
        bestStreak: _bestStreak,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clearedCount = _cleared.length;
    final reviewCount = _problems.where((p) => (_wrong[p.id] ?? 0) > 0).length;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('手筋トレーニング',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.amber),
            onPressed: _showAnalysis,
            tooltip: '分析',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          tabs: _categories.map((c) {
            if (c == _reviewCategory && reviewCount > 0) {
              return Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(c),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color: Colors.red, borderRadius: BorderRadius.circular(8)),
                    child: Text('$reviewCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ]),
              );
            }
            return Tab(text: c);
          }).toList(),
        ),
      ),
      body: Column(children: [
        // ヘッダー：進捗 + ストリーク
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('進捗: $clearedCount / ${_problems.length} 問',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Row(children: [
                if (_currentStreak >= 2) ...[
                  const Text('🔥', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 2),
                  Text('$_currentStreak連続',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                ],
                Text(
                    '${(clearedCount / _problems.length * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ]),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: clearedCount / _problems.length,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                minHeight: 8,
              ),
            ),
          ]),
        ),
        // タブコンテンツ
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _categories.map((cat) {
              final probs = _filtered(cat);
              if (probs.isEmpty && cat == _reviewCategory) {
                return Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.check_circle_outline,
                        color: Colors.green, size: 48),
                    const SizedBox(height: 12),
                    const Text('復習リストは空です！',
                        style: TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text('間違えた問題が自動で追加されます',
                        style: TextStyle(color: Colors.white38, fontSize: 13)),
                  ]),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: probs.length,
                itemBuilder: (context, index) {
                  final prob = probs[index];
                  final isCleared = _cleared.contains(prob.id);
                  return _ProblemCard(
                    prob: prob,
                    isCleared: isCleared,
                    wrongCount: _wrong[prob.id] ?? 0,
                    correctCount: _correct[prob.id] ?? 0,
                    onTap: () async {
                      final result = await Navigator.push<_ProbResult>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              _TesujiDetailScreen(prob: prob, isCleared: isCleared),
                        ),
                      );
                      if (result != null &&
                          (result.solved || result.wrongInSession > 0)) {
                        await _onResult(
                            prob.id, result.wrongInSession, result.solved);
                      }
                    },
                  );
                },
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

// ===== 問題カード =====
class _ProblemCard extends StatelessWidget {
  final _TesujiProb prob;
  final bool isCleared;
  final int wrongCount;
  final int correctCount;
  final VoidCallback onTap;

  const _ProblemCard({
    required this.prob,
    required this.isCleared,
    required this.wrongCount,
    required this.correctCount,
    required this.onTap,
  });

  Color get _categoryColor {
    switch (prob.category) {
      case '飛車取り':   return Colors.blue.shade400;
      case '王手金取り': return Colors.red.shade400;
      case '両取り':     return Colors.purple.shade300;
      case '守り':       return Colors.green.shade400;
      case '詰め':       return Colors.orange.shade400;
      default:           return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCleared ? Colors.green.withAlpha(100) : Colors.white12,
            width: isCleared ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          // クリア状態アイコン
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCleared ? Colors.green.withAlpha(40) : Colors.white12,
            ),
            child: Center(
              child: isCleared
                  ? const Icon(Icons.check, color: Colors.green, size: 20)
                  : Text(
                      _problems
                          .indexWhere((p) => p.id == prob.id)
                          .toString()
                          .padLeft(2, '0'),
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(prob.title,
                  style: TextStyle(
                    color: isCleared ? Colors.white70 : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _categoryColor.withAlpha(40),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _categoryColor.withAlpha(120), width: 0.8),
                  ),
                  child: Text(prob.category,
                      style: TextStyle(
                          color: _categoryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                if (wrongCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withAlpha(100), width: 0.8),
                    ),
                    child: Text('×$wrongCount',
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 11)),
                  ),
                ],
                if (correctCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withAlpha(100), width: 0.8),
                    ),
                    child: Text('○$correctCount',
                        style: const TextStyle(color: Colors.green, fontSize: 11)),
                  ),
                ],
              ]),
            ]),
          ),
          Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
        ]),
      ),
    );
  }
}

// ===== 分析シート =====
class _AnalysisSheet extends StatelessWidget {
  final List<TesujiProb> problems;
  final Map<String, int> correct;
  final Map<String, int> wrong;
  final int bestStreak;

  const _AnalysisSheet({
    required this.problems,
    required this.correct,
    required this.wrong,
    required this.bestStreak,
  });

  @override
  Widget build(BuildContext context) {
    final cats = _baseCategories.where((c) => c != '全て').toList();

    final totalCorrect = correct.values.fold(0, (a, b) => a + b);
    final totalWrong = wrong.values.fold(0, (a, b) => a + b);
    final totalAttempts = totalCorrect + totalWrong;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A2340),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('手筋分析',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // サマリーチップ
            Wrap(spacing: 8, runSpacing: 8, children: [
              _StatChip(label: '総正解', value: '$totalCorrect', color: Colors.green),
              _StatChip(label: '総ミス', value: '$totalWrong', color: Colors.red),
              _StatChip(label: '最長連続', value: '$bestStreak', color: Colors.orange),
              if (totalAttempts > 0)
                _StatChip(
                  label: '正解率',
                  value:
                      '${(totalCorrect / totalAttempts * 100).toStringAsFixed(0)}%',
                  color: Colors.amber,
                ),
            ]),
            const SizedBox(height: 24),
            const Text('カテゴリ別ミス分析',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...cats.map((cat) {
              final probs = problems.where((p) => p.category == cat).toList();
              final c = probs.fold(0, (s, p) => s + (correct[p.id] ?? 0));
              final w = probs.fold(0, (s, p) => s + (wrong[p.id] ?? 0));
              final attempts = c + w;
              final accuracy = attempts > 0 ? c / attempts : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    SizedBox(
                      width: 88,
                      child: Text(cat,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: accuracy,
                          minHeight: 10,
                          backgroundColor: w > 0
                              ? Colors.red.withAlpha(50)
                              : Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            accuracy >= 0.8
                                ? Colors.green
                                : accuracy >= 0.5
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 58,
                      child: Text(
                        attempts > 0 ? '○$c  ×$w' : '未挑戦',
                        style: TextStyle(
                          color: attempts > 0 ? Colors.white54 : Colors.white24,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ]),
                ]),
              );
            }),

            // 対策マップへの導線
            const SizedBox(height: 8),
            Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),
            Builder(builder: (ctx) => GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => const StrategyMapScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withAlpha(80)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.alt_route, color: Colors.amber, size: 16),
                    SizedBox(width: 6),
                    Text('対策マップで戦法を確認',
                        style: TextStyle(
                            color: Colors.amber,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, color: Colors.amber, size: 11),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ]),
    );
  }
}

// ===== 問題詳細画面 =====
class _TesujiDetailScreen extends StatefulWidget {
  final _TesujiProb prob;
  final bool isCleared;
  const _TesujiDetailScreen({required this.prob, required this.isCleared});

  @override
  State<_TesujiDetailScreen> createState() => _TesujiDetailScreenState();
}

class _TesujiDetailScreenState extends State<_TesujiDetailScreen>
    with TickerProviderStateMixin {
  (int, int)? _selectedFrom;
  Set<(int, int)> _moveDots = {};
  bool? _result;
  (int, int)? _lastFrom;
  (int, int)? _lastTo;
  PieceType? _selectedDropType;

  // セッション統計
  int _wrongInSession = 0;
  bool _solved = false;

  // アニメーション
  late AnimationController _moveController;
  bool _animating = false;
  Piece? _animPiece;
  (int, int)? _pendingFrom;
  (int, int)? _pendingTo;

  late List<List<Piece?>> _board;

  @override
  void initState() {
    super.initState();
    _board = widget.prob.board.map((row) => List<Piece?>.from(row)).toList();
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finishAnimation();
      });
  }

  @override
  void dispose() {
    _moveController.dispose();
    super.dispose();
  }

  void _popWithResult() {
    Navigator.pop(
        context, _ProbResult(solved: _solved, wrongInSession: _wrongInSession));
  }

  void _onCellTap(int r, int c) {
    if (_result != null || _animating) return;
    final piece = _board[r][c];
    if (_selectedFrom == null) {
      if (piece != null && piece.isPlayer1 == widget.prob.p1Turn) {
        setState(() {
          _selectedFrom = (r, c);
          _moveDots = _calcSimpleDots(r, c, piece);
        });
      }
    } else {
      final (fr, fc) = _selectedFrom!;
      if (fr == r && fc == c) {
        setState(() {
          _selectedFrom = null;
          _moveDots = {};
        });
        return;
      }
      _checkAnswer(fr, fc, r, c, null);
    }
  }

  void _onHandPieceTap(PieceType type) {
    if (_result != null || _animating) return;
    setState(() {
      if (_selectedDropType == type) {
        _selectedFrom = null;
        _selectedDropType = null;
        _moveDots = {};
      } else {
        _selectedFrom = (-1, -1);
        _selectedDropType = type;
        _moveDots = _calcDropDots(type);
      }
    });
  }

  void _onDropTarget(int r, int c, PieceType type) {
    if (_result != null || _animating) return;
    if (_board[r][c] != null) return;
    _checkAnswer(-1, -1, r, c, type);
  }

  void _checkAnswer(int fr, int fc, int tr, int tc, PieceType? drop) {
    final ans = widget.prob.answer;
    final correct = ans.fr == fr &&
        ans.fc == fc &&
        ans.tr == tr &&
        ans.tc == tc &&
        ans.drop == drop;

    if (!correct) {
      // 不正解: 即時反映
      if (drop != null) {
        _board[tr][tc] = Piece(drop, widget.prob.p1Turn);
      } else if (fr >= 0 && fc >= 0) {
        final piece = _board[fr][fc];
        if (piece != null) {
          _board[tr][tc] = piece;
          _board[fr][fc] = null;
        }
      }
      _wrongInSession++;
      setState(() {
        _result = false;
        _selectedFrom = null;
        _selectedDropType = null;
        _moveDots = {};
        _lastFrom = fr >= 0 ? (fr, fc) : null;
        _lastTo = (tr, tc);
      });
      return;
    }

    // 正解: アニメーション開始
    _solved = true;
    if (drop != null) {
      _animPiece = Piece(drop, widget.prob.p1Turn);
      _pendingFrom = null;
    } else if (fr >= 0 && fc >= 0) {
      _animPiece = _board[fr][fc];
      _board[fr][fc] = null; // 移動元から駒を消してオーバーレイで表示
      _pendingFrom = (fr, fc);
    }
    _pendingTo = (tr, tc);

    setState(() {
      _animating = true;
      _selectedFrom = null;
      _selectedDropType = null;
      _moveDots = {};
    });
    _moveController.forward(from: 0);
  }

  void _finishAnimation() {
    if (_animPiece != null && _pendingTo != null) {
      _board[_pendingTo!.$1][_pendingTo!.$2] = _animPiece;
      if (mounted) {
        setState(() {
          _animating = false;
          _result = true;
          _lastFrom = _pendingFrom;
          _lastTo = _pendingTo;
          _animPiece = null;
        });
      }
    }
  }

  Set<(int, int)> _calcSimpleDots(int r, int c, Piece piece) {
    final dots = <(int, int)>{};
    final fwd = piece.isPlayer1 ? -1 : 1;
    void add(int nr, int nc) {
      if (nr >= 0 && nr < 9 && nc >= 0 && nc < 9) {
        final target = _board[nr][nc];
        if (target == null || target.isPlayer1 != piece.isPlayer1) {
          dots.add((nr, nc));
        }
      }
    }
    void slide(int dr, int dc) {
      int nr = r + dr, nc = c + dc;
      while (nr >= 0 && nr < 9 && nc >= 0 && nc < 9) {
        final target = _board[nr][nc];
        if (target != null) {
          if (target.isPlayer1 != piece.isPlayer1) dots.add((nr, nc));
          break;
        }
        dots.add((nr, nc));
        nr += dr;
        nc += dc;
      }
    }

    switch (piece.type) {
      case PieceType.king:
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            if (dr != 0 || dc != 0) add(r + dr, c + dc);
          }
        }
        break;
      case PieceType.rook:
      case PieceType.promotedRook:
        slide(-1, 0); slide(1, 0); slide(0, -1); slide(0, 1);
        if (piece.type == PieceType.promotedRook) {
          add(r - 1, c - 1); add(r - 1, c + 1);
          add(r + 1, c - 1); add(r + 1, c + 1);
        }
        break;
      case PieceType.bishop:
      case PieceType.promotedBishop:
        slide(-1, -1); slide(-1, 1); slide(1, -1); slide(1, 1);
        if (piece.type == PieceType.promotedBishop) {
          add(r - 1, c); add(r + 1, c);
          add(r, c - 1); add(r, c + 1);
        }
        break;
      case PieceType.gold:
      case PieceType.promotedSilver:
      case PieceType.promotedKnight:
      case PieceType.promotedLance:
      case PieceType.promotedPawn:
        add(r + fwd, c); add(r + fwd, c - 1); add(r + fwd, c + 1);
        add(r, c - 1); add(r, c + 1); add(r - fwd, c);
        break;
      case PieceType.silver:
        add(r + fwd, c); add(r + fwd, c - 1); add(r + fwd, c + 1);
        add(r - fwd, c - 1); add(r - fwd, c + 1);
        break;
      case PieceType.knight:
        add(r + fwd * 2, c - 1); add(r + fwd * 2, c + 1);
        break;
      case PieceType.lance:
        slide(fwd, 0);
        break;
      case PieceType.pawn:
        add(r + fwd, c);
        break;
    }
    return dots;
  }

  Set<(int, int)> _calcDropDots(PieceType type) {
    final dots = <(int, int)>{};
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_board[r][c] == null) dots.add((r, c));
      }
    }
    return dots;
  }

  void _reset() {
    _moveController.stop();
    setState(() {
      _board = widget.prob.board.map((row) => List<Piece?>.from(row)).toList();
      _animating = false;
      _animPiece = null;
      _pendingFrom = null;
      _pendingTo = null;
      _selectedFrom = null;
      _selectedDropType = null;
      _moveDots = {};
      _result = null;
      _lastFrom = null;
      _lastTo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prob = widget.prob;
    final isDrop = _selectedFrom == (-1, -1);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _popWithResult();
      },
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _popWithResult,
          ),
          title: Text(prob.title,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            // セッション中のミス数表示
            if (_wrongInSession > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withAlpha(100)),
                    ),
                    child: Text('×$_wrongInSession',
                        style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white54),
              onPressed: _reset,
              tooltip: 'リセット',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // カテゴリバッジ
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withAlpha(120)),
                  ),
                  child: Text(prob.category,
                      style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),

              // 持ち駒（後手）
              if (prob.p2Hand.isNotEmpty)
                _HandDisplay(
                    hand: prob.p2Hand, isPlayer1: false, label: '後手の持ち駒'),

              const SizedBox(height: 8),

              // 盤面
              LayoutBuilder(builder: (context, constraints) {
                final size =
                    constraints.maxWidth < 400 ? constraints.maxWidth : 380.0;
                final labelSize = size * 0.05;
                final boardOffset = labelSize * 1.2;
                final cellSize = (size - labelSize) / 9;

                return Center(
                  child: SizedBox(
                    width: size,
                    child: Stack(children: [
                      GestureDetector(
                        onTapDown: _animating
                            ? null
                            : (details) {
                                final localX =
                                    details.localPosition.dx - labelSize;
                                final localY =
                                    details.localPosition.dy - boardOffset;
                                final c = (localX / cellSize).floor();
                                final r = (localY / cellSize).floor();
                                if (r >= 0 && r < 9 && c >= 0 && c < 9) {
                                  if (isDrop) {
                                    if (_selectedDropType != null) {
                                      _onDropTarget(r, c, _selectedDropType!);
                                    }
                                  } else {
                                    _onCellTap(r, c);
                                  }
                                }
                              },
                        child: MiniBoardWidget(
                          board: _board,
                          moveDots: _moveDots,
                          lastMoveFrom: !_animating && _result != null
                              ? _lastFrom
                              : (_selectedFrom != null && !isDrop
                                  ? _selectedFrom
                                  : null),
                          lastMoveTo:
                              !_animating && _result != null ? _lastTo : null,
                          size: size,
                        ),
                      ),
                      // 正解アニメーション: 駒が移動元→移動先へスライド
                      if (_animating && _animPiece != null)
                        AnimatedBuilder(
                          animation: _moveController,
                          builder: (context, _) {
                            final t = CurvedAnimation(
                              parent: _moveController,
                              curve: Curves.easeInOutCubic,
                            ).value;

                            final double fromX, fromY;
                            if (_pendingFrom != null) {
                              fromX =
                                  labelSize + _pendingFrom!.$2 * cellSize;
                              fromY =
                                  boardOffset + _pendingFrom!.$1 * cellSize;
                            } else {
                              // 打ち駒: 目標マスの上方から落下
                              fromX =
                                  labelSize + _pendingTo!.$2 * cellSize;
                              fromY = boardOffset +
                                  (_pendingTo!.$1 - 2.5) * cellSize;
                            }
                            final toX = labelSize + _pendingTo!.$2 * cellSize;
                            final toY =
                                boardOffset + _pendingTo!.$1 * cellSize;

                            final x = fromX + (toX - fromX) * t;
                            final y = fromY + (toY - fromY) * t;

                            return Positioned(
                              left: x,
                              top: y,
                              width: cellSize,
                              height: cellSize,
                              child: Opacity(
                                opacity: _pendingFrom == null
                                    ? t.clamp(0.0, 1.0)
                                    : 1.0,
                                child: _BoardPieceCell(
                                  piece: _animPiece!,
                                  cellSize: cellSize,
                                ),
                              ),
                            );
                          },
                        ),
                    ]),
                  ),
                );
              }),

              const SizedBox(height: 8),

              // 持ち駒（先手）
              if (prob.p1Hand.isNotEmpty)
                _HandDisplay(
                  hand: prob.p1Hand,
                  isPlayer1: true,
                  label: '先手の持ち駒',
                  onPieceTap:
                      (_selectedFrom == null || isDrop) ? _onHandPieceTap : null,
                  selectedDrop: isDrop ? _selectedDropType : null,
                ),

              const SizedBox(height: 12),

              // 指示テキスト
              if (_result == null && !_animating)
                Center(
                  child: Text(
                    '${prob.p1Turn ? "先手" : "後手"}の最善手を選んでください',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),

              const SizedBox(height: 12),

              // 結果表示
              if (_result != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        (_result! ? Colors.green : Colors.red).withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (_result! ? Colors.green : Colors.red)
                          .withAlpha(120),
                    ),
                  ),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(
                        _result! ? Icons.check_circle : Icons.cancel,
                        color: _result! ? Colors.green : Colors.red,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _result! ? (_wrongInSession == 0 ? '正解！🔥' : '正解！') : '不正解',
                        style: TextStyle(
                          color: _result! ? Colors.green : Colors.red,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ]),
                    if (_result!) ...[
                      const SizedBox(height: 12),
                      Text(prob.explanation,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                          textAlign: TextAlign.center),
                    ],
                  ]),
                ),
                const SizedBox(height: 12),
                if (_result!)
                  ElevatedButton.icon(
                    onPressed: _popWithResult,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('次の問題へ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh, color: Colors.amber),
                    label: const Text('もう一度',
                        style: TextStyle(color: Colors.amber)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.amber),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== 持ち駒表示 =====
class _HandDisplay extends StatelessWidget {
  final Map<PieceType, int> hand;
  final bool isPlayer1;
  final String label;
  final void Function(PieceType)? onPieceTap;
  final PieceType? selectedDrop;

  const _HandDisplay({
    required this.hand,
    required this.isPlayer1,
    required this.label,
    this.onPieceTap,
    this.selectedDrop,
  });

  @override
  Widget build(BuildContext context) {
    if (hand.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(width: 8),
        Wrap(
          spacing: 6,
          children: hand.entries.map((e) {
            final isSelected = selectedDrop == e.key;
            return GestureDetector(
              onTap: onPieceTap != null ? () => onPieceTap!(e.key) : null,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.amber.withAlpha(60)
                      : const Color(0xFFE8C87A).withAlpha(200),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color:
                        isSelected ? Colors.amber : const Color(0xFF7A4E2B),
                    width: isSelected ? 2 : 0.8,
                  ),
                ),
                child: Text(
                  '${pieceLabel(e.key)}${e.value > 1 ? "×${e.value}" : ""}',
                  style: TextStyle(
                    color: isSelected
                        ? Colors.amber.shade900
                        : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

// ===== アニメーション中の浮き駒セル =====
class _BoardPieceCell extends StatelessWidget {
  final Piece piece;
  final double cellSize;
  const _BoardPieceCell({required this.piece, required this.cellSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8C87A),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.amber.shade700, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 5)),
        ],
      ),
      child: Center(
        child: Transform.rotate(
          angle: piece.isPlayer1 ? 0 : 3.14159,
          child: Text(
            pieceLabel(piece.type),
            style: TextStyle(
              fontSize: cellSize * 0.52,
              fontWeight: FontWeight.bold,
              color: piece.isPlayer1 ? Colors.black87 : Colors.red.shade900,
            ),
          ),
        ),
      ),
    );
  }
}
