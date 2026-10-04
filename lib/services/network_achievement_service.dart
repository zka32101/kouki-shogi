// lib/services/network_achievement_service.dart
// ネットワーク対局実績の追跡・解除

import 'package:cloud_firestore/cloud_firestore.dart';
import 'fcm_service.dart';

// ── 実績ID定数 ──────────────────────────────────────────────────

class AchievementId {
  // 対局系
  static const String netFirst = 'net_first';     // 初のネット対局
  static const String netWin1 = 'net_win_1';       // 初勝利
  static const String netWin10 = 'net_win_10';     // 10勝
  static const String netWin50 = 'net_win_50';     // 50勝
  static const String netWin100 = 'net_win_100';   // 100勝
  static const String netWin500 = 'net_win_500';   // 500勝
  static const String play100 = 'play_100';         // 100局
  static const String play500 = 'play_500';         // 500局

  // レーティング系
  static const String rating1600 = 'rating_1600'; // 1600達成
  static const String rating1800 = 'rating_1800'; // 1800達成
  static const String rating2000 = 'rating_2000'; // 2000達成
  static const String rating2200 = 'rating_2200'; // 2200達成
  static const String rating2500 = 'rating_2500'; // 2500達成

  // 連勝系
  static const String streak3 = 'streak_3';   // 3連勝
  static const String streak5 = 'streak_5';   // 5連勝
  static const String streak10 = 'streak_10'; // 10連勝

  // 終局方法系
  static const String win5Checkmate = 'win_5_checkmate'; // 詰みで5勝
  static const String win5Resign = 'win_5_resign';       // 投了で5勝

  // コミュニティ系
  static const String spectate10 = 'spectate_10';       // 10試合観戦
  static const String friend5 = 'friend_5';             // 5人フレンド
  static const String tournamentWin = 'tournament_win'; // トーナメント優勝

  // デイリー系
  static const String streak7Daily = 'streak_7_daily';  // 7日連続ログイン
  static const String streak30Daily = 'streak_30_daily'; // 30日連続ログイン
  static const String challenge100pt = 'challenge_100pt'; // 100pt以上獲得
}

// ── 実績定義 ──────────────────────────────────────────────────────

class AchievementDef {
  final String id;
  final String title;
  final String description;
  final String emoji;

  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
  });
}

const Map<String, AchievementDef> kAchievements = {
  AchievementId.netFirst: AchievementDef(
    id: AchievementId.netFirst,
    title: 'ネット初陣',
    description: '初めてネットワーク対局を行った',
    emoji: '🌐',
  ),
  AchievementId.netWin1: AchievementDef(
    id: AchievementId.netWin1,
    title: '初勝利',
    description: 'ネットワーク対局で初めて勝利した',
    emoji: '🥇',
  ),
  AchievementId.netWin10: AchievementDef(
    id: AchievementId.netWin10,
    title: '10勝達成',
    description: 'ネットワーク対局で10勝した',
    emoji: '🏅',
  ),
  AchievementId.netWin50: AchievementDef(
    id: AchievementId.netWin50,
    title: '50勝の猛者',
    description: 'ネットワーク対局で50勝した',
    emoji: '🏆',
  ),
  AchievementId.netWin100: AchievementDef(
    id: AchievementId.netWin100,
    title: '百戦百勝',
    description: 'ネットワーク対局で100勝した',
    emoji: '👑',
  ),
  AchievementId.netWin500: AchievementDef(
    id: AchievementId.netWin500,
    title: '将棋の達人',
    description: 'ネットワーク対局で500勝した',
    emoji: '⚡',
  ),
  AchievementId.play100: AchievementDef(
    id: AchievementId.play100,
    title: '百試合の経験',
    description: 'ネットワーク対局を100局行った',
    emoji: '📚',
  ),
  AchievementId.play500: AchievementDef(
    id: AchievementId.play500,
    title: '五百試合の猛者',
    description: 'ネットワーク対局を500局行った',
    emoji: '🎖️',
  ),
  AchievementId.rating1600: AchievementDef(
    id: AchievementId.rating1600,
    title: '有段者',
    description: 'レーティングが1600を超えた',
    emoji: '📊',
  ),
  AchievementId.rating1800: AchievementDef(
    id: AchievementId.rating1800,
    title: '上位プレイヤー',
    description: 'レーティングが1800を超えた',
    emoji: '⬆️',
  ),
  AchievementId.rating2000: AchievementDef(
    id: AchievementId.rating2000,
    title: '達人の域',
    description: 'レーティングが2000を超えた',
    emoji: '🎯',
  ),
  AchievementId.rating2200: AchievementDef(
    id: AchievementId.rating2200,
    title: '高段者',
    description: 'レーティングが2200を超えた',
    emoji: '🌟',
  ),
  AchievementId.rating2500: AchievementDef(
    id: AchievementId.rating2500,
    title: '将棋の神',
    description: 'レーティングが2500を超えた',
    emoji: '⚜️',
  ),
  AchievementId.streak3: AchievementDef(
    id: AchievementId.streak3,
    title: '3連勝',
    description: '3連勝を達成した',
    emoji: '🔥',
  ),
  AchievementId.streak5: AchievementDef(
    id: AchievementId.streak5,
    title: '5連勝',
    description: '5連勝を達成した',
    emoji: '💥',
  ),
  AchievementId.streak10: AchievementDef(
    id: AchievementId.streak10,
    title: '10連勝',
    description: '10連勝を達成した伝説',
    emoji: '🌠',
  ),
  AchievementId.win5Checkmate: AchievementDef(
    id: AchievementId.win5Checkmate,
    title: '詰み職人',
    description: '詰みで5勝した',
    emoji: '♟️',
  ),
  AchievementId.win5Resign: AchievementDef(
    id: AchievementId.win5Resign,
    title: '投了を引き出す',
    description: '相手の投了で5勝した',
    emoji: '🤝',
  ),
  AchievementId.spectate10: AchievementDef(
    id: AchievementId.spectate10,
    title: '観戦好き',
    description: '10試合観戦した',
    emoji: '👁️',
  ),
  AchievementId.friend5: AchievementDef(
    id: AchievementId.friend5,
    title: '友達の輪',
    description: '5人フレンドになった',
    emoji: '🤗',
  ),
  AchievementId.tournamentWin: AchievementDef(
    id: AchievementId.tournamentWin,
    title: 'トーナメント覇者',
    description: 'トーナメントで優勝した',
    emoji: '🏆',
  ),
  AchievementId.streak7Daily: AchievementDef(
    id: AchievementId.streak7Daily,
    title: '週7皆勤',
    description: '7日連続でログインした',
    emoji: '📅',
  ),
  AchievementId.streak30Daily: AchievementDef(
    id: AchievementId.streak30Daily,
    title: '30日皆勤',
    description: '30日連続でログインした',
    emoji: '🗓️',
  ),
  AchievementId.challenge100pt: AchievementDef(
    id: AchievementId.challenge100pt,
    title: 'チャレンジャー',
    description: 'デイリーチャレンジで100pt以上獲得した',
    emoji: '⭐',
  ),
};

// ── サービス ────────────────────────────────────────────────────

class NetworkAchievementService {
  static final NetworkAchievementService _instance =
      NetworkAchievementService._internal();
  factory NetworkAchievementService() => _instance;
  NetworkAchievementService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FcmService _fcmService = FcmService();

  // ── 解除チェック ──────────────────────────────────────────────

  /// ネット対局終了後に全実績をチェック
  Future<List<String>> checkAfterMatch({
    required String userId,
    required bool won,
    required String result, // 'checkmate', 'resignation', 'timeout', 'draw'
    required int newRating,
    required int totalWins,
    required int totalMatches,
  }) async {
    final unlocked = <String>[];

    // 初対局
    if (totalMatches == 1) {
      await _unlock(userId, AchievementId.netFirst, unlocked);
    }

    // 初勝利
    if (won && totalWins == 1) {
      await _unlock(userId, AchievementId.netWin1, unlocked);
    }

    // 勝利数
    if (won) {
      if (totalWins == 10) await _unlock(userId, AchievementId.netWin10, unlocked);
      if (totalWins == 50) await _unlock(userId, AchievementId.netWin50, unlocked);
      if (totalWins == 100) await _unlock(userId, AchievementId.netWin100, unlocked);
      if (totalWins == 500) await _unlock(userId, AchievementId.netWin500, unlocked);
    }

    // 対局数
    if (totalMatches == 100) await _unlock(userId, AchievementId.play100, unlocked);
    if (totalMatches == 500) await _unlock(userId, AchievementId.play500, unlocked);

    // レーティング
    if (newRating >= 1600) await _unlock(userId, AchievementId.rating1600, unlocked);
    if (newRating >= 1800) await _unlock(userId, AchievementId.rating1800, unlocked);
    if (newRating >= 2000) await _unlock(userId, AchievementId.rating2000, unlocked);
    if (newRating >= 2200) await _unlock(userId, AchievementId.rating2200, unlocked);
    if (newRating >= 2500) await _unlock(userId, AchievementId.rating2500, unlocked);

    // 終局方法
    if (won && result == 'checkmate') {
      await _checkCount(
          userId, 'checkmate_wins', AchievementId.win5Checkmate, 5, unlocked);
    }
    if (won && result == 'resignation') {
      await _checkCount(
          userId, 'resign_wins', AchievementId.win5Resign, 5, unlocked);
    }

    // FCM通知（解除したものそれぞれ）
    for (final id in unlocked) {
      final def = kAchievements[id];
      if (def != null) {
        await _fcmService.notifyAchievementUnlocked(
          recipientId: userId,
          achievementName: '${def.emoji} ${def.title}',
          achievementId: id,
        );
      }
    }

    return unlocked;
  }

  /// 連勝チェック（別途 streak フィールドを管理）
  Future<List<String>> checkStreak(String userId, int currentStreak) async {
    final unlocked = <String>[];
    if (currentStreak >= 3) await _unlock(userId, AchievementId.streak3, unlocked);
    if (currentStreak >= 5) await _unlock(userId, AchievementId.streak5, unlocked);
    if (currentStreak >= 10) await _unlock(userId, AchievementId.streak10, unlocked);
    return unlocked;
  }

  /// 観戦チェック
  Future<List<String>> checkSpectate(String userId) async {
    final unlocked = <String>[];
    await _checkCount(
        userId, 'spectate_count', AchievementId.spectate10, 10, unlocked);
    return unlocked;
  }

  /// フレンド数チェック
  Future<List<String>> checkFriendCount(String userId, int count) async {
    final unlocked = <String>[];
    if (count >= 5) await _unlock(userId, AchievementId.friend5, unlocked);
    return unlocked;
  }

  /// トーナメント優勝
  Future<List<String>> checkTournamentWin(String userId) async {
    final unlocked = <String>[];
    await _unlock(userId, AchievementId.tournamentWin, unlocked);
    return unlocked;
  }

  /// ログインストリーク
  Future<List<String>> checkLoginStreak(String userId, int streak) async {
    final unlocked = <String>[];
    if (streak >= 7) await _unlock(userId, AchievementId.streak7Daily, unlocked);
    if (streak >= 30) await _unlock(userId, AchievementId.streak30Daily, unlocked);
    return unlocked;
  }

  /// チャレンジポイント
  Future<List<String>> checkChallengePoints(String userId, int points) async {
    final unlocked = <String>[];
    if (points >= 100) {
      await _unlock(userId, AchievementId.challenge100pt, unlocked);
    }
    return unlocked;
  }

  // ── 解除済み実績取得 ──────────────────────────────────────────

  Future<List<String>> getUnlockedAchievements(String userId) async {
    try {
      final doc =
          await _firestore.collection('users').doc(userId).get();
      final achievements =
          (doc['achievements'] as List?)?.cast<String>() ?? [];
      return achievements;
    } catch (e) {
      return [];
    }
  }

  Stream<List<String>> watchUnlockedAchievements(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => !doc.exists
            ? <String>[]
            : (doc.data()?['achievements'] as List?)?.cast<String>() ?? []);
  }

  // ── 内部ヘルパー ──────────────────────────────────────────────

  Future<void> _unlock(
    String userId,
    String achievementId,
    List<String> unlocked,
  ) async {
    try {
      final doc =
          await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return;

      final existing =
          (doc['achievements'] as List?)?.cast<String>() ?? [];
      if (existing.contains(achievementId)) return; // 既解除

      await _firestore.collection('users').doc(userId).update({
        'achievements': FieldValue.arrayUnion([achievementId]),
        'achievement_unlocked_at.$achievementId':
            FieldValue.serverTimestamp(),
      });

      unlocked.add(achievementId);
    } catch (e) {
      print('Unlock achievement error: $e');
    }
  }

  /// カウントフィールドをインクリメントして閾値で解除
  Future<void> _checkCount(
    String userId,
    String field,
    String achievementId,
    int threshold,
    List<String> unlocked,
  ) async {
    try {
      await _firestore.runTransaction((tx) async {
        final ref = _firestore.collection('users').doc(userId);
        final doc = await tx.get(ref);
        if (!doc.exists) return;

        final current = doc[field] as int? ?? 0;
        final newCount = current + 1;
        tx.update(ref, {field: newCount});

        if (newCount >= threshold) {
          await _unlock(userId, achievementId, unlocked);
        }
      });
    } catch (e) {
      print('Check count achievement error: $e');
    }
  }
}
