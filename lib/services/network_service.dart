// lib/services/network_service.dart
// Firebase ネットワーク対局・報告機能

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_profile.dart';
import '../models/match.dart';
import '../models/report.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'network_achievement_service.dart'; // 将来の実装用（Cloud Functions移行後に削除可）
import 'daily_challenge_service.dart';     // 将来の実装用
import 'fcm_service.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();

  factory NetworkService() {
    return _instance;
  }

  NetworkService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final NetworkAchievementService _achievementService =
      NetworkAchievementService();
  final DailyChallengeService _dailyChallengeService =
      DailyChallengeService();
  final FcmService _fcmService = FcmService();

  // ── ユーザー認証 ────────────────────────────
  Future<bool> initFirebase() async {
    try {
      // Firebase.initializeApp() は main.dart で実行済み
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously()
            .timeout(const Duration(seconds: 5));
        print('Anonymous sign-in successful: ${_auth.currentUser?.uid}');
      } else {
        print('Already signed in: ${_auth.currentUser?.uid}');
      }
      return true;
    } catch (e) {
      print('Firebase initFirebase error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;

  // ── ユーザープロフィール ────────────────────────────
  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserProfile.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Get user profile error: $e');
      return null;
    }
  }

  Future<void> createUserProfile(String uid, UserProfile profile) async {
    try {
      await _firestore.collection('users').doc(uid).set(profile.toJson());
    } catch (e) {
      print('Create user profile error: $e');
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
      print('Update user profile error: $e');
    }
  }

  // ── 対局情報 ────────────────────────────
  Future<String> createMatch(String player1Id, String player2Id) async {
    try {
      final matchRef = _firestore.collection('matches').doc();
      final match = Match(
        id: matchRef.id,
        player1Id: player1Id,
        player2Id: player2Id,
        boardState: '', // 初期盤面
        winner: null,
        createdAt: DateTime.now(),
      );
      await matchRef.set(match.toJson());
      return matchRef.id;
    } catch (e) {
      print('Create match error: $e');
      return '';
    }
  }

  Future<Match?> getMatch(String matchId) async {
    try {
      final doc = await _firestore.collection('matches').doc(matchId).get();
      if (doc.exists) {
        return Match.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Get match error: $e');
      return null;
    }
  }

  Future<void> updateMatchBoard(String matchId, String boardState) async {
    try {
      await _firestore.collection('matches').doc(matchId).update({
        'board_state': boardState,
      });
    } catch (e) {
      print('Update match board error: $e');
    }
  }

  /// マッチを終了し、ステータスを更新
  /// ELO計算はCloud Functions (onMatchFinished) が自動実行
  /// [matchId]: マッチID
  /// [winnerId]: 勝者のUID（null の場合は引き分け）
  /// [result]: 結果種類（'checkmate', 'resignation', 'timeout', 'draw'）
  Future<void> finishMatchWithRating(
    String matchId,
    String? winnerId,
    String result,
  ) async {
    // RTDBを先に更新（必須: MatchScreenのboardStreamが終了を検知する）
    await FirebaseDatabase.instance.ref('games/$matchId').update({
      'status':    'finished',
      'winner_id': winnerId,
      'result':    result,
    });
    // Firestoreへの更新（オプション: 認証エラー時はスキップ）
    try {
      await _firestore.collection('matches').doc(matchId).update({
        'status':      'finished',
        'winner_id':   winnerId,
        'result':      result,
        'finished_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ── 報告機能 ────────────────────────────
  /// 不正報告を作成（報告数10件で自動停止 + 報告スパム検出）
  Future<bool> submitReport(
    String reporterUid,
    String reportedUid,
    String matchId,
    String reason,
  ) async {
    try {
      // ① 報告者がスパム状態かチェック
      final isReporterSpam = await _isReporterSpamming(reporterUid);
      if (isReporterSpam) {
        print('Reporter is spamming. Banning reporter.');

        final reporterProfile = await getUserProfile(reporterUid);
        await _firestore.collection('users').doc(reporterUid).update({
          'is_banned': true,
          'banned_at': DateTime.now(),
          'ban_reason': 'spam_reporting',
        });

        // 📧 報告者に BAN 通知を送信
        final reporterEmail = await _notificationService.getUserEmail(reporterUid);
        if (reporterEmail != null) {
          await _notificationService.sendBanNotification(
            reporterUid,
            reporterEmail,
            reporterProfile?.username ?? 'User',
            'spam_reporting',
          );
        }
        return false; // 報告を受け付けない
      }

      final reportRef = _firestore.collection('reports').doc();
      final report = Report(
        id: reportRef.id,
        reporterId: reporterUid,
        reportedUserId: reportedUid,
        matchId: matchId,
        reason: reason,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      // ② 報告を保存
      await reportRef.set(report.toJson());

      // ③ 報告対象者の報告数をカウント（待機中のみ）
      final reportsSnapshot = await _firestore
          .collection('reports')
          .where('reported_user_id', isEqualTo: reportedUid)
          .where('status', isEqualTo: 'pending')
          .get();

      // 報告数が10以上で自動停止
      if (reportsSnapshot.docs.length >= 10) {
        final reportedProfile = await getUserProfile(reportedUid);
        await _firestore.collection('users').doc(reportedUid).update({
          'is_banned': true,
          'banned_at': DateTime.now(),
          'ban_reason': 'too_many_reports',
        });

        // 📧 報告対象者に BAN 通知を送信
        final reportedEmail = await _notificationService.getUserEmail(reportedUid);
        if (reportedEmail != null) {
          await _notificationService.sendBanNotification(
            reportedUid,
            reportedEmail,
            reportedProfile?.username ?? 'User',
            'too_many_reports',
          );
        }
      }

      return true;
    } catch (e) {
      print('Submit report error: $e');
      return false;
    }
  }

  /// 報告者がスパム状態かチェック
  /// - 同一ユーザーへ3件以上の報告
  /// - または報告総数10件以上で却下率80%以上
  Future<bool> _isReporterSpamming(String reporterUid) async {
    try {
      // ① 報告者の全報告を取得
      final allReports = await _firestore
          .collection('reports')
          .where('reporter_id', isEqualTo: reporterUid)
          .get();

      if (allReports.docs.length < 5) return false; // 5件未満はスパムではない

      // ② 同一ユーザーへの重複報告をチェック
      final reportCounts = <String, int>{};
      for (var doc in allReports.docs) {
        final reportedUid = doc['reported_user_id'] as String;
        reportCounts[reportedUid] = (reportCounts[reportedUid] ?? 0) + 1;
      }

      // 同じユーザーに3件以上報告 → スパム
      if (reportCounts.values.any((count) => count >= 3)) {
        return true;
      }

      // ③ 却下率をチェック（報告総数10件以上で却下率80%以上）
      if (allReports.docs.length >= 10) {
        final dismissedCount = allReports.docs
            .where((doc) => doc['status'] == 'dismissed')
            .length;
        final dismissalRate = dismissedCount / allReports.docs.length;

        if (dismissalRate >= 0.8) {
          return true; // 却下率80%以上 → スパム
        }
      }

      return false;
    } catch (e) {
      print('Check reporter spamming error: $e');
      return false;
    }
  }

  /// ユーザーの報告数を取得
  Future<int> getReportCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .where('reported_user_id', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Get report count error: $e');
      return 0;
    }
  }

  /// ユーザーがバンされているか確認
  Future<bool> isUserBanned(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data()?['is_banned'] ?? false;
      }
      return false;
    } catch (e) {
      print('Is user banned error: $e');
      return false;
    }
  }

  /// 報告を確認（管理者用）
  Future<void> reviewReport(String reportId, bool approved) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': approved ? 'reviewed' : 'dismissed',
      });
    } catch (e) {
      print('Review report error: $e');
    }
  }

  /// BAN を解除（管理者用）
  Future<void> unbanUser(String userId) async {
    try {
      final userProfile = await getUserProfile(userId);
      await _firestore.collection('users').doc(userId).update({
        'is_banned': false,
        'banned_at': null,
      });

      // 📧 BAN 解除通知を送信
      final userEmail = await _notificationService.getUserEmail(userId);
      if (userEmail != null) {
        await _notificationService.sendUnbanNotification(
          userId,
          userEmail,
          userProfile?.username ?? 'User',
        );
      }
    } catch (e) {
      print('Unban user error: $e');
    }
  }

  // ── ブロック機能 ────────────────────────────────────────────

  /// 指定ユーザーをブロック（Firestore の blocked_users サブコレクションに保存）
  Future<void> blockUser(String targetUserId) async {
    final me = currentUser;
    if (me == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(me.uid)
          .collection('blocked_users')
          .doc(targetUserId)
          .set({'blocked_at': FieldValue.serverTimestamp()});
    } catch (e) {
      print('Block user error: $e');
    }
  }

  /// ブロック解除
  Future<void> unblockUser(String targetUserId) async {
    final me = currentUser;
    if (me == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(me.uid)
          .collection('blocked_users')
          .doc(targetUserId)
          .delete();
    } catch (e) {
      print('Unblock user error: $e');
    }
  }

  /// ブロック済みかどうかを確認
  Future<bool> isBlocked(String targetUserId) async {
    final me = currentUser;
    if (me == null) return false;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(me.uid)
          .collection('blocked_users')
          .doc(targetUserId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// ブロック済みユーザー一覧を取得
  Future<List<String>> getBlockedUserIds() async {
    final me = currentUser;
    if (me == null) return [];
    try {
      final snap = await _firestore
          .collection('users')
          .doc(me.uid)
          .collection('blocked_users')
          .get();
      return snap.docs.map((d) => d.id).toList();
    } catch (e) {
      return [];
    }
  }

  // ── ストリーム（リアルタイム監視） ────────────────────────────
  Stream<Match?> watchMatch(String matchId) {
    return _firestore.collection('matches').doc(matchId).snapshots().map((doc) {
      return doc.exists ? Match.fromJson(doc.data()!) : null;
    });
  }

  Stream<UserProfile?> watchUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      return doc.exists ? UserProfile.fromJson(doc.data()!) : null;
    });
  }
}
