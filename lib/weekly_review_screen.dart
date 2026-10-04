// lib/weekly_review_screen.dart — 週次AI対局振り返り（プレミアム機能）

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'purchase_service.dart';
import 'stats_screen.dart'; // ratingToRank, ratingToColor
import 'theme/app_theme.dart';

// ── データモデル ─────────────────────────────────────────────

class _RatingRecord {
  final String date;
  final int rating;
  final int delta;
  final int aiLevel;
  final String mode;

  _RatingRecord({
    required this.date,
    required this.rating,
    required this.delta,
    required this.aiLevel,
    this.mode = '',
  });

  factory _RatingRecord.fromJson(Map<String, dynamic> j) => _RatingRecord(
    date: j['date'] as String? ?? '',
    rating: j['rating'] as int? ?? 1000,
    delta: j['delta'] as int? ?? 0,
    aiLevel: j['aiLevel'] as int? ?? 0,
    mode: j['mode'] as String? ?? '',
  );
}

// ── 分析結果 ─────────────────────────────────────────────────

class _WeeklyStats {
  final int totalGames;
  final int wins;
  final int losses;
  final int startRating;
  final int endRating;
  final Map<int, int> winsByLevel;
  final Map<int, int> lossByLevel;
  final List<String> improvements;
  final List<String> strengths;
  final List<String> weaknesses;

  _WeeklyStats({
    required this.totalGames,
    required this.wins,
    required this.losses,
    required this.startRating,
    required this.endRating,
    required this.winsByLevel,
    required this.lossByLevel,
    required this.improvements,
    required this.strengths,
    required this.weaknesses,
  });

  double get winRate => totalGames == 0 ? 0.0 : wins / totalGames;
  int get ratingDelta => endRating - startRating;
}

// ── 分析ロジック ──────────────────────────────────────────────

_WeeklyStats _analyzeWeeklyData(List<_RatingRecord> allRecords) {
  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));

  // 直近7日間のみ
  final weekly = allRecords.where((r) {
    try {
      final dt = DateTime.parse(r.date.replaceFirst(' ', 'T'));
      return dt.isAfter(weekAgo);
    } catch (_) {
      return false;
    }
  }).toList();

  // 勝敗の判定: delta > 0 → 勝ち、delta < 0 → 負け、delta == 0 → 引き分け
  final wins = weekly.where((r) => r.delta > 0).length;
  final losses = weekly.where((r) => r.delta < 0).length;

  // レーティング
  final int startRating = weekly.isEmpty
      ? (allRecords.isEmpty ? 1000 : allRecords.first.rating)
      : weekly.first.rating - weekly.first.delta;
  final int endRating = weekly.isEmpty
      ? (allRecords.isEmpty ? 1000 : allRecords.last.rating)
      : weekly.last.rating;

  // AIレベル別集計
  final Map<int, int> winsByLevel = {};
  final Map<int, int> lossByLevel = {};
  for (final r in weekly) {
    if (r.delta > 0) {
      winsByLevel[r.aiLevel] = (winsByLevel[r.aiLevel] ?? 0) + 1;
    } else if (r.delta < 0) {
      lossByLevel[r.aiLevel] = (lossByLevel[r.aiLevel] ?? 0) + 1;
    }
  }

  // AIレベル別勝率
  final Map<int, double> winRateByLevel = {};
  for (int level = 0; level <= 3; level++) {
    final w = winsByLevel[level] ?? 0;
    final l = lossByLevel[level] ?? 0;
    final total = w + l;
    if (total > 0) winRateByLevel[level] = w / total;
  }

  // 連勝・連敗の検出
  int currentStreak = 0;
  String streakType = '';
  if (weekly.isNotEmpty) {
    final last = weekly.last;
    streakType = last.delta > 0 ? 'win' : (last.delta < 0 ? 'loss' : '');
    for (int i = weekly.length - 1; i >= 0; i--) {
      final r = weekly[i];
      final isWin = r.delta > 0;
      final isLoss = r.delta < 0;
      if (streakType == 'win' && isWin) {
        currentStreak++;
      } else if (streakType == 'loss' && isLoss) {
        currentStreak++;
      } else {
        break;
      }
    }
  }

  // 強み
  final strengths = <String>[];
  for (int level = 0; level <= 3; level++) {
    final wr = winRateByLevel[level];
    if (wr == null) continue;
    final levelName = _aiLevelName(level);
    if (level == 0 && wr >= 0.70) strengths.add('$levelName に強い（勝率${(wr * 100).round()}%）');
    if (level == 1 && wr >= 0.50) strengths.add('$levelName に強い（勝率${(wr * 100).round()}%）');
    if (level == 2 && wr >= 0.40) strengths.add('$levelName に強い（勝率${(wr * 100).round()}%）');
    if (level == 3 && wr >= 0.30) strengths.add('$levelName に強い（勝率${(wr * 100).round()}%）');
  }
  if (streakType == 'win' && currentStreak >= 3) {
    strengths.add('現在$currentStreak連勝中！');
  }

  // 弱点
  final weaknesses = <String>[];
  for (int level = 0; level <= 3; level++) {
    final wr = winRateByLevel[level];
    if (wr == null) continue;
    final levelName = _aiLevelName(level);
    if (level == 0 && wr < 0.70) weaknesses.add('$levelName への勝率が低い（${(wr * 100).round()}%）');
    if (level == 1 && wr < 0.50) weaknesses.add('$levelName への勝率が低い（${(wr * 100).round()}%）');
    if (level == 2 && wr < 0.40) weaknesses.add('$levelName への勝率が低い（${(wr * 100).round()}%）');
    if (level == 3 && wr < 0.30) weaknesses.add('$levelName への勝率が低い（${(wr * 100).round()}%）');
  }
  if (streakType == 'loss' && currentStreak >= 3) {
    weaknesses.add('現在$currentStreak連敗中');
  }

  // 改善案（ルールベース）
  final improvements = <String>[];
  if (weekly.isEmpty) {
    improvements.add('今週はまだ対局していません。まず1局指しましょう！');
  } else {
    for (int level = 0; level <= 3; level++) {
      final wr = winRateByLevel[level];
      if (wr == null) continue;
      if (level == 0 && wr < 0.70) {
        improvements.add('基本的な詰みを覚えましょう（ランダム戦で勝率アップ）');
      }
      if (level == 1 && wr < 0.50) {
        improvements.add('駒の交換を有利に進めましょう（易しいAIへの対策）');
      }
      if (level == 2 && wr < 0.40) {
        improvements.add('囲いを覚えると守りが安定します（中級AI対策）');
      }
      if (level == 3 && wr < 0.30) {
        improvements.add('序盤定跡を学ぶと有利に進められます（上級AI対策）');
      }
    }
    if (streakType == 'loss' && currentStreak >= 3) {
      improvements.add('連敗中です。一度定跡ガイドで復習しましょう');
    }
    if (streakType == 'win' && currentStreak >= 3) {
      improvements.add('連勝中！より強いAIに挑戦しましょう');
    }
    if (improvements.isEmpty) {
      improvements.add('この調子で対局を続けましょう！');
    }
  }

  return _WeeklyStats(
    totalGames: weekly.length,
    wins: wins,
    losses: losses,
    startRating: startRating,
    endRating: endRating,
    winsByLevel: winsByLevel,
    lossByLevel: lossByLevel,
    improvements: improvements,
    strengths: strengths,
    weaknesses: weaknesses,
  );
}

String _aiLevelName(int level) {
  switch (level) {
    case 0: return 'ランダム';
    case 1: return '易しいAI';
    case 2: return '中級AI';
    case 3: return '上級AI';
    default: return 'AI(Lv$level)';
  }
}

// ── メイン画面 ────────────────────────────────────────────────

class WeeklyReviewScreen extends StatefulWidget {
  const WeeklyReviewScreen({super.key});

  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
  static const _bgColor = AppTheme.bg;
  static const _cardColor = AppTheme.surface;

  bool _loading = true;
  bool _hasPlan500 = false;
  _WeeklyStats? _stats;
  int _currentRating = 1000;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _hasPlan500 = PurchaseService.hasPlan500;
      if (_hasPlan500) {
        await _loadStats();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('rating_history') ?? '[]';
      final list = (jsonDecode(raw) as List)
          .map((e) => _RatingRecord.fromJson(e as Map<String, dynamic>))
          .toList();

      _currentRating = list.isEmpty ? 1000 : list.last.rating;
      _stats = _analyzeWeeklyData(list);
    } catch (_) {
      _stats = _analyzeWeeklyData([]);
      _currentRating = 1000;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.analytics, color: Colors.amber, size: 22),
            SizedBox(width: 8),
            Text('週次振り返り'),
            SizedBox(width: 6),
            Icon(Icons.workspace_premium, color: Colors.amber, size: 18),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : !_hasPlan500
              ? _buildLockedView()
              : _buildContent(),
    );
  }

  // ── ロック画面 ──────────────────────────────────────────────

  Widget _buildLockedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, color: Colors.amber, size: 72),
            const SizedBox(height: 24),
            const Text(
              '週次AI振り返りは\nプレミアム機能です',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              '過去7日間の対局を分析し、\n強み・弱点・改善案を提示します。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.workspace_premium),
              label: const Text('プレミアムにアップグレード'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── メインコンテンツ ────────────────────────────────────────

  Widget _buildContent() {
    final stats = _stats!;
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _loading = true);
        await _loadStats();
        setState(() => _loading = false);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(stats),
          const SizedBox(height: 16),
          if (stats.strengths.isNotEmpty) ...[
            _buildSectionCard('強み', Icons.emoji_events, Colors.green.shade700, stats.strengths),
            const SizedBox(height: 12),
          ],
          if (stats.weaknesses.isNotEmpty) ...[
            _buildSectionCard('弱点', Icons.warning_amber_rounded, Colors.red.shade700, stats.weaknesses),
            const SizedBox(height: 12),
          ],
          _buildImprovementsCard(stats.improvements),
          const SizedBox(height: 12),
          _buildNextGoalCard(stats),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── 今週の戦績サマリーカード ────────────────────────────────

  Widget _buildSummaryCard(_WeeklyStats stats) {
    final delta = stats.ratingDelta;
    final deltaStr = delta >= 0 ? '+$delta' : '$delta';
    final deltaColor = delta >= 0 ? Colors.greenAccent : Colors.redAccent;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade800, Colors.amber.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.black87, size: 18),
              SizedBox(width: 8),
              Text('今週の戦績', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('対局数', '${stats.totalGames}', Colors.black87),
              _statItem('勝利', '${stats.wins}', Colors.black87),
              _statItem('敗北', '${stats.losses}', Colors.black87),
              _statItem(
                '勝率',
                stats.totalGames == 0 ? '--' : '${(stats.winRate * 100).round()}%',
                Colors.black87,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'レーティング: ${stats.endRating}  (${ratingToRank(stats.endRating)})',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  deltaStr,
                  style: TextStyle(color: deltaColor, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 12)),
      ],
    );
  }

  // ── 強み・弱点カード ────────────────────────────────────────

  Widget _buildSectionCard(String title, IconData icon, Color accentColor, List<String> items) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withOpacity(0.4), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.circle, color: accentColor, size: 8),
                const SizedBox(width: 8),
                Expanded(child: Text(item, style: const TextStyle(color: Colors.white70, fontSize: 14))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ── 改善案リスト ────────────────────────────────────────────

  Widget _buildImprovementsCard(List<String> improvements) {
    const icons = [
      Icons.lightbulb_outline,
      Icons.school,
      Icons.fitness_center,
      Icons.trending_up,
      Icons.auto_awesome,
    ];

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tips_and_updates, color: Colors.blueAccent, size: 20),
              SizedBox(width: 8),
              Text('改善案', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          ...improvements.asMap().entries.map((entry) {
            final idx = entry.key;
            final text = entry.value;
            final iconData = icons[idx % icons.length];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(iconData, color: Colors.blueAccent, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── 次週目標カード ──────────────────────────────────────────

  Widget _buildNextGoalCard(_WeeklyStats stats) {
    final target = _currentRating + 20;
    final targetRank = ratingToRank(target);
    final targetColor = ratingToColor(target);

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.3), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flag, color: Colors.purpleAccent, size: 20),
              SizedBox(width: 8),
              Text('次週の目標', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.arrow_upward, color: Colors.greenAccent, size: 18),
              const SizedBox(width: 6),
              Text(
                '目標レーティング: $target',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text('(+20)', style: const TextStyle(color: Colors.greenAccent, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
              const SizedBox(width: 6),
              Text(
                '目標段位: $targetRank',
                style: TextStyle(color: targetColor, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
