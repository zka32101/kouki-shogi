// lib/cloud_sync_service.dart — レーティング・バッジ・統計の Firebase 同期

import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'badge_service.dart';
import 'ranking_service.dart';

class CloudSyncService {
  CloudSyncService._();

  static bool _firebaseReady = false;
  static void setReady() => _firebaseReady = true;

  static DatabaseReference get _db => FirebaseDatabase.instance.ref();

  // ── ユーザーデータをサーバーへプッシュ ──────────────────────────────
  static Future<void> pushUserData() async {
    if (!_firebaseReady) return;
    try {
      final userId = await RankingService.getUserId();
      final prefs  = await SharedPreferences.getInstance();

      final rating           = prefs.getInt('rating_current') ?? 700;
      final ratingHistoryRaw = prefs.getString('rating_history') ?? '[]';
      final statsTotal       = prefs.getInt('stats_total') ?? 0;
      final statsP1Wins      = prefs.getInt('stats_p1_wins') ?? 0;
      final statsAiTotal     = prefs.getInt('stats_total_ai') ?? 0;
      final streakDays       = prefs.getInt('badge_streak_days') ?? 0;

      // アンロック済みバッジ一覧
      final unlockedBadges = allBadges
          .where((b) => prefs.getBool('badge_${b.id.name}') == true)
          .map((b) => b.id.name)
          .toList();

      await _db.child('users/$userId').update({
        'rating':        rating,
        'ratingHistory': ratingHistoryRaw,
        'badges':        jsonEncode(unlockedBadges),
        'statsTotal':    statsTotal,
        'statsP1Wins':   statsP1Wins,
        'statsAiTotal':  statsAiTotal,
        'streakDays':    streakDays,
        'lastSync':      DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  // ── サーバーからデータを取得してローカルとマージ ────────────────────
  static Future<void> pullAndMerge() async {
    if (!_firebaseReady) return;
    try {
      final userId  = await RankingService.getUserId();
      final snapshot = await _db.child('users/$userId').get();
      if (!snapshot.exists || snapshot.value == null) return;

      final data  = Map<String, dynamic>.from(snapshot.value as Map);
      final prefs = await SharedPreferences.getInstance();

      // レーティング: より高い方を採用
      final serverRating = (data['rating'] as num?)?.toInt() ?? 700;
      final localRating  = prefs.getInt('rating_current') ?? 700;
      if (serverRating > localRating) {
        await prefs.setInt('rating_current', serverRating);
        // レーティング履歴もサーバー優先
        final serverHistory = data['ratingHistory'] as String?;
        if (serverHistory != null && serverHistory.isNotEmpty) {
          await prefs.setString('rating_history', serverHistory);
        }
      }

      // バッジ: ユニオン（どちらかで獲得済みなら保持）
      final serverBadgesRaw = data['badges'] as String? ?? '[]';
      try {
        final serverBadges = (jsonDecode(serverBadgesRaw) as List).whereType<String>().toList();
        for (final badgeName in serverBadges) {
          await prefs.setBool('badge_$badgeName', true);
        }
      } catch (_) {}

      // 対局数: より多い方を採用
      final serverTotal  = (data['statsTotal'] as num?)?.toInt() ?? 0;
      final localTotal   = prefs.getInt('stats_total') ?? 0;
      if (serverTotal > localTotal) {
        await prefs.setInt('stats_total',   serverTotal);
        await prefs.setInt('stats_p1_wins', (data['statsP1Wins'] as num?)?.toInt() ?? 0);
      }

      // 連続対局日数: より長い方を採用
      final serverStreak = (data['streakDays'] as num?)?.toInt() ?? 0;
      final localStreak  = prefs.getInt('badge_streak_days') ?? 0;
      if (serverStreak > localStreak) {
        await prefs.setInt('badge_streak_days', serverStreak);
      }
    } catch (_) {}
  }
}
