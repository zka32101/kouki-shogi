import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'services/kifu_analytics_service.dart';
import 'models/game_analysis.dart';

enum WeaknessLevel {
  great,
  good,
  needsWork,
  weak,
}

extension WeaknessLevelExt on WeaknessLevel {
  String get label {
    switch (this) {
      case WeaknessLevel.great:
        return '得意';
      case WeaknessLevel.good:
        return '良好';
      case WeaknessLevel.needsWork:
        return '要改善';
      case WeaknessLevel.weak:
        return '弱点';
    }
  }

  Color get color {
    switch (this) {
      case WeaknessLevel.great:
        return const Color(0xFF4CAF50);
      case WeaknessLevel.good:
        return const Color(0xFF2196F3);
      case WeaknessLevel.needsWork:
        return const Color(0xFFFF9800);
      case WeaknessLevel.weak:
        return const Color(0xFFF44336);
    }
  }

  IconData get icon {
    switch (this) {
      case WeaknessLevel.great:
        return Icons.star;
      case WeaknessLevel.good:
        return Icons.thumb_up;
      case WeaknessLevel.needsWork:
        return Icons.trending_up;
      case WeaknessLevel.weak:
        return Icons.warning_amber;
    }
  }

  static WeaknessLevel fromScore(double score) {
    if (score > 80) return WeaknessLevel.great;
    if (score > 60) return WeaknessLevel.good;
    if (score > 40) return WeaknessLevel.needsWork;
    return WeaknessLevel.weak;
  }
}

class SkillDimension {
  final String name;
  final String nameEn;
  final double score;
  final WeaknessLevel level;
  final String advice;
  final String practiceLabel;
  final VoidCallback? onPractice;

  const SkillDimension({
    required this.name,
    required this.nameEn,
    required this.score,
    required this.level,
    required this.advice,
    required this.practiceLabel,
    this.onPractice,
  });
}

class WeaknessAnalysisScreen extends StatefulWidget {
  final VoidCallback? onGoToTsume;
  final VoidCallback? onGoToTesuji;
  final VoidCallback? onGoToJoseki;
  final VoidCallback? onGoToAiGame;
  final VoidCallback? onGoToKifu;

  const WeaknessAnalysisScreen({
    Key? key,
    this.onGoToTsume,
    this.onGoToTesuji,
    this.onGoToJoseki,
    this.onGoToAiGame,
    this.onGoToKifu,
  }) : super(key: key);

  @override
  State<WeaknessAnalysisScreen> createState() => _WeaknessAnalysisScreenState();
}

class _WeaknessAnalysisScreenState extends State<WeaknessAnalysisScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;

  int _totalGames = 0;
  int _totalWins = 0;
  int _tsumeClearedCount = 0;
  int _tesujiClearedCount = 0;
  double _josekiAvgScore = 0.0;
  int _rating = 1000;
  int _totalAiGames = 0;
  int _aiWins = 0;
  int _p2Wins = 0;

  List<SkillDimension> _dimensions = [];
  List<SkillDimension> _weakTop3 = [];
  List<BlunderPattern> _topBlunderPatterns = [];

  late AnimationController _radarAnimController;
  late Animation<double> _radarAnim;
  late AnimationController _barsAnimController;
  late Animation<double> _barsAnim;

  @override
  void initState() {
    super.initState();
    _radarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _radarAnim = CurvedAnimation(
      parent: _radarAnimController,
      curve: Curves.easeOut,
    );
    _barsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _barsAnim = CurvedAnimation(
      parent: _barsAnimController,
      curve: Curves.easeOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _radarAnimController.dispose();
    _barsAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // 実際に game_screen.dart が書き込んでいるキーに合わせる
    // （total_games/total_wins/total_ai_games/ai_wins は存在しないキーで
    //  常に0になっていたバグ）。_totalGames/_totalWins は全モード通算、
    // _totalAiGames/_aiWins はAI対局のみの内訳。
    _totalGames = prefs.getInt('stats_total') ?? 0;
    _totalWins = prefs.getInt('stats_total_wins') ?? 0;
    _rating = prefs.getInt('rating_current') ?? 1000;
    _totalAiGames = prefs.getInt('stats_total_ai') ?? 0;
    _aiWins = prefs.getInt('stats_p1_wins_ai') ?? 0;
    _p2Wins = prefs.getInt('stats_p2_wins') ?? 0;

    final allKeys = prefs.getKeys();
    int tsume = 0;
    int tesuji = 0;
    List<int> josekiScores = [];

    for (final key in allKeys) {
      if (key.startsWith('tsume_clear_')) {
        if (prefs.getBool(key) == true) tsume++;
      } else if (key.startsWith('tesuji_cleared_')) {
        if (prefs.getBool(key) == true) tesuji++;
      } else if (key.startsWith('joseki_drill_')) {
        final score = prefs.getInt(key);
        if (score != null && score > 0) josekiScores.add(score);
      }
    }

    _tsumeClearedCount = tsume;
    _tesujiClearedCount = tesuji;
    _josekiAvgScore = josekiScores.isEmpty
        ? 0.0
        : josekiScores.reduce((a, b) => a + b) / josekiScores.length;

    _computeDimensions();

    // 実際の対局分析（KifuAnalyticsService）から繰り返す悪手パターンを取得。
    // 集計カウンタベースの7軸スコアだけでなく、具体的にどこでミスしているか
    // という実データに基づく気づきを提示する。
    try {
      _topBlunderPatterns =
          await KifuAnalyticsService().getRepeatedBlunders(topN: 3);
    } catch (_) {
      _topBlunderPatterns = [];
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    _barsAnimController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _radarAnimController.forward();
  }

  double _clamp100(double v) => v.clamp(0.0, 100.0);

  void _computeDimensions() {
    final endgameScore = _clamp100(_tsumeClearedCount / 100.0 * 100);
    final tacticsScore = _clamp100(_tesujiClearedCount / 80.0 * 100);
    final openingsScore = _clamp100(_josekiAvgScore);
    // _totalGames は既に全モード通算なので、AI対局分を二重加算しない
    final expScore = _clamp100(_totalGames / 200.0 * 100);
    final ratingScore = _clamp100((_rating - 500) / 2000.0 * 100);

    // 攻撃力: AI対局での勝率 × 80 + 手筋クリア数ボーナス × 20
    final aiWinRate = _totalAiGames > 0 ? _aiWins / _totalAiGames : 0.0;
    final attackScore = _clamp100(aiWinRate * 80 + (_tesujiClearedCount / 80.0 * 20));

    // 防御力: 全対局での後手勝率（守りの指標）+ 詰将棋ボーナス
    final p2WinRate = _totalGames > 0 ? _p2Wins / _totalGames : 0.0;
    final defenseScore = _clamp100(p2WinRate * 80 + (_tsumeClearedCount / 100.0 * 20));

    _dimensions = [
      SkillDimension(
        name: '終盤力',
        nameEn: 'Endgame',
        score: endgameScore,
        level: WeaknessLevelExt.fromScore(endgameScore),
        advice: endgameScore < 40
            ? '詰将棋をもっと解いて終盤の読みを鍛えましょう'
            : endgameScore < 60
                ? '詰将棋の難易度を上げて終盤力を伸ばしましょう'
                : '上級詰将棋で更なる高みを目指しましょう',
        practiceLabel: '詰将棋を練習',
        onPractice: widget.onGoToTsume,
      ),
      SkillDimension(
        name: '手筋力',
        nameEn: 'Tactics',
        score: tacticsScore,
        level: WeaknessLevelExt.fromScore(tacticsScore),
        advice: tacticsScore < 40
            ? '基本手筋から始めて駒の効率的な使い方を学びましょう'
            : tacticsScore < 60
                ? '中級手筋に挑戦して応用力を身につけましょう'
                : '高度な手筋で実戦に活かせる技を増やしましょう',
        practiceLabel: '手筋練習へ',
        onPractice: widget.onGoToTesuji,
      ),
      SkillDimension(
        name: '定跡知識',
        nameEn: 'Openings',
        score: openingsScore,
        level: WeaknessLevelExt.fromScore(openingsScore),
        advice: openingsScore < 40
            ? '基本定跡を覚えて序盤の安定感を高めましょう'
            : openingsScore < 60
                ? '得意戦法の定跡を深く掘り下げましょう'
                : '複数の定跡を使いこなして幅を広げましょう',
        practiceLabel: '定跡ドリルへ',
        onPractice: widget.onGoToJoseki,
      ),
      SkillDimension(
        name: '対局経験',
        nameEn: 'Experience',
        score: expScore,
        level: WeaknessLevelExt.fromScore(expScore),
        advice: expScore < 40
            ? 'まずは対局数を増やして経験値を積みましょう'
            : expScore < 60
                ? '勝敗に関わらず毎日1局を目標にしましょう'
                : '強い相手に挑戦して質の高い経験を積みましょう',
        practiceLabel: 'AI対局へ',
        onPractice: widget.onGoToAiGame,
      ),
      SkillDimension(
        name: '総合棋力',
        nameEn: 'Overall',
        score: ratingScore,
        level: WeaknessLevelExt.fromScore(ratingScore),
        advice: ratingScore < 40
            ? '基礎をしっかり固めてレーティングを上げましょう'
            : ratingScore < 60
                ? '弱点を克服してバランスよく成長しましょう'
                : '上位プレイヤーに挑戦してさらなる高みへ',
        practiceLabel: 'AI対局へ',
        onPractice: widget.onGoToAiGame,
      ),
      SkillDimension(
        name: '攻撃力',
        nameEn: 'Attack',
        score: attackScore,
        level: WeaknessLevelExt.fromScore(attackScore),
        advice: attackScore < 40
            ? '手筋練習でキレのある攻め筋を身につけましょう'
            : attackScore < 60
                ? '攻めの手筋を増やしてAI対局での勝率を上げましょう'
                : '鋭い攻めが武器になっています。さらに磨きをかけましょう',
        practiceLabel: '手筋練習へ',
        onPractice: widget.onGoToTesuji,
      ),
      SkillDimension(
        name: '防御力',
        nameEn: 'Defense',
        score: defenseScore,
        level: WeaknessLevelExt.fromScore(defenseScore),
        advice: defenseScore < 40
            ? '詰将棋で相手の攻めを読む力を養いましょう'
            : defenseScore < 60
                ? '囲いの崩し方を学んで守りの穴を塞ぎましょう'
                : '堅固な守りが身についています。攻守のバランスを意識しましょう',
        practiceLabel: '詰将棋を練習',
        onPractice: widget.onGoToTsume,
      ),
    ];

    final sorted = List<SkillDimension>.from(_dimensions)
      ..sort((a, b) => a.score.compareTo(b.score));
    _weakTop3 = sorted.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text(
          '弱点分析',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              setState(() => _isLoading = true);
              _radarAnimController.reset();
              _barsAnimController.reset();
              _loadData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE94560)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryHeader(),
                  const SizedBox(height: 20),
                  _buildRadarChart(),
                  const SizedBox(height: 24),
                  _buildDimensionCards(),
                  const SizedBox(height: 24),
                  _buildWeakTop3(),
                  if (_topBlunderPatterns.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildRecentBlunderInsights(),
                  ],
                  const SizedBox(height: 24),
                  _buildImprovementSuggestions(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryHeader() {
    final winRate = _totalGames > 0
        ? (_totalWins / _totalGames * 100).toStringAsFixed(1)
        : '0.0';
    final aiWinRate = _totalAiGames > 0
        ? (_aiWins / _totalAiGames * 100).toStringAsFixed(1)
        : '0.0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0F3460), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'あなたの棋力サマリー',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statChip('レーティング', '$_rating', Icons.bar_chart),
              const SizedBox(width: 8),
              _statChip('総対局数', '$_totalGames局', Icons.games),
              const SizedBox(width: 8),
              _statChip('通算勝率', '$winRate%', Icons.emoji_events),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _statChip('詰将棋', '$_tsumeClearedCount問', Icons.extension),
              const SizedBox(width: 8),
              _statChip('手筋', '$_tesujiClearedCount問', Icons.auto_awesome),
              const SizedBox(width: 8),
              _statChip('AI勝率', '$aiWinRate%', Icons.smart_toy),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F3460),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFE94560), size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0F3460), width: 1),
      ),
      child: Column(
        children: [
          const Text(
            '能力レーダーチャート',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _radarAnim,
            builder: (context, _) {
              return CustomPaint(
                size: const Size(280, 280),
                painter: RadarChartPainter(
                  scores: _dimensions.map((d) => d.score).toList(),
                  labels: _dimensions.map((d) => d.name).toList(),
                  progress: _radarAnim.value,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'スキル詳細',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._dimensions.map((dim) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildDimensionCard(dim),
            )),
      ],
    );
  }

  Widget _buildDimensionCard(SkillDimension dim) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dim.level.color.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: dim.level.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(dim.level.icon, color: dim.level.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dim.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: dim.level.color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            dim.level.label,
                            style: TextStyle(
                              color: dim.level.color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${dim.score.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: dim.level.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AnimatedBuilder(
                  animation: _barsAnim,
                  builder: (context, _) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (dim.score / 100.0) * _barsAnim.value,
                        minHeight: 6,
                        backgroundColor: const Color(0xFF0F3460),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(dim.level.color),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeakTop3() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF44336).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber, color: Color(0xFFF44336), size: 20),
              SizedBox(width: 8),
              Text(
                'あなたの弱点TOP3',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._weakTop3.asMap().entries.map((entry) {
            final idx = entry.key;
            final dim = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildWeakItem(idx + 1, dim),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWeakItem(int rank, SkillDimension dim) {
    final rankColors = [
      const Color(0xFFF44336),
      const Color(0xFFFF9800),
      const Color(0xFFFFEB3B),
    ];
    final rankColor = rank <= 3 ? rankColors[rank - 1] : Colors.white;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: rankColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$rank',
              style: TextStyle(
                color: rankColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    dim.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${dim.score.toStringAsFixed(0)}点)',
                    style: TextStyle(color: rankColor, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                dim.advice,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: dim.onPractice ?? () => _defaultPractice(dim),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dim.practiceLabel,
                      style: TextStyle(
                        color: rankColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios,
                        color: rankColor, size: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentBlunderInsights() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.query_stats, color: Color(0xFFFF9800), size: 20),
              SizedBox(width: 8),
              Text(
                '実際の対局で繰り返しているミス',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '対局分析データから、評価値が大きく下がった局面のパターンを抽出しています。',
            style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 14),
          ..._topBlunderPatterns.map((p) {
            final square = p.mistakes.isNotEmpty ? p.mistakes.last : '?';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$square付近',
                      style: const TextStyle(
                        color: Color(0xFFFF9800),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'この局面で${p.occurrenceCount}回、評価値を大きく落とす手を指しています',
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: widget.onGoToTsume,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  '詰将棋・手筋で読みを鍛える',
                  style: TextStyle(
                    color: Color(0xFFFF9800),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Color(0xFFFF9800), size: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _defaultPractice(SkillDimension dim) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${dim.name}の練習画面へ移動します'),
        backgroundColor: const Color(0xFF0F3460),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildImprovementSuggestions() {
    final suggestions = _buildSuggestions();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb, color: Color(0xFF4CAF50), size: 20),
              SizedBox(width: 8),
              Text(
                '今週の改善提案',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...suggestions.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildSuggestionCard(
                entry.value['icon'] as IconData,
                entry.value['title'] as String,
                entry.value['body'] as String,
                entry.value['action'] as String,
                entry.value['onTap'] as VoidCallback?,
              ),
            );
          }),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildSuggestions() {
    final sorted = List<SkillDimension>.from(_dimensions)
      ..sort((a, b) => a.score.compareTo(b.score));
    final weakest = sorted.first;

    List<Map<String, dynamic>> result = [];

    if (weakest.name == '終盤力') {
      result.add({
        'icon': Icons.extension,
        'title': '詰将棋を5問解こう',
        'body': '毎日5問の詰将棋を解くことで終盤の読み力が大幅に向上します。まずは3手詰めから始めましょう。',
        'action': '詰将棋へ',
        'onTap': widget.onGoToTsume,
      });
    } else if (weakest.name == '手筋力') {
      result.add({
        'icon': Icons.auto_awesome,
        'title': '手筋を3問練習しよう',
        'body': '基本手筋をマスターすると実戦で自然と活かせるようになります。今日は3問チャレンジ！',
        'action': '手筋練習へ',
        'onTap': widget.onGoToTesuji,
      });
    } else if (weakest.name == '定跡知識') {
      result.add({
        'icon': Icons.menu_book,
        'title': '定跡ドリルを1セット',
        'body': '得意戦法の定跡を1セット復習しましょう。序盤の安定が全体の勝率を底上げします。',
        'action': '定跡ドリルへ',
        'onTap': widget.onGoToJoseki,
      });
    } else {
      result.add({
        'icon': Icons.smart_toy,
        'title': 'AIと2局対戦しよう',
        'body': '対局経験を積むことが最速の上達法です。今週はAIと2局対戦してみましょう。',
        'action': 'AI対局へ',
        'onTap': widget.onGoToAiGame,
      });
    }

    result.add({
      'icon': Icons.balance,
      'title': 'バランストレーニング',
      'body': '詰将棋・手筋・定跡をバランスよく練習しましょう。各10分ずつ、合計30分が理想です。',
      'action': '練習メニューを見る',
      'onTap': null,
    });

    result.add({
      'icon': Icons.history,
      'title': '過去の対局を振り返ろう',
      'body': '負けた対局の敗因を分析することで、同じミスを繰り返さなくなります。週1回の振り返りを習慣に。',
      'action': '対局履歴へ',
      'onTap': widget.onGoToKifu ?? widget.onGoToAiGame,
    });

    return result;
  }

  Widget _buildSuggestionCard(
    IconData icon,
    String title,
    String body,
    String action,
    VoidCallback? onTap,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F3460),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF4CAF50), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onTap ?? () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.play_arrow, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          '今すぐ練習する',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
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

class RadarChartPainter extends CustomPainter {
  final List<double> scores;
  final List<String> labels;
  final double progress;

  static const int sides = 5;

  RadarChartPainter({
    required this.scores,
    required this.labels,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 40;

    _drawGrid(canvas, center, radius);
    _drawAxes(canvas, center, radius);
    _drawData(canvas, center, radius);
    _drawLabels(canvas, center, radius);
  }

  void _drawGrid(Canvas canvas, Offset center, double radius) {
    final gridPaint = Paint()
      ..color = const Color(0xFF0F3460)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int level = 1; level <= 5; level++) {
      final r = radius * level / 5;
      final path = Path();
      for (int i = 0; i < sides; i++) {
        final angle = _angleForIndex(i);
        final x = center.dx + r * cos(angle);
        final y = center.dy + r * sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    for (int level = 1; level <= 5; level++) {
      final r = radius * level / 5;
      final angle = _angleForIndex(0) - 0.15;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      textPainter.text = TextSpan(
        text: '${level * 20}',
        style: const TextStyle(
          color: Color(0xFF4A5568),
          fontSize: 9,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  void _drawAxes(Canvas canvas, Offset center, double radius) {
    final axisPaint = Paint()
      ..color = const Color(0xFF1A365D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < sides; i++) {
      final angle = _angleForIndex(i);
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      canvas.drawLine(center, Offset(x, y), axisPaint);
    }
  }

  void _drawData(Canvas canvas, Offset center, double radius) {
    final fillPaint = Paint()
      ..color = const Color(0xFFE94560).withOpacity(0.25)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFFE94560)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final dotPaint = Paint()
      ..color = const Color(0xFFE94560)
      ..style = PaintingStyle.fill;

    final path = Path();
    for (int i = 0; i < sides; i++) {
      final score = (scores[i] / 100.0).clamp(0.0, 1.0) * progress;
      final angle = _angleForIndex(i);
      final r = radius * score;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    for (int i = 0; i < sides; i++) {
      final score = (scores[i] / 100.0).clamp(0.0, 1.0) * progress;
      final angle = _angleForIndex(i);
      final r = radius * score;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _drawLabels(Canvas canvas, Offset center, double radius) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    final labelRadius = radius + 28;

    for (int i = 0; i < sides; i++) {
      final angle = _angleForIndex(i);
      final x = center.dx + labelRadius * cos(angle);
      final y = center.dy + labelRadius * sin(angle);

      final score = scores[i];
      final level = WeaknessLevelExt.fromScore(score);

      textPainter.text = TextSpan(
        children: [
          TextSpan(
            text: labels[i],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: '\n${score.toStringAsFixed(0)}',
            style: TextStyle(
              color: level.color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
      textPainter.layout(maxWidth: 60);
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  double _angleForIndex(int i) {
    return -pi / 2 + (2 * pi / sides) * i;
  }

  @override
  bool shouldRepaint(RadarChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.scores != scores;
  }
}
