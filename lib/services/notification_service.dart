// lib/services/notification_service.dart
// BAN通知とメール送信

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// BANユーザーに通知メールを送信（Cloud Functions 経由）
  Future<void> sendBanNotification(
    String userId,
    String userEmail,
    String username,
    String banReason,
  ) async {
    try {
      // Cloud Functions を呼び出す
      // 実装例: Cloud Functions の HTTP トリガー
      await _firestore.collection('notifications').add({
        'type': 'ban_notification',
        'user_id': userId,
        'email': userEmail,
        'username': username,
        'reason': banReason,
        'created_at': DateTime.now(),
        'sent': false,
      });

      print('Ban notification queued for $userEmail');
    } catch (e) {
      print('Send ban notification error: $e');
    }
  }

  /// BANが解除されたことをメールで通知
  Future<void> sendUnbanNotification(
    String userId,
    String userEmail,
    String username,
  ) async {
    try {
      await _firestore.collection('notifications').add({
        'type': 'unban_notification',
        'user_id': userId,
        'email': userEmail,
        'username': username,
        'created_at': DateTime.now(),
        'sent': false,
      });

      print('Unban notification queued for $userEmail');
    } catch (e) {
      print('Send unban notification error: $e');
    }
  }

  /// ユーザーのメールアドレスを取得
  Future<String?> getUserEmail(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc['email'] as String?;
    } catch (e) {
      print('Get user email error: $e');
      return null;
    }
  }
}

/// Cloud Functions の実装例（Dart Code ではなく Firebase 側）
/// 以下は参考実装です：
///
/// exports.sendBanNotification = functions.firestore
///   .document('notifications/{docId}')
///   .onCreate(async (snap, context) => {
///     const data = snap.data();
///     if (data.type !== 'ban_notification') return;
///
///     const transporter = nodemailer.createTransport({
///       service: 'gmail',
///       auth: {
///         user: functions.config().email.address,
///         pass: functions.config().email.password,
///       },
///     });
///
///     const reasonLabel = {
///       'too_many_reports': '報告多数により',
///       'spam_reporting': '虚偽報告のため',
///     }[data.reason] || 'システム規約違反のため';
///
///     const mailOptions = {
///       from: 'noreply@kouki.jp',
///       to: data.email,
///       subject: '【効棋】アカウント停止のお知らせ',
///       html: `
///         <h2>アカウントが停止されました</h2>
///         <p>${data.username} さん</p>
///         <p>${reasonLabel}、アカウントが停止されています。</p>
///         <p>詳細は以下のメールでお問い合わせください。</p>
///         <p>support@kouki.jp</p>
///       `,
///     };
///
///     await transporter.sendMail(mailOptions);
///     await snap.ref.update({ sent: true });
///   });
