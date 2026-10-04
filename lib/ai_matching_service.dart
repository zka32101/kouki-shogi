// lib/ai_matching_service.dart
// AI棋風マッチング - 棋風診断とゴースト棋士から対手を推奨

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ghost_service.dart';
import 'ai_personality.dart';

class AiMatchingSuggestion {
  final String ghostUid;
  final String displayName;
  final String personalityType;
  final double matchScore; // 0.0-1.0, 高いほど相性良好
  final String reason; // マッチング理由

  AiMatchingSuggestion({
    required this.ghostUid,
    required this.displayName,
    required this.personalityType,
    required this.matchScore,
    required this.reason,
  });
}

class AiMatchingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// プレイヤーの棋風に基づいて、相手を推奨
  static Future<List<AiMatchingSuggestion>> getMatchingSuggestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // プレイヤーの棋風統計を取得
      final totalMoves = prefs.getInt('playstyle_total') ?? 0;
      if (totalMoves == 0) return [];

      final attack = prefs.getInt('playstyle_attack') ?? 0;
      final retreat = prefs.getInt('playstyle_retreat') ?? 0;
      final drop = prefs.getInt('playstyle_drop') ?? 0;

      final attackRatio = attack / totalMoves;
      final retreatRatio = retreat / totalMoves;
      final dropRatio = drop / totalMoves;

      // プレイヤーのパーソナリティを計算
      final playerPers = GhostPersonalityData.fromPlaystyleStats(
        attackRatio: attackRatio,
        retreatRatio: retreatRatio,
        dropRatio: dropRatio,
      );

      // Firestoreからゴーストを取得
      final ghostSnap = await _firestore.collection('ghosts').limit(50).get();

      final suggestions = <AiMatchingSuggestion>[];
      for (final doc in ghostSnap.docs) {
        final ghost = GhostOpponent.fromDoc(doc);
        if (ghost == null) continue;

        // マッチスコアを計算
        final score = _calculateMatchScore(playerPers, ghost.personality);
        final reason = _getMatchReason(playerPers, ghost.personality);

        suggestions.add(AiMatchingSuggestion(
          ghostUid: ghost.uid,
          displayName: ghost.displayName,
          personalityType: ghost.personality.typeName,
          matchScore: score,
          reason: reason,
        ));
      }

      // スコアでソート（高い順）
      suggestions.sort((a, b) => b.matchScore.compareTo(a.matchScore));
      return suggestions.take(5).toList(); // トップ5を返す
    } catch (_) {
      return [];
    }
  }

  /// 2つの棋風のマッチスコアを計算（補完性を評価）
  static double _calculateMatchScore(
    GhostPersonalityData player,
    GhostPersonalityData opponent,
  ) {
    // 攻守のバランスが補完関係にあるほど高スコア
    final attackDiff = (player.attackBias - opponent.attackBias).abs();
    final defenceDiff = (player.defenceBias - opponent.defenceBias).abs();
    final greedDiff = (player.greedBias - opponent.greedBias).abs();

    // 差が大きいほど補完的（最大で1.0）
    final balance = 1.0 - ((attackDiff + defenceDiff + greedDiff) / 9.0).clamp(0.0, 1.0);

    // 実力が近いほど+ボーナス
    final levelMatch = 0.5; // ゴースト棋士は同等レベルと仮定

    return (balance * 0.7 + levelMatch * 0.3).clamp(0.0, 1.0);
  }

  /// マッチング理由を生成
  static String _getMatchReason(
    GhostPersonalityData player,
    GhostPersonalityData opponent,
  ) {
    if (player.attackBias > 1.5 && opponent.defenceBias > 1.5) {
      return '攻守が補完的';
    } else if (player.greedBias > 1.2 && opponent.greedBias < 1.0) {
      return '駒活用スタイルが対照的';
    } else {
      return '棋風が相補的';
    }
  }

  /// 推奨相手と対局開始
  static Future<void> startMatchWithSuggestion(
    AiMatchingSuggestion suggestion,
  ) async {
    // ゴースト棋士と対局開始ロジック
    // game_screen.dart で opponentCharacterId を設定して AI 対局を開始
  }
}
