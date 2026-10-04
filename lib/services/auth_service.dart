// lib/services/auth_service.dart — Firebase Authentication サービス

import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Authentication を管理するサービス
class AuthService {
  static final _auth = FirebaseAuth.instance;

  /// 現在のユーザーを取得
  static User? get currentUser => _auth.currentUser;

  /// ユーザーがログイン中か
  static bool get isLoggedIn => currentUser != null;

  /// 認証状態の変化を監視
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// メール/パスワードでサインアップ
  static Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// メール/パスワードでログイン
  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// 匿名でログイン
  static Future<UserCredential> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// サインアウト
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('サインアウトに失敗しました: $e');
    }
  }

  /// メールアドレスで認証
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// ユーザー情報を更新
  static Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      await currentUser?.updateProfile(
        displayName: displayName,
        photoURL: photoURL,
      );
    } catch (e) {
      throw Exception('ユーザー情報の更新に失敗しました: $e');
    }
  }

  /// メールアドレスを確認
  static Future<void> sendEmailVerification() async {
    try {
      await currentUser?.sendEmailVerification();
    } catch (e) {
      throw Exception('確認メールの送信に失敗しました: $e');
    }
  }

  /// 例外を処理して日本語メッセージを返す
  static String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'パスワードが弱すぎます。もっと複雑なパスワードを使用してください。';
      case 'email-already-in-use':
        return 'このメールアドレスは既に使用されています。';
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません。';
      case 'user-not-found':
        return 'ユーザーが見つかりません。';
      case 'wrong-password':
        return 'パスワードが正しくありません。';
      case 'user-disabled':
        return 'このアカウントは無効になっています。';
      case 'too-many-requests':
        return 'ログイン試行回数が多すぎます。後でもう一度お試しください。';
      case 'operation-not-allowed':
        return 'この操作は許可されていません。';
      default:
        return 'エラーが発生しました: ${e.message}';
    }
  }

  /// デバッグ用：認証状態をログに出力
  static void debugPrintAuthState() {
    print('=== Auth State Debug ===');
    print('isLoggedIn: $isLoggedIn');
    print('currentUser: ${currentUser?.email}');
    print('isAnonymous: ${currentUser?.isAnonymous}');
    print('uid: ${currentUser?.uid}');
  }
}
