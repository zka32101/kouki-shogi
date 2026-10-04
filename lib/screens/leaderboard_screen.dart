import 'package:flutter/material.dart';
import '../models/game_analysis.dart';
import '../models/game_statistics.dart';
import '../theme/app_theme.dart';

class LeaderboardScreen extends StatefulWidget {
  final List<GameAnalysis> games;

  const LeaderboardScreen({
    required this.games,
    super.key,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _selectedTab = 0; // 0: 全期間, 1: 今月, 2: 先月

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('スコアボード'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // タブバー
          Container(
            color: AppTheme.surface,
            child: Row(
              children: [
                _buildLeaderboardTab('全期間', 0),
                _buildLeaderboardTab('今月', 1),
                _buildLeaderboardTab('先月', 2),
              ],
            ),
          ),
          // コンテンツ
          Expanded(
            child: _buildLeaderboardContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppTheme.accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppTheme.accent : AppTheme.textLow,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardContent() {
    DateTime startDate;
    DateTime endDate = DateTime.now();

    switch (_selectedTab) {
      case 0:
        // 全期間
        startDate = widget.games.isEmpty ? DateTime.now() : widget.games.last.playedAt;
        break;
      case 1:
        // 今月
        startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
        break;
      case 2:
        // 先月（月末日の23:59:59.999まで含める）
        final now = DateTime.now();
        endDate = DateTime(now.year, now.month, 1).subtract(const Duration(milliseconds: 1));
        startDate = DateTime(endDate.year, endDate.month, 1);
        break;
      default:
        startDate = DateTime.now();
    }

    final filtered = widget.games
        .where((g) => !g.playedAt.isBefore(startDate) && !g.playedAt.isAfter(endDate))
        .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          '対局データがありません',
          style: TextStyle(color: AppTheme.textLow),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 成績サマリー
          _buildSummaryStat(filtered),
          const SizedBox(height: 24),
          // ランキングセクション
          _sectionHeader(Icons.menu_book, '定跡別成績'),
          const SizedBox(height: 12),
          ..._buildOpeningRankings(filtered),
          const SizedBox(height: 24),
          // 時間帯別ランキング
          _sectionHeader(Icons.schedule, '時間帯別パフォーマンス'),
          const SizedBox(height: 12),
          ..._buildHourlyRankings(filtered),
          const SizedBox(height: 24),
          // 連勝記録
          _sectionHeader(Icons.insights, 'パフォーマンス'),
          const SizedBox(height: 12),
          _buildPerformanceCard(filtered),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String label) {
    return Row(children: [
      Icon(icon, size: 15, color: AppTheme.accent),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          color: AppTheme.accent,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    ]);
  }

  Widget _buildSummaryStat(List<GameAnalysis> games) {
    final totalGames = games.length;
    final wins = games.where((g) => g.playerWon).length;
    final winRate = totalGames == 0 ? 0.0 : (wins / totalGames * 100);
    final avgMoves = totalGames == 0
        ? 0.0
        : games.fold<int>(0, (sum, g) => sum + g.movesCount) / totalGames;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.accent.withAlpha(30), AppTheme.accent.withAlpha(8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppTheme.accent.withAlpha(70)),
        borderRadius: BorderRadius.circular(AppTheme.rCard),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '成績サマリー',
            style: TextStyle(
              color: AppTheme.accent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatBadge('対局数', totalGames.toString(), AppTheme.textHigh),
              _buildStatBadge('勝利', wins.toString(), AppTheme.success),
              _buildStatBadge('勝率', '${winRate.toStringAsFixed(1)}%', AppTheme.accent),
              _buildStatBadge('平均手', avgMoves.toStringAsFixed(1), AppTheme.textMid),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textLow,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildOpeningRankings(List<GameAnalysis> games) {
    final openingStats = <String, (int, int)>{};

    for (final game in games) {
      final opening = game.openingName ?? '不明';
      final (g, w) = openingStats[opening] ?? (0, 0);
      openingStats[opening] = (g + 1, w + (game.playerWon ? 1 : 0));
    }

    final rankings = openingStats.entries
        .map((e) {
          final name = e.key;
          final (games, wins) = e.value;
          final winRate = games == 0 ? 0.0 : (wins / games * 100);
          return (name: name, games: games, wins: wins, winRate: winRate);
        })
        .toList()
        ..sort((a, b) => b.winRate.compareTo(a.winRate));

    return rankings.isEmpty
        ? [
            Text(
              '定跡データがありません',
              style: TextStyle(color: AppTheme.textLow),
            )
          ]
        : rankings.asMap().entries.map((e) {
            final idx = e.key;
            final rank = e.value;
            return _buildOpeningRankCard(idx + 1, rank);
          }).toList();
  }

  // 順位1〜3の丸バッジ配色（金・銀・銅）。4位以降はAppTheme.primary。
  static const _rankKanji = {1: '一', 2: '二', 3: '三'};
  static const _silver = Color(0xFF9A9A92);
  static const _bronze = Color(0xFFB07040);

  Color _rankColor(int rank) {
    switch (rank) {
      case 1: return AppTheme.accent;
      case 2: return _silver;
      case 3: return _bronze;
      default: return AppTheme.primary;
    }
  }

  Widget _rankBadge(int rank) {
    final color = _rankColor(rank);
    final kanji = _rankKanji[rank];
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Center(
        child: kanji != null
            ? Text(
                kanji,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'serif',
                ),
              )
            : Text(
                '$rank',
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  // 勝率の意味色: 高い=成功(松葉)/中間=情報(藍)/低い=控えめ(低輝度)。警告色は使わない。
  Color _winRateColor(double rate) {
    if (rate >= 60) return AppTheme.success;
    if (rate >= 40) return AppTheme.primary;
    return AppTheme.textLow;
  }

  Widget _buildOpeningRankCard(
    int rank,
    ({String name, int games, int wins, double winRate}) rankData,
  ) {
    final color = _rankColor(rank);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: color.withAlpha(70)),
        borderRadius: BorderRadius.circular(AppTheme.rBtn),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          _rankBadge(rank),
          const SizedBox(width: 12),
          // 定跡情報
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rankData.name,
                  style: TextStyle(
                    color: AppTheme.textHigh,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${rankData.wins}勝 / ${rankData.games}局',
                  style: TextStyle(
                    color: AppTheme.textLow,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // 勝率
          Text(
            '${rankData.winRate.toStringAsFixed(1)}%',
            style: TextStyle(
              color: _winRateColor(rankData.winRate),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(List<GameAnalysis> games) {
    final longestWinStreak = _calculateLongestWinStreak(games);
    final maxMovesGame = games.isEmpty ? 0 : games.map((g) => g.movesCount).reduce((a, b) => a > b ? a : b);
    final minMovesGame = games.isEmpty ? 0 : games.map((g) => g.movesCount).reduce((a, b) => a < b ? a : b);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: Colors.white.withAlpha(20)),
        borderRadius: BorderRadius.circular(AppTheme.rBtn),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPerformanceRow('最長連勝', '$longestWinStreak連勝', AppTheme.success),
          const SizedBox(height: 10),
          _buildPerformanceRow('最長対局', '$maxMovesGame手', AppTheme.primary),
          const SizedBox(height: 10),
          _buildPerformanceRow('最短対局', '$minMovesGame手', AppTheme.textMid),
        ],
      ),
    );
  }

  Widget _buildPerformanceRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textMid,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  int _calculateLongestWinStreak(List<GameAnalysis> games) {
    if (games.isEmpty) return 0;

    int maxStreak = 0;
    int currentStreak = 0;

    for (final game in games) {
      if (game.playerWon) {
        currentStreak++;
        maxStreak = currentStreak > maxStreak ? currentStreak : maxStreak;
      } else {
        currentStreak = 0;
      }
    }

    return maxStreak;
  }

  List<Widget> _buildHourlyRankings(List<GameAnalysis> games) {
    final hourlyStats = StatisticsCalculator.calculateHourlyStats(games);
    final activeHours = hourlyStats
        .where((h) => h.games > 0)
        .toList()
        ..sort((a, b) => b.winRate.compareTo(a.winRate));

    if (activeHours.isEmpty) {
      return [
        Text(
          '時間帯データがありません',
          style: TextStyle(color: AppTheme.textLow),
        )
      ];
    }

    return activeHours.take(5).toList().asMap().entries.map((e) {
      final idx = e.key;
      final hour = e.value;
      final rank = idx + 1;
      final color = _rankColor(rank);

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: color.withAlpha(70)),
          borderRadius: BorderRadius.circular(AppTheme.rBtn),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            _rankBadge(rank),
            const SizedBox(width: 12),
            // 時間帯情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${hour.hour.toString().padLeft(2, '0')}:00～${(hour.hour + 1).toString().padLeft(2, '0')}:00',
                    style: TextStyle(
                      color: AppTheme.textHigh,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${hour.wins}勝 / ${hour.games}局',
                    style: TextStyle(
                      color: AppTheme.textLow,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // 勝率
            Text(
              '${hour.winRate.toStringAsFixed(1)}%',
              style: TextStyle(
                color: _winRateColor(hour.winRate),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
