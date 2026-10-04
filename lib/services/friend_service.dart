// lib/services/friend_service.dart
// フレンドシステム（申請・承認・対局招待）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'fcm_service.dart';
import 'network_achievement_service.dart';

// ── モデル ──────────────────────────────────────────────────────

enum FriendStatus { pending, accepted, declined, blocked }

class FriendRequest {
  final String id;
  final String senderId;
  final String senderName;
  final int senderRating;
  final String recipientId;
  final FriendStatus status;
  final DateTime createdAt;

  FriendRequest({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRating,
    required this.recipientId,
    required this.status,
    required this.createdAt,
  });

  factory FriendRequest.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FriendRequest(
      id: doc.id,
      senderId: d['sender_id'] as String,
      senderName: d['sender_name'] as String? ?? '?',
      senderRating: d['sender_rating'] as int? ?? 1500,
      recipientId: d['recipient_id'] as String,
      status: FriendStatus.values.firstWhere(
        (s) => s.name == (d['status'] as String? ?? 'pending'),
        orElse: () => FriendStatus.pending,
      ),
      createdAt: d['created_at'] is Timestamp
          ? (d['created_at'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class FriendInfo {
  final String userId;
  final String username;
  final int rating;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? currentMatchId;

  FriendInfo({
    required this.userId,
    required this.username,
    required this.rating,
    required this.isOnline,
    this.lastSeen,
    this.currentMatchId,
  });

  factory FriendInfo.fromJson(Map<String, dynamic> j) => FriendInfo(
        userId: j['user_id'] as String,
        username: j['username'] as String? ?? '?',
        rating: j['rating'] as int? ?? 1500,
        isOnline: j['is_online'] as bool? ?? false,
        lastSeen: j['last_seen'] is Timestamp
            ? (j['last_seen'] as Timestamp).toDate()
            : null,
        currentMatchId: j['current_match_id'] as String?,
      );
}

class DirectChallenge {
  final String id;
  final String senderId;
  final String senderName;
  final int senderRating;
  final String recipientId;
  final String status; // pending, accepted, declined, expired
  final DateTime createdAt;

  DirectChallenge({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRating,
    required this.recipientId,
    required this.status,
    required this.createdAt,
  });

  factory DirectChallenge.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DirectChallenge(
      id: doc.id,
      senderId: d['sender_id'] as String,
      senderName: d['sender_name'] as String? ?? '?',
      senderRating: d['sender_rating'] as int? ?? 1500,
      recipientId: d['recipient_id'] as String,
      status: d['status'] as String? ?? 'pending',
      createdAt: d['created_at'] is Timestamp
          ? (d['created_at'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

// ── サービス ────────────────────────────────────────────────────

class FriendService {
  static final FriendService _instance = FriendService._internal();
  factory FriendService() => _instance;
  FriendService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FcmService _fcmService = FcmService();
  final NetworkAchievementService _achievementService =
      NetworkAchievementService();

  // ── フレンド申請 ──────────────────────────────────────────────

  Future<bool> sendFriendRequest({
    required String senderId,
    required String senderName,
    required int senderRating,
    required String recipientId,
  }) async {
    try {
      // 自分への申請はNG
      if (senderId == recipientId) return false;

      // すでにフレンドか確認
      final existing = await _firestore
          .collection('friends')
          .doc(_friendDocId(senderId, recipientId))
          .get();
      if (existing.exists) return false;

      // 申請済み確認
      final pendingQuery = await _firestore
          .collection('friend_requests')
          .where('sender_id', isEqualTo: senderId)
          .where('recipient_id', isEqualTo: recipientId)
          .where('status', isEqualTo: 'pending')
          .get();
      if (pendingQuery.docs.isNotEmpty) return false;

      // 相手からの申請が既にある場合は自動承認
      final reverseQuery = await _firestore
          .collection('friend_requests')
          .where('sender_id', isEqualTo: recipientId)
          .where('recipient_id', isEqualTo: senderId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (reverseQuery.docs.isNotEmpty) {
        // 相互承認
        final reverseId = reverseQuery.docs.first.id;
        await acceptFriendRequest(reverseId, senderId, recipientId);
        return true;
      }

      // 新規申請
      final ref = _firestore.collection('friend_requests').doc();
      await ref.set({
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_rating': senderRating,
        'recipient_id': recipientId,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      });

      // FCM通知
      await _fcmService.notifyFriendRequest(
        recipientId: recipientId,
        senderName: senderName,
        senderId: senderId,
      );

      return true;
    } catch (e) {
      print('Send friend request error: $e');
      return false;
    }
  }

  Future<void> acceptFriendRequest(
    String requestId,
    String acceptorId,
    String requesterId,
  ) async {
    try {
      final batch = _firestore.batch();

      // 申請ステータス更新
      batch.update(_firestore.collection('friend_requests').doc(requestId), {
        'status': 'accepted',
        'accepted_at': FieldValue.serverTimestamp(),
      });

      // 両方のフレンドリストに追加
      final docId = _friendDocId(acceptorId, requesterId);

      // 双方の情報を取得
      final req = await _firestore
          .collection('friend_requests')
          .doc(requestId)
          .get();
      if (!req.exists) return;
      final reqData = req.data() as Map<String, dynamic>;
      final senderName = reqData['sender_name'] as String? ?? '?';
      final senderRating = reqData['sender_rating'] as int? ?? 1500;

      final acceptorDoc =
          await _firestore.collection('users').doc(acceptorId).get();
      final acceptorName =
          acceptorDoc['username'] as String? ?? '?';
      final acceptorRating =
          acceptorDoc['rating'] as int? ?? 1500;

      batch.set(_firestore.collection('friends').doc(docId), {
        'user1_id': requesterId,
        'user1_name': senderName,
        'user1_rating': senderRating,
        'user2_id': acceptorId,
        'user2_name': acceptorName,
        'user2_rating': acceptorRating,
        'created_at': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // フレンド数実績判定（両者とも1人増えたので判定し直す）
      for (final uid in [acceptorId, requesterId]) {
        final count = await _friendCount(uid);
        await _achievementService.checkFriendCount(uid, count);
      }
    } catch (e) {
      print('Accept friend request error: $e');
      rethrow;
    }
  }

  Future<int> _friendCount(String userId) async {
    final asUser1 = await _firestore
        .collection('friends')
        .where('user1_id', isEqualTo: userId)
        .count()
        .get();
    final asUser2 = await _firestore
        .collection('friends')
        .where('user2_id', isEqualTo: userId)
        .count()
        .get();
    return (asUser1.count ?? 0) + (asUser2.count ?? 0);
  }

  Future<void> declineFriendRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).update({
      'status': 'declined',
    });
  }

  Future<void> removeFriend(String userId, String friendId) async {
    final docId = _friendDocId(userId, friendId);
    await _firestore.collection('friends').doc(docId).delete();
  }

  // ── フレンドリスト取得 ────────────────────────────────────────

  Stream<List<FriendInfo>> watchFriends(String userId) {
    return _firestore
        .collection('friends')
        .where(Filter.or(
          Filter('user1_id', isEqualTo: userId),
          Filter('user2_id', isEqualTo: userId),
        ))
        .snapshots()
        .asyncMap((snap) async {
      final friends = <FriendInfo>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        final friendId = d['user1_id'] == userId
            ? d['user2_id'] as String
            : d['user1_id'] as String;
        try {
          final userDoc =
              await _firestore.collection('users').doc(friendId).get();
          if (userDoc.exists) {
            final ud = userDoc.data()!;
            friends.add(FriendInfo(
              userId: friendId,
              username: ud['username'] as String? ?? '?',
              rating: ud['rating'] as int? ?? 1500,
              isOnline: ud['is_online'] as bool? ?? false,
              lastSeen: ud['last_seen'] is Timestamp
                  ? (ud['last_seen'] as Timestamp).toDate()
                  : null,
              currentMatchId: ud['current_match_id'] as String?,
            ));
          }
        } catch (_) {}
      }
      friends.sort((a, b) {
        if (a.isOnline && !b.isOnline) return -1;
        if (!a.isOnline && b.isOnline) return 1;
        return b.rating.compareTo(a.rating);
      });
      return friends;
    });
  }

  Stream<List<FriendRequest>> watchIncomingRequests(String userId) {
    return _firestore
        .collection('friend_requests')
        .where('recipient_id', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => FriendRequest.fromDoc(d)).toList());
  }

  Future<bool> isFriend(String userId, String otherId) async {
    final doc = await _firestore
        .collection('friends')
        .doc(_friendDocId(userId, otherId))
        .get();
    return doc.exists;
  }

  // ── ユーザー検索 ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      // ユーザー名で前方一致検索
      final snap = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThan: '${query}z')
          .limit(20)
          .get();
      return snap.docs.map((d) {
        final data = d.data();
        return {
          'uid': d.id,
          'username': data['username'] as String? ?? '?',
          'rating': data['rating'] as int? ?? 1500,
          'is_banned': data['is_banned'] as bool? ?? false,
        };
      }).toList();
    } catch (e) {
      print('Search users error: $e');
      return [];
    }
  }

  // ── 対局招待 ──────────────────────────────────────────────────

  Future<String> sendDirectChallenge({
    required String senderId,
    required String senderName,
    required int senderRating,
    required String recipientId,
  }) async {
    try {
      final ref = _firestore.collection('direct_challenges').doc();
      await ref.set({
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_rating': senderRating,
        'recipient_id': recipientId,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
        'expires_at': Timestamp.fromDate(
            DateTime.now().add(const Duration(minutes: 5))),
      });

      await _fcmService.notifyFriendChallenge(
        recipientId: recipientId,
        senderName: senderName,
        challengeId: ref.id,
      );

      return ref.id;
    } catch (e) {
      print('Send direct challenge error: $e');
      rethrow;
    }
  }

  Future<void> respondToChallenge(
    String challengeId,
    bool accept,
  ) async {
    await _firestore
        .collection('direct_challenges')
        .doc(challengeId)
        .update({'status': accept ? 'accepted' : 'declined'});
  }

  Stream<DirectChallenge?> watchChallenge(String challengeId) {
    return _firestore
        .collection('direct_challenges')
        .doc(challengeId)
        .snapshots()
        .map((d) => d.exists ? DirectChallenge.fromDoc(d) : null);
  }

  Stream<List<DirectChallenge>> watchIncomingChallenges(String userId) {
    return _firestore
        .collection('direct_challenges')
        .where('recipient_id', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.map((d) => DirectChallenge.fromDoc(d)).toList());
  }

  // ── オンライン状態管理 ────────────────────────────────────────

  Future<void> setOnline(String userId, {String? currentMatchId}) async {
    await _firestore.collection('users').doc(userId).update({
      'is_online': true,
      'last_seen': FieldValue.serverTimestamp(),
      'current_match_id': currentMatchId,
    });
  }

  Future<void> setOffline(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'is_online': false,
      'last_seen': FieldValue.serverTimestamp(),
      'current_match_id': null,
    });
  }

  // ── ヘルパー ──────────────────────────────────────────────────

  /// 順序不問のフレンドドキュメントID（uid1_uid2 or uid2_uid1 の小さい方）
  String _friendDocId(String a, String b) {
    return a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';
  }
}
