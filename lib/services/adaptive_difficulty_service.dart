// lib/services/adaptive_difficulty_service.dart
//
// レーティングだけでなく直近の対局内容（連敗/連勝・悪手率）を加味して
// AIの難易度を微調整するサービス。
//
// レーティングは指し手全体の長期的な実力を表すが、調子の波（好調/不調）を
// 反映しないため、「レーティング上は appropriate でも今日は全然勝てない/
// 勝ちすぎる」というミスマッチが起きる。直近5局の勝敗と悪手率を見て
// ±1段階だけ調整することでこれを緩和する。

import 'package:shared_preferences/shared_preferences.dart';
import '../game_screen.dart' show AILevel, autoAiLevelFromRating;
import '../models/game_analysis.dart';
import 'kifu_analytics_service.dart';

/// 弱い順に並べた実際の強さの並び。
/// AILevel の enum 宣言順とは異なる（宣言順は実装都合の順序）ため、
/// autoAiLevelFromRating() のレーティング閾値と対応させたこの並びを使う。
const List<AILevel> kAiLevelStrengthOrder = [
  AILevel.random,
  AILevel.beginner,
  AILevel.easy,
  AILevel.elementary,
  AILevel.medium,
  AILevel.upperMedium,
  AILevel.hard,
  AILevel.expert,
];

class AdaptiveLevelResult {
  final AILevel level;
  final AILevel baseLevel;
  final int adjustmentSteps; // -1, 0, +1
  final String reason;
  final double recentWinRate;
  final double recentBlunderRate;
  final int sampleSize;

  AdaptiveLevelResult({
    required this.level,
    required this.baseLevel,
    required this.adjustmentSteps,
    required this.reason,
    required this.recentWinRate,
    required this.recentBlunderRate,
    required this.sampleSize,
  });

  bool get isAdjusted => adjustmentSteps != 0;
}

class AdaptiveDifficultyService {
  static const int _windowSize = 5;
  static const String _lastStepsKey = 'adaptive_difficulty_last_steps';

  /// レーティングと直近の対局内容から調整後のAIレベルを算出する。
  static Future<AdaptiveLevelResult> computeAdaptiveLevel({
    required int rating,
  }) async {
    final baseLevel = autoAiLevelFromRating(rating);
    final baseIndex = kAiLevelStrengthOrder.indexOf(baseLevel);

    List<GameAnalysis> recent;
    try {
      recent = await KifuAnalyticsService().getAllAnalyses();
    } catch (_) {
      recent = const [];
    }
    recent = recent.take(_windowSize).toList();

    if (recent.length < 3) {
      // サンプル不足時は調整せずベースレベルをそのまま使う
      return AdaptiveLevelResult(
        level: baseLevel,
        baseLevel: baseLevel,
        adjustmentSteps: 0,
        reason: '対局データがまだ少ないため、レーティングに基づく標準レベルです。',
        recentWinRate: 0,
        recentBlunderRate: 0,
        sampleSize: recent.length,
      );
    }

    final wins = recent.where((g) => g.playerWon).length;
    final winRate = wins / recent.length * 100;

    final totalBlunders = recent.fold<int>(0, (sum, g) => sum + g.blunders.length);
    final blunderRate = totalBlunders / recent.length;

    // 連敗・連勝の判定（直近から数えて何連続か）
    int currentStreak = 0;
    bool? streakIsWin;
    for (final g in recent) {
      if (streakIsWin == null) {
        streakIsWin = g.playerWon;
        currentStreak = 1;
      } else if (g.playerWon == streakIsWin) {
        currentStreak++;
      } else {
        break;
      }
    }

    int steps = 0;
    String reason;

    final isLosingBadly = streakIsWin == false && currentStreak >= 3 && blunderRate >= 1.5;
    final isStrugglingOverall = winRate <= 20 && blunderRate >= 2.0;
    final isWinningEasily = streakIsWin == true && currentStreak >= 3 && blunderRate <= 0.5;
    final isDominatingOverall = winRate >= 90 && blunderRate <= 0.6;

    if (isLosingBadly || isStrugglingOverall) {
      steps = -1;
      reason = '直近$_windowSize局中${recent.length - wins}敗、悪手も多め（平均${blunderRate.toStringAsFixed(1)}回/局）'
          'なので、少し易しめのAIに調整しました。';
    } else if (isWinningEasily || isDominatingOverall) {
      steps = 1;
      reason = '直近$_windowSize局中$wins勝、悪手も少なめ（平均${blunderRate.toStringAsFixed(1)}回/局）'
          'なので、少し手強いAIに調整しました。';
    } else {
      steps = 0;
      reason = '直近の調子（勝率${winRate.toStringAsFixed(0)}%）は標準的なので、'
          'レーティング通りのレベルで対局します。';
    }

    final adjustedIndex = (baseIndex + steps).clamp(0, kAiLevelStrengthOrder.length - 1);
    final adjustedLevel = kAiLevelStrengthOrder[adjustedIndex];
    final actualSteps = adjustedIndex - baseIndex;

    await _saveLastSteps(actualSteps);

    return AdaptiveLevelResult(
      level: adjustedLevel,
      baseLevel: baseLevel,
      adjustmentSteps: actualSteps,
      reason: reason,
      recentWinRate: winRate,
      recentBlunderRate: blunderRate,
      sampleSize: recent.length,
    );
  }

  static Future<void> _saveLastSteps(int steps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastStepsKey, steps);
  }

  static Future<int> getLastSteps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastStepsKey) ?? 0;
  }
}
