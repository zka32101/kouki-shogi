import 'package:shared_preferences/shared_preferences.dart';

class PracticePointsSystem {
  static const String _totalKey = 'practice_points_total';
  static const String _lastUpdateKey = 'practice_points_last_update';
  static const String _historyKey = 'practice_points_history';

  // 対局での修練値獲得
  static const int pointsPerGame = 10;
  static const int bonusPointsForWin = 15;
  static const int bonusPointsForAnalysis = 5;
  static const int bonusPointsForLongGame = 3; // 30手以上でボーナス

  static Future<int> getTotalPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalKey) ?? 0;
  }

  static Future<void> addPointsForGame({
    required int moveCount,
    required bool playerWon,
    bool viewedAnalysis = false,
  }) async {
    try {
      // 入力値の検証
      if (moveCount < 0) return;

      final prefs = await SharedPreferences.getInstance();
      int points = pointsPerGame;

      // 勝利ボーナス
      if (playerWon) {
        points += bonusPointsForWin;
      }

      // 長手数ボーナス
      if (moveCount >= 30) {
        points += bonusPointsForLongGame;
      }

      // 分析閲覧ボーナス
      if (viewedAnalysis) {
        points += bonusPointsForAnalysis;
      }

      final current = prefs.getInt(_totalKey) ?? 0;
      await prefs.setInt(_totalKey, current + points);
      await prefs.setString(
        _lastUpdateKey,
        DateTime.now().toIso8601String(),
      );

      // 履歴に記録（日付ごとの獲得量）
      await _recordHistory(prefs, points);
    } catch (e) {
      // SharedPreferences エラーを無視（ゲーム進行を止めない）
      print('PracticePointsSystem error: $e');
    }
  }

  static Future<Map<String, int>> getDailyEarnings() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? [];
    final dailyMap = <String, int>{};

    for (final entry in history) {
      final parts = entry.split('|');
      if (parts.length == 2) {
        final date = parts[0];
        final points = int.tryParse(parts[1]) ?? 0;
        dailyMap[date] = (dailyMap[date] ?? 0) + points;
      }
    }

    return dailyMap;
  }

  static Future<void> _recordHistory(
    SharedPreferences prefs,
    int points,
  ) async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final history = prefs.getStringList(_historyKey) ?? [];
    history.add('$dateStr|$points');

    // 最新100件のみ保持
    if (history.length > 100) {
      history.removeRange(0, history.length - 100);
    }

    await prefs.setStringList(_historyKey, history);
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_totalKey);
    await prefs.remove(_lastUpdateKey);
    await prefs.remove(_historyKey);
  }
}
