// lib/services/cheat_detection_service.dart
// 指し手パターン分析 → ソフト指し・嫌がらせ行為検出
//
// 検出指標：
// 1. 応答時間の異常な短さ（1秒未満の一手） → ソフト指し
// 2. 驚異的な勝率（新規アカウントで90%超）  → ソフト指し
// 3. レーティング急上昇                     → ソフト指し
// 4. 投了パターン（一方的な相手投了）       → ソフト指し
// 5. 遅延行為（持ち時間の80%超を連続使用）  → 嫌がらせ

import 'dart:math' show sqrt;
import 'package:cloud_firestore/cloud_firestore.dart';

/// 検出スコアのしきい値
/// 0-100 スケール。70以上 → 要注目、85以上 → 自動フラグ
const double _warnThreshold = 70.0;
const double _autoFlagThreshold = 85.0;

class CheatAnalysisResult {
  final String userId;
  final double score; // 0-100
  final List<String> flags; // フラグ理由
  final bool shouldWarn;
  final bool shouldAutoFlag;

  CheatAnalysisResult({
    required this.userId,
    required this.score,
    required this.flags,
  })  : shouldWarn = score >= _warnThreshold,
        shouldAutoFlag = score >= _autoFlagThreshold;

  @override
  String toString() =>
      'CheatAnalysis(score=$score, flags=$flags)';
}

class CheatDetectionService {
  static final CheatDetectionService _instance =
      CheatDetectionService._internal();
  factory CheatDetectionService() => _instance;
  CheatDetectionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── メインの分析エントリポイント ──────────────────────────

  /// 対局終了後にプレイヤーの指し手を分析
  Future<CheatAnalysisResult> analyzePlayer(String userId) async {
    final flags = <String>[];
    double score = 0;

    try {
      // ① ユーザー情報取得
      final userDoc =
          await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return CheatAnalysisResult(
            userId: userId, score: 0, flags: ['user_not_found']);
      }

      final wins = userDoc['wins'] as int? ?? 0;
      final losses = userDoc['losses'] as int? ?? 0;
      final rating = userDoc['rating'] as int? ?? 1500;
      final totalGames = wins + losses;

      // ② 最近の対局を取得（最大20件）
      final recentMatches = await _firestore
          .collection('matches')
          .where(Filter.or(
            Filter('player1_id', isEqualTo: userId),
            Filter('player2_id', isEqualTo: userId),
          ))
          .where('status', isEqualTo: 'finished')
          .orderBy('finished_at', descending: true)
          .limit(20)
          .get();

      // ③ 各指標を計算
      final winRateScore =
          _analyzeWinRate(wins, totalGames, flags);
      final quickMoveScore =
          await _analyzeResponseTimes(recentMatches.docs, userId, flags);
      final ratingClimbScore =
          _analyzeRatingClimb(rating, totalGames, flags);
      final resignPatternScore =
          _analyzeResignPattern(recentMatches.docs, userId, flags);
      final stallingScore =
          await _analyzeStalling(recentMatches.docs, userId, flags);
      final uniformityScore =
          await _analyzeThinkTimeUniformity(recentMatches.docs, userId, flags);

      // ④ 総合スコアを算出（重み付き平均）
      score = (winRateScore * 0.28) +
          (quickMoveScore * 0.22) +
          (ratingClimbScore * 0.18) +
          (resignPatternScore * 0.10) +
          (stallingScore * 0.12) +
          (uniformityScore * 0.10);

      score = score.clamp(0.0, 100.0);

      // ⑤ 結果を Firestore に保存
      await _saveAnalysisResult(userId, score, flags);

      // ⑥ 自動フラグ処理
      if (score >= _autoFlagThreshold) {
        await _flagUserForReview(userId, score, flags);
      }
    } catch (e) {
      print('Cheat analysis error: $e');
    }

    return CheatAnalysisResult(
      userId: userId,
      score: score,
      flags: flags,
    );
  }

  // ── 個別指標の分析 ──────────────────────────────────────

  /// 指標①: 異常な勝率
  double _analyzeWinRate(int wins, int totalGames, List<String> flags) {
    if (totalGames < 5) return 0; // サンプル不足

    final winRate = wins / totalGames;

    if (winRate >= 0.95 && totalGames >= 10) {
      flags.add('extremely_high_win_rate:${(winRate * 100).toStringAsFixed(1)}%');
      return 90;
    }
    if (winRate >= 0.85 && totalGames >= 15) {
      flags.add('high_win_rate:${(winRate * 100).toStringAsFixed(1)}%');
      return 65;
    }
    if (winRate >= 0.75 && totalGames >= 20) {
      flags.add('suspicious_win_rate:${(winRate * 100).toStringAsFixed(1)}%');
      return 40;
    }

    return 0;
  }

  /// 指標②: 応答時間パターン（一手あたりの時間）
  Future<double> _analyzeResponseTimes(
    List<QueryDocumentSnapshot> matches,
    String userId,
    List<String> flags,
  ) async {
    if (matches.isEmpty) return 0;

    int fastMoveCount = 0;
    int totalMoves = 0;

    for (final matchDoc in matches) {
      final data = matchDoc.data() as Map<String, dynamic>;
      final moves = data['moves'] as List? ?? [];

      // 各手のタイムスタンプを分析
      for (int i = 0; i < moves.length; i++) {
        final move = moves[i] as Map<String, dynamic>?;
        if (move == null) continue;

        final playerId = move['player_id'] as String?;
        if (playerId != userId) continue;

        final thinkTime = move['think_time_ms'] as int? ?? 5000;
        totalMoves++;

        // 1秒未満 = 人間では難しい超高速手
        if (thinkTime < 1000) {
          fastMoveCount++;
        }
      }
    }

    if (totalMoves < 10) return 0;

    final fastRatio = fastMoveCount / totalMoves;

    if (fastRatio >= 0.5) {
      flags.add(
          'fast_moves:${(fastRatio * 100).toStringAsFixed(0)}% under_1s');
      return 85;
    }
    if (fastRatio >= 0.3) {
      flags.add('many_fast_moves:${(fastRatio * 100).toStringAsFixed(0)}%');
      return 55;
    }

    return 0;
  }

  /// 指標③: レーティング急上昇（新規プレイヤーが高レート）
  double _analyzeRatingClimb(
      int rating, int totalGames, List<String> flags) {
    if (totalGames < 3) return 0;

    // 初期 1500 から急激に上昇
    final ratingGain = rating - 1500;
    final gamesPerPoint = totalGames > 0 ? ratingGain / totalGames : 0;

    if (rating >= 2000 && totalGames <= 15) {
      flags.add(
          'rapid_rating_climb:+$ratingGain in $totalGames games');
      return 75;
    }
    if (gamesPerPoint > 20 && totalGames <= 20) {
      // 1試合あたり20点以上の上昇は異常
      flags.add(
          'abnormal_rating_gain:${gamesPerPoint.toStringAsFixed(1)}/game');
      return 60;
    }

    return 0;
  }

  /// 指標④: 投了パターン（一方的に相手が投了する）
  double _analyzeResignPattern(
    List<QueryDocumentSnapshot> matches,
    String userId,
    List<String> flags,
  ) {
    if (matches.length < 5) return 0;

    int wonByResignation = 0;
    int totalWins = 0;

    for (final matchDoc in matches) {
      final data = matchDoc.data() as Map<String, dynamic>;
      final winner = data['winner'] as String?;
      if (winner != userId) continue;

      totalWins++;
      final result = data['result'] as String? ?? '';
      if (result == 'resignation') wonByResignation++;
    }

    if (totalWins < 3) return 0;

    final resignRatio = wonByResignation / totalWins;

    if (resignRatio >= 0.9 && totalWins >= 8) {
      flags.add(
          'all_wins_by_resignation:${(resignRatio * 100).toStringAsFixed(0)}%');
      return 50;
    }

    return 0;
  }

  /// 指標⑤: 遅延行為（持ち時間の大部分を毎手消費し続ける）
  Future<double> _analyzeStalling(
    List<QueryDocumentSnapshot> matches,
    String userId,
    List<String> flags,
  ) async {
    if (matches.isEmpty) return 0;

    int stallingMoveCount = 0;
    int trackedMoves = 0;

    for (final matchDoc in matches) {
      final data = matchDoc.data() as Map<String, dynamic>;
      final moves = data['moves'] as List? ?? [];

      for (final entry in moves) {
        final move = entry as Map<String, dynamic>?;
        if (move == null) continue;
        if (move['player_id'] != userId) continue;

        final thinkTimeMs = move['think_time_ms'] as int? ?? 0;
        final timeLimitMs = move['time_limit_ms'] as int? ?? 0;
        if (timeLimitMs <= 0) continue;

        trackedMoves++;
        if (thinkTimeMs > timeLimitMs * 0.80) stallingMoveCount++;
      }
    }

    if (trackedMoves < 10) return 0;

    final stallingRatio = stallingMoveCount / trackedMoves;

    if (stallingRatio >= 0.70) {
      flags.add(
          'intentional_stalling:${(stallingRatio * 100).toStringAsFixed(0)}% of moves');
      return 80;
    }
    if (stallingRatio >= 0.50) {
      flags.add(
          'possible_stalling:${(stallingRatio * 100).toStringAsFixed(0)}% of moves');
      return 50;
    }

    return 0;
  }

  /// 指標⑥: 思考時間の分散が異常に小さい（ソフトのタイマー制御疑い）
  ///
  /// 人間は局面によって思考時間が大きく変動する。
  /// 毎手ほぼ同じ時間 → AIがタイマーで管理している可能性が高い。
  Future<double> _analyzeThinkTimeUniformity(
    List<QueryDocumentSnapshot> matches,
    String userId,
    List<String> flags,
  ) async {
    if (matches.isEmpty) return 0;

    final times = <int>[];

    for (final matchDoc in matches) {
      final data = matchDoc.data() as Map<String, dynamic>;
      final moves = data['moves'] as List? ?? [];
      for (final entry in moves) {
        final move = entry as Map<String, dynamic>?;
        if (move == null || move['player_id'] != userId) continue;
        final t = move['think_time_ms'] as int? ?? 0;
        if (t > 500) times.add(t); // 500ms未満は除外（高速手は別指標で判定）
      }
    }

    if (times.length < 10) return 0;

    final mean = times.reduce((a, b) => a + b) / times.length;
    if (mean < 2000) return 0; // 全体が速い場合は別指標で判定

    final variance =
        times.map((t) => (t - mean) * (t - mean)).reduce((a, b) => a + b) /
            times.length;
    final cv = sqrt(variance) / mean; // 変動係数（標準偏差 / 平均）

    if (cv < 0.08) {
      flags.add(
          'uniform_think_time:cv=${cv.toStringAsFixed(3)},mean=${mean.toStringAsFixed(0)}ms');
      return 75;
    }
    if (cv < 0.15) {
      flags.add('low_variance_think_time:cv=${cv.toStringAsFixed(3)}');
      return 40;
    }

    return 0;
  }

  // ── 管理機能 ──────────────────────────────────────

  /// 分析結果を Firestore に保存
  Future<void> _saveAnalysisResult(
      String userId, double score, List<String> flags) async {
    try {
      await _firestore
          .collection('cheat_analysis')
          .doc(userId)
          .set({
        'user_id': userId,
        'score': score,
        'flags': flags,
        'analyzed_at': DateTime.now(),
        'requires_review': score >= _warnThreshold,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Save analysis error: $e');
    }
  }

  /// 要注目ユーザーにフラグを立てる
  Future<void> _flagUserForReview(
      String userId, double score, List<String> flags) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'cheat_score': score,
        'cheat_flags': flags,
        'flagged_for_review': true,
        'flagged_at': DateTime.now(),
      });
      print(
          'User $userId flagged for review (score: $score, flags: $flags)');
    } catch (e) {
      print('Flag user error: $e');
    }
  }

  /// 管理者: フラグ付きユーザー一覧を取得
  Stream<QuerySnapshot> watchFlaggedUsers() {
    return _firestore
        .collection('users')
        .where('flagged_for_review', isEqualTo: true)
        .orderBy('cheat_score', descending: true)
        .snapshots();
  }

  /// 管理者: フラグをクリア（誤検知の場合）
  Future<void> clearFlag(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'cheat_score': 0,
        'cheat_flags': [],
        'flagged_for_review': false,
      });
    } catch (e) {
      print('Clear flag error: $e');
    }
  }

  /// 対局中トラッキングデータを Firestore に保存（遅延行為の証跡）
  Future<void> saveInGameTracking(
      String matchId, String userId, InGameSoftPlayTracker tracker) async {
    try {
      await _firestore
          .collection('matches')
          .doc(matchId)
          .collection('tracking')
          .doc(userId)
          .set(tracker.toFirestoreMap(), SetOptions(merge: true));
    } catch (e) {
      print('Save in-game tracking error: $e');
    }
  }

  /// バッチ分析: 全フラグなしユーザーをスキャン（管理者用、週次実行想定）
  Future<List<CheatAnalysisResult>> batchAnalyze({int limit = 100}) async {
    final results = <CheatAnalysisResult>[];
    try {
      final users = await _firestore
          .collection('users')
          .where('flagged_for_review', isEqualTo: false)
          .where('wins', isGreaterThanOrEqualTo: 5)
          .limit(limit)
          .get();

      for (final doc in users.docs) {
        final result = await analyzePlayer(doc.id);
        if (result.shouldWarn) {
          results.add(result);
        }
      }
    } catch (e) {
      print('Batch analyze error: $e');
    }
    return results;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// 対局中リアルタイム遅延行為トラッカー
///
/// match_screen.dart で相手の手番終了ごとに recordMove() を呼ぶ。
/// isStallingNow() でリアルタイム警告判定、
/// 対局終了後に CheatDetectionService.saveInGameTracking() で証跡を保存する。
class InGameSoftPlayTracker {
  final List<int> _thinkTimesMs = [];
  final List<double> _usageRatios = []; // think / limit

  void recordMove({required int thinkTimeMs, int? timeLimitMs}) {
    _thinkTimesMs.add(thinkTimeMs);
    if (timeLimitMs != null && timeLimitMs > 0) {
      _usageRatios.add((thinkTimeMs / timeLimitMs).clamp(0.0, 1.0));
    }
  }

  int get moveCount => _thinkTimesMs.length;

  /// 遅延行為の疑い: 直近8手中5手以上で持ち時間の80%超を使用
  bool isStallingNow() {
    if (_usageRatios.length < 5) return false;
    final window = _usageRatios.length > 8
        ? _usageRatios.sublist(_usageRatios.length - 8)
        : _usageRatios;
    return window.where((r) => r > 0.80).length >= 5;
  }

  /// 思考時間の変動係数（CV = std / mean）
  /// 0.08未満 = 一定すぎる = ソフトのタイマー制御疑い
  double get thinkTimeCV {
    if (_thinkTimesMs.length < 6) return 1.0; // データ不足 → 正常扱い
    final filtered = _thinkTimesMs.where((t) => t > 500).toList();
    if (filtered.length < 6) return 1.0;
    final mean = filtered.reduce((a, b) => a + b) / filtered.length;
    if (mean < 2000) return 1.0;
    final variance =
        filtered.map((t) => (t - mean) * (t - mean)).reduce((a, b) => a + b) /
            filtered.length;
    return sqrt(variance) / mean;
  }

  bool isUniformThinkTime() => thinkTimeCV < 0.08;

  /// 通算遅延スコア (0-100)
  double get stallingScore {
    if (_usageRatios.isEmpty) return 0;
    final ratio =
        _usageRatios.where((r) => r > 0.80).length / _usageRatios.length;
    if (ratio >= 0.70) return 80;
    if (ratio >= 0.50) return 55;
    if (ratio >= 0.30) return 30;
    return 0;
  }

  Map<String, dynamic> toFirestoreMap() => {
        'think_times_ms': _thinkTimesMs,
        'time_usage_ratios': _usageRatios,
        'stalling_score': stallingScore,
        'total_moves_tracked': _thinkTimesMs.length,
      };

  void reset() {
    _thinkTimesMs.clear();
    _usageRatios.clear();
  }
}
