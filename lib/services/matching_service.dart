// lib/services/matching_service.dart
// マッチングシステム

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/matching_queue.dart';
import '../models/user_profile.dart';
import '../stats_screen.dart' show rankTable, ratingToRank;
import 'fcm_service.dart';

class MatchingService {
  static final MatchingService _instance = MatchingService._internal();

  factory MatchingService() {
    return _instance;
  }

  MatchingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FcmService _fcmService = FcmService();

  // マッチングタイムアウト（秒）
  static const matchingTimeoutSeconds = 300; // 5分

  // ── マッチング待機 ────────────────────────────

  /// 現在のレーティングが属する段級位の範囲 [minRating, maxRating) を返す。
  /// ランク帯マッチング（同じ段級位の相手とのみ対戦）に使用する。
  (int, int) _rankTierBounds(int rating) {
    for (int i = 0; i < rankTable.length; i++) {
      if (rating >= rankTable[i].minRating) {
        final maxRating = i == 0 ? 9999 : rankTable[i - 1].minRating - 1;
        return (rankTable[i].minRating, maxRating);
      }
    }
    return (0, rankTable.last.minRating - 1);
  }

  /// マッチング待機キューに参加
  /// [ratingRange]: 対戦相手レーティング許容範囲（±100等）。[rankTierOnly]がtrueの場合は無視される
  /// [clubMatchOnly]: trueの場合、同クラブ限定マッチング
  /// [rankTierOnly]: trueの場合、同じ段級位（例: 初段同士）の相手とのみマッチングする
  Future<String> joinMatchingQueue(
    String userId,
    UserProfile userProfile,
    int ratingRange, {
    bool clubMatchOnly = false,
    bool rankTierOnly = false,
  }) async {
    try {
      // 同一ユーザーの既存の待機中エントリを無効化（二重申込による多重マッチ防止）
      try {
        final existing = await _firestore
            .collection('matching_queue')
            .where('user_id', isEqualTo: userId)
            .where('status', isEqualTo: 'waiting')
            .get();
        for (final doc in existing.docs) {
          await doc.reference.update({'status': 'cancelled'});
        }
      } catch (_) {}

      // ユーザーの所属クラブを取得
      List<String> clubIds = [];
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        clubIds = (userDoc.data()?['club_ids'] as List?)?.cast<String>() ?? [];
      } catch (_) {}

      final queueRef = _firestore.collection('matching_queue').doc();

      int minRating;
      int maxRating;
      if (rankTierOnly) {
        final (tierMin, tierMax) = _rankTierBounds(userProfile.rating);
        minRating = tierMin;
        maxRating = tierMax;
      } else {
        minRating = (userProfile.rating - ratingRange).clamp(0, 3500);
        maxRating = userProfile.rating + ratingRange;
      }

      final queue = MatchingQueue(
        id: queueRef.id,
        userId: userId,
        username: userProfile.username,
        rating: userProfile.rating,
        minRatingRange: minRating,
        maxRatingRange: maxRating,
        queuedAt: DateTime.now(),
        status: 'waiting',
        clubIds: clubIds,
        clubMatchOnly: clubMatchOnly,
      );

      await queueRef.set({
        ...queue.toJson(),
        'expires_at': Timestamp.fromDate(
            DateTime.now().add(const Duration(minutes: 10))),
      });

      // 古いエントリを非同期でクリーンアップ（Cloud Functionもあるが念のため）
      Future.microtask(_cleanupExpiredEntries);

      // マッチング試行（即座に相手を探す）
      await _tryMatchmaking(queue);

      return queueRef.id;
    } catch (e) {
      print('Join matching queue error: $e');
      rethrow;
    }
  }

  /// マッチング待機をキャンセル
  Future<void> cancelMatchingQueue(String queueId) async {
    try {
      await _firestore.collection('matching_queue').doc(queueId).update({
        'status': 'cancelled',
      });
    } catch (e) {
      print('Cancel matching queue error: $e');
    }
  }

  // ── 自動マッチング ────────────────────────────

  /// マッチメイキング試行（同クラブ優先）
  Future<void> _tryMatchmaking(MatchingQueue queue) async {
    try {
      // 待機中の他ユーザーを検索
      final otherQueues = await _firestore
          .collection('matching_queue')
          .where('status', isEqualTo: 'waiting')
          .where('user_id', isNotEqualTo: queue.userId)
          .orderBy('created_at') // uses the composite index from firestore.indexes.json
          .limit(50)             // limit to prevent full table scan
          .get();

      // ブロック済みユーザーIDを取得（自分がブロックした相手を除外）
      final blockedSnap = await _firestore
          .collection('users')
          .doc(queue.userId)
          .collection('blocked_users')
          .get();
      final blocked = blockedSnap.docs.map((d) => d.id).toSet();

      final candidates = <MatchingQueue>[];
      for (final doc in otherQueues.docs) {
        final otherQueue = MatchingQueue.fromJson(doc.data());
        // ブロック済みはスキップ
        if (blocked.contains(otherQueue.userId)) continue;
        // 双方向でレーティング範囲内か確認
        if (queue.canMatch(otherQueue.rating) &&
            otherQueue.canMatch(queue.rating)) {
          // 相手がクラブ限定の場合、共通クラブが必要
          if (otherQueue.clubMatchOnly && !queue.shareClub(otherQueue)) continue;
          candidates.add(otherQueue);
        }
      }

      if (candidates.isEmpty) {
        // クラブ限定モードで見つからない場合もタイムアウトを設定
        _setMatchingTimeout(queue.id);
        return;
      }

      // 同クラブメンバーを優先（共通クラブがある相手を先に試す）
      candidates.sort((a, b) {
        final aShares = queue.shareClub(a) ? 0 : 1;
        final bShares = queue.shareClub(b) ? 0 : 1;
        return aShares.compareTo(bShares);
      });

      // 自分がクラブ限定の場合は同クラブのみ
      if (queue.clubMatchOnly) {
        final clubMatch = candidates.where((c) => queue.shareClub(c)).toList();
        if (clubMatch.isNotEmpty) {
          await _createMatch(queue, clubMatch.first);
          return;
        }
        _setMatchingTimeout(queue.id);
        return;
      }

      // 通常マッチング（同クラブ優先）
      await _createMatch(queue, candidates.first);
    } catch (e) {
      print('Try matchmaking error: $e');
    }
  }

  /// マッチング成立 → Match ドキュメント作成
  Future<void> _createMatch(
    MatchingQueue queue1,
    MatchingQueue queue2,
  ) async {
    try {
      final matchRef = _firestore.collection('matches').doc();
      final now = DateTime.now();

      await matchRef.set({
        'id': matchRef.id,
        'player1_id': queue1.userId,
        'player1_name': queue1.username,
        'player1_rating': queue1.rating,
        'player2_id': queue2.userId,
        'player2_name': queue2.username,
        'player2_rating': queue2.rating,
        'board_state': '', // 初期盤面（詰将棋なら空）
        'current_turn': 1, // 先手のターン
        'moves': [], // 指し手の履歴
        'player1_time': 600, // 時間（秒）
        'player2_time': 600,
        'status': 'playing', // playing, finished, cancelled
        'winner': null,
        'result': null, // 'checkmate', 'resignation', 'timeout', 'draw'
        'created_at': now,
        'started_at': now,
        'finished_at': null,
      });

      // マッチング待機キューを更新
      await _firestore.collection('matching_queue').doc(queue1.id).update({
        'status': 'matched',
        'matched_with': queue2.userId,
        'match_id': matchRef.id,
      });

      await _firestore.collection('matching_queue').doc(queue2.id).update({
        'status': 'matched',
        'matched_with': queue1.userId,
        'match_id': matchRef.id,
      });

      // ✅ FCM通知：両プレイヤーに対局開始を通知
      Future.microtask(() async {
        await _fcmService.notifyMatchFound(
          recipientId: queue1.userId,
          opponentName: queue2.username,
          opponentRating: queue2.rating,
          matchId: matchRef.id,
        );
        await _fcmService.notifyMatchFound(
          recipientId: queue2.userId,
          opponentName: queue1.username,
          opponentRating: queue1.rating,
          matchId: matchRef.id,
        );
      });

      print('Match created: ${matchRef.id}');
    } catch (e) {
      print('Create match error: $e');
    }
  }

  /// 期限切れのキューエントリをexpiredに更新
  Future<void> _cleanupExpiredEntries() async {
    try {
      final now = Timestamp.now();
      final stale = await _firestore
          .collection('matching_queue')
          .where('status', isEqualTo: 'waiting')
          .where('expires_at', isLessThan: now)
          .limit(20)
          .get();
      final batch = _firestore.batch();
      for (final doc in stale.docs) {
        batch.update(doc.reference, {'status': 'expired'});
      }
      if (stale.docs.isNotEmpty) await batch.commit();
    } catch (_) {}
  }

  /// マッチングタイムアウト設定（5分待機して見つからない場合キャンセル）
  void _setMatchingTimeout(String queueId) {
    Future.delayed(const Duration(seconds: matchingTimeoutSeconds), () async {
      try {
        final doc = await _firestore
            .collection('matching_queue')
            .doc(queueId)
            .get();

        if (doc.exists && doc['status'] == 'waiting') {
          await cancelMatchingQueue(queueId);
          print('Matching timeout for queue: $queueId');
        }
      } catch (e) {
        print('Matching timeout error: $e');
      }
    });
  }

  // ── マッチング状態監視 ────────────────────────────

  /// マッチング待機キューをリアルタイム監視
  Stream<MatchingQueue?> watchMatchingQueue(String queueId) {
    return _firestore
        .collection('matching_queue')
        .doc(queueId)
        .snapshots()
        .map((doc) {
      return doc.exists ? MatchingQueue.fromJson(doc.data()!) : null;
    });
  }

  /// マッチを監視
  Stream<Map<String, dynamic>?> watchMatch(String matchId) {
    return _firestore.collection('matches').doc(matchId).snapshots().map((doc) {
      return doc.exists ? doc.data() : null;
    });
  }


  /// マッチをキャンセル（接続エラー等）
  Future<void> cancelMatch(String matchId) async {
    try {
      await _firestore.collection('matches').doc(matchId).update({
        'status': 'cancelled',
        'finished_at': DateTime.now(),
      });
    } catch (e) {
      print('Cancel match error: $e');
    }
  }
}
