// lib/services/season_service.dart
// シーズン制管理サービス（月次リセット・報酬・ランキング）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'network_service.dart';

class SeasonInfo {
  final String id;        // "2026-06"
  final String label;     // "2026年6月"
  final DateTime startAt;
  final DateTime endAt;
  final bool isActive;

  const SeasonInfo({
    required this.id,
    required this.label,
    required this.startAt,
    required this.endAt,
    required this.isActive,
  });
}

class SeasonRankEntry {
  final String userId;
  final String username;
  final int rating;
  final int wins;
  final int losses;
  final int rank;

  const SeasonRankEntry({
    required this.userId,
    required this.username,
    required this.rating,
    required this.wins,
    required this.losses,
    required this.rank,
  });

  factory SeasonRankEntry.fromDoc(DocumentSnapshot doc, int rank) {
    final d = doc.data() as Map<String, dynamic>;
    return SeasonRankEntry(
      userId: doc.id,
      username: d['username'] as String? ?? 'Unknown',
      rating: d['season_rating'] as int? ?? d['rating'] as int? ?? 1500,
      wins: d['season_wins'] as int? ?? 0,
      losses: d['season_losses'] as int? ?? 0,
      rank: rank,
    );
  }
}

class SeasonService {
  static final SeasonService _instance = SeasonService._();
  SeasonService._();
  factory SeasonService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NetworkService _networkService = NetworkService();

  // 現在のシーズン情報を返す
  SeasonInfo getCurrentSeason() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(days: 1));
    final id = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final label = '${now.year}年${now.month}月シーズン';
    return SeasonInfo(
      id: id,
      label: label,
      startAt: start,
      endAt: end,
      isActive: true,
    );
  }

  // トップN件のシーズンランキングを取得
  Future<List<SeasonRankEntry>> getTopRankings({int limit = 20}) async {
    try {
      final snap = await _firestore
          .collection('users')
          .where('is_banned', isEqualTo: false)
          .orderBy('season_rating', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .asMap()
          .entries
          .map((e) => SeasonRankEntry.fromDoc(e.value, e.key + 1))
          .toList();
    } catch (_) {
      // season_rating フィールドがない場合は rating でフォールバック
      try {
        final snap = await _firestore
            .collection('users')
            .orderBy('rating', descending: true)
            .limit(limit)
            .get();
        return snap.docs
            .asMap()
            .entries
            .map((e) => SeasonRankEntry.fromDoc(e.value, e.key + 1))
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  // 自分のシーズン順位を取得
  Future<int?> getMyRank() async {
    final uid = _networkService.currentUser?.uid;
    if (uid == null) return null;
    try {
      final myDoc = await _firestore.collection('users').doc(uid).get();
      if (!myDoc.exists) return null;
      final myRating = (myDoc.data()!['season_rating'] as int?) ??
          (myDoc.data()!['rating'] as int?) ?? 1500;

      final higher = await _firestore
          .collection('users')
          .where('season_rating', isGreaterThan: myRating)
          .get();
      return higher.docs.length + 1;
    } catch (_) {
      return null;
    }
  }

  // シーズン開始時（または月が変わった時）にスコアをリセット
  // 対局後の season_rating/season_wins/season_losses 更新は
  // Cloud Functions (onMatchFinished) がトランザクション内で実施
  Future<void> initSeasonRating() async {
    final uid = _networkService.currentUser?.uid;
    if (uid == null) return;
    final currentSeasonId = getCurrentSeason().id;
    final ref = _firestore.collection('users').doc(uid);
    try {
      // トランザクション化: 対局終了直後にCloud Functions
      // (onMatchFinished)がseason_wins/lossesを加算するのと同時に
      // このリセットが走ると、非トランザクションのupdate()では
      // どちらか一方の書き込みが失われうるため
      await _firestore.runTransaction((tx) async {
        final doc = await tx.get(ref);
        if (!doc.exists) return;
        final data = doc.data()!;
        final needsReset = data['season_rating'] == null ||
            data['season_id'] != currentSeasonId;
        if (!needsReset) return;
        final baseRating = data['rating'] as int? ?? 1500;
        tx.update(ref, {
          'season_rating': baseRating,
          'season_wins': 0,
          'season_losses': 0,
          'season_id': currentSeasonId,
        });
      });
    } catch (_) {}
  }
}
