import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'theme/app_theme.dart';
import 'services/kifu_analytics_service.dart';
import 'tsume_screen.dart';
import 'joseki_screen.dart';

class _OpeningStat {
  int total = 0;
  int losses = 0;
}

class WeaknessPattern {
  final String patternName;
  final int losses;
  final int totalGames;
  final String recommendation;

  WeaknessPattern({
    required this.patternName,
    required this.losses,
    required this.totalGames,
    required this.recommendation,
  });

  double get lossRate => totalGames > 0 ? (losses / totalGames) * 100 : 0;

  Map<String, dynamic> toJson() => {
    'patternName': patternName,
    'losses': losses,
    'totalGames': totalGames,
    'recommendation': recommendation,
  };

  factory WeaknessPattern.fromJson(Map<String, dynamic> json) => WeaknessPattern(
    patternName: json['patternName'] as String,
    losses: json['losses'] as int,
    totalGames: json['totalGames'] as int,
    recommendation: json['recommendation'] as String? ?? '',
  );
}

class WeaknessMiningScreen extends StatefulWidget {
  const WeaknessMiningScreen({Key? key}) : super(key: key);

  @override
  State<WeaknessMiningScreen> createState() => _WeaknessMiningScreenState();
}

class _WeaknessMiningScreenState extends State<WeaknessMiningScreen> {
  late SharedPreferences _prefs;
  List<WeaknessPattern> _weaknessPatterns = [];
  int _totalAiGames = 0;
  int _aiWins = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    _prefs = await SharedPreferences.getInstance();

    // Load stats（total_ai_games/ai_winsは存在しないキーで常に0だったため修正）
    _totalAiGames = _prefs.getInt('stats_total_ai') ?? 0;
    _aiWins = _prefs.getInt('stats_p1_wins_ai') ?? 0;

    // Load or analyze weakness patterns
    await _loadOrAnalyzeWeaknesses();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadOrAnalyzeWeaknesses() async {
    // Try to load cached weakness patterns
    final cached = _prefs.getString('weakness_patterns_json');

    if (cached != null && cached.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(cached);
        _weaknessPatterns = decoded
            .map((p) => WeaknessPattern.fromJson(p as Map<String, dynamic>))
            .toList();
      } catch (e) {
        print('Error loading cached patterns: $e');
        await _analyzeGameHistory();
      }
    } else {
      // Analyze game history to detect patterns
      await _analyzeGameHistory();
    }

    // Sort by loss rate (descending) and keep top 5
    _weaknessPatterns.sort((a, b) => b.lossRate.compareTo(a.lossRate));
    if (_weaknessPatterns.length > 5) {
      _weaknessPatterns = _weaknessPatterns.sublist(0, 5);
    }
  }

  // (旧版は書き込み元の存在しない 'game_history_json' キーを読もうとしており、
  //  常にモックの弱点パターンを表示していた。TsumeEngine監査で発覚・修正:
  //  対局ごとに実際に保存されている KifuAnalyticsService のデータ
  //  （戦型別の勝敗・繰り返す悪手パターン）から実データで分析するよう変更)
  Future<void> _analyzeGameHistory() async {
    try {
      final analyses = await KifuAnalyticsService().getAllAnalyses();

      // 戦型（openingName）別の勝敗集計
      final byOpening = <String, _OpeningStat>{};
      for (final a in analyses) {
        final name = a.openingName;
        if (name == null || name.isEmpty) continue;
        final stat = byOpening.putIfAbsent(name, () => _OpeningStat());
        stat.total++;
        if (!a.playerWon) stat.losses++;
      }

      final recommendations = {
        '穴熊': '穴熊の防御を強化する。駒組み練習に進む',
        '角換わり': '角換わり定跡を学習する。詰将棋練習',
        '4五桂': '4五桂への対抗策を学習する。詰め合い練習',
        '横歩取り': '横歩取り定跡を強化する。詰め合い練習',
        '早仕掛け': '早仕掛けへの対抗策を学習する',
      };

      final openingPatterns = byOpening.entries
          .where((e) => e.value.total >= 2 && e.value.losses > 0)
          .map((e) => WeaknessPattern(
                patternName: '${e.key}で負けやすい',
                losses: e.value.losses,
                totalGames: e.value.total,
                recommendation: _findRecommendation(e.key, recommendations),
              ))
          .toList();

      // 繰り返し発生している悪手パターン（実際の対局分析データから）
      final blunderPatterns =
          await KifuAnalyticsService().getRepeatedBlunders(topN: 5);
      final blunderCards = blunderPatterns
          .where((p) => p.occurrenceCount >= 2)
          .map((p) {
        final square = p.mistakes.isNotEmpty ? p.mistakes.last : '?';
        return WeaknessPattern(
          patternName: '$square 付近で悪手を繰り返す',
          losses: p.occurrenceCount,
          totalGames: p.occurrenceCount,
          recommendation: '詰将棋・手筋トレーニングでこの局面パターンを重点的に練習する',
        );
      }).toList();

      _weaknessPatterns = [...openingPatterns, ...blunderCards];

      await _saveWeaknessPatterns();
    } catch (e) {
      // 分析に失敗した場合は空のまま（モックデータは表示しない）
      _weaknessPatterns = [];
    }
  }

  String _findRecommendation(String pattern, Map<String, String> recommendations) {
    for (final key in recommendations.keys) {
      if (pattern.contains(key)) {
        return recommendations[key] ?? '詰め合い練習を進める';
      }
    }
    return '定跡学習と詰め合い練習を進める';
  }

  Future<void> _saveWeaknessPatterns() async {
    final json = jsonEncode(
      _weaknessPatterns.map((p) => p.toJson()).toList(),
    );
    await _prefs.setString('weakness_patterns_json', json);
  }

  Future<void> _refreshAnalysis() async {
    setState(() => _isLoading = true);
    await _prefs.remove('weakness_patterns_json');
    _weaknessPatterns.clear();
    await _loadOrAnalyzeWeaknesses();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text(
          '弱点採掘',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshAnalysis,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Section
                    _buildStatsSection(),
                    const SizedBox(height: 24),

                    // Weakness Patterns Section
                    const Text(
                      '検出された弱点パターン',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_weaknessPatterns.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(
                            'まだ弱点パターンが検出されていません',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _weaknessPatterns
                            .asMap()
                            .entries
                            .map((e) => _buildWeaknessCard(e.value, e.key + 1))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsSection() {
    final aiLosses = _totalAiGames - _aiWins;
    final winRate = _totalAiGames > 0 ? (_aiWins / _totalAiGames) * 100 : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00D4FF).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI対局成績',
            style: TextStyle(
              color: Color(0xFF00D4FF),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('総対局数', '$_totalAiGames'),
              _buildStatItem('勝利数', '$_aiWins'),
              _buildStatItem('敗数', '$aiLosses'),
              _buildStatItem('勝率', '${winRate.toStringAsFixed(1)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF00D4FF),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildWeaknessCard(WeaknessPattern pattern, int rank) {
    final lossPercentage = pattern.lossRate.toStringAsFixed(1);
    final severityColor = pattern.lossRate > 70
        ? Colors.red
        : pattern.lossRate > 50
            ? Colors.orange
            : Colors.yellow;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: severityColor.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Center(
                  child: Icon(
                    Icons.warning,
                    color: severityColor,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${rank}. ${pattern.patternName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'この局面で弱い',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Loss Rate
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: severityColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(
                  '敗率: ',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${pattern.losses}/${pattern.totalGames}戦 $lossPercentage%',
                  style: TextStyle(
                    color: severityColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Recommendation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey[700]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '推奨トレーニング',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  pattern.recommendation,
                  style: const TextStyle(
                    color: Color(0xFF00D4FF),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4FF),
                foregroundColor: AppTheme.bg,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _handleWeaknessTap(pattern),
              child: const Text(
                'この弱点を克服する',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleWeaknessTap(WeaknessPattern pattern) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${pattern.patternName} の克服トレーニングを開始します'),
        backgroundColor: AppTheme.surface,
        duration: const Duration(seconds: 2),
      ),
    );

    // 戦型（開き）の負けパターンは定跡学習へ、悪手の繰り返しパターンは
    // 詰将棋トレーニングへ誘導する（_analyzeGameHistory() が付与する
    // patternName の2種類の形式に対応）。
    final isOpeningWeakness = pattern.patternName.endsWith('で負けやすい');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isOpeningWeakness ? const JosekiScreen() : const TsumeScreen(),
      ),
    );
  }
}
