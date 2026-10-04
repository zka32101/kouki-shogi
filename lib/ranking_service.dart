// lib/ranking_service.dart — Firebase Realtime DB ランキング更新サービス

import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'network_game_service.dart';

class RankingService {
  RankingService._();

  static const _userIdKey   = 'ranking_user_id';
  static const _nicknameKey = 'ranking_nickname';

  // ── userId / ニックネーム 取得・生成 ──────────────────────────────────────

  static String _generateUserId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(16, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_userIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final newId = _generateUserId();
    await prefs.setString(_userIdKey, newId);
    return newId;
  }

  static Future<String> getNickname() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_nicknameKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final userId = await getUserId();
    final auto = '棋士#${userId.substring(0, 4).toUpperCase()}';
    await prefs.setString(_nicknameKey, auto);
    return auto;
  }

  static Future<void> setNickname(String nickname) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nicknameKey, nickname);
  }

  // ── Firebase へランキング更新 ─────────────────────────────────────────────

  static Future<void> updateRating({
    required int rating,
    required int wins,
    required int losses,
  }) async {
    // Firebase 未設定時はスキップ
    if (!NetworkGameService.firebaseReady) return;

    try {
      final userId   = await getUserId();
      final nickname = await getNickname();

      await FirebaseDatabase.instance.ref('rankings/$userId').update({
        'nickname' : nickname,
        'rating'   : rating,
        'wins'     : wins,
        'losses'   : losses,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (_) {
      // ネットワークエラーは無視（ランキングはベストエフォート）
    }
  }
}
