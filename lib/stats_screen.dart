// lib/stats_screen.dart — 対局統計 + 段級位・成長記録グラフ

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'rank_badge_widget.dart';
import 'theme/app_theme.dart';

// ── 段級位テーブル ────────────────────────────────────────
class RatingRank {
  final int minRating;
  final String rank;
  final Color color;
  const RatingRank(this.minRating, this.rank, this.color);
}

const rankTable = [
  RatingRank(2400, '九段',  Color(0xFFFF6B35)),
  RatingRank(2200, '八段',  Color(0xFFFF8C42)),
  RatingRank(2050, '七段',  Color(0xFFFFAA00)),
  RatingRank(1900, '六段',  Color(0xFFFFD700)),
  RatingRank(1750, '五段',  Color(0xFFFFE55C)),
  RatingRank(1600, '四段',  Color(0xFFFFD700)),
  RatingRank(1450, '三段',  Color(0xFFFFAB40)),
  RatingRank(1300, '二段',  Color(0xFFFF9800)),
  RatingRank(1150, '初段',  Color(0xFFFFC107)),
  RatingRank(1050, '1級',   Color(0xFF81D4FA)),
  RatingRank(950,  '2級',   Color(0xFF64B5F6)),
  RatingRank(880,  '3級',   Color(0xFF4FC3F7)),
  RatingRank(820,  '4級',   Color(0xFF4DD0E1)),
  RatingRank(760,  '5級',   Color(0xFF80CBC4)),
  RatingRank(700,  '6級',   Color(0xFFA5D6A7)),
  RatingRank(650,  '7級',   Color(0xFFC5E1A5)),
  RatingRank(600,  '8級',   Color(0xFFCFD8DC)),
  RatingRank(550,  '9級',   Color(0xFFB0BEC5)),
  RatingRank(500,  '10級',  Color(0xFF90A4AE)),
  RatingRank(450,  '11級',  Color(0xFF78909C)),
  RatingRank(400,  '12級',  Color(0xFF607D8B)),
  RatingRank(350,  '13級',  Color(0xFF546E7A)),
  RatingRank(200,  '14級',  Color(0xFF455A64)),
  RatingRank(0,    '15級',  Color(0xFF37474F)),
];

/// 段位の「格」を数値で返す（高いほど上位）
int rankOrder(String rank) {
  final idx = rankTable.indexWhere((r) => r.rank == rank);
  return idx >= 0 ? rankTable.length - idx : 0;
}

/// 次の段位と必要ELO差を返す（null=最高位）
(String, int)? nextRankInfo(int rating) {
  for (int i = rankTable.length - 1; i >= 0; i--) {
    if (rating < rankTable[i].minRating) {
      // rankTable[i] が次の段位
      final prev = i + 1 < rankTable.length ? rankTable[i + 1].minRating : 0;
      final needed = rankTable[i].minRating - rating;
      final range = rankTable[i].minRating - prev;
      return (rankTable[i].rank, needed);
    }
  }
  return null; // 九段
}

/// 現在段位の進捗 0.0〜1.0
double rankProgress(int rating) {
  for (int i = rankTable.length - 1; i >= 0; i--) {
    if (rating >= rankTable[i].minRating) {
      // 現在はこのランク
      if (i == 0) return 1.0; // 最高位
      final next = rankTable[i - 1].minRating;
      final curr = rankTable[i].minRating;
      return ((rating - curr) / (next - curr)).clamp(0.0, 1.0);
    }
  }
  return 0.0;
}

String ratingToRank(int r) {
  for (final e in rankTable) if (r >= e.minRating) return e.rank;
  return '15級';
}

Color ratingToColor(int r) {
  for (final e in rankTable) if (r >= e.minRating) return e.color;
  return const Color(0xFF37474F);
}

/// 段/級 どちらか
bool isKyuu(String rank) => rank.contains('級');
bool isDan(String rank) => rank.contains('段') || rank.contains('初段');

// ── 対局モード ─────────────────────────────────────────────
enum _GameModeFilter { all, ai, pvp, net }

extension _GameModeFilterExt on _GameModeFilter {
  String get label => const {'all': '全体', 'ai': 'AI対局', 'pvp': 'ローカル対局', 'net': 'ネット対局'}[name]!;
  String get key   => name; // 'all', 'ai', 'pvp', 'net'
}

// ── 履歴レコード ─────────────────────────────────────────
class _RatingRecord {
  final String date;
  final int rating;
  final int delta;
  final int aiLevel;
  final String mode; // 'vsAI', 'pvp', 'network', etc.

  _RatingRecord({required this.date, required this.rating, required this.delta, required this.aiLevel, this.mode = ''});

  factory _RatingRecord.fromJson(Map<String, dynamic> j) => _RatingRecord(
    date:    j['date']    as String? ?? '',
    rating:  j['rating']  as int? ?? 1000,
    delta:   j['delta']   as int? ?? 0,
    aiLevel: j['aiLevel'] as int? ?? 0,
    mode:    j['mode']    as String? ?? 'vsAI',
  );
}

// ── メイン画面 ────────────────────────────────────────────
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  // 対局統計（全体）
  int _total   = 0;
  int _p1Wins  = 0;
  int _p2Wins  = 0;
  int _movesSum = 0;

  // 対局種別統計
  final Map<String, int> _modeTotal   = {};
  final Map<String, int> _modeP1Wins  = {};
  final Map<String, int> _modeP2Wins  = {};

  // レーティング（全体・AI別・ネット別）
  int _rating    = 700;
  int _ratingAi  = 700;
  int _ratingNet = 700;
  List<_RatingRecord> _ratingHistory = [];

  bool _loading = true;
  _GameModeFilter _modeFilter = _GameModeFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('rating_history') ?? '[]';
    List<dynamic> hist;
    try { hist = jsonDecode(raw) as List; } catch (_) { hist = []; }

    // kifu_records から wins/losses を再計算（未完了・不明を除外）
    int p1WinsFromKifu = 0;
    int p2WinsFromKifu = 0;
    bool hasKifuData = false;
    try {
      final kifuRaw = prefs.getString('kifu_records') ?? '[]';
      final kifuList = (jsonDecode(kifuRaw) as List)
          .whereType<Map<String, dynamic>>()
          .toList();
      for (final r in kifuList) {
        final result = r['result'] as String? ?? '';
        if (result.isEmpty || result == '不明' || result.contains('未完') ||
            result == 'インポート') {
          continue;
        }
        // 結果文字列は必ず勝者側から「{勝者}の勝ち」の形式で始まる。
        // contains() だと投了・持将棋など敗者側の呼称も括弧内に含む文言で
        // 誤って両方にカウントされるため、startsWith() で判定する。
        if (result.startsWith('先手の勝ち')) p1WinsFromKifu++;
        if (result.startsWith('後手の勝ち')) p2WinsFromKifu++;
        hasKifuData = true;
      }
    } catch (_) {}

    setState(() {
      _total    = prefs.getInt('stats_total') ?? 0;
      _p1Wins   = hasKifuData ? p1WinsFromKifu : (prefs.getInt('stats_p1_wins') ?? 0);
      _p2Wins   = hasKifuData ? p2WinsFromKifu : (prefs.getInt('stats_p2_wins') ?? 0);
      _movesSum = prefs.getInt('stats_moves_sum') ?? 0;
      _ratingAi  = prefs.getInt('rating_ai_current') ?? 700;
      _ratingNet = prefs.getInt('rating_net_current') ?? 700;
      _rating    = max(_ratingAi, _ratingNet);
      for (final mk in ['ai', 'pvp', 'net']) {
        _modeTotal[mk]  = prefs.getInt('stats_total_$mk') ?? 0;
        _modeP1Wins[mk] = prefs.getInt('stats_p1_wins_$mk') ?? 0;
        _modeP2Wins[mk] = prefs.getInt('stats_p2_wins_$mk') ?? 0;
      }
      _ratingHistory = hist.map((e) => _RatingRecord.fromJson(e as Map<String, dynamic>)).toList();
      _loading  = false;
    });
  }

  Future<void> _resetStats() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('統計をリセット', style: TextStyle(color: Colors.white)),
        content: const Text('すべての統計・レーティングデータを削除しますか？',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('リセット', style: TextStyle(color: Colors.red.shade400))),
        ],
      ),
    );
    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      for (final k in ['stats_total','stats_p1_wins','stats_p2_wins','stats_moves_sum',
                        'rating_current','rating_history',
                        'stats_total_ai','stats_p1_wins_ai','stats_p2_wins_ai',
                        'stats_total_pvp','stats_p1_wins_pvp','stats_p2_wins_pvp',
                        'stats_total_net','stats_p1_wins_net','stats_p2_wins_net']) {
        await prefs.remove(k);
      }
      await _load();
    }
  }

  // アクティブフィルタに応じた統計値
  int get _dispTotal  => _modeFilter == _GameModeFilter.all ? _total  : _modeTotal[_modeFilter.key] ?? 0;
  int get _dispP1Wins => _modeFilter == _GameModeFilter.all ? _p1Wins : _modeP1Wins[_modeFilter.key] ?? 0;
  int get _dispP2Wins => _modeFilter == _GameModeFilter.all ? _p2Wins : _modeP2Wins[_modeFilter.key] ?? 0;
  int get _draws => max(0, _dispTotal - _dispP1Wins - _dispP2Wins);
  double get _avgMoves => _total > 0 ? _movesSum / _total : 0;

  List<_RatingRecord> get _filteredHistory {
    if (_modeFilter == _GameModeFilter.all) return _ratingHistory;
    final modeVal = _modeFilter == _GameModeFilter.ai  ? 'vsAI'
                  : _modeFilter == _GameModeFilter.net ? 'network'
                  : 'pvp';
    return _ratingHistory.where((r) => r.mode == modeVal).toList();
  }

  @override
  Widget build(BuildContext context) {
    final hist = _filteredHistory;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('統計・段級位', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 対局モード切替タブ ──
                  _ModeTabs(
                    selected: _modeFilter,
                    onChanged: (f) => setState(() => _modeFilter = f),
                  ),
                  const SizedBox(height: 16),

                  // ── 段級位カード（全体・AI・ネット対局で表示） ──
                  if (_modeFilter == _GameModeFilter.all || _modeFilter == _GameModeFilter.ai || _modeFilter == _GameModeFilter.net) ...[
                    // モード別レーティングを表示（AI対局↔ネット対局が混在しない）
                    _RatingCard(
                      rating: _modeFilter == _GameModeFilter.ai  ? _ratingAi
                            : _modeFilter == _GameModeFilter.net ? _ratingNet
                            : _rating,
                      history: hist,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── 成長グラフ ──
                  if (hist.isNotEmpty)
                    _StatCard(title: 'レーティング推移',
                        child: _RatingGraph(history: hist)),
                  if (hist.isNotEmpty) const SizedBox(height: 16),

                  // ── 対局統計 ──
                  _StatCard(title: '対局数',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _BigNumber('$_dispTotal', '総対局', Colors.white),
                        _BigNumber('$_dispP1Wins', '先手勝', Colors.blue.shade400),
                        _BigNumber('$_dispP2Wins', '後手勝', Colors.red.shade400),
                        _BigNumber('$_draws',  '引分/未了', Colors.grey),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 勝率バー ──
                  if (_dispTotal > 0)
                    _StatCard(
                      title: '勝率',
                      child: Column(children: [
                        _WinRateBar('先手', _dispTotal > 0 ? _dispP1Wins / _dispTotal : 0, Colors.blue.shade400),
                        const SizedBox(height: 10),
                        _WinRateBar('後手', _dispTotal > 0 ? _dispP2Wins / _dispTotal : 0, Colors.red.shade400),
                      ]),
                    ),
                  if (_dispTotal > 0) const SizedBox(height: 16),


                  // ── 勝率ドーナツ ──
                  if (_dispTotal > 0)
                    _StatCard(
                      title: '勝率グラフ',
                      child: _WinRatePie(wins: _dispP1Wins, losses: _dispP2Wins, draws: _draws),
                    ),
                  if (_dispTotal > 0) const SizedBox(height: 16),

                  // ── 連勝カード ──
                  if (hist.isNotEmpty)
                    _StatCard(
                      title: '連勝・連敗',
                      child: _StreakCard(history: hist),
                    ),
                  if (hist.isNotEmpty) const SizedBox(height: 16),

                  // ── 週次成長比較 ──
                  if (hist.isNotEmpty)
                    _StatCard(
                      title: '週次成長',
                      child: _WeeklyGrowthCard(history: hist),
                    ),
                  if (hist.isNotEmpty) const SizedBox(height: 16),

                  // ── 弱点分析 ──
                  if (hist.length >= 3)
                    _StatCard(
                      title: '弱点分析',
                      child: _WeaknessCard(history: hist),
                    ),
                  if (hist.length >= 3) const SizedBox(height: 16),

                  // ── AIレベル別内訳（AI対局時のみ） ──
                  if (hist.isNotEmpty && (_modeFilter == _GameModeFilter.all || _modeFilter == _GameModeFilter.ai))
                    _StatCard(
                      title: 'AIレベル別成績',
                      child: _AiBreakdown(history: hist),
                    ),
                  if (hist.isNotEmpty && (_modeFilter == _GameModeFilter.all || _modeFilter == _GameModeFilter.ai))
                    const SizedBox(height: 16),

                  // ── 段級位表 ──
                  _RankTable(currentRating: _rating),
                  const SizedBox(height: 24),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

// ── 対局モードタブ ──────────────────────────────────────────
class _ModeTabs extends StatelessWidget {
  final _GameModeFilter selected;
  final ValueChanged<_GameModeFilter> onChanged;
  const _ModeTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _GameModeFilter.values.map((f) {
          final isSelected = f == selected;
          return GestureDetector(
            onTap: () => onChanged(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.amber.withAlpha(200) : AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.amber : Colors.white24,
                  width: 1,
                ),
              ),
              child: Text(
                f.label,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── レーティングカード ──────────────────────────────────
class _RatingCard extends StatelessWidget {
  final int rating;
  final List<_RatingRecord> history;
  const _RatingCard({required this.rating, required this.history});

  @override
  Widget build(BuildContext context) {
    final rank  = ratingToRank(rating);
    final color = ratingToColor(rating);

    // 最新デルタ
    final lastDelta = history.isNotEmpty ? history.last.delta : 0;
    final trendIcon = lastDelta > 0 ? '▲' : lastDelta < 0 ? '▼' : '─';
    final trendColor = lastDelta > 0 ? Colors.greenAccent : lastDelta < 0 ? Colors.redAccent : Colors.white38;

    // 連勝数
    int streak = 0;
    for (int i = history.length - 1; i >= 0; i--) {
      if (history[i].delta > 0) streak++;
      else break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.surface, color.withAlpha(30)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(80), width: 1.5),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('段級位', style: TextStyle(color: color.withAlpha(180), fontSize: 12)),
            Text(rank, style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('レーティング', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            Row(children: [
              Text('$rating', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              Text('$trendIcon${lastDelta.abs()}',
                  style: TextStyle(color: trendColor, fontSize: 13, fontWeight: FontWeight.bold)),
            ]),
          ]),
        ]),
        if (streak >= 2) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade300.withAlpha(100)),
            ),
            child: Text('🔥 $streak連勝中！',
                style: TextStyle(color: Colors.orange.shade300, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
        const SizedBox(height: 12),
        // 段位進捗バー
        RankProgressBar(rating: rating),
      ]),
    );
  }
}

// ── 成長グラフ（対局軸 / 時間軸 トグル）──────────────────────
class _RatingGraph extends StatefulWidget {
  final List<_RatingRecord> history;
  const _RatingGraph({required this.history});

  @override
  State<_RatingGraph> createState() => _RatingGraphState();
}

class _RatingGraphState extends State<_RatingGraph> {
  bool _byTime = false;

  @override
  Widget build(BuildContext context) {
    final recent = widget.history.length > 50
        ? widget.history.sublist(widget.history.length - 50)
        : widget.history;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _axisChip('対局軸', !_byTime, () => setState(() => _byTime = false)),
            const SizedBox(width: 6),
            _axisChip('時間軸', _byTime, () => setState(() => _byTime = true)),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 130,
          child: ClipRect(
            child: CustomPaint(
              size: const Size(double.infinity, 130),
              painter: _byTime
                  ? _TimeAxisGraphPainter(records: recent)
                  : _GraphPainter(records: recent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _axisChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.amber.shade700 : Colors.white12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white54,
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  final List<_RatingRecord> records;
  _GraphPainter({required this.records});

  @override
  void paint(Canvas canvas, Size size) {
    if (records.isEmpty) return;

    canvas.clipRect(Offset.zero & size);

    final minR = records.map((e) => e.rating).reduce(min) - 30;
    final maxR = records.map((e) => e.rating).reduce(max) + 30;
    final range = (maxR - minR).clamp(1, 99999);

    double xOf(int i) => records.length == 1
        ? size.width / 2
        : size.width * i / (records.length - 1);
    double yOf(int r) => size.height - (r - minR) / range * size.height * 0.85 - size.height * 0.05;

    // グリッド（中央横線）
    final gridPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, yOf(1000)), Offset(size.width, yOf(1000)), gridPaint);

    // 段級位境界線（1000, 1200, 1400, 1600）
    const boundaryLines = [
      (1000, '3級'),
      (1200, '初段'),
      (1400, '二段'),
      (1600, '三段'),
    ];
    final boundaryPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    for (final entry in boundaryLines) {
      final rating = entry.$1;
      final label = entry.$2;
      if (rating >= minR && rating <= maxR) {
        final y = yOf(rating);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), boundaryPaint);
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(size.width - tp.width - 2, y - tp.height - 1));
      }
    }

    // 折れ線
    final linePaint = Paint()
      ..color = Colors.amber.withAlpha(220)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (int i = 0; i < records.length; i++) {
      final x = xOf(i);
      final y = yOf(records[i].rating);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, linePaint);

    // 塗りつぶし
    final fillPath = Path.from(path)
      ..lineTo(xOf(records.length - 1), size.height)
      ..lineTo(xOf(0), size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()..shader = LinearGradient(
        colors: [Colors.amber.withAlpha(80), Colors.amber.withAlpha(0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // 各ドットを勝ち/負けで色分け
    for (int i = 0; i < records.length; i++) {
      final rec = records[i];
      final dotColor = rec.delta > 0
          ? Colors.green
          : rec.delta < 0
              ? Colors.red
              : Colors.white54;
      canvas.drawCircle(
        Offset(xOf(i), yOf(rec.rating)),
        i == records.length - 1 ? 5 : 3,
        Paint()..color = dotColor,
      );
    }

    // 最新値ラベル
    final last = records.last;
    final dotColor = ratingToColor(last.rating);
    final tp = TextPainter(
      text: TextSpan(text: '${last.rating}', style: TextStyle(color: dotColor, fontSize: 11, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    final lx = (xOf(records.length - 1) - tp.width / 2).clamp(0.0, size.width - tp.width);
    tp.paint(canvas, Offset(lx, yOf(last.rating) - 16));
  }

  @override
  bool shouldRepaint(_GraphPainter old) => old.records != records;
}

// ── 時間軸グラフ ──────────────────────────────────────────
class _TimeAxisGraphPainter extends CustomPainter {
  final List<_RatingRecord> records;
  _TimeAxisGraphPainter({required this.records});

  @override
  void paint(Canvas canvas, Size size) {
    if (records.isEmpty) return;
    canvas.clipRect(Offset.zero & size);

    // 日付を DateTime に変換
    final dates = records.map((r) {
      try { return DateTime.parse(r.date); }
      catch (_) { return DateTime.now(); }
    }).toList();

    final minMs = dates.first.millisecondsSinceEpoch.toDouble();
    final maxMs = dates.last.millisecondsSinceEpoch.toDouble();
    final timeRange = (maxMs - minMs).clamp(1.0, double.infinity);

    final minR = records.map((e) => e.rating).reduce(min) - 30;
    final maxR = records.map((e) => e.rating).reduce(max) + 30;
    final rRange = (maxR - minR).clamp(1, 99999);

    double xOf(int i) => timeRange == 0
        ? size.width / 2
        : size.width * (dates[i].millisecondsSinceEpoch - minMs) / timeRange;
    double yOf(int r) => size.height - (r - minR) / rRange * size.height * 0.82 - size.height * 0.05;

    // グリッド
    final gridPaint = Paint()..color = Colors.white12..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, yOf(1000)), Offset(size.width, yOf(1000)), gridPaint);

    // 段級位境界線
    const boundaryLines = [(1000, '3級'), (1150, '初段'), (1300, '二段')];
    final bPaint = Paint()..color = Colors.white24..strokeWidth = 0.5..style = PaintingStyle.stroke;
    for (final entry in boundaryLines) {
      final r = entry.$1;
      if (r >= minR && r <= maxR) {
        final y = yOf(r);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), bPaint);
        final tp = TextPainter(
          text: TextSpan(text: entry.$2, style: const TextStyle(color: Colors.white38, fontSize: 9)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(size.width - tp.width - 2, y - tp.height - 1));
      }
    }

    // 折れ線
    final linePaint = Paint()
      ..color = AppTheme.accent.withAlpha(200)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (int i = 0; i < records.length; i++) {
      final x = xOf(i);
      final y = yOf(records[i].rating);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, linePaint);

    // グラデーション塗りつぶし
    final fillPath = Path.from(path)
      ..lineTo(xOf(records.length - 1), size.height)
      ..lineTo(xOf(0), size.height)
      ..close();
    canvas.drawPath(fillPath, Paint()
      ..shader = LinearGradient(
        colors: [AppTheme.accent.withAlpha(60), AppTheme.accent.withAlpha(0)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    // ドット（勝ち/負け色分け）
    for (int i = 0; i < records.length; i++) {
      final rec = records[i];
      final dotColor = rec.delta > 0 ? Colors.green : rec.delta < 0 ? Colors.red : Colors.white54;
      canvas.drawCircle(Offset(xOf(i), yOf(rec.rating)),
          i == records.length - 1 ? 5 : 3, Paint()..color = dotColor);
    }

    // 最新値ラベル
    final last = records.last;
    final tp = TextPainter(
      text: TextSpan(
        text: '${last.rating}',
        style: TextStyle(color: ratingToColor(last.rating), fontSize: 11, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final lx = (xOf(records.length - 1) - tp.width / 2).clamp(0.0, size.width - tp.width);
    tp.paint(canvas, Offset(lx, yOf(last.rating) - 16));

    // 日付ラベル（最初・最後）
    if (records.length > 1) {
      _drawDateLabel(canvas, size, dates.first.toString().substring(0, 10), 0, 0);
      _drawDateLabel(canvas, size, dates.last.toString().substring(0, 10), size.width, 1);
    }
  }

  void _drawDateLabel(Canvas canvas, Size size, String label, double x, int align) {
    final tp = TextPainter(
      text: TextSpan(text: label, style: const TextStyle(color: Colors.white38, fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = align == 0 ? x : x - tp.width;
    tp.paint(canvas, Offset(dx.clamp(0, size.width - tp.width), size.height - tp.height));
  }

  @override
  bool shouldRepaint(_TimeAxisGraphPainter old) => old.records != records;
}

// ── 勝率ドーナツグラフ ─────────────────────────────────────
class _WinRatePie extends StatelessWidget {
  final int wins, losses, draws;
  const _WinRatePie({required this.wins, required this.losses, required this.draws});

  @override
  Widget build(BuildContext context) {
    final total = wins + losses + draws;
    final winPct = total > 0 ? (wins / total * 100).toStringAsFixed(1) : '0.0';
    return Column(children: [
      Center(
        child: SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            size: const Size(120, 120),
            painter: _PiePainter(wins: wins, losses: losses, draws: draws),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('$winPct%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    )),
                const Text('勝率', style: TextStyle(color: Colors.white54, fontSize: 11)),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _PieLegend(color: Colors.green, label: '勝ち $wins'),
        const SizedBox(width: 16),
        _PieLegend(color: Colors.red, label: '負け $losses'),
        const SizedBox(width: 16),
        _PieLegend(color: Colors.grey, label: '引分 $draws'),
      ]),
    ]);
  }
}

class _PieLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _PieLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
  ]);
}

class _PiePainter extends CustomPainter {
  final int wins, losses, draws;
  const _PiePainter({required this.wins, required this.losses, required this.draws});

  @override
  void paint(Canvas canvas, Size size) {
    final total = wins + losses + draws;
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 * 0.9;
    final innerRadius = outerRadius * 0.55;

    final fractions = [
      wins / total,
      losses / total,
      draws / total,
    ];
    const colors = [Colors.green, Colors.red, Colors.grey];

    double startAngle = -pi / 2;
    for (int i = 0; i < fractions.length; i++) {
      final fraction = fractions[i];
      if (fraction <= 0) continue;
      final sweep = fraction * 2 * pi;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerRadius - innerRadius;
      canvas.drawArc(
        Rect.fromCircle(
          center: center,
          radius: (outerRadius + innerRadius) / 2,
        ),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }

    // 境界線（薄い区切り）
    final divPaint = Paint()
      ..color = AppTheme.bg
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    double angle = -pi / 2;
    for (final fraction in fractions) {
      if (fraction > 0) {
        canvas.drawLine(
          Offset(center.dx + innerRadius * cos(angle), center.dy + innerRadius * sin(angle)),
          Offset(center.dx + outerRadius * cos(angle), center.dy + outerRadius * sin(angle)),
          divPaint,
        );
        angle += fraction * 2 * pi;
      }
    }
  }

  @override
  bool shouldRepaint(_PiePainter old) =>
      old.wins != wins || old.losses != losses || old.draws != draws;
}

// ── 連勝カード ────────────────────────────────────────────
class _StreakCard extends StatelessWidget {
  final List<_RatingRecord> history;
  const _StreakCard({required this.history});

  @override
  Widget build(BuildContext context) {
    // 現在の連勝/連敗
    int currentStreak = 0;
    bool? isWinStreak;
    for (int i = history.length - 1; i >= 0; i--) {
      final d = history[i].delta;
      if (d == 0) break;
      final isWin = d > 0;
      if (isWinStreak == null) {
        isWinStreak = isWin;
        currentStreak = 1;
      } else if (isWin == isWinStreak) {
        currentStreak++;
      } else {
        break;
      }
    }

    // 最高連勝記録
    int maxWinStreak = 0, tempStreak = 0;
    for (final rec in history) {
      if (rec.delta > 0) {
        tempStreak++;
        if (tempStreak > maxWinStreak) maxWinStreak = tempStreak;
      } else {
        tempStreak = 0;
      }
    }

    final streakColor = isWinStreak == true ? Colors.green : isWinStreak == false ? Colors.red : Colors.white54;
    final streakLabel = isWinStreak == true
        ? '$currentStreak連勝中 🔥'
        : isWinStreak == false
            ? '$currentStreak連敗中'
            : '記録なし';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(children: [
          Text(streakLabel, style: TextStyle(color: streakColor, fontSize: 16, fontWeight: FontWeight.bold)),
          const Text('現在の連勝/連敗', style: TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
        Container(width: 1, height: 40, color: Colors.white12),
        Column(children: [
          Text('$maxWinStreak連勝', style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
          const Text('最高連勝記録', style: TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
      ],
    );
  }
}

// ── AIレベル別内訳 ────────────────────────────────────────
class _AiBreakdown extends StatelessWidget {
  final List<_RatingRecord> history;
  const _AiBreakdown({required this.history});

  @override
  Widget build(BuildContext context) {
    // AIレベル別に集計
    final Map<int, (int, int)> stats = {}; // level -> (wins, losses)
    for (final rec in history) {
      final lv = rec.aiLevel;
      final (w, l) = stats[lv] ?? (0, 0);
      if (rec.delta > 0) {
        stats[lv] = (w + 1, l);
      } else if (rec.delta < 0) {
        stats[lv] = (w, l + 1);
      }
    }
    if (stats.isEmpty) {
      return const Text('対局データなし', style: TextStyle(color: Colors.white38, fontSize: 13));
    }
    final levels = stats.keys.toList()..sort();
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(2),
      },
      children: [
        const TableRow(children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('AIレベル', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          Text('勝ち', style: TextStyle(color: Colors.green, fontSize: 12)),
          Text('負け', style: TextStyle(color: Colors.red, fontSize: 12)),
          Text('勝率', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
        ...levels.map((lv) {
          final (w, l) = stats[lv]!;
          final total = w + l;
          final pct = total > 0 ? '${(w / total * 100).toStringAsFixed(0)}%' : '-';
          return TableRow(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text('Lv.$lv', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ),
            Text('$w', style: const TextStyle(color: Colors.green, fontSize: 13)),
            Text('$l', style: const TextStyle(color: Colors.red, fontSize: 13)),
            Text(pct, style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
          ]);
        }),
      ],
    );
  }
}

// ── 段級位表 ──────────────────────────────────────────────
class _RankTable extends StatelessWidget {
  final int currentRating;
  const _RankTable({required this.currentRating});

  @override
  Widget build(BuildContext context) {
    return _StatCard(
      title: '段級位表',
      child: Column(
        children: rankTable.take(8).map((e) {
          final isCurrent = currentRating >= e.minRating &&
              (rankTable.indexOf(e) == 0 || currentRating < rankTable[rankTable.indexOf(e) - 1].minRating);
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isCurrent ? e.color.withAlpha(30) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: isCurrent ? Border.all(color: e.color.withAlpha(120), width: 1) : null,
            ),
            child: Row(children: [
              if (isCurrent) ...[
                Icon(Icons.arrow_right, color: e.color, size: 16),
                const SizedBox(width: 4),
              ] else const SizedBox(width: 20),
              Expanded(child: Text(e.rank, style: TextStyle(
                  color: isCurrent ? e.color : Colors.white38, fontSize: 13,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal))),
              Text('${e.minRating}+', style: TextStyle(
                  color: isCurrent ? e.color.withAlpha(200) : Colors.white24, fontSize: 12)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ── 共通ウィジェット ──────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _StatCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _BigNumber extends StatelessWidget {
  final String value, label;
  final Color color;
  const _BigNumber(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
  ]);
}

class _WinRateBar extends StatelessWidget {
  final String label;
  final double rate;
  final Color color;
  const _WinRateBar(this.label, this.rate, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text('${(rate * 100).toStringAsFixed(1)}%',
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: rate.clamp(0.0, 1.0),
          backgroundColor: Colors.white12,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
        ),
      ),
    ]);
  }
}

// ── 週次成長カード ────────────────────────────────────────
class _WeeklyGrowthCard extends StatelessWidget {
  final List<_RatingRecord> history;
  const _WeeklyGrowthCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final twoWeekAgo = now.subtract(const Duration(days: 14));

    int thisWins = 0, thisTotal = 0;
    int prevWins = 0, prevTotal = 0;

    for (final rec in history) {
      DateTime? dt;
      try { dt = DateTime.parse(rec.date); } catch (_) {}
      if (dt == null) continue;

      if (dt.isAfter(weekAgo)) {
        thisTotal++;
        if (rec.delta > 0) thisWins++;
      } else if (dt.isAfter(twoWeekAgo)) {
        prevTotal++;
        if (rec.delta > 0) prevWins++;
      }
    }

    final thisRate = thisTotal > 0 ? thisWins / thisTotal : null;
    final prevRate = prevTotal > 0 ? prevWins / prevTotal : null;

    final diff = (thisRate != null && prevRate != null) ? thisRate - prevRate : null;
    final diffText = diff == null ? '-'
        : diff > 0 ? '▲${(diff * 100).toStringAsFixed(1)}%'
        : diff < 0 ? '▼${(diff.abs() * 100).toStringAsFixed(1)}%'
        : '±0%';
    final diffColor = diff == null ? Colors.white38
        : diff > 0 ? Colors.greenAccent
        : diff < 0 ? Colors.redAccent
        : Colors.white54;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _WeekBlock('今週', thisTotal, thisRate),
        Container(width: 1, height: 40, color: Colors.white12),
        _WeekBlock('先週', prevTotal, prevRate),
        Container(width: 1, height: 40, color: Colors.white12),
        Column(children: [
          Text(diffText, style: TextStyle(color: diffColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('成長', style: TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
      ],
    );
  }
}

class _WeekBlock extends StatelessWidget {
  final String label;
  final int total;
  final double? rate;
  const _WeekBlock(this.label, this.total, this.rate);

  @override
  Widget build(BuildContext context) {
    final pct = rate != null ? '${(rate! * 100).toStringAsFixed(0)}%' : '-';
    return Column(children: [
      Text(pct, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      Text('勝率 ($total局)', style: const TextStyle(color: Colors.white38, fontSize: 10)),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    ]);
  }
}

// ── 弱点分析カード ────────────────────────────────────────
class _WeaknessCard extends StatelessWidget {
  final List<_RatingRecord> history;
  const _WeaknessCard({required this.history});

  @override
  Widget build(BuildContext context) {
    // 最近20局を分析
    final recent = history.length > 20 ? history.sublist(history.length - 20) : history;
    final total = recent.length;
    if (total == 0) return const SizedBox.shrink();

    final wins = recent.where((r) => r.delta > 0).length;
    final losses = recent.where((r) => r.delta < 0).length;

    // 序盤弱い？（連敗が集中している場合）
    int loseStreak = 0, maxLoseStreak = 0, tmp = 0;
    for (final r in recent) {
      if (r.delta < 0) { tmp++; if (tmp > maxLoseStreak) maxLoseStreak = tmp; }
      else tmp = 0;
    }

    // 成績に基づくアドバイス
    final winRate = wins / total;
    final advices = <String>[];

    if (winRate < 0.3) {
      advices.add('💡 詰将棋で終盤力を鍛えましょう');
      advices.add('💡 1ランク下のAIで基礎を確認してみては？');
    } else if (winRate < 0.5) {
      advices.add('💡 もう一息！中盤の駒得を意識しましょう');
    } else if (winRate > 0.7) {
      advices.add('✨ 好調！難しいAIに挑戦してみましょう');
    } else {
      advices.add('✨ 安定した成績です。このまま継続！');
    }

    if (maxLoseStreak >= 3) {
      advices.add('📌 ${maxLoseStreak}連敗のパターンあり。休憩も大切です');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _MiniStat('${(winRate * 100).toStringAsFixed(0)}%', '直近勝率',
              winRate >= 0.5 ? Colors.greenAccent : Colors.orangeAccent),
          const SizedBox(width: 24),
          _MiniStat('$maxLoseStreak', '最長連敗', maxLoseStreak >= 3 ? Colors.redAccent : Colors.white54),
          const SizedBox(width: 24),
          _MiniStat('$total', '直近対局', Colors.white70),
        ]),
        const SizedBox(height: 12),
        ...advices.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(a, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
        )),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _MiniStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
  ]);
}
