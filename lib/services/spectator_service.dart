// lib/services/spectator_service.dart
// ライブ対局観戦サービス

import 'package:cloud_firestore/cloud_firestore.dart';
import 'board_sync_service.dart';
import 'network_achievement_service.dart';

/// 観戦中の対局情報
class LiveMatch {
  final String matchId;
  final String player1Name;
  final String player2Name;
  final int player1Rating;
  final int player2Rating;
  final int moveCount;
  final int spectatorCount;
  final DateTime startedAt;
  final String status;

  LiveMatch({
    required this.matchId,
    required this.player1Name,
    required this.player2Name,
    required this.player1Rating,
    required this.player2Rating,
    required this.moveCount,
    required this.spectatorCount,
    required this.startedAt,
    required this.status,
  });

  factory LiveMatch.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LiveMatch(
      matchId: doc.id,
      player1Name: d['player1_name'] as String? ?? '?',
      player2Name: d['player2_name'] as String? ?? '?',
      player1Rating: d['player1_rating'] as int? ?? 1500,
      player2Rating: d['player2_rating'] as int? ?? 1500,
      moveCount: (d['moves'] as List?)?.length ?? 0,
      spectatorCount: d['spectator_count'] as int? ?? 0,
      startedAt: d['started_at'] is Timestamp
          ? (d['started_at'] as Timestamp).toDate()
          : DateTime.now(),
      status: d['status'] as String? ?? 'playing',
    );
  }
}

class SpectatorService {
  static final SpectatorService _instance = SpectatorService._internal();
  factory SpectatorService() => _instance;
  SpectatorService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── ライブ対局一覧 ────────────────────────────────────────

  /// 現在進行中の対局一覧を取得（観戦者数・手数順）
  Stream<List<LiveMatch>> watchLiveMatches({int limit = 20}) {
    return _firestore
        .collection('matches')
        .where('status', isEqualTo: 'playing')
        .orderBy('spectator_count', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => LiveMatch.fromDoc(d)).toList());
  }

  // ── 観戦入室・退室 ────────────────────────────────────────

  /// 観戦を開始（観戦者数を +1）
  Future<void> joinSpectate(String matchId, String userId) async {
    try {
      final matchRef = _firestore.collection('matches').doc(matchId);
      final spectatorRef = matchRef.collection('spectators').doc(userId);
      await _firestore.runTransaction((tx) async {
        final doc = await tx.get(matchRef);
        if (!doc.exists) return;

        // 同一ユーザーの多重入室（画面再入場・initState複数回呼び出し等）で
        // 観戦者数が重複加算されないよう、既に観戦者リストにいれば加算しない
        final spectatorDoc = await tx.get(spectatorRef);
        if (spectatorDoc.exists) return;

        final count = doc['spectator_count'] as int? ?? 0;
        tx.update(matchRef, {'spectator_count': count + 1});
        tx.set(spectatorRef, {'joined_at': DateTime.now(), 'user_id': userId});
      });
    } catch (e) {
      print('Join spectate error: $e');
    }
  }

  /// 観戦を終了（観戦者数を -1）
  Future<void> leaveSpectate(String matchId, String userId) async {
    try {
      await _firestore.runTransaction((tx) async {
        final ref =
            _firestore.collection('matches').doc(matchId);
        final doc = await tx.get(ref);
        if (!doc.exists) return;

        final count = doc['spectator_count'] as int? ?? 0;
        tx.update(ref, {
          'spectator_count': count > 0 ? count - 1 : 0
        });
      });

      await _firestore
          .collection('matches')
          .doc(matchId)
          .collection('spectators')
          .doc(userId)
          .delete();

      // 観戦回数の実績判定（1試合の観戦終了ごとに+1）
      await NetworkAchievementService().checkSpectate(userId);
    } catch (e) {
      print('Leave spectate error: $e');
    }
  }

  // ── 盤面ストリーム（観戦用） ──────────────────────────────

  Stream<NetworkBoardState?> watchBoardAsSpectator(String matchId) {
    return BoardSyncService().watchBoardState(matchId);
  }

  // ── 観戦コメント ──────────────────────────────────────────

  Future<void> sendSpectatorComment(
      String matchId, String userId, String username, String text) async {
    try {
      if (text.trim().isEmpty || text.length > 100) return;

      await _firestore
          .collection('matches')
          .doc(matchId)
          .collection('spectator_chat')
          .add({
        'user_id': userId,
        'username': username,
        'text': text.trim(),
        'sent_at': DateTime.now(),
      });
    } catch (e) {
      print('Send spectator comment error: $e');
    }
  }

  Stream<QuerySnapshot> watchSpectatorChat(String matchId) {
    return _firestore
        .collection('matches')
        .doc(matchId)
        .collection('spectator_chat')
        .orderBy('sent_at', descending: false)
        .limit(100)
        .snapshots();
  }
}
