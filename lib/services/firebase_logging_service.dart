// lib/services/firebase_logging_service.dart — Firebase ロギング

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firebase にゲーム進行ログを記録するサービス
class FirebaseLoggingService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _userId => _auth.currentUser?.uid;

  /// ゲーム開始ログ
  static Future<void> logGameStart({
    required String gameMode, // 'vsAI' or 'network'
    required String? opponentId,
    required String aiCharacterId,
    required int handicap,
  }) async {
    if (_userId == null) return;
    try {
      await _firestore
          .collection('game_logs')
          .doc(_userId)
          .collection('logs')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'eventType': 'start',
        'gameMode': gameMode,
        'opponentId': opponentId,
        'aiCharacterId': aiCharacterId,
        'handicap': handicap,
      });
    } catch (e) {
      // ロギング失敗は無視（ゲーム進行を止めない）
    }
  }

  /// ゲーム終了ログ
  static Future<void> logGameEnd({
    required String gameMode,
    required String? opponentId,
    required String result, // '先手の勝ち！' など
    required int moveCount,
    required int elapsedSeconds,
  }) async {
    if (_userId == null) return;
    try {
      await _firestore
          .collection('game_logs')
          .doc(_userId)
          .collection('logs')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'eventType': 'end',
        'gameMode': gameMode,
        'opponentId': opponentId,
        'result': result,
        'moveCount': moveCount,
        'elapsedSeconds': elapsedSeconds,
        'playerWon': result.contains(_userId == opponentId ? '先手' : '後手'),
      });
    } catch (e) {
      // ロギング失敗は無視
    }
  }

  /// エラーログ
  static Future<void> logError({
    required String errorType, // 'ai_crash', 'network_error', etc
    required String message,
    required String context, // 'game_screen', 'network_match', etc
  }) async {
    if (_userId == null) return;
    try {
      await _firestore
          .collection('game_logs')
          .doc(_userId)
          .collection('logs')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'eventType': 'error',
        'errorType': errorType,
        'message': message,
        'context': context,
      });
    } catch (e) {
      // ロギング失敗は無視
    }
  }

  /// AI思考ログ
  static Future<void> logAIThinking({
    required int thinkingTimeMs,
    required int depth,
    required int evaluationScore,
  }) async {
    if (_userId == null) return;
    try {
      await _firestore
          .collection('game_logs')
          .doc(_userId)
          .collection('logs')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'eventType': 'ai_thinking',
        'thinkingTimeMs': thinkingTimeMs,
        'depth': depth,
        'evaluationScore': evaluationScore,
      });
    } catch (e) {
      // ロギング失敗は無視
    }
  }

  /// ゲーム統計を取得
  static Future<Map<String, dynamic>> getGameStats() async {
    if (_userId == null) return {};
    try {
      final snapshot = await _firestore
          .collection('game_logs')
          .doc(_userId)
          .collection('logs')
          .where('eventType', isEqualTo: 'end')
          .get();

      int totalGames = snapshot.docs.length;
      int wins = snapshot.docs.where((d) => d['playerWon'] == true).length;
      int totalMoves =
          snapshot.docs.fold<int>(0, (sum, d) => sum + ((d['moveCount'] as int?) ?? 0));

      return {
        'totalGames': totalGames,
        'wins': wins,
        'losses': totalGames - wins,
        'winRate': totalGames > 0 ? (wins / totalGames * 100).toStringAsFixed(1) : '0.0',
        'averageMoves': totalGames > 0 ? (totalMoves / totalGames).toStringAsFixed(1) : '0',
      };
    } catch (e) {
      return {};
    }
  }
}
