import 'package:intl/intl.dart';
import 'game_analysis.dart';

/// 成績統計データモデル
class GameStatistics {
  final int totalGames;
  final int wins;
  final int losses;
  final int draws;
  final double winRate;
  final int totalMoves;
  final double avgMoves;
  final DateTime periodStart;
  final DateTime periodEnd;

  GameStatistics({
    required this.totalGames,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.winRate,
    required this.totalMoves,
    required this.avgMoves,
    required this.periodStart,
    required this.periodEnd,
  });

  String get periodLabel {
    final formatter = DateFormat('yyyy年M月d日');
    return '${formatter.format(periodStart)} ～ ${formatter.format(periodEnd)}';
  }

  String get recordText => '$wins勝 $losses敗${draws > 0 ? ' $draws分' : ''}';
}

/// 時間帯別パフォーマンス
class HourlyStats {
  final int hour; // 0-23
  final int games;
  final int wins;
  final double winRate;

  HourlyStats({
    required this.hour,
    required this.games,
    required this.wins,
    required this.winRate,
  });

  String get timeRange => '${hour.toString().padLeft(2, '0')}:00～';
}

/// 定跡・戦型別の成績
class OpeningStats {
  final String openingName;
  final int games;
  final int wins;
  final double winRate;

  OpeningStats({
    required this.openingName,
    required this.games,
    required this.wins,
    required this.winRate,
  });
}

/// 統計計算サービス
class StatisticsCalculator {
  static GameStatistics calculateStats(
    List<GameAnalysis> games, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final now = DateTime.now();
    final start = startDate ?? DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
    final end = endDate ?? now;

    final filtered = games
        .where((g) => !g.playedAt.isBefore(start) && !g.playedAt.isAfter(end))
        .toList();

    if (filtered.isEmpty) {
      return GameStatistics(
        totalGames: 0,
        wins: 0,
        losses: 0,
        draws: 0,
        winRate: 0,
        totalMoves: 0,
        avgMoves: 0,
        periodStart: start,
        periodEnd: end,
      );
    }

    final wins = filtered.where((g) => g.playerWon).length;
    final losses = filtered.length - wins;
    final draws = 0;

    final totalMoves = filtered.fold<int>(0, (sum, g) => sum + g.movesCount);
    final avgMoves = filtered.isEmpty ? 0.0 : totalMoves / filtered.length;

    return GameStatistics(
      totalGames: filtered.length,
      wins: wins,
      losses: losses,
      draws: draws,
      winRate: filtered.isEmpty ? 0 : wins / filtered.length * 100,
      totalMoves: totalMoves,
      avgMoves: avgMoves,
      periodStart: start,
      periodEnd: end,
    );
  }

  static List<HourlyStats> calculateHourlyStats(List<GameAnalysis> games) {
    final hourlyData = <int, (int, int)>{};

    for (int hour = 0; hour < 24; hour++) {
      hourlyData[hour] = (0, 0); // (games, wins)
    }

    for (final game in games) {
      final hour = game.playedAt.hour;
      final (games, wins) = hourlyData[hour] ?? (0, 0);
      hourlyData[hour] = (games + 1, wins + (game.playerWon ? 1 : 0));
    }

    return hourlyData.entries
        .map((e) {
          final hour = e.key;
          final (games, wins) = e.value;
          return HourlyStats(
            hour: hour,
            games: games,
            wins: wins,
            winRate: games == 0 ? 0 : wins / games * 100,
          );
        })
        .toList();
  }

  static List<GameStatistics> calculateMonthlyStats(List<GameAnalysis> games) {
    final now = DateTime.now();
    final months = <GameStatistics>[];

    for (int i = 0; i < 12; i++) {
      final targetMonth = DateTime(now.year, now.month - i, 1);
      final startDate = targetMonth;
      // 月末日の23:59:59.999まで含める（0時ちょうどだけだと月末の対局が漏れる）
      final endDate = DateTime(targetMonth.year, targetMonth.month + 1, 1)
          .subtract(const Duration(milliseconds: 1));

      months.add(calculateStats(games, startDate: startDate, endDate: endDate));
    }

    return months;
  }
}
