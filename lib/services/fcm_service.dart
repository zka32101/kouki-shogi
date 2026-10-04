// lib/services/fcm_service.dart
// FCM プッシュ通知管理

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── バックグラウンドハンドラ（トップレベル必須） ──────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // バックグラウンドメッセージ処理
  debugPrint('FCM Background: ${message.messageId}');
}

// ── 通知タイプ定数 ──────────────────────────────────────────────
class FcmNotificationType {
  static const String matchFound = 'match_found';
  static const String opponentMoved = 'opponent_moved';
  static const String tournamentReady = 'tournament_ready';
  static const String friendRequest = 'friend_request';
  static const String friendChallenge = 'friend_challenge';
  static const String matchResult = 'match_result';
  static const String dailyChallenge = 'daily_challenge';
  static const String achievementUnlocked = 'achievement_unlocked';
}

// ── FCMサービス ──────────────────────────────────────────────────
class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // コールバック（UIで受け取るため）
  Function(RemoteMessage)? onForegroundMessage;

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;
  StreamSubscription<String>? _onTokenRefreshSub;

  // ── 初期化 ───────────────────────────────────────────────────

  Future<void> initialize() async {
    // バックグラウンドハンドラ登録
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 権限リクエスト
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    debugPrint('FCM permission: ${settings.authorizationStatus}');

    // フォアグラウンドメッセージ（重複登録防止）
    _onMessageSub ??= FirebaseMessaging.onMessage.listen((message) {
      debugPrint('FCM Foreground: ${message.notification?.title}');
      onForegroundMessage?.call(message);
    });

    // アプリ起動時（通知タップから）
    _onMessageOpenedAppSub ??= FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationTap(message);
    });

    // トークン更新時の自動保存
    _onTokenRefreshSub ??= _fcm.onTokenRefresh.listen((token) => _saveTokenToFirestore(token));

    // 初回トークン保存
    await saveCurrentToken();
  }

  // ── トークン管理 ──────────────────────────────────────────────

  Future<void> saveCurrentToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      debugPrint('FCM get token error: $e');
    }
  }

  static const _lastTokenPrefKey = 'fcm_last_saved_token';

  Future<void> _saveTokenToFirestore(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final prevToken = prefs.getString(_lastTokenPrefKey);
      final docRef = _firestore.collection('users').doc(uid);
      // ローテーションで無効になった旧トークン（この端末が以前使っていた
      // もの）を、fcm_tokens配列に無期限で残さないよう先に取り除く
      if (prevToken != null && prevToken != token) {
        await docRef.update({
          'fcm_tokens': FieldValue.arrayRemove([prevToken]),
        });
      }
      await docRef.update({
        'fcm_tokens': FieldValue.arrayUnion([token]),
        'fcm_token_updated_at': FieldValue.serverTimestamp(),
      });
      await prefs.setString(_lastTokenPrefKey, token);
    } catch (e) {
      debugPrint('FCM save token error: $e');
    }
  }

  Future<void> removeCurrentToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(uid).update({
          'fcm_tokens': FieldValue.arrayRemove([token]),
        });
      }
      await _fcm.deleteToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastTokenPrefKey);
    } catch (e) {
      debugPrint('FCM remove token error: $e');
    }
  }

  // ── 通知送信（Firestoreキュー経由 → Cloud Functions） ─────────

  /// 対局相手が見つかった通知
  Future<void> notifyMatchFound({
    required String recipientId,
    required String opponentName,
    required int opponentRating,
    required String matchId,
  }) async {
    await _queueNotification(
      recipientId: recipientId,
      type: FcmNotificationType.matchFound,
      title: '対戦相手が見つかりました！',
      body: '$opponentName (${opponentRating}点) と対局を開始します',
      data: {
        'match_id': matchId,
        'screen': 'match',
      },
    );
  }

  /// 相手が指した通知
  Future<void> notifyOpponentMoved({
    required String recipientId,
    required String opponentName,
    required String matchId,
    required String moveNotation,
  }) async {
    await _queueNotification(
      recipientId: recipientId,
      type: FcmNotificationType.opponentMoved,
      title: '$opponentName が指しました',
      body: '手番です：$moveNotation',
      data: {
        'match_id': matchId,
        'screen': 'match',
      },
    );
  }

  /// トーナメント試合開始通知
  Future<void> notifyTournamentMatchReady({
    required String recipientId,
    required String tournamentName,
    required String opponentName,
    required String matchId,
  }) async {
    await _queueNotification(
      recipientId: recipientId,
      type: FcmNotificationType.tournamentReady,
      title: 'トーナメント対局開始！',
      body: '$tournamentName：$opponentName との試合が始まります',
      data: {
        'match_id': matchId,
        'screen': 'match',
      },
    );
  }

  /// フレンドリクエスト通知
  Future<void> notifyFriendRequest({
    required String recipientId,
    required String senderName,
    required String senderId,
  }) async {
    await _queueNotification(
      recipientId: recipientId,
      type: FcmNotificationType.friendRequest,
      title: 'フレンド申請',
      body: '$senderName さんからフレンド申請が届きました',
      data: {
        'sender_id': senderId,
        'screen': 'friends',
      },
    );
  }

  /// フレンドから対局招待
  Future<void> notifyFriendChallenge({
    required String recipientId,
    required String senderName,
    required String challengeId,
  }) async {
    await _queueNotification(
      recipientId: recipientId,
      type: FcmNotificationType.friendChallenge,
      title: '対局招待',
      body: '$senderName さんから対局に招待されました',
      data: {
        'challenge_id': challengeId,
        'screen': 'challenge',
      },
    );
  }

  /// 対局結果通知
  Future<void> notifyMatchResult({
    required String recipientId,
    required bool isWin,
    required int ratingChange,
    required String matchId,
  }) async {
    final sign = ratingChange >= 0 ? '+' : '';
    await _queueNotification(
      recipientId: recipientId,
      type: FcmNotificationType.matchResult,
      title: isWin ? '勝利！' : '敗北',
      body: 'レーティング $sign$ratingChange (${isWin ? "👑" : "💪"} 次の対局頑張りましょう)',
      data: {
        'match_id': matchId,
        'screen': 'match_history',
      },
    );
  }

  /// デイリーチャレンジ利用可能通知
  Future<void> notifyDailyChallenge({
    required String recipientId,
    required String challengeTitle,
  }) async {
    await _queueNotification(
      recipientId: recipientId,
      type: FcmNotificationType.dailyChallenge,
      title: '本日のデイリーチャレンジ',
      body: challengeTitle,
      data: {
        'screen': 'daily_challenge',
      },
    );
  }

  /// 実績解除通知
  Future<void> notifyAchievementUnlocked({
    required String recipientId,
    required String achievementName,
    required String achievementId,
  }) async {
    await _queueNotification(
      recipientId: recipientId,
      type: FcmNotificationType.achievementUnlocked,
      title: '🏆 実績解除！',
      body: achievementName,
      data: {
        'achievement_id': achievementId,
        'screen': 'achievements',
      },
    );
  }

  // ── Firestoreキュー ───────────────────────────────────────────

  Future<void> _queueNotification({
    required String recipientId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // 受信者のFCMトークンを取得
      final userDoc =
          await _firestore.collection('users').doc(recipientId).get();
      if (!userDoc.exists) return;

      final tokens = (userDoc['fcm_tokens'] as List?)?.cast<String>() ?? [];
      if (tokens.isEmpty) return;

      // notificationsキューに追加（Cloud Functionsがトリガー）
      await _firestore.collection('fcm_queue').add({
        'recipient_id': recipientId,
        'tokens': tokens,
        'type': type,
        'title': title,
        'body': body,
        'data': data ?? {},
        'created_at': FieldValue.serverTimestamp(),
        'sent': false,
        'sent_at': null,
      });
    } catch (e) {
      debugPrint('FCM queue notification error: $e');
    }
  }

  // ── 通知タップ処理 ────────────────────────────────────────────

  void _handleNotificationTap(RemoteMessage message) {
    // GlobalKey<NavigatorState> が必要なためコールバックで処理
    onNotificationTap?.call(message.data);
  }

  Function(Map<String, dynamic>)? onNotificationTap;

  /// アプリが完全終了状態から通知タップで起動された場合（cold start）の
  /// ハンドリング。onMessageOpenedAppはバックグラウンド→フォアグラウンドの
  /// 遷移しか捕捉できないため、これを別途呼ぶ必要がある。
  /// onNotificationTapコールバックが登録された後に呼び出すこと。
  Future<void> checkInitialMessage() async {
    try {
      final message = await _fcm.getInitialMessage();
      if (message != null) _handleNotificationTap(message);
    } catch (e) {
      debugPrint('FCM initial message error: $e');
    }
  }

  // ── 通知設定 ──────────────────────────────────────────────────

  Future<void> updateNotificationSettings({
    required String userId,
    required bool matchFound,
    required bool opponentMoved,
    required bool tournament,
    required bool friends,
    required bool dailyChallenge,
  }) async {
    await _firestore.collection('users').doc(userId).update({
      'notification_settings': {
        'match_found': matchFound,
        'opponent_moved': opponentMoved,
        'tournament': tournament,
        'friends': friends,
        'daily_challenge': dailyChallenge,
      },
    });
  }

  Future<Map<String, bool>> getNotificationSettings(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final settings =
          (doc['notification_settings'] as Map?)?.cast<String, dynamic>() ??
              {};
      return {
        'match_found': settings['match_found'] as bool? ?? true,
        'opponent_moved': settings['opponent_moved'] as bool? ?? true,
        'tournament': settings['tournament'] as bool? ?? true,
        'friends': settings['friends'] as bool? ?? true,
        'daily_challenge': settings['daily_challenge'] as bool? ?? false,
      };
    } catch (e) {
      return {
        'match_found': true,
        'opponent_moved': true,
        'tournament': true,
        'friends': true,
        'daily_challenge': false,
      };
    }
  }
}
