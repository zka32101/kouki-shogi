// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'purchase_service.dart';
import 'piece.dart';
import 'theme/app_theme.dart';
import 'logic.dart';
import 'mini_board_widget.dart';
import 'tsume_engine.dart';
import 'tsume_builtin_problems.dart' show TsumeProb, buildTsumeProblems;
import 'study_calendar_screen.dart';

// ===== 問題データ =====
// 内蔵詰将棋問題（1手/3手/5手詰め）本体は tsume_builtin_problems.dart
// （純Dart・flutter非依存）へ分離済み。tool/validate_tsume_screen.dart から
// 詰み成立の自動検証ができるようにするため。
typedef _TsumeProb = TsumeProb;
List<_TsumeProb> _buildProblems() => buildTsumeProblems();

List<List<Piece?>> _empty() =>
    List.generate(9, (_) => List<Piece?>.filled(9, null));

// ===== 問題集 =====
// 座標: board[row][col], row=0=1段目(上端), col=0=9筋(右端)
// 先手(p1=true): 上向き、敵陣=row0付近
// 後手(p2=false): 下向き、敵陣=row8付近

List<_TsumeProb> _problems = _buildProblems();
bool _extraProblemsLoaded = false;

// 外部JSON問題を非同期ロード（アプリ初回起動時に一度だけ）
Future<void> _loadExtraProblems() async {
  if (_extraProblemsLoaded) return;
  _extraProblemsLoaded = true;
  try {
    final jsonStr = await rootBundle.loadString('assets/tsume_extra.json');
    final List<dynamic> data = json.decode(jsonStr) as List<dynamic>;
    final extras = data
        .map((e) => _tsumeFromJson(e as Map<String, dynamic>))
        .whereType<_TsumeProb>()
        // 開始局面で後手玉がすでに王手/詰みの問題を除外
        .where((p) =>
            !GL.inCheck(p.board, false) &&
            GL.hasLegalMove(p.board, false, p.p2Hand, p.p1Hand))
        .toList();
    _problems.addAll(extras);
  } catch (_) {
    // ファイルがない/パースエラーは無視して内蔵問題のみ使用
  }
}

// ── JSON → _TsumeProb 変換 ──
// board: 81要素の文字列リスト。空="", 先手="+XX", 後手="-XX"
// CSAコード: OU王 HI飛 KA角 KI金 GI銀 KE桂 KY香 FU歩 RY龍 UM馬 NG全 NK圭 NY杏 TO と
_TsumeProb? _tsumeFromJson(Map<String, dynamic> j) {
  try {
    final rawBoard = (j['board'] as List<dynamic>).cast<String>();
    if (rawBoard.length != 81) return null;
    final b = _empty();
    for (int i = 0; i < 81; i++) {
      final s = rawBoard[i];
      if (s.isEmpty) continue;
      final isP1 = s[0] == '+';
      final code = s.substring(1);
      final type = _csaToType(code);
      if (type != null) b[i ~/ 9][i % 9] = Piece(type, isP1);
    }
    Map<PieceType, int> parseHand(Map<String, dynamic>? m) {
      if (m == null) return {};
      return {
        for (final e in m.entries)
          if (_csaToType(e.key) != null) _csaToType(e.key)!: e.value as int
      };
    }
    // 王の数チェック（先手・後手各1枚必須）
    int p1Kings = 0, p2Kings = 0;
    for (final row in b) {
      for (final p in row) {
        if (p?.type == PieceType.king) {
          if (p!.isPlayer1) p1Kings++; else p2Kings++;
        }
      }
    }
    if (p1Kings != 1 || p2Kings != 1) return null;

    final sol = (j['solution'] as List<dynamic>).map((e) {
      final m = e as Map<String, dynamic>;
      final tr = m['tr'] as int;
      final tc = m['tc'] as int;
      final fr = m['fr'] as int? ?? -1;
      final fc = m['fc'] as int? ?? -1;
      // 座標範囲チェック
      if (tr < 0 || tr > 8 || tc < 0 || tc > 8) throw FormatException('out of bounds');
      if (fr != -1 && (fr < 0 || fr > 8 || fc < 0 || fc > 8)) throw FormatException('out of bounds');
      return AMove(
        fr: fr,
        fc: fc,
        tr: tr,
        tc: tc,
        drop: m['drop'] != null ? _csaToType(m['drop'] as String) : null,
        promote: m['promote'] as bool? ?? false,
      );
    }).toList();
    return _TsumeProb(
      title: j['title'] as String,
      moves: j['moves'] as int,
      board: b,
      p1Hand: parseHand(j['p1Hand'] as Map<String, dynamic>?),
      p2Hand: parseHand(j['p2Hand'] as Map<String, dynamic>?),
      solution: sol,
      explanation: j['explanation'] as String? ?? '',
    );
  } catch (_) {
    return null;
  }
}

PieceType? _csaToType(String code) => const {
  'OU': PieceType.king,
  'HI': PieceType.rook,
  'KA': PieceType.bishop,
  'KI': PieceType.gold,
  'GI': PieceType.silver,
  'KE': PieceType.knight,
  'KY': PieceType.lance,
  'FU': PieceType.pawn,
  'RY': PieceType.promotedRook,
  'UM': PieceType.promotedBishop,
  'NG': PieceType.promotedSilver,
  'NK': PieceType.promotedKnight,
  'NY': PieceType.promotedLance,
  'TO': PieceType.promotedPawn,
}[code];


// ===== タイムアタック画面 =====

enum _TaMode { threeMin, perProblem }
enum _TaDiff { mix, one, three, five }

class TsumeTimeAttackScreen extends StatefulWidget {
  const TsumeTimeAttackScreen({super.key});

  @override
  State<TsumeTimeAttackScreen> createState() => _TsumeTimeAttackScreenState();
}

class _TsumeTimeAttackScreenState extends State<TsumeTimeAttackScreen> {
  static const _bg = AppTheme.bg;
  static const _totalSec = 180;
  static const _perProbSec = 30;
  static const _prefBest3 = 'ta_best_3min';
  static const _prefBestPp = 'ta_best_perproblem';

  _TaMode _mode = _TaMode.threeMin;
  _TaDiff _diff = _TaDiff.mix;

  List<(int, _TsumeProb)> _pool = [];

  int _score = 0;
  int _skipped = 0;
  int _remaining = _totalSec;
  int _problemRemaining = _perProbSec;
  Timer? _sessionTimer;
  Timer? _problemTimer;
  bool _started = false;
  bool _finished = false;
  int _currentIdx = 0;
  final _random = _Rng();

  int _best3min = 0;
  int _bestPerproblem = 0;

  @override
  void initState() {
    super.initState();
    _buildPool();
    _loadBest();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _problemTimer?.cancel();
    super.dispose();
  }

  void _buildPool() {
    final all = <(int, _TsumeProb)>[];
    for (int i = 0; i < _problems.length; i++) {
      final p = _problems[i];
      if (GL.inCheck(p.board, false)) continue;
      final ok = switch (_diff) {
        _TaDiff.mix   => true,
        _TaDiff.one   => p.moves == 1,
        _TaDiff.three => p.moves == 3,
        _TaDiff.five  => p.moves >= 5,
      };
      if (ok) all.add((i, p));
    }
    _pool = all;
    if (_pool.isNotEmpty) _currentIdx = _random.nextInt(_pool.length);
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _best3min = prefs.getInt(_prefBest3) ?? 0;
      _bestPerproblem = prefs.getInt(_prefBestPp) ?? 0;
    });
  }

  Future<void> _saveBest() async {
    final prefs = await SharedPreferences.getInstance();
    if (_mode == _TaMode.threeMin && _score > _best3min) {
      await prefs.setInt(_prefBest3, _score);
      if (mounted) setState(() => _best3min = _score);
    } else if (_mode == _TaMode.perProblem && _score > _bestPerproblem) {
      await prefs.setInt(_prefBestPp, _score);
      if (mounted) setState(() => _bestPerproblem = _score);
    }
  }

  void _start() {
    _sessionTimer?.cancel();
    _problemTimer?.cancel();
    setState(() {
      _started = true;
      _remaining = _totalSec;
      _problemRemaining = _perProbSec;
    });
    if (_mode == _TaMode.threeMin) {
      _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _remaining--;
          if (_remaining <= 0) {
            _remaining = 0;
            _sessionTimer?.cancel();
            _finished = true;
            _saveBest();
          }
        });
      });
    } else {
      _startProblemTimer();
    }
  }

  void _startProblemTimer() {
    _problemTimer?.cancel();
    setState(() => _problemRemaining = _perProbSec);
    _problemTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _problemRemaining--;
        if (_problemRemaining <= 0) {
          _problemRemaining = 0;
          _problemTimer?.cancel();
          _skipped++;
          if (_skipped >= 3) {
            _finished = true;
            _saveBest();
          } else {
            _nextProblem();
          }
        }
      });
    });
  }

  void _nextProblem() {
    if (_pool.isEmpty) return;
    setState(() => _currentIdx = _random.nextInt(_pool.length));
    if (_mode == _TaMode.perProblem) _startProblemTimer();
  }

  void _onSolved() {
    _problemTimer?.cancel();
    setState(() => _score++);
    _nextProblem();
  }

  String _fmtTime(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_finished) return _buildResult();
    if (!_started) return _buildStartScreen();

    final timerColor = _mode == _TaMode.threeMin
        ? (_remaining <= 30 ? Colors.red : _remaining <= 60 ? Colors.orange : AppTheme.accent)
        : (_problemRemaining <= 10 ? Colors.red : _problemRemaining <= 20 ? Colors.orange : Colors.green);

    final (origIdx, prob) = _pool[_currentIdx];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('タイムアタック', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_mode == _TaMode.perProblem)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                ...List.generate(3, (i) => Icon(
                  i < (3 - _skipped) ? Icons.favorite : Icons.favorite_border,
                  color: i < (3 - _skipped) ? Colors.redAccent : Colors.grey.shade700,
                  size: 20,
                )),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.timer, color: timerColor, size: 18),
              const SizedBox(width: 4),
              Text(
                _mode == _TaMode.threeMin ? _fmtTime(_remaining) : '$_problemRemaining秒',
                style: TextStyle(color: timerColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ]),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(40),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withAlpha(120)),
            ),
            child: Text(
              '$_score問',
              style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_mode == _TaMode.perProblem) _buildProblemTimerBar(),
          Expanded(
            child: _SolvePage(
              key: ValueKey((_currentIdx, _score, _skipped)),
              prob: prob,
              index: origIdx,
              timeAttackMode: true,
              onSolvedInTimeAttack: _onSolved,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemTimerBar() {
    final fraction = (_problemRemaining / _perProbSec).clamp(0.0, 1.0);
    final color = fraction > 0.5 ? Colors.green : fraction > 0.25 ? Colors.orange : Colors.red;
    return SizedBox(
      height: 6,
      child: LayoutBuilder(builder: (_, c) {
        return Stack(children: [
          Container(color: AppTheme.surface),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: c.maxWidth * fraction,
            color: color,
          ),
        ]);
      }),
    );
  }

  Widget _buildStartScreen() {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('タイムアタック', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Center(
              child: Icon(Icons.timer, color: AppTheme.accent, size: 64),
            ),
            const SizedBox(height: 20),

            // Mode
            const Text('モード', style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _TaModeButton(
                label: '3分チャレンジ',
                sub: '3分間で何問解けるか',
                icon: Icons.hourglass_bottom,
                selected: _mode == _TaMode.threeMin,
                onTap: () => setState(() { _mode = _TaMode.threeMin; }),
              )),
              const SizedBox(width: 10),
              Expanded(child: _TaModeButton(
                label: '1問30秒',
                sub: 'ミス3回でゲームオーバー',
                icon: Icons.flash_on,
                selected: _mode == _TaMode.perProblem,
                onTap: () => setState(() { _mode = _TaMode.perProblem; }),
              )),
            ]),
            const SizedBox(height: 20),

            // Difficulty
            const Text('難易度', style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              _TaDiffButton(label: 'ミックス', selected: _diff == _TaDiff.mix,
                onTap: () => setState(() { _diff = _TaDiff.mix; _buildPool(); })),
              const SizedBox(width: 8),
              _TaDiffButton(label: '1手詰め', selected: _diff == _TaDiff.one,
                onTap: () => setState(() { _diff = _TaDiff.one; _buildPool(); })),
              const SizedBox(width: 8),
              _TaDiffButton(label: '3手詰め', selected: _diff == _TaDiff.three,
                onTap: () => setState(() { _diff = _TaDiff.three; _buildPool(); })),
              const SizedBox(width: 8),
              _TaDiffButton(label: '5手+', selected: _diff == _TaDiff.five,
                onTap: () => setState(() { _diff = _TaDiff.five; _buildPool(); })),
            ]),
            const SizedBox(height: 6),
            Text('問題数: ${_pool.length}問', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 20),

            // Best scores
            if (_best3min > 0 || _bestPerproblem > 0)
              Wrap(spacing: 10, runSpacing: 8, children: [
                if (_best3min > 0)
                  _TaBestChip(label: '3分ベスト', score: _best3min),
                if (_bestPerproblem > 0)
                  _TaBestChip(label: '30秒ベスト', score: _bestPerproblem),
              ]),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pool.isEmpty ? null : _start,
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  _pool.isEmpty ? '問題がありません' : 'スタート',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final isNewBest = (_mode == _TaMode.threeMin && _score > 0 && _score >= _best3min) ||
        (_mode == _TaMode.perProblem && _score > 0 && _score >= _bestPerproblem);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _score >= 15 ? '🏆' : _score >= 8 ? '🥈' : _score >= 3 ? '🎯' : '😤',
                  style: const TextStyle(fontSize: 72),
                ),
                const SizedBox(height: 16),
                const Text('終了！', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                if (isNewBest) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(30),
                      border: Border.all(color: Colors.amber),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('🌟 新記録！', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                  ),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    const Text('正解数', style: TextStyle(color: Colors.white54, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      '$_score問',
                      style: const TextStyle(color: Colors.amber, fontSize: 52, fontWeight: FontWeight.bold),
                    ),
                    if (_mode == _TaMode.perProblem && _skipped > 0) ...[
                      const SizedBox(height: 4),
                      Text('タイムアウト: $_skipped回', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _score >= 15 ? '驚異的！詰将棋マスターです'
                        : _score >= 8 ? '素晴らしい！将棋の達人です'
                        : _score >= 3 ? 'よくできました！'
                        : 'もう少し！次は速く解けるよ',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ]),
                ),
                const SizedBox(height: 32),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      _sessionTimer?.cancel();
                      _problemTimer?.cancel();
                      setState(() {
                        _score = 0;
                        _skipped = 0;
                        _remaining = _totalSec;
                        _problemRemaining = _perProbSec;
                        _started = false;
                        _finished = false;
                        _buildPool();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('もう一度'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('戻る'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaModeButton extends StatelessWidget {
  final String label, sub;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TaModeButton({required this.label, required this.sub, required this.icon, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent.withAlpha(40) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppTheme.accent : Colors.white24, width: selected ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? AppTheme.accent : Colors.white54, size: 28),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _TaDiffButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TaDiffButton({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.amber.withAlpha(30) : AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? Colors.amber : Colors.white24),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.amber : Colors.white54,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _TaBestChip extends StatelessWidget {
  final String label;
  final int score;
  const _TaBestChip({required this.label, required this.score});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withAlpha(20),
        border: Border.all(color: Colors.amber.withAlpha(100)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.emoji_events, color: Colors.amber, size: 14),
        const SizedBox(width: 4),
        Text('$label: $score問', style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ランダム整数ヘルパー（dart:math Random のラッパー）
class _Rng {
  final _r = Random();
  int nextInt(int max) => _r.nextInt(max);
}

// ===== デイリー詰将棋（Wordle式）=====

class DailyTsumeScreen extends StatefulWidget {
  const DailyTsumeScreen({super.key});
  @override
  State<DailyTsumeScreen> createState() => _DailyTsumeScreenState();
}

class _DailyTsumeScreenState extends State<DailyTsumeScreen> {
  static const _bg = AppTheme.bg;
  static const _maxAttempts = 999;  // 無制限（実質上限）

  late final _TsumeProb _prob;
  late final int _probIdx;
  late final String _dateKey;

  late List<String> _attempts;
  int _currentAttempt = 0;
  bool _done = false;
  bool _solved = false;
  int _solveKey = 0;
  bool _loaded = false;
  bool _freezeAvailable = true;
  bool _streakFrozenToday = false;

  @override
  void initState() {
    super.initState();
    _attempts = List<String>.filled(_maxAttempts, 'pending');
    final now = DateTime.now();
    _dateKey = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    // 日付シードで全ユーザー共通の問題を選択
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final valid = <(int, _TsumeProb)>[];
    for (int i = 0; i < _problems.length; i++) {
      if (!GL.inCheck(_problems[i].board, false)) valid.add((i, _problems[i]));
    }
    final idx = seed % valid.length;
    final picked = valid[idx];
    _probIdx = picked.$1;
    _prob = picked.$2;

    _loadState();
  }

  String get _prefBase => 'daily_wordle_$_dateKey';

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  }

  String get _weekKey {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2,'0')}-${monday.day.toString().padLeft(2,'0')}';
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('${_prefBase}_attempts');
    final savedSolved = prefs.getBool('${_prefBase}_solved') ?? false;
    final lastFreezeDate = prefs.getString('tsume_freeze_used_date') ?? '';
    final frozenToday = prefs.getString('tsume_frozen_date') == _todayKey;
    if (!mounted) return;
    setState(() {
      if (saved != null && saved.length == _maxAttempts) {
        _attempts = saved;
      }
      _solved = savedSolved;
      final pending = _attempts.indexOf('pending');
      _currentAttempt = pending == -1 ? _maxAttempts : pending;
      _done = _solved || _currentAttempt >= _maxAttempts;
      _loaded = true;
      _freezeAvailable = lastFreezeDate != _weekKey;
      _streakFrozenToday = frozenToday;
    });
  }

  Future<void> _useFreeze() async {
    final prefs = await SharedPreferences.getInstance();
    final sub = PurchaseService.isPremium;
    if (!_freezeAvailable && !sub) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('今週のフリーズは使用済みです（サブスクで無制限）')),
        );
      }
      return;
    }
    final today = _todayKey;
    await prefs.setString('tsume_frozen_date', today);
    if (!sub) {
      await prefs.setString('tsume_freeze_used_date', _weekKey);
    }
    if (mounted) {
      setState(() {
        _streakFrozenToday = true;
        if (!sub) _freezeAvailable = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ストリークを保護しました ❄️')),
        );
      }
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('${_prefBase}_attempts', _attempts);
    await prefs.setBool('${_prefBase}_solved', _solved);
  }

  void _onSolved() {
    if (!mounted) return;
    setState(() {
      if (_currentAttempt < _maxAttempts) _attempts[_currentAttempt] = 'solved';
      _solved = true;
      _done = true;
    });
    _saveState();
    StudyCalendarScreen.recordActivity('tsume');
  }

  void _onReset() {
    if (_done || !mounted) return;
    setState(() {
      if (_currentAttempt < _maxAttempts) _attempts[_currentAttempt] = 'failed';
      _currentAttempt++;
      if (_currentAttempt >= _maxAttempts) _done = true;
      _solveKey++;
    });
    _saveState();
  }

  String _buildShareText() {
    final now = DateTime.now();
    final dateStr = '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    final emojis = _attempts.map((a) => a == 'solved' ? '🟩' : a == 'failed' ? '🟥' : '⬜').join('');
    return '効棋 デイリー詰将棋 $dateStr\n$emojis ${_prob.moves}手詰め';
  }

  Widget _buildAttemptBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_maxAttempts, (i) {
        final status = _attempts[i];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: status == 'solved'
                ? Colors.green.shade700
                : status == 'failed'
                    ? Colors.red.shade800
                    : i == _currentAttempt
                        ? AppTheme.surface
                        : Colors.grey.shade900,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: i == _currentAttempt && !_done
                  ? Colors.amber
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              status == 'solved'
                  ? '🟩'
                  : status == 'failed'
                      ? '🟥'
                      : '${i + 1}',
              style: TextStyle(
                fontSize: status == 'pending' ? 16 : 20,
                color: Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('デイリー詰将棋', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _done
              ? _buildResult()
              : _buildGame(),
    );
  }

  Widget _buildGame() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: const Color(0xFF0F1729),
          child: Column(
            children: [
              _buildAttemptBar(),
              const SizedBox(height: 8),
              Text(
                '残り ${_maxAttempts - _currentAttempt} 回',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: _SolvePage(
            key: ValueKey(_solveKey),
            prob: _prob,
            index: _probIdx,
            onSolvedCallback: _onSolved,
            onResetRequested: _onReset,
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final shareText = _buildShareText();
    final solveAttempt = _attempts.indexWhere((a) => a == 'solved');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_solved ? '🎉' : '😔', style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            Text(
              _solved ? '正解！' : '残念…',
              style: TextStyle(
                color: _solved ? Colors.amber : Colors.white70,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _solved
                  ? '${solveAttempt + 1}回目で解けました！'
                  : '明日また挑戦してください',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _attempts
                  .map((a) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          a == 'solved' ? '🟩' : a == 'failed' ? '🟥' : '⬜',
                          style: const TextStyle(fontSize: 32),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Text(
              '${_prob.moves}手詰め',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 28),
            if (_solved)
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: shareText));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('クリップボードにコピーしました'),
                        backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('結果をコピー'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _useFreeze,
                icon: const Icon(Icons.shield),
                label: const Text('ストリーク保護'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('戻る'),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== ローグライト タイムアタック =====

class TsumeRogueliteScreen extends StatefulWidget {
  const TsumeRogueliteScreen({super.key});
  @override
  State<TsumeRogueliteScreen> createState() => _TsumeRogueliteScreenState();
}

class _TsumeRogueliteScreenState extends State<TsumeRogueliteScreen> {
  static const _bg = AppTheme.bg;
  static const _maxLives = 3;
  static const _prefBestKey = 'roguelite_best_score';

  late final List<(int, _TsumeProb)> _sortedProblems;
  int _lives = _maxLives;
  int _score = 0;
  int _currentProbIdx = 0;
  bool _finished = false;
  bool _started = false;
  int _bestScore = 0;
  int _solveKey = 0;

  @override
  void initState() {
    super.initState();
    final valid = <(int, _TsumeProb)>[];
    for (int i = 0; i < _problems.length; i++) {
      if (!GL.inCheck(_problems[i].board, false)) valid.add((i, _problems[i]));
    }
    valid.sort((a, b) => a.$2.moves.compareTo(b.$2.moves));
    _sortedProblems = valid;
    _loadBest();
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _bestScore = prefs.getInt(_prefBestKey) ?? 0);
  }

  Future<void> _saveBest() async {
    if (_score > _bestScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefBestKey, _score);
      if (mounted) setState(() => _bestScore = _score);
    }
  }

  void _onSolved() {
    if (!mounted) return;
    if (_currentProbIdx + 1 >= _sortedProblems.length) {
      setState(() { _score++; _finished = true; });
    } else {
      setState(() { _score++; _currentProbIdx++; _solveKey++; });
    }
    _saveBest();
  }

  void _onWrongAttempt() {
    if (!mounted) return;
    setState(() {
      _lives--;
      _solveKey++;
      if (_lives <= 0) _finished = true;
    });
    if (_lives <= 0) _saveBest();
  }

  Widget _buildLivesBar() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(_maxLives, (i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            i < _lives ? Icons.favorite : Icons.favorite_border,
            color: i < _lives ? Colors.redAccent : Colors.grey.shade700,
            size: 22,
          ),
        )),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return _buildResult();
    if (!_started) return _buildStart();

    final (origIdx, prob) = _sortedProblems[_currentProbIdx];
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('ローグライト', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: _buildLivesBar(),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(40),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withAlpha(120)),
            ),
            child: Text(
              '$_score問',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _SolvePage(
        key: ValueKey(_solveKey),
        prob: prob,
        index: origIdx,
        onSolvedCallback: _onSolved,
        onResetRequested: _onWrongAttempt,
      ),
    );
  }

  Widget _buildStart() {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('ローグライト', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('❤️❤️❤️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 20),
              const Text(
                'ローグライト',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'ライフ3つで詰将棋に挑戦！\n間違えるとライフが減る。\n難易度は1手詰めから徐々に上がる。',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              if (_bestScore > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withAlpha(80)),
                  ),
                  child: Text(
                    '自己ベスト: $_bestScore問',
                    style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => setState(() => _started = true),
                icon: const Icon(Icons.play_arrow),
                label: const Text('スタート', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    final isNewBest = _score > 0 && _score >= _bestScore;
    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _lives > 0 ? '🏆' : _score >= 5 ? '⚔️' : '💀',
              style: const TextStyle(fontSize: 72),
            ),
            const SizedBox(height: 16),
            Text(
              _lives > 0 ? '全問クリア！' : 'ゲームオーバー',
              style: TextStyle(
                color: _lives > 0 ? Colors.amber : Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('正解数', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    '$_score問',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isNewBest) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(40),
                        border: Border.all(color: Colors.amber),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('🏆 自己ベスト更新！', style: TextStyle(color: Colors.amber, fontSize: 12)),
                    ),
                  ] else if (_bestScore > 0) ...[
                    const SizedBox(height: 4),
                    Text('自己ベスト: $_bestScore問', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _lives = _maxLives;
                      _score = 0;
                      _currentProbIdx = 0;
                      _finished = false;
                      _started = true;
                      _solveKey++;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('もう一度'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
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

// ===== 問題一覧画面 =====

class TsumeScreen extends StatefulWidget {
  const TsumeScreen({super.key});

  @override
  State<TsumeScreen> createState() => _TsumeScreenState();
}

class _TsumeScreenState extends State<TsumeScreen>
    with SingleTickerProviderStateMixin {
  static const _bg = AppTheme.bg;
  static const _card = AppTheme.surface;

  // 0=全て, 1=1手, 3=3手, 5=5手, 7=7手
  // (9手詰めは健全な問題を安定して構成できなかったため、
  //  カテゴリごと廃止した)
  int _filterMoves = 0;
  late TabController _tabController;

  List<bool> _cleared = [];

  // ── デイリー＆ストリーク ──
  int _streak = 0;
  bool _dailySolved = false;
  bool _freezeAvailable = true;  // 週1回無料フリーズ使用可
  bool _streakFrozenToday = false;
  int get _dailyIdx {
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    return seed % _problems.length;
  }
  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        switch (_tabController.index) {
          case 0: _filterMoves = 0; break;
          case 1: _filterMoves = 1; break;
          case 2: _filterMoves = 3; break;
          case 3: _filterMoves = 5; break;
          case 4: _filterMoves = 7; break;
        }
      });
    });
    _cleared = List.filled(_problems.length, false);
    _loadCleared();
    _loadStreak();
    // 外部JSON問題を非同期ロード（初回のみ）
    _loadExtraProblems().then((_) {
      if (mounted) {
        setState(() {
          // 外部問題追加後に _cleared を拡張
          if (_cleared.length < _problems.length) {
            _cleared = List.filled(_problems.length, false);
            _loadCleared();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── タイムランキング表示 ──
  Future<void> _showTimeRanking() async {
    final prefs = await SharedPreferences.getInstance();
    // 解決済み問題のベストタイムを収集
    final entries = <({String title, int moves, int bestSec, int idx})>[];
    for (int i = 0; i < _problems.length; i++) {
      final best = prefs.getInt('tsume_best_time_$i');
      if (best != null) {
        entries.add((title: _problems[i].title, moves: _problems[i].moves, bestSec: best, idx: i));
      }
    }
    // ベストタイム昇順でソート
    entries.sort((a, b) {
      if (a.moves != b.moves) return a.moves.compareTo(b.moves);
      return a.bestSec.compareTo(b.bestSec);
    });

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Row(children: [
          Icon(Icons.emoji_events, color: Colors.amber, size: 22),
          SizedBox(width: 8),
          Text('タイムランキング', style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: SizedBox(
          width: 320,
          child: entries.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('まだ解いた問題がありません', style: TextStyle(color: Colors.white54), textAlign: TextAlign.center),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 8),
                  itemBuilder: (_, i) {
                    final e = entries[i];
                    final fmtTime = e.bestSec < 60
                        ? '${e.bestSec}秒'
                        : '${e.bestSec ~/ 60}分${e.bestSec % 60}秒';
                    final medals = ['🥇', '🥈', '🥉'];
                    final medal = i < 3 ? medals[i] : '${i + 1}.';
                    return Row(children: [
                      Text(medal, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(e.title,
                            style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(fmtTime,
                            style: TextStyle(
                              color: i == 0 ? Colors.amber : Colors.white70,
                              fontSize: 12,
                              fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal,
                            )),
                      ),
                    ]);
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  // ── ストリーク読み込み ──
  Future<void> _loadStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString('tsume_last_solve_date') ?? '';
    final streak = prefs.getInt('tsume_streak') ?? 0;
    final dailySolvedToday = prefs.getString('tsume_daily_solved') == _todayKey;

    // フリーズ状態を確認（週単位でリセット）
    final lastFreezeDate = prefs.getString('tsume_freeze_used_date') ?? '';
    final freezeAvailable = lastFreezeDate != _getWeekKey;
    final frozenToday = prefs.getString('tsume_frozen_date') == _todayKey;

    if (mounted) setState(() {
      _streak = streak;
      _dailySolved = dailySolvedToday;
      _freezeAvailable = freezeAvailable;
      _streakFrozenToday = frozenToday;
    });
  }

  String get _getWeekKey {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return '${weekStart.year}-${weekStart.month.toString().padLeft(2,'0')}-${weekStart.day.toString().padLeft(2,'0')}';
  }

  // ── 正解時のストリーク更新 ──
  Future<void> _recordSolve({required bool isDaily}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey;
    final lastDate = prefs.getString('tsume_last_solve_date') ?? '';

    // ストリーク更新
    int newStreak = _streak;
    if (lastDate == today) {
      // 今日すでに解いていた → 変わらず
    } else {
      // 昨日解いたか判定
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayKey =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2,'0')}-${yesterday.day.toString().padLeft(2,'0')}';
      if (lastDate == yesterdayKey) {
        newStreak = _streak + 1;
      } else {
        newStreak = 1; // リセット
      }
      await prefs.setString('tsume_last_solve_date', today);
      await prefs.setInt('tsume_streak', newStreak);
    }

    // デイリー問題の完了記録
    if (isDaily) {
      await prefs.setString('tsume_daily_solved', today);
    }

    if (mounted) setState(() {
      _streak = newStreak;
      if (isDaily) _dailySolved = true;
    });
  }

  // ── ストリーク保険（フリーズ） ──
  Future<void> _useFreeze() async {
    final prefs = await SharedPreferences.getInstance();
    final sub = PurchaseService.isPremium;

    // サブスク無制限、未加入は週1回
    if (!_freezeAvailable && !sub) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('フリーズは週1回までです。サブスク加入で無制限に！'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // フリーズ使用
    await prefs.setString('tsume_frozen_date', _todayKey);
    if (!sub) {
      await prefs.setString('tsume_freeze_used_date', _getWeekKey);
    }

    // ストリークを継続（昨日解いた扱いにする）
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayKey = '${yesterday.year}-${yesterday.month.toString().padLeft(2,'0')}-${yesterday.day.toString().padLeft(2,'0')}';
    await prefs.setString('tsume_last_solve_date', yesterdayKey);

    if (mounted) {
      setState(() {
        _freezeAvailable = false;
        _streakFrozenToday = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ストリークが保護されました！'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadCleared() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _cleared = List.generate(
        _problems.length,
        (i) => prefs.getBool('tsume_clear_$i') ?? false,
      );
    });
  }

  Future<void> _saveCleared(int idx) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tsume_clear_$idx', true);
    setState(() => _cleared[idx] = true);
  }

  // ── デイリー問題カード ──
  Widget _timeAttackCard(BuildContext ctx) {
    return Card(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.deepOrange.withAlpha(100), width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: Colors.deepOrange.shade900.withAlpha(120),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.timer, color: Colors.deepOrange, size: 26),
        ),
        title: const Text('タイムアタック',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        subtitle: const Text('3分間で何問解けるか挑戦！',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
        onTap: () => Navigator.push(
          ctx, MaterialPageRoute(builder: (_) => const TsumeTimeAttackScreen())),
      ),
    );
  }

  Widget _dailyCard() {
    final idx = _dailyIdx;
    final prob = _problems[idx];
    final now = DateTime.now();
    final dateStr = '${now.month}月${now.day}日';

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<dynamic>(
          context,
          MaterialPageRoute(
            builder: (_) => _SolvePage(prob: prob, index: idx),
          ),
        );
        if (result == true) {
          await _saveCleared(idx);
          await _recordSolve(isDaily: true);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _dailySolved
                ? [Colors.green.shade900, Colors.green.shade800]
                : [const Color(0xFF2D1B69), const Color(0xFF1A1054)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _dailySolved ? Colors.green.shade400 : Colors.deepPurpleAccent.withAlpha(180),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (_dailySolved ? Colors.green : Colors.deepPurple).withAlpha(60),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _dailySolved ? Colors.green.shade700 : Colors.deepPurple.shade700,
            ),
            child: Center(
              child: _dailySolved
                  ? const Icon(Icons.check_circle, color: Colors.white, size: 28)
                  : const Icon(Icons.calendar_today, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📅 デイリー問題 $dateStr',
                  style: TextStyle(
                    color: _dailySolved ? Colors.green.shade300 : Colors.amber.shade200,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  prob.title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  _dailySolved ? '✓ クリア済み' : '${prob.moves}手詰め  タップして挑戦！',
                  style: TextStyle(
                    color: _dailySolved ? Colors.green.shade300 : Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_streak > 0)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 22)),
                Text(
                  '$_streak日',
                  style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
        ]),
      ),
    );
  }

  String _clearCountLabel(int moves) {
    final idxs = <int>[];
    for (int i = 0; i < _problems.length; i++) {
      if (_problems[i].moves == moves && !GL.inCheck(_problems[i].board, false)) {
        idxs.add(i);
      }
    }
    final total = idxs.length;
    final done = idxs.where((i) => i < _cleared.length && _cleared[i]).length;
    return '$done/$total';
  }

  Tab _tabItem(String title, String sub) => Tab(
    height: 52,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 1),
        Text(sub, style: const TextStyle(fontSize: 9)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    // フィルタ後の問題リスト(元インデックス付き) ※開始局面で王手の問題は除外
    final filtered = <(int, _TsumeProb)>[];
    for (int i = 0; i < _problems.length; i++) {
      if (_filterMoves == 0 || _problems[i].moves == _filterMoves) {
        if (!GL.inCheck(_problems[i].board, false)) {
          filtered.add((i, _problems[i]));
        }
      }
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        title: const Text('詰将棋', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // タイムランキング
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined, color: Colors.amber),
            tooltip: 'タイムランキング',
            onPressed: _showTimeRanking,
          ),
          // ストリークバッジ
          if (_streak > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade800.withAlpha(200),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade400, width: 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🔥', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    '$_streak日連続',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Colors.amber,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.white54,
            labelPadding: const EdgeInsets.symmetric(horizontal: 10),
            tabs: [
              const Tab(height: 52, text: '全て'),
              _tabItem('1手詰め', _clearCountLabel(1)),
              _tabItem('3手詰め', _clearCountLabel(3)),
              _tabItem('5手詰め', _clearCountLabel(5)),
              _tabItem('7手詰め', _clearCountLabel(7)),
            ],
          ),
        ),
      ),
      body: filtered.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.construction, color: Colors.white38, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    '問題を準備中です',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '近日公開予定',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ],
              ),
            )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length + (_filterMoves == 0 ? 2 : 0), // +2 for daily + time attack cards
        itemBuilder: (context, listIdx) {
          // デイリー問題カード（全てタブのみ・先頭）
          if (_filterMoves == 0 && listIdx == 0) {
            return _dailyCard();
          }
          if (_filterMoves == 0 && listIdx == 1) {
            return _timeAttackCard(context);
          }
          final realIdx = _filterMoves == 0 ? listIdx - 2 : listIdx;
          final (origIdx, prob) = filtered[realIdx];
          final cleared = origIdx < _cleared.length && _cleared[origIdx];
          return Card(
            color: _card,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: cleared ? Colors.amber.shade400 : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: CircleAvatar(
                backgroundColor: cleared
                    ? Colors.amber.shade700
                    : Colors.blueGrey.shade800,
                child: Text(
                  '${origIdx + 1}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                prob.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${prob.moves}手詰め',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              trailing: cleared
                  ? Icon(Icons.check_circle, color: Colors.amber.shade400)
                  : const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () async {
                final result = await Navigator.push<dynamic>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _SolvePage(prob: prob, index: origIdx),
                  ),
                );
                if (result == true) {
                  await _saveCleared(origIdx);
                  await _recordSolve(isDaily: origIdx == _dailyIdx);
                }
                // 'skip' が返った場合は問題に誤りがあるため何もしない
              },
            ),
          );
        },
      ),
    );
  }
}

// ===== 解答画面 =====

class _SolvePage extends StatefulWidget {
  final _TsumeProb prob;
  final int index;
  final bool timeAttackMode;
  final VoidCallback? onSolvedInTimeAttack;
  final VoidCallback? onSolvedCallback;   // generic: skips dialog, shows snackbar
  final VoidCallback? onResetRequested;   // intercept reset button
  const _SolvePage({
    super.key,
    required this.prob,
    required this.index,
    this.timeAttackMode = false,
    this.onSolvedInTimeAttack,
    this.onSolvedCallback,
    this.onResetRequested,
  });

  @override
  State<_SolvePage> createState() => _SolvePageState();
}

class _SolvePageState extends State<_SolvePage> {
  static const _bg = AppTheme.bg;
  static const _card = AppTheme.surface;

  late List<List<Piece?>> _board;
  late Map<PieceType, int> _p1Hand;
  late Map<PieceType, int> _p2Hand;

  // solution のインデックス: 偶数=先手の手、奇数=後手の応手
  int _solutionIdx = 0;
  bool _solved = false;
  bool _startInCheck = false; // 開始局面で後手玉がすでに王手されている場合は問題に誤りあり

  (int, int)? _selected;
  Set<(int, int)> _legalDots = {};
  (int, int)? _lastFrom;
  (int, int)? _lastTo;
  PieceType? _selectedHandPiece;
  int _hintLevel = 0;

  // ── タイマー ──
  final _stopwatch = Stopwatch();
  Timer? _ticker;
  int _elapsedSec = 0;
  int? _bestTimeSec;

  // ── 詰み探索エンジン ──
  final _engine = TsumeEngine();
  bool _verifying = false; // 検証中フラグ

  bool get _p1Turn => _solutionIdx % 2 == 0; // 偶数=先手番

  // 残り手数（この手番から詰みまで）
  int get _remainingMoves => widget.prob.moves - _solutionIdx;

  @override
  void initState() {
    super.initState();
    _resetState();
    _loadBestTime();
    // 1秒ごとに画面更新
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_solved && mounted) {
        setState(() => _elapsedSec = _stopwatch.elapsed.inSeconds);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadBestTime() async {
    final prefs = await SharedPreferences.getInstance();
    final best = prefs.getInt('tsume_best_time_${widget.index}');
    if (mounted) setState(() => _bestTimeSec = best);
  }

  Future<void> _saveBestTime(int sec) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('tsume_best_time_${widget.index}');
    if (current == null || sec < current) {
      await prefs.setInt('tsume_best_time_${widget.index}', sec);
      if (mounted) setState(() => _bestTimeSec = sec);
    }
  }

  String _fmtTime(int sec) {
    if (sec < 60) return '${sec}秒';
    return '${sec ~/ 60}分${sec % 60}秒';
  }

  void _resetState() {
    final prob = widget.prob;
    _board = List.generate(9, (r) => List<Piece?>.from(prob.board[r]));
    _p1Hand = Map<PieceType, int>.from(prob.p1Hand);
    _p2Hand = Map<PieceType, int>.from(prob.p2Hand);
    _solutionIdx = 0;
    _solved = false;
    _selected = null;
    _legalDots = {};
    _lastFrom = null;
    _lastTo = null;
    _selectedHandPiece = null;
    _stopwatch.reset();
    _stopwatch.start();
    _elapsedSec = 0;
    // 安全チェック: 開始局面で後手玉がすでに王手されていないか確認
    _startInCheck = GL.inCheck(_board, false);
  }

  AMove? get _currentSol {
    final sol = widget.prob.solution;
    return _solutionIdx < sol.length ? sol[_solutionIdx] : null;
  }

  // ===== 盤面タップ =====

  void _onBoardTap(int row, int col) {
    if (_solved || !_p1Turn || _verifying) return;

    if (_selectedHandPiece != null) {
      _tryDrop(row, col); // async - fire and forget OK
      return;
    }

    final tapped = _board[row][col];

    if (_selected == null) {
      if (tapped != null && tapped.isPlayer1) {
        setState(() {
          _selected = (row, col);
          _legalDots = GL.legal(_board, row, col).toSet();
        });
      }
    } else {
      final sel = _selected!;
      if (sel == (row, col)) {
        setState(() {
          _selected = null;
          _legalDots = {};
        });
        return;
      }
      if (tapped != null && tapped.isPlayer1) {
        setState(() {
          _selected = (row, col);
          _legalDots = GL.legal(_board, row, col).toSet();
        });
        return;
      }
      if (_legalDots.contains((row, col))) {
        _tryMove(sel.$1, sel.$2, row, col);
      } else {
        setState(() {
          _selected = null;
          _legalDots = {};
        });
      }
    }
  }

  // ── 動的詰み検証 ──────────────────────────────────────
  // 固定手順との一致ではなく「詰みに向かう有効手か」を判定する。

  Future<void> _tryMove(int fr, int fc, int tr, int tc) async {
    if (_verifying) return;
    final piece = _board[fr][fc];
    if (piece == null) return;

    setState(() {
      _selected = null;
      _legalDots = {};
    });

    // 成り判定: 詰み探索で成りと不成りを両方試す（自動で良い方を選ぶ）
    // 必須成り
    bool forcedPromote = piece.canPromote && piece.mustPromote(tr);

    // 成り・不成りの候補を構築
    final candidates = <AMove>[];
    if (forcedPromote) {
      candidates.add(AMove(fr: fr, fc: fc, tr: tr, tc: tc, promote: true));
    } else if (piece.canPromote) {
      // 成りゾーンなら両方試す（詰みに繋がる方を優先）
      bool inZ(int row) => piece.isPlayer1 ? row <= 2 : row >= 6;
      if (inZ(fr) || inZ(tr)) {
        candidates.add(AMove(fr: fr, fc: fc, tr: tr, tc: tc, promote: true));
        candidates.add(AMove(fr: fr, fc: fc, tr: tr, tc: tc, promote: false));
      } else {
        candidates.add(AMove(fr: fr, fc: fc, tr: tr, tc: tc, promote: false));
      }
    } else {
      candidates.add(AMove(fr: fr, fc: fc, tr: tr, tc: tc, promote: false));
    }

    await _verifyAndApplyMove(candidates);
  }

  Future<void> _tryDrop(int tr, int tc) async {
    if (_verifying) return;
    final type = _selectedHandPiece;
    if (type == null) return;

    // 打てるマスでなければ選択解除のみ
    if (!_legalDots.contains((tr, tc))) {
      setState(() {
        _selectedHandPiece = null;
        _legalDots = {};
      });
      return;
    }

    setState(() {
      _selectedHandPiece = null;
      _selected = null;
      _legalDots = {};
    });

    final mv = AMove(fr: -1, fc: -1, tr: tr, tc: tc, drop: type);
    await _verifyAndApplyMove([mv]);
  }

  /// 手を適用し、後手の最善防御を自動実行してから
  /// 残り手数内に詰みが存在するか確認する。
  /// 詰みが存在しなければ初期局面に戻す。
  Future<void> _verifyAndApplyMove(List<AMove> candidates) async {
    if (_verifying) return;
    setState(() => _verifying = true);

    // ── 1. 王手になる候補を選んで適用 ──────────────────────────
    AMove? mv;
    for (final c in candidates) {
      final tmp = AI.apply(_board, _p1Hand, _p2Hand, c, true);
      if (GL.inCheck(tmp.b, false)) { mv = c; break; }
    }
    mv ??= candidates.first; // 王手にならない場合も視覚表示のために適用

    if (mv.drop != null) {
      _execDrop(mv.drop!, mv.tr, mv.tc, isP1: true);
    } else {
      _execMove(mv.fr, mv.fc, mv.tr, mv.tc, mv.promote);
    }
    setState(() {
      _selected = null;
      _legalDots = {};
      _selectedHandPiece = null;
    });

    // ── 2. 詰将棋ルール: 攻め方の手は必ず王手 ──────────────────
    if (!GL.inCheck(_board, false)) {
      await _handleWrongAttempt();
      return;
    }

    // ── 3. 即詰み（後手に合法手なし）→ 正解 ────────────────────
    if (!GL.hasLegalMove(_board, false, _p2Hand, _p1Hand)) {
      setState(() => _verifying = false);
      _onSolved();
      return;
    }

    // ── 4. 後手の最善防御手を自動実行 ───────────────────────────
    _solutionIdx++;
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    final defMove = await Future(
      () => AI.bestMove(_board, _p1Hand, _p2Hand, false, 2),
    );
    if (!mounted) return;

    if (defMove == null) {
      setState(() => _verifying = false);
      _onSolved();
      return;
    }

    if (defMove.drop != null) {
      _execDrop(defMove.drop!, defMove.tr, defMove.tc, isP1: false);
    } else {
      _execMove(defMove.fr, defMove.fc, defMove.tr, defMove.tc, defMove.promote);
    }
    _solutionIdx++;
    setState(() {});

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    // ── 5. 残り手数内に詰みが存在するか確認 ─────────────────────
    final remaining = widget.prob.moves - _solutionIdx;

    if (remaining <= 0) {
      // 手数を全て使ったが詰んでいない
      await _handleWrongAttempt(delayMs: 700);
      return;
    }

    final mateResult = await _engine.findMate(
      board: _board,
      p1Hand: _p1Hand,
      p2Hand: _p2Hand,
      attackerIsP1: true,
      depth: remaining,
    );
    if (!mounted) return;

    if (!mateResult.isMate) {
      // 残り手数内に詰み経路なし → 最初の局面に戻す
      await _handleWrongAttempt(delayMs: 700);
      return;
    }

    // ── 6. まだ詰み経路あり → 継続 ─────────────────────────────
    setState(() => _verifying = false);
  }

  void _execMove(int fr, int fc, int tr, int tc, bool promote) {
    final piece = _board[fr][fc]!;
    final cap = _board[tr][tc];
    if (cap != null) {
      final hand = piece.isPlayer1 ? _p1Hand : _p2Hand;
      hand[cap.baseType] = (hand[cap.baseType] ?? 0) + 1;
    }
    _board[tr][tc] = promote ? Piece(piece.promotedType, piece.isPlayer1) : piece;
    _board[fr][fc] = null;
    _lastFrom = (fr, fc);
    _lastTo = (tr, tc);
  }

  void _execDrop(PieceType type, int tr, int tc, {required bool isP1}) {
    final hand = isP1 ? _p1Hand : _p2Hand;
    _board[tr][tc] = Piece(type, isP1);
    hand[type] = (hand[type] ?? 1) - 1;
    if ((hand[type] ?? 0) <= 0) hand.remove(type);
    _lastFrom = null;
    _lastTo = (tr, tc);
  }

  void _onSolved() {
    _stopwatch.stop();
    final elapsed = _stopwatch.elapsed.inSeconds;
    _saveBestTime(elapsed);
    setState(() {
      _solved = true;
      _elapsedSec = elapsed;
    });

    // タイムアタックモード: ダイアログなしで次の問題へ
    if (widget.timeAttackMode) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
          content: Text('正解！次の問題へ'),
          backgroundColor: Colors.green,
          duration: Duration(milliseconds: 800),
        ),
        );
      }
      Future.delayed(const Duration(milliseconds: 900), () {
        widget.onSolvedInTimeAttack?.call();
      });
      return;
    }

    // 汎用コールバックモード（デイリー・ローグライト）
    if (widget.onSolvedCallback != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正解！'),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 800),
          ),
        );
      }
      Future.delayed(const Duration(milliseconds: 900), () {
        widget.onSolvedCallback?.call();
      });
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('詰みました！',
            style: TextStyle(
                color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('正解です！おめでとうございます。',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.timer_outlined, color: AppTheme.accent, size: 16),
              const SizedBox(width: 6),
              Text(
                '解答時間: ${_fmtTime(elapsed)}',
                style: const TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              if (_bestTimeSec != null && elapsed <= _bestTimeSec!) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(40),
                    border: Border.all(color: Colors.amber),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('🏆 自己ベスト！', style: TextStyle(color: Colors.amber, fontSize: 11)),
                ),
              ],
            ]),
            if (widget.prob.explanation.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withAlpha(60)),
                ),
                child: Text(
                  widget.prob.explanation,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);       // ダイアログ閉じる
              Navigator.pop(context, true); // 一覧に戻り(クリア通知)
            },
            child: const Text('戻る', style: TextStyle(color: Colors.amber)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _resetState());
            },
            child:
                const Text('もう一度', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _showWrong() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✗ その手では詰みません'),
        duration: Duration(milliseconds: 700),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // 誤答時の共通処理。onResetRequested が渡されている場合
  // （デイリー詰将棋・ローグライトモード）は親側の残機/回数管理を
  // 必ず経由させる。以前は _resetState() を直接呼んでいたため、
  // ローグライトで間違えてもライフが減らないバグがあった。
  Future<void> _handleWrongAttempt({int delayMs = 800}) async {
    _showWrong();
    await Future.delayed(Duration(milliseconds: delayMs));
    if (!mounted) return;
    if (widget.onResetRequested != null) {
      widget.onResetRequested!();
    } else {
      setState(() {
        _resetState();
        _verifying = false;
      });
    }
  }

  // ===== 持ち駒ウィジェット =====

  Widget _handWidget(Map<PieceType, int> hand, {required bool isP1}) {
    if (hand.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text('なし', style: TextStyle(color: Colors.white38, fontSize: 12)),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: hand.entries.map((e) {
        final selected = isP1 && _selectedHandPiece == e.key;
        return GestureDetector(
          onTap: isP1 && _p1Turn && !_solved && !_verifying
              ? () {
                  setState(() {
                    final tapping = e.key;
                    if (_selectedHandPiece == tapping) {
                      // 同じ駒を再タップ → 選択解除
                      _selectedHandPiece = null;
                      _legalDots = {};
                    } else {
                      _selectedHandPiece = tapping;
                      _selected = null;
                      // 打てるマスをハイライト表示
                      _legalDots = GL
                          .dropSquares(_board, tapping, true, _p1Hand, _p2Hand)
                          .toSet();
                    }
                  });
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.amber.shade700
                  : Colors.blueGrey.shade800,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected
                    ? Colors.amber.shade300
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Text(
              '${pieceLabel(e.key)}×${e.value}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ===== ビルド =====

  @override
  Widget build(BuildContext context) {
    final prob = widget.prob;
    final sol = _currentSol;

    final turnText = _verifying
        ? '検証中...'
        : _p1Turn ? '▲先手番' : '△後手番(自動応手中...)';
    final moveNum = (_solutionIdx ~/ 2) + 1;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        title: Text(prob.title,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // タイマー表示
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.accent.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accent.withAlpha(100)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.timer_outlined, color: AppTheme.accent, size: 14),
                const SizedBox(width: 4),
                Text(
                  _solved ? _fmtTime(_elapsedSec) : _fmtTime(_elapsedSec),
                  style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ]),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              if (widget.onResetRequested != null) {
                widget.onResetRequested!();
              } else {
                setState(() => _resetState());
              }
            },
            icon: const Icon(Icons.refresh, color: Colors.white54, size: 18),
            label: const Text('リセット',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final boardSize = (maxW * 0.92).clamp(200.0, 440.0);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 開始局面エラー警告
                if (_startInCheck)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withAlpha(200),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'この問題は修正中です。\n開始局面に誤りがある可能性があります。',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('戻る', style: TextStyle(color: Colors.amber, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                // 状態表示
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text('${prob.moves}手詰め',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13)),
                    if (_verifying) ...[
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                    Text('第$moveNum手  $turnText',
                        style: TextStyle(
                            color: _verifying
                                ? AppTheme.accent
                                : _p1Turn
                                    ? Colors.lightBlue.shade300
                                    : Colors.orange.shade300,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),

                // 後手持ち駒(上)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('後手持ち駒:',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 11)),
                      _handWidget(_p2Hand, isP1: false),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 盤面
                Center(
                  child: GestureDetector(
                    onTapUp: (details) {
                      final labelSize = boardSize * 0.05;
                      final cellSize = (boardSize - labelSize) / 9;
                      final x = details.localPosition.dx - labelSize;
                      final y = details.localPosition.dy - labelSize;
                      final col = (x / cellSize).floor();
                      final row = (y / cellSize).floor();
                      if (row >= 0 && row < 9 && col >= 0 && col < 9) {
                        _onBoardTap(row, col);
                      }
                    },
                    child: SizedBox(
                      width: boardSize,
                      child: MiniBoardWidget(
                        board: _board,
                        moveDots: _legalDots,
                        lastMoveFrom: _lastFrom,
                        lastMoveTo: _lastTo,
                        highlightSquares:
                            _selected != null ? {_selected!} : {},
                        showLabels: true,
                        size: boardSize,
                        boardFlipped: false,
                        currentIsP1: _p1Turn,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 先手持ち駒(下)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('先手持ち駒:',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 11)),
                      _handWidget(_p1Hand, isP1: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ヒントボタン
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      icon: Icon(
                        _hintLevel == 0 ? Icons.lightbulb_outline : Icons.lightbulb,
                        color: _hintLevel > 0 ? Colors.amber : Colors.white54,
                        size: 16,
                      ),
                      label: Text(
                        _hintLevel == 0 ? 'ヒント' : _hintLevel == 1 ? 'ヒント (駒種)' : 'ヒント (移動先)',
                        style: TextStyle(
                          color: _hintLevel > 0 ? Colors.amber : Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: !_solved ? () {
                        setState(() => _hintLevel = (_hintLevel + 1) % 3);
                      } : null,
                    ),
                    if (_hintLevel > 0)
                      TextButton(
                        onPressed: () => setState(() => _hintLevel = 0),
                        child: const Text('リセット', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      ),
                  ],
                ),
                if (_hintLevel > 0 && !_solved) Builder(builder: (ctx) {
                  final sol = widget.prob.solution;
                  if (sol.isEmpty) return const SizedBox.shrink();
                  final firstMove = sol[0];

                  if (_hintLevel == 1) {
                    // Level 1: 駒の種類のみ
                    Piece? piece;
                    if (firstMove.drop != null) {
                      piece = Piece(firstMove.drop!, true);
                    } else if (firstMove.fr >= 0 && firstMove.fr < 9) {
                      piece = _board[firstMove.fr][firstMove.fc];
                    }
                    final pieceName = piece?.label ?? '?';
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withAlpha(80)),
                      ),
                      child: Text('ヒント: $pieceName を動かす',
                          style: const TextStyle(color: Colors.amber, fontSize: 12),
                          textAlign: TextAlign.center),
                    );
                  } else {
                    // Level 2: 移動先も表示
                    Piece? piece;
                    if (firstMove.drop != null) {
                      piece = Piece(firstMove.drop!, true);
                    } else if (firstMove.fr >= 0 && firstMove.fr < 9) {
                      piece = _board[firstMove.fr][firstMove.fc];
                    }
                    final pieceName = piece?.label ?? '?';
                    const cols = ['9','8','7','6','5','4','3','2','1'];
                    const rows = ['一','二','三','四','五','六','七','八','九'];
                    final tr = firstMove.tr;
                    final tc = firstMove.tc;
                    final dest = (tr >= 0 && tr < 9 && tc >= 0 && tc < 9)
                        ? '${cols[tc]}${rows[tr]}' : '?';
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withAlpha(120)),
                      ),
                      child: Text('ヒント: $pieceName → $dest',
                          style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                    );
                  }
                }),
                const SizedBox(height: 8),
                // 操作ガイド
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F3460),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '駒をタップして選択し、移動先をタップしてください。\n'
                    '持ち駒は「先手持ち駒」からタップして選択して打てます。',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
