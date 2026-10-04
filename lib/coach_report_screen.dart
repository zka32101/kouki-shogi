// lib/coach_report_screen.dart — AI 1局講評レポート

import 'package:flutter/material.dart';
import 'piece.dart';
import 'logic.dart';
import 'mini_board_widget.dart';
import 'kansousen_screen.dart'
    show
        MoveQuality,
        MoveQualityExt,
        classifyMove,
        playerEvalChange,
        KansousenScreen;
import 'theme/app_theme.dart';

// ───────────────────────────────────────
// 内部スナップショット
// ───────────────────────────────────────
class _Snap {
  final List<List<Piece?>> board;
  final Map<PieceType, int> p1Hand;
  final Map<PieceType, int> p2Hand;
  final bool p1Turn;
  final int eval;
  _Snap(this.board, this.p1Hand, this.p2Hand, this.p1Turn, this.eval);
}

// ───────────────────────────────────────
// 精度グレード
// ───────────────────────────────────────
enum _Grade { s, a, b, c, d }

extension _GradeExt on _Grade {
  String get label {
    switch (this) {
      case _Grade.s: return 'S';
      case _Grade.a: return 'A';
      case _Grade.b: return 'B';
      case _Grade.c: return 'C';
      case _Grade.d: return 'D';
    }
  }

  Color get color {
    switch (this) {
      case _Grade.s: return const Color(0xFFFFD700); // gold
      case _Grade.a: return Colors.lightBlue.shade400;
      case _Grade.b: return Colors.green.shade400;
      case _Grade.c: return Colors.orange.shade400;
      case _Grade.d: return Colors.red.shade400;
    }
  }

  String get message {
    switch (this) {
      case _Grade.s: return 'ほぼミスなし！素晴らしい精度です。';
      case _Grade.a: return '高精度の一局でした。さらに上を目指せます！';
      case _Grade.b: return '良い指し手が多かった一局です。';
      case _Grade.c: return '改善の余地あり。重要局面を振り返りましょう。';
      case _Grade.d: return '疑問手・悪手が多めでした。基礎を見直しましょう。';
    }
  }
}

_Grade _calcGrade(double accuracy) {
  if (accuracy >= 0.92) return _Grade.s;
  if (accuracy >= 0.80) return _Grade.a;
  if (accuracy >= 0.65) return _Grade.b;
  if (accuracy >= 0.45) return _Grade.c;
  return _Grade.d;
}

// ───────────────────────────────────────
// 重要局面データ
// ───────────────────────────────────────
class _KeyMoment {
  final int step;
  final KifuMove move;
  final _Snap snapBefore;
  final int evalChange;
  final MoveQuality quality;
  _KeyMoment(this.step, this.move, this.snapBefore, this.evalChange, this.quality);
}

// ───────────────────────────────────────
// CoachReportScreen
// ───────────────────────────────────────
class CoachReportScreen extends StatefulWidget {
  final List<KifuMove> kifu;
  final List<List<Piece?>> initialBoard;
  final String result;
  /// プレイヤーが先手か（true=P1, false=P2）
  final bool playerIsP1;

  const CoachReportScreen({
    super.key,
    required this.kifu,
    required this.initialBoard,
    required this.result,
    required this.playerIsP1,
  });

  @override
  State<CoachReportScreen> createState() => _CoachReportScreenState();
}

class _CoachReportScreenState extends State<CoachReportScreen> {
  late List<MoveQuality?> _quals;
  late List<_KeyMoment> _keyMoments;
  late double _accuracy;
  late _Grade _grade;
  late Map<MoveQuality, int> _playerCounts;

  @override
  void initState() {
    super.initState();
    _buildReport();
  }

  void _buildReport() {
    // ── スナップショット構築 ──
    final snaps = <_Snap>[];
    var board = GL.copy(widget.initialBoard);
    Map<PieceType, int> p1Hand = {}, p2Hand = {};
    bool p1Turn = true;

    snaps.add(_Snap(
      GL.copy(board), Map.from(p1Hand), Map.from(p2Hand), p1Turn,
      AI.eval(board, p1Hand, p2Hand, ignorePersonality: true),
    ));

    for (final move in widget.kifu) {
      GL.applyKifuMove(board, p1Hand, p2Hand, move);
      p1Turn = !p1Turn;
      snaps.add(_Snap(
        GL.copy(board), Map.from(p1Hand), Map.from(p2Hand), p1Turn,
        AI.eval(board, p1Hand, p2Hand, ignorePersonality: true),
      ));
    }
    // ── 手の品質 ──
    _quals = List.generate(snaps.length, (i) {
      if (i == 0) return null;
      final move = widget.kifu[i - 1];
      final chg = playerEvalChange(snaps[i - 1].eval, snaps[i].eval, move.p1);
      return classifyMove(chg);
    });

    // ── プレイヤーの手だけをカウント ──
    _playerCounts = {for (final q in MoveQuality.values) q: 0};
    int totalPlayerMoves = 0;
    int goodOrBetterMoves = 0;

    for (int i = 1; i < snaps.length; i++) {
      final move = widget.kifu[i - 1];
      if (move.p1 != widget.playerIsP1) continue; // 相手の手はスキップ
      final q = _quals[i];
      if (q == null) continue;
      _playerCounts[q] = (_playerCounts[q] ?? 0) + 1;
      totalPlayerMoves++;
      if (q == MoveQuality.excellent || q == MoveQuality.good || q == MoveQuality.normal) {
        goodOrBetterMoves++;
      }
    }

    _accuracy = totalPlayerMoves > 0 ? goodOrBetterMoves / totalPlayerMoves : 1.0;
    _grade = _calcGrade(_accuracy);

    // ── 重要局面（プレイヤーの最大悪手 Top3）──
    final moments = <_KeyMoment>[];
    for (int i = 1; i < snaps.length; i++) {
      final move = widget.kifu[i - 1];
      if (move.p1 != widget.playerIsP1) continue;
      final chg = playerEvalChange(snaps[i - 1].eval, snaps[i].eval, move.p1);
      final q = classifyMove(chg);
      if (q == MoveQuality.dubious || q == MoveQuality.bad) {
        moments.add(_KeyMoment(i, move, snaps[i - 1], chg, q));
      }
    }
    // 評価値低下が大きい順にソート
    moments.sort((a, b) => a.evalChange.compareTo(b.evalChange));
    _keyMoments = moments.take(3).toList();
  }

  // ── アドバイス生成 ──
  List<String> _generateAdvice() {
    final advice = <String>[];
    final badCount = (_playerCounts[MoveQuality.bad] ?? 0);
    final dubiousCount = (_playerCounts[MoveQuality.dubious] ?? 0);
    final excellentCount = (_playerCounts[MoveQuality.excellent] ?? 0);
    final totalMoves = widget.kifu.length;

    if (badCount >= 3) {
      advice.add('🔴 致命的なミスが $badCount 手ありました。各局面で「詰めろ」「王手への対応」を意識しましょう。');
    }
    if (dubiousCount >= 3) {
      advice.add('🟠 疑問手が $dubiousCount 手。指す前に「この手でどう変わるか」を一度考える習慣をつけましょう。');
    }
    if (excellentCount >= 3) {
      advice.add('⭐ 好手が $excellentCount 手！積極的な仕掛けが光りました。');
    }

    // 局面の傾向分析
    bool midgameBlunder = _keyMoments.any((m) => m.step > 20 && m.step <= 60);
    bool endgameBlunder = _keyMoments.any((m) => m.step > 60);

    if (endgameBlunder) {
      advice.add('♟️ 終盤で形勢を逃しました。詰将棋練習で終盤の計算力を鍛えましょう。');
    } else if (midgameBlunder) {
      advice.add('⚔️ 中盤の仕掛けで判断ミスがありました。定跡・手筋の学習が効果的です。');
    }

    if (totalMoves < 30) {
      advice.add('⚡ 短手数で決着。序盤の定跡をしっかり学ぶと安定します。');
    }

    if (advice.isEmpty) {
      advice.add('✨ バランスの良い一局でした。このまま対局数を重ねてレートアップを目指しましょう！');
    }

    return advice;
  }

  // ── 次の練習メニュー ──
  List<Map<String, dynamic>> _practiceMenu() {
    final menu = <Map<String, dynamic>>[];
    final badCount = (_playerCounts[MoveQuality.bad] ?? 0);
    final dubiousCount = (_playerCounts[MoveQuality.dubious] ?? 0);

    if (badCount + dubiousCount >= 2) {
      menu.add({'icon': Icons.extension, 'color': Colors.orange, 'label': '詰将棋練習', 'desc': '終盤の計算力UP'});
    }
    if (widget.kifu.length < 40) {
      menu.add({'icon': Icons.book_outlined, 'color': AppTheme.accent, 'label': '定跡を学ぶ', 'desc': '序盤の知識を強化'});
    }
    menu.add({'icon': Icons.computer, 'color': Colors.amber, 'label': 'AI対局（再戦）', 'desc': '今度こそ完封を目指せ'});

    return menu.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    const bg = AppTheme.bg;
    const cardBg = AppTheme.surface;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        title: const Text('AI 1局講評', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // 感想戦へ
          TextButton.icon(
            icon: const Icon(Icons.science_outlined, color: Colors.amber, size: 18),
            label: const Text('感想戦', style: TextStyle(color: Colors.amber, fontSize: 13)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => KansousenScreen(
                  moves: widget.kifu,
                  initialBoard: widget.initialBoard,
                  title: widget.result,
                  flipped: !widget.playerIsP1,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── グレード ──
              _gradeCard(),
              const SizedBox(height: 16),

              // ── 手の品質内訳 ──
              _qualityCard(),
              const SizedBox(height: 16),

              // ── 重要局面 ──
              if (_keyMoments.isNotEmpty) ...[
                _keyMomentsCard(),
                const SizedBox(height: 16),
              ],

              // ── AI アドバイス ──
              _adviceCard(),
              const SizedBox(height: 16),

              // ── 練習メニュー ──
              _practiceCard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ─── グレードカード ───────────────────────────────────
  Widget _gradeCard() {
    final pct = (_accuracy * 100).round();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _grade.color.withAlpha(80), width: 2),
        boxShadow: [BoxShadow(color: _grade.color.withAlpha(40), blurRadius: 16)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _grade.color.withAlpha(30),
                  border: Border.all(color: _grade.color, width: 3),
                ),
                child: Center(
                  child: Text(
                    _grade.label,
                    style: TextStyle(
                      color: _grade.color,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '精度 $pct%',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.kifu.length}手  ${widget.result.replaceAll('！', '').replaceAll('🎉', '')}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _grade.message,
            textAlign: TextAlign.center,
            style: TextStyle(color: _grade.color.withAlpha(220), fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ─── 手の品質内訳 ─────────────────────────────────────
  Widget _qualityCard() {
    final total = _playerCounts.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    return _card(
      icon: Icons.bar_chart,
      title: '手の品質',
      child: Column(
        children: MoveQuality.values.map((q) {
          final count = _playerCounts[q] ?? 0;
          if (count == 0) return const SizedBox.shrink();
          final ratio = count / total;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(
                width: 60,
                child: Row(children: [
                  Icon(q.icon, color: q.color, size: 14),
                  const SizedBox(width: 4),
                  Text(q.label, style: TextStyle(color: q.color, fontSize: 12)),
                ]),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(q.color),
                    minHeight: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 32,
                child: Text(
                  '$count',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: q.color, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ─── 重要局面 ─────────────────────────────────────────
  Widget _keyMomentsCard() {
    return _card(
      icon: Icons.warning_amber_rounded,
      title: '重要局面（ミス上位 ${_keyMoments.length}手）',
      child: Column(
        children: _keyMoments.asMap().entries.map((entry) {
          final i = entry.key;
          final m = entry.value;
          final sign = m.evalChange >= 0 ? '+' : '';
          return Container(
            margin: EdgeInsets.only(top: i > 0 ? 12.0 : 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1628),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: m.quality.color.withAlpha(100)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ミニボード
                SizedBox(
                  width: 90,
                  height: 90,
                  child: MiniBoardWidget(
                    board: m.snapBefore.board,
                    size: 90,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: m.quality.color.withAlpha(40),
                            border: Border.all(color: m.quality.color),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(m.quality.icon, color: m.quality.color, size: 12),
                            const SizedBox(width: 3),
                            Text(m.quality.label, style: TextStyle(color: m.quality.color, fontSize: 11, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Text('${m.step}手目', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        '${m.move.p1 ? "▲" : "△"}${m.move.note}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '評価値 $sign${m.evalChange}',
                        style: TextStyle(
                          color: m.evalChange < 0 ? Colors.red.shade300 : Colors.green.shade300,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── AI アドバイス ────────────────────────────────────
  Widget _adviceCard() {
    final advice = _generateAdvice();
    return _card(
      icon: Icons.psychology_outlined,
      title: 'AI アドバイス',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: advice.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            a,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
        )).toList(),
      ),
    );
  }

  // ─── 練習メニュー ─────────────────────────────────────
  Widget _practiceCard() {
    final menu = _practiceMenu();
    return _card(
      icon: Icons.fitness_center_outlined,
      title: '次の練習メニュー',
      child: Row(
        children: menu.map((item) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color: (item['color'] as Color).withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: (item['color'] as Color).withAlpha(80)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item['icon'] as IconData, color: item['color'] as Color, size: 24),
                  const SizedBox(height: 6),
                  Text(
                    item['label'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: item['color'] as Color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['desc'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── 共通カードラッパー ───────────────────────────────
  Widget _card({required IconData icon, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: Colors.amber.shade300, size: 16),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: Colors.amber.shade200,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
