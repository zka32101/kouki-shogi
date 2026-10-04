// lib/services/daily_challenge_service.dart
// デイリーチャレンジ管理（ネットワーク実績と連携）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fcm_service.dart';
import 'network_achievement_service.dart';

// ── モデル ──────────────────────────────────────────────────────

enum ChallengeType {
  winMatch,       // 対局に勝つ
  winByCheckmate, // 詰みで勝つ
  winByResign,    // 投了で勝つ
  playMatches,    // N局指す
  winStreak,      // 連勝
  ratingGain,     // レーティング上昇
  spectateMatch,  // 観戦する
  useDrop,        // 打ち駒で勝つ
}

class DailyChallenge {
  final String id;
  final ChallengeType type;
  final String title;
  final String description;
  final int targetCount;
  final int rewardPoints; // ポイント報酬（将来の課金アイテム交換などに使用）
  final DateTime date; // yyyy-mm-dd の日付（チャレンジの有効期間）

  DailyChallenge({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.targetCount,
    required this.rewardPoints,
    required this.date,
  });

  factory DailyChallenge.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DailyChallenge(
      id: doc.id,
      type: ChallengeType.values.firstWhere(
        (t) => t.name == (d['type'] as String? ?? 'winMatch'),
        orElse: () => ChallengeType.winMatch,
      ),
      title: d['title'] as String? ?? 'チャレンジ',
      description: d['description'] as String? ?? '',
      targetCount: d['target_count'] as int? ?? 1,
      rewardPoints: d['reward_points'] as int? ?? 10,
      date: d['date'] is Timestamp
          ? (d['date'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class UserChallengeProgress {
  final String challengeId;
  final int currentCount;
  final bool completed;
  final bool rewardClaimed;
  final DateTime? completedAt;

  UserChallengeProgress({
    required this.challengeId,
    required this.currentCount,
    required this.completed,
    required this.rewardClaimed,
    this.completedAt,
  });

  factory UserChallengeProgress.fromJson(Map<String, dynamic> j) =>
      UserChallengeProgress(
        challengeId: j['challenge_id'] as String,
        currentCount: j['current_count'] as int? ?? 0,
        completed: j['completed'] as bool? ?? false,
        rewardClaimed: j['reward_claimed'] as bool? ?? false,
        completedAt: j['completed_at'] is Timestamp
            ? (j['completed_at'] as Timestamp).toDate()
            : null,
      );
}

// ── サービス ────────────────────────────────────────────────────

class DailyChallengeService {
  static final DailyChallengeService _instance =
      DailyChallengeService._internal();
  factory DailyChallengeService() => _instance;
  DailyChallengeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FcmService _fcmService = FcmService();

  // ── 今日のチャレンジ取得 ──────────────────────────────────────

  String get _todayStr {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Stream<List<DailyChallenge>> watchTodayChallenges() {
    final todayStart = DateTime.now();
    final start = DateTime(todayStart.year, todayStart.month, todayStart.day);
    final end = start.add(const Duration(days: 1));

    return _firestore
        .collection('daily_challenges')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((s) => s.docs.map((d) => DailyChallenge.fromDoc(d)).toList());
  }

  Future<List<DailyChallenge>> getTodayChallenges() async {
    final todayStart = DateTime.now();
    final start = DateTime(todayStart.year, todayStart.month, todayStart.day);
    final end = start.add(const Duration(days: 1));

    final snap = await _firestore
        .collection('daily_challenges')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    if (snap.docs.isEmpty) {
      // まだ今日のチャレンジがない場合は自動生成
      await _generateTodayChallenges();
      return getTodayChallenges();
    }

    return snap.docs.map((d) => DailyChallenge.fromDoc(d)).toList();
  }

  // ── チャレンジ自動生成 ────────────────────────────────────────

  Future<void> _generateTodayChallenges() async {
    final today = DateTime.now();
    final dateStr = _todayStr;

    // 既存確認
    final check = await _firestore
        .collection('daily_challenges')
        .where('date_str', isEqualTo: dateStr)
        .get();
    if (check.docs.isNotEmpty) return;

    // 曜日ベースのルーテーション（月=0...日=6）
    final weekday = today.weekday - 1; // 0=月...6=日

    final templates = [
      // 月
      [
        {
          'type': 'winMatch',
          'title': '勝利を掴め',
          'description': 'ネットワーク対局で1勝しよう',
          'target_count': 1,
          'reward_points': 10,
        },
        {
          'type': 'playMatches',
          'title': '対局デビュー',
          'description': '本日中に3局指そう',
          'target_count': 3,
          'reward_points': 15,
        },
      ],
      // 火
      [
        {
          'type': 'winByCheckmate',
          'title': '詰み職人',
          'description': '詰みで対局を終わらせよう',
          'target_count': 1,
          'reward_points': 15,
        },
        {
          'type': 'ratingGain',
          'title': 'レーティングアップ',
          'description': 'レーティングを10以上上げよう',
          'target_count': 10,
          'reward_points': 20,
        },
      ],
      // 水
      [
        {
          'type': 'winMatch',
          'title': '連勝チャレンジ',
          'description': 'ネットワーク対局で2勝しよう',
          'target_count': 2,
          'reward_points': 20,
        },
        {
          'type': 'spectateMatch',
          'title': '観戦学習',
          'description': 'ライブ対局を1試合観戦しよう',
          'target_count': 1,
          'reward_points': 5,
        },
      ],
      // 木
      [
        {
          'type': 'winByResign',
          'title': '投了へ誘う',
          'description': '相手の投了で勝利しよう',
          'target_count': 1,
          'reward_points': 15,
        },
        {
          'type': 'playMatches',
          'title': '精力的な対局',
          'description': '本日中に5局指そう',
          'target_count': 5,
          'reward_points': 25,
        },
      ],
      // 金
      [
        {
          'type': 'winStreak',
          'title': '連勝記録',
          'description': '2連勝を達成しよう',
          'target_count': 2,
          'reward_points': 25,
        },
        {
          'type': 'ratingGain',
          'title': '週末前ダッシュ',
          'description': 'レーティングを20以上上げよう',
          'target_count': 20,
          'reward_points': 30,
        },
      ],
      // 土
      [
        {
          'type': 'winMatch',
          'title': '土曜の闘士',
          'description': 'ネットワーク対局で3勝しよう',
          'target_count': 3,
          'reward_points': 30,
        },
        {
          'type': 'useDrop',
          'title': '打ち駒マスター',
          'description': '打ち駒で相手を詰ませよう',
          'target_count': 1,
          'reward_points': 20,
        },
      ],
      // 日
      [
        {
          'type': 'winMatch',
          'title': '日曜勝負師',
          'description': 'ネットワーク対局で3勝しよう',
          'target_count': 3,
          'reward_points': 35,
        },
        {
          'type': 'winByCheckmate',
          'title': '詰将棋の達人',
          'description': '詰みで2勝しよう',
          'target_count': 2,
          'reward_points': 25,
        },
      ],
    ];

    final todayTemplates = templates[weekday % 7];
    final batch = _firestore.batch();
    for (var i = 0; i < todayTemplates.length; i++) {
      // 日付+インデックスの決定的なIDにすることで、複数端末が同時に
      // 生成しても重複ドキュメントが作られない（同じIDへの上書きになる）
      final ref = _firestore.collection('daily_challenges').doc('${dateStr}_$i');
      batch.set(ref, {
        ...todayTemplates[i],
        'date': Timestamp.fromDate(
            DateTime(today.year, today.month, today.day)),
        'date_str': dateStr,
      });
    }
    await batch.commit();
  }

  // ── 進捗更新 ──────────────────────────────────────────────────

  /// 対局結果に応じてチャレンジ進捗を更新
  Future<void> updateProgress({
    required String userId,
    required ChallengeType type,
    required int amount, // 達成量
    String? matchResult, // 'checkmate', 'resignation', 'timeout', 'draw'
    bool won = false,
  }) async {
    try {
      final challenges = await getTodayChallenges();
      final relevantChallenges =
          challenges.where((c) => c.type == type).toList();

      for (final challenge in relevantChallenges) {
        await _incrementProgress(
          userId: userId,
          challenge: challenge,
          amount: amount,
        );
      }
    } catch (e) {
      print('Update challenge progress error: $e');
    }
  }

  /// ネットワーク対局終了後に全チャレンジタイプを一括更新
  Future<void> onMatchFinished({
    required String userId,
    required bool won,
    required String result,
    required int ratingChange,
  }) async {
    try {
      // 対局回数
      await updateProgress(
          userId: userId, type: ChallengeType.playMatches, amount: 1);

      if (won) {
        // 勝利
        await updateProgress(
            userId: userId, type: ChallengeType.winMatch, amount: 1);
        // 詰み勝利
        if (result == 'checkmate') {
          await updateProgress(
              userId: userId,
              type: ChallengeType.winByCheckmate,
              amount: 1);
        }
        // 投了勝利
        if (result == 'resignation') {
          await updateProgress(
              userId: userId,
              type: ChallengeType.winByResign,
              amount: 1);
        }
      }

      // レーティング上昇
      if (ratingChange > 0) {
        await updateProgress(
            userId: userId,
            type: ChallengeType.ratingGain,
            amount: ratingChange);
      }
    } catch (e) {
      print('On match finished challenge update error: $e');
    }
  }

  Future<void> onSpectate(String userId) async {
    await updateProgress(
        userId: userId, type: ChallengeType.spectateMatch, amount: 1);
  }

  Future<void> _incrementProgress({
    required String userId,
    required DailyChallenge challenge,
    required int amount,
  }) async {
    final progressRef = _firestore
        .collection('user_challenge_progress')
        .doc('${userId}_${challenge.id}');

    bool justCompleted = false;

    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(progressRef);
      final current = doc.exists
          ? (doc['current_count'] as int? ?? 0)
          : 0;
      final alreadyCompleted =
          doc.exists ? (doc['completed'] as bool? ?? false) : false;

      if (alreadyCompleted) return;

      final newCount = current + amount;
      final completed = newCount >= challenge.targetCount;

      tx.set(
          progressRef,
          {
            'user_id': userId,
            'challenge_id': challenge.id,
            'current_count': newCount,
            'completed': completed,
            'reward_claimed': false,
            'updated_at': FieldValue.serverTimestamp(),
            if (completed)
              'completed_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      // 完了時にポイント付与
      if (completed && !alreadyCompleted) {
        tx.update(_firestore.collection('users').doc(userId), {
          'challenge_points':
              FieldValue.increment(challenge.rewardPoints),
        });
        justCompleted = true;
      }
    });

    // チャレンジポイント実績判定（累計ポイントで判定）
    if (justCompleted) {
      try {
        final userDoc =
            await _firestore.collection('users').doc(userId).get();
        final totalPoints = userDoc.data()?['challenge_points'] as int? ?? 0;
        await NetworkAchievementService()
            .checkChallengePoints(userId, totalPoints);
      } catch (_) {}
    }
  }

  // ── 進捗取得 ──────────────────────────────────────────────────

  Stream<Map<String, UserChallengeProgress>> watchMyProgress(
      String userId) {
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return _firestore
        .collection('user_challenge_progress')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .asyncMap((snap) async {
      final challenges = await getTodayChallenges();
      final challengeIds = challenges.map((c) => c.id).toSet();

      final Map<String, UserChallengeProgress> progress = {};
      for (final doc in snap.docs) {
        final d = doc.data();
        final cId = d['challenge_id'] as String? ?? '';
        if (challengeIds.contains(cId)) {
          progress[cId] = UserChallengeProgress.fromJson(d);
        }
      }
      return progress;
    });
  }

  // ── 連続ログインストリーク ────────────────────────────────────

  Future<int> updateLoginStreak(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastLoginKey = 'last_login_$userId';
      final streakKey = 'login_streak_$userId';

      final lastLoginStr = prefs.getString(lastLoginKey);
      final today = _todayStr;

      int streak = prefs.getInt(streakKey) ?? 0;

      if (lastLoginStr == null) {
        // 初回
        streak = 1;
      } else {
        final lastDate = DateTime.parse(lastLoginStr);
        final diff = DateTime.now().difference(lastDate).inDays;
        if (diff == 0) {
          // 今日すでにログイン済み
          return streak;
        } else if (diff == 1) {
          // 翌日ログイン→ストリーク継続
          streak++;
        } else {
          // 1日以上空いた
          streak = 1;
        }
      }

      await prefs.setString(lastLoginKey, today);
      await prefs.setInt(streakKey, streak);

      // Firestoreにも保存
      await _firestore.collection('users').doc(userId).update({
        'login_streak': streak,
        'last_login': FieldValue.serverTimestamp(),
      });

      return streak;
    } catch (e) {
      print('Update login streak error: $e');
      return 0;
    }
  }

  Future<int> getLoginStreak(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('login_streak_$userId') ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ── チャレンジポイント ────────────────────────────────────────

  Future<int> getChallengePoints(String userId) async {
    try {
      final doc =
          await _firestore.collection('users').doc(userId).get();
      return doc['challenge_points'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
