// lib/strength_test_screen.dart — 棋力診断モード（10問強化版）

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'piece.dart';
import 'logic.dart';
import 'game_screen.dart' show initShogiBoard;
import 'mini_board_widget.dart';
import 'theme/app_theme.dart';

// ── ランク判定（パーセンテージ基準）────────────────────────────
String _scoreToRank(int pct) {
  if (pct >= 90) return '三段';
  if (pct >= 75) return '初段';
  if (pct >= 60) return '3級';
  if (pct >= 45) return '7級';
  if (pct >= 30) return '12級';
  return '15級';
}

String _rankEmoji(String rank) {
  switch (rank) {
    case '三段': return '👑';
    case '初段': return '🏆';
    case '3級':  return '⭐';
    case '7級':  return '🎯';
    default:     return '🔰';
  }
}

Color _rankColor(int pct) {
  if (pct >= 75) return Colors.amber;
  if (pct >= 45) return Colors.lightBlue;
  return Colors.white54;
}

// ── 局面モデル ────────────────────────────────────────────
class _Position {
  final List<List<Piece?>> board;
  final Map<PieceType, int> p1Hand;
  final Map<PieceType, int> p2Hand;
  final bool p1Turn;
  final AMove bestMove;
  final String phase;  // 序盤 / 中盤 / 終盤

  _Position({
    required this.board,
    required this.p1Hand,
    required this.p2Hand,
    required this.p1Turn,
    required this.bestMove,
    required this.phase,
  });
}

/// N 手ランダム進行した局面を生成して AI.bestMove depth3 を正解とする
_Position? _generatePosition(Random rng) {
  var board = initShogiBoard();
  Map<PieceType, int> p1Hand = {}, p2Hand = {};
  bool p1Turn = true;
  final steps = 5 + rng.nextInt(65); // 5〜69 手ランダム（より多様な局面）
  final phase = steps < 20 ? '序盤' : steps < 40 ? '中盤' : '終盤';

  for (int i = 0; i < steps; i++) {
    final moves = AI.allMoves(board, p1Turn, p1Hand, p2Hand);
    if (moves.isEmpty) return null;
    final mv = moves[rng.nextInt(moves.length)];
    final applied = AI.apply(board, p1Hand, p2Hand, mv, p1Turn);
    board = applied.b;
    p1Hand = applied.p1h;
    p2Hand = applied.p2h;
    p1Turn = !p1Turn;
  }

  // depth 3 で最善手を計算
  final best = AI.bestMove(board, p1Hand, p2Hand, p1Turn, 3);
  if (best == null) return null;

  return _Position(
    board: board,
    p1Hand: p1Hand,
    p2Hand: p2Hand,
    p1Turn: p1Turn,
    bestMove: best,
    phase: phase,
  );
}

// ── 履歴レコード ─────────────────────────────────────────
class _HistRecord {
  final String date; // "2026-05-22"
  final int pct;     // 0-100%
  final String rank;

  _HistRecord({required this.date, required this.pct, required this.rank});

  Map<String, dynamic> toJson() => {'date': date, 'pct': pct, 'rank': rank};
  factory _HistRecord.fromJson(Map<String, dynamic> j) =>
      _HistRecord(date: j['date'] as String, pct: j['pct'] as int, rank: j['rank'] as String);
}

Future<List<_HistRecord>> _loadHistory() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('strength_history_v2') ?? '[]';
    final list = jsonDecode(raw) as List;
    return list.map((e) => _HistRecord.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
}

Future<void> _saveHistory(int pct, String rank) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final history = await _loadHistory();
    final today = DateTime.now().toString().substring(0, 10);
    history.insert(0, _HistRecord(date: today, pct: pct, rank: rank));
    if (history.length > 12) history.removeLast();
    await prefs.setString(
        'strength_history_v2', jsonEncode(history.map((e) => e.toJson()).toList()));
    // ベストスコア更新
    final best = prefs.getInt('strength_best_pct') ?? 0;
    if (pct > best) await prefs.setInt('strength_best_pct', pct);
  } catch (_) {}
}

// ── メイン画面 ────────────────────────────────────────────
class StrengthTestScreen extends StatefulWidget {
  const StrengthTestScreen({super.key});

  @override
  State<StrengthTestScreen> createState() => _StrengthTestScreenState();
}

class _StrengthTestScreenState extends State<StrengthTestScreen> {
  static const _totalQuestions = 10;
  static const _pointsPerQ    = 20;
  static const _maxScore      = _totalQuestions * _pointsPerQ; // 200

  // ステート
  bool _loading = true;
  List<_Position> _questions = [];
  int _current = 0;
  int _totalScore = 0;
  List<int> _scores = [];

  // 盤面選択
  int? _selR, _selC;
  PieceType? _selHand;
  Set<(int, int)> _hl = {};

  // 結果表示
  AMove? _userMove;
  bool _answered = false;
  bool _correct = false;

  @override
  void initState() {
    super.initState();
    _generateQuestions();
  }

  Future<void> _generateQuestions() async {
    final rng = Random();
    final positions = <_Position>[];
    await Future(() {
      int tries = 0;
      while (positions.length < _totalQuestions && tries < 120) {
        final pos = _generatePosition(rng);
        if (pos != null) positions.add(pos);
        tries++;
      }
    });
    if (mounted) {
      setState(() {
        _questions = positions;
        _loading = false;
      });
    }
  }

  _Position get _pos => _questions[_current];

  // ── 盤面反転ヘルパー ──────────────────────────────────────
  bool get _boardFlipped => false;

  List<List<Piece?>> _flipBoard(List<List<Piece?>> b) =>
      List.generate(9, (r) => List.generate(9, (c) => b[8 - r][8 - c]));

  (int, int)? _flipSq((int, int)? sq) =>
      sq == null ? null : (8 - sq.$1, 8 - sq.$2);

  Set<(int, int)> _flipSet(Set<(int, int)> s) =>
      s.map((sq) => (8 - sq.$1, 8 - sq.$2)).toSet();

  void _clearSel() {
    _selR = null;
    _selC = null;
    _selHand = null;
    _hl = {};
  }

  void _onCellTap(int r, int c) {
    if (_answered) return;
    final pos = _pos;

    if ((_selR != null || _selHand != null) && _hl.contains((r, c))) {
      AMove mv;
      if (_selHand != null) {
        mv = AMove(drop: _selHand, tr: r, tc: c, fr: -1, fc: -1);
      } else {
        final piece = pos.board[_selR!][_selC!]!;
        final shouldPromote = !piece.isPromoted &&
            piece.type != PieceType.king &&
            piece.type != PieceType.gold &&
            ((pos.p1Turn && r <= 2) || (!pos.p1Turn && r >= 6));
        mv = AMove(fr: _selR!, fc: _selC!, tr: r, tc: c, promote: shouldPromote);
      }
      _submitMove(mv);
      return;
    }

    final piece = pos.board[r][c];
    if (piece != null && piece.isPlayer1 == pos.p1Turn) {
      setState(() {
        _clearSel();
        _selR = r;
        _selC = c;
        for (final sq in GL.legal(pos.board, r, c)) _hl.add(sq);
      });
    } else {
      setState(() => _clearSel());
    }
  }

  void _submitMove(AMove mv) {
    final pos = _pos;
    final best = pos.bestMove;

    // 完全一致 = 正解
    final isCorrect = mv.tr == best.tr && mv.tc == best.tc &&
        (mv.drop == null
            ? (mv.fr == best.fr && mv.fc == best.fc)
            : mv.drop == best.drop);

    // top3 に入っているか（depth=3）
    final topMvs = AI.topMoves(pos.board, pos.p1Hand, pos.p2Hand, pos.p1Turn, 3, n: 3);
    final inTop3 = topMvs.any((e) =>
        e.$1.tr == mv.tr && e.$1.tc == mv.tc &&
        (mv.drop == null
            ? (e.$1.fr == mv.fr && e.$1.fc == mv.fc)
            : e.$1.drop == mv.drop));

    final score = isCorrect ? 20 : (inTop3 ? 10 : 0);

    setState(() {
      _userMove   = mv;
      _answered   = true;
      _correct    = isCorrect;
      _scores.add(score);
      _totalScore += score;
      _clearSel();
    });
  }

  void _next() {
    if (_current < _questions.length - 1) {
      setState(() {
        _current++;
        _answered = false;
        _userMove = null;
        _clearSel();
      });
    } else {
      _showResult();
    }
  }

  Future<void> _showResult() async {
    final pct = (_totalScore * 100 ~/ _maxScore).clamp(0, 100);
    final rank = _scoreToRank(pct);
    await _saveHistory(pct, rank);
    final history = await _loadHistory();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(
        score: _totalScore,
        maxScore: _maxScore,
        pct: pct,
        scores: _scores,
        history: history,
        onRetry: () {
          Navigator.pop(context);
          setState(() {
            _loading    = true;
            _questions  = [];
            _current    = 0;
            _totalScore = 0;
            _scores     = [];
            _answered   = false;
            _userMove   = null;
            _clearSel();
          });
          _generateQuestions();
        },
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text(
          _loading
              ? '棋力診断'
              : '棋力診断  ${_current + 1}/${_questions.length}問',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (!_loading && _questions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '$_totalScore / ${(_current + (_answered ? 1 : 0)) * 20}',
                  style: TextStyle(
                    color: Colors.amber.shade300,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? _loadingView()
          : _questions.isEmpty
              ? _errorView()
              : _questionView(),
    );
  }

  Widget _loadingView() => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: Colors.amber),
      SizedBox(height: 16),
      Text('10問の局面を生成中...', style: TextStyle(color: Colors.white54, fontSize: 14)),
    ]),
  );

  Widget _errorView() => const Center(
    child: Text('問題の生成に失敗しました', style: TextStyle(color: Colors.white54)),
  );

  Widget _questionView() {
    final pos  = _pos;
    final best = pos.bestMove;

    (int, int)? hintFrom;
    (int, int)? hintTo;
    if (_answered) {
      if (best.fr >= 0) hintFrom = (best.fr, best.fc);
      hintTo = (best.tr, best.tc);
    }

    (int, int)? userFrom;
    (int, int)? userTo;
    if (_answered && _userMove != null) {
      if (_userMove!.fr >= 0) userFrom = (_userMove!.fr, _userMove!.fc);
      userTo = (_userMove!.tr, _userMove!.tc);
    }

    return Column(
      children: [
        // ── プログレスバー ──
        LinearProgressIndicator(
          value: (_current + (_answered ? 1 : 0)) / _totalQuestions,
          backgroundColor: Colors.white12,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade700),
        ),

        // ── 問題ヘッダー ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF0F2040),
          child: Row(children: [
            Icon(
              pos.p1Turn ? Icons.arrow_upward : Icons.arrow_downward,
              color: pos.p1Turn ? Colors.blue.shade300 : Colors.red.shade300,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${pos.p1Turn ? "▲先手" : "△後手"}番 — 最善手を選んでください',
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            // 局面フェーズタグ
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: pos.phase == '序盤'
                    ? Colors.green.shade900
                    : pos.phase == '中盤'
                        ? Colors.orange.shade900
                        : Colors.red.shade900,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                pos.phase,
                style: TextStyle(
                  color: pos.phase == '序盤'
                      ? Colors.green.shade300
                      : pos.phase == '中盤'
                          ? Colors.orange.shade300
                          : Colors.red.shade300,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ]),
        ),

        // ── 駒の色凡例 ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: const Color(0xFF0F2040),
          child: Row(
            children: [
              Container(width: 10, height: 10, color: Colors.blue.shade200.withAlpha(160)),
              const SizedBox(width: 4),
              const Text('自分の駒', style: TextStyle(color: Colors.white54, fontSize: 10)),
              const SizedBox(width: 12),
              Container(width: 10, height: 10, color: Colors.red.shade200.withAlpha(100)),
              const SizedBox(width: 4),
              const Text('相手の駒', style: TextStyle(color: Colors.white54, fontSize: 10)),
            ],
          ),
        ),

        // ── 盤面 ──
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(builder: (ctx, cs) {
                final boardW = cs.maxWidth;
                return GestureDetector(
                  onTapDown: (det) {
                    if (_answered) return;
                    final cellSize = boardW / 9;
                    int r = (det.localPosition.dy / cellSize).floor().clamp(0, 8);
                    int c = (det.localPosition.dx / cellSize).floor().clamp(0, 8);
                    if (_boardFlipped) {
                      r = 8 - r;
                      c = 8 - c;
                    }
                    _onCellTap(r, c);
                  },
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: MiniBoardWidget(
                      board: _boardFlipped ? _flipBoard(pos.board) : pos.board,
                      lastMoveFrom: _boardFlipped ? _flipSq(userFrom) : userFrom,
                      lastMoveTo: _boardFlipped ? _flipSq(userTo) : userTo,
                      hintFrom: _answered
                          ? (_boardFlipped ? _flipSq(hintFrom) : hintFrom)
                          : (_selR != null
                              ? (_boardFlipped ? _flipSq((_selR!, _selC!)) : (_selR!, _selC!))
                              : null),
                      hintTo: _answered ? (_boardFlipped ? _flipSq(hintTo) : hintTo) : null,
                      showLabels: true,
                      size: boardW,
                      highlightSquares: _boardFlipped ? _flipSet(_hl) : _hl,
                      currentIsP1: pos.p1Turn,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),

        // ── 持ち駒 ──
        _handRow(pos.p1Hand, true, pos.p1Turn),
        _handRow(pos.p2Hand, false, pos.p1Turn),

        // ── 下パネル ──
        _bottomPanel(pos, best),
      ],
    );
  }

  Widget _handRow(Map<PieceType, int> hand, bool isP1, bool p1Turn) {
    if (hand.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: const Color(0xFF0A1628),
      child: Wrap(spacing: 8, children: [
        Text(isP1 ? '▲持駒: ' : '△持駒: ',
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ...hand.entries.map((e) => GestureDetector(
          onTap: (!_answered && isP1 == p1Turn)
              ? () {
                  setState(() {
                    _clearSel();
                    _selHand = e.key;
                    final pos2  = _pos;
                    final myH   = isP1 ? pos2.p1Hand : pos2.p2Hand;
                    final oppH  = isP1 ? pos2.p2Hand : pos2.p1Hand;
                    for (final sq in GL.dropSquares(pos2.board, e.key, isP1, myH, oppH)) {
                      _hl.add(sq);
                    }
                  });
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (_selHand == e.key && isP1 == p1Turn)
                  ? Colors.amber.withAlpha(60)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: (_selHand == e.key && isP1 == p1Turn)
                    ? Colors.amber
                    : Colors.white24,
                width: 0.8,
              ),
            ),
            child: Text(
              '${pieceLabel(e.key)}${e.value > 1 ? "×${e.value}" : ""}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        )),
      ]),
    );
  }

  Widget _bottomPanel(_Position pos, AMove best) {
    if (!_answered) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: const Color(0xFF0A1628),
        child: Text(
          _selR != null
              ? '移動先のマスをタップしてください'
              : _selHand != null
                  ? '打つマスをタップしてください'
                  : '動かしたい駒をタップしてください',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    final scoreNow = _scores.last;
    final bestNote = best.drop != null
        ? '${_sq(best.tr, best.tc)}${pieceLabel(best.drop!)}打'
        : '${_sq(best.tr, best.tc)} へ移動${best.promote ? "（成）" : ""}';

    return Container(
      padding: const EdgeInsets.all(14),
      color: _correct
          ? const Color(0xFF0A3020)
          : scoreNow > 0
              ? const Color(0xFF1A2A0A)
              : const Color(0xFF300A0A),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            _correct
                ? Icons.check_circle
                : scoreNow > 0
                    ? Icons.check_circle_outline
                    : Icons.cancel,
            color: _correct
                ? Colors.green
                : scoreNow > 0
                    ? Colors.lightGreen
                    : Colors.red.shade400,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            _correct ? '正解！ +20点' : scoreNow > 0 ? '惜しい！（上位3手） +10点' : '不正解 +0点',
            style: TextStyle(
              color: _correct
                  ? Colors.greenAccent
                  : scoreNow > 0
                      ? Colors.lightGreenAccent
                      : Colors.redAccent,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ]),
        if (!_correct) ...[
          const SizedBox(height: 6),
          Text('正解: $bestNote', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
        const SizedBox(height: 6),
        // スコアバー
        Row(children: [
          Text('進捗: ', style: const TextStyle(color: Colors.white38, fontSize: 11)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: _totalScore / ((_current + 1) * _pointsPerQ),
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$_totalScore/${(_current + 1) * _pointsPerQ}',
              style: const TextStyle(color: Colors.amber, fontSize: 11)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _next,
            child: Text(
              _current < _questions.length - 1 ? '次の問題 →' : '結果を見る',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── ユーティリティ ─────────────────────────────────────────
const _rowKanji = ['一','二','三','四','五','六','七','八','九'];
String _sq(int r, int c) => '${9 - c}${_rowKanji[r]}';

// ── 結果ダイアログ ─────────────────────────────────────────
class _ResultDialog extends StatelessWidget {
  final int score;
  final int maxScore;
  final int pct;
  final List<int> scores;
  final List<_HistRecord> history;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  const _ResultDialog({
    required this.score,
    required this.maxScore,
    required this.pct,
    required this.scores,
    required this.history,
    required this.onRetry,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final rank  = _scoreToRank(pct);
    final emoji = _rankEmoji(rank);
    final color = _rankColor(pct);

    // 前回との比較
    String trendText = '';
    Color trendColor = Colors.white54;
    if (history.length >= 2) {
      final prevPct = history[1].pct;
      final diff = pct - prevPct;
      if (diff > 0) { trendText = '▲${diff}%UP'; trendColor = Colors.greenAccent; }
      else if (diff < 0) { trendText = '▼${diff.abs()}%DOWN'; trendColor = Colors.redAccent; }
      else { trendText = '前回と同じ'; trendColor = Colors.white54; }
    }

    return AlertDialog(
      backgroundColor: AppTheme.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('診断結果', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── ランク ──
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(children: [
              Text('$emoji $rank $emoji',
                  style: TextStyle(color: color, fontSize: 36, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('推定棋力', style: TextStyle(color: color.withAlpha(180), fontSize: 12)),
              if (trendText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(trendText, style: TextStyle(color: trendColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ]),
          ),

          // ── スコア ──
          Text('$score / $maxScore 点  ($pct%)',
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 10),

          // ── 各問スコアチップ ──
          Wrap(
            spacing: 6, runSpacing: 6,
            children: scores.asMap().entries.map((e) {
              final c = e.value == 20
                  ? Colors.green
                  : e.value > 0 ? Colors.lightGreen : Colors.red.shade400;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: c.withAlpha(40),
                  border: Border.all(color: c, width: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Q${e.key + 1}: +${e.value}',
                    style: TextStyle(color: c, fontSize: 11)),
              );
            }).toList(),
          ),

          // ── 履歴グラフ ──
          if (history.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('履歴', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 60,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: history.reversed.take(10).toList().reversed.map((rec) {
                  final barH = (rec.pct / 100 * 50).clamp(4.0, 50.0);
                  final isLatest = rec == history.first;
                  final barColor = isLatest ? color : Colors.white24;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isLatest)
                            Text('${rec.pct}%',
                                style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
                          Container(
                            height: barH,
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),
            Text('過去${history.length}回の履歴',
                style: const TextStyle(color: Colors.white24, fontSize: 9),
                textAlign: TextAlign.center),
          ],

          const SizedBox(height: 8),
          const Text('棋力は問題のランダム性により変動します',
              style: TextStyle(color: Colors.white24, fontSize: 10),
              textAlign: TextAlign.center),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: onRetry,
          child: const Text('もう一度', style: TextStyle(color: Colors.lightBlue)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.brown.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onClose,
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
