// lib/exceptions/app_exception.dart
// 統一されたエラーハンドリング例外クラス

/// アプリケーション全体の基底例外クラス
abstract class AppException implements Exception {
  final String code;
  final String message;
  final String userMessage;
  final Severity severity;
  final bool shouldRetry;
  final Exception? cause;

  AppException({
    required this.code,
    required this.message,
    required this.userMessage,
    required this.severity,
    required this.shouldRetry,
    this.cause,
  });

  @override
  String toString() => '$code: $message';
}

/// エラーの重大度レベル
enum Severity {
  /// 背景で処理されるエラー（ユーザーに通知不要）
  info,

  /// 警告レベル（ユーザーに通知推奨）
  warning,

  /// エラーレベル（ユーザーに必ず通知）
  error,

  /// 重大エラー（クラッシュレポート送信）
  critical,
}

// ===== ゲーム関連エラー =====

class GameException extends AppException {
  GameException({
    required String code,
    required String message,
    required String userMessage,
    Severity severity = Severity.error,
    bool shouldRetry = false,
    Exception? cause,
  }) : super(
    code: code,
    message: message,
    userMessage: userMessage,
    severity: severity,
    shouldRetry: shouldRetry,
    cause: cause,
  );

  /// 違法な手の生成
  factory GameException.illegalMove(
    String move, {
    String reason = '',
    Exception? cause,
  }) =>
      GameException(
        code: 'GAME_ILLEGAL_MOVE',
        message: '違法手が生成されました: $move ($reason)',
        userMessage: '違法な手です。別の手を指してください。',
        severity: Severity.error,
        shouldRetry: false,
        cause: cause,
      );

  /// ゲーム状態の不正
  factory GameException.invalidState({Exception? cause}) =>
      GameException(
        code: 'GAME_INVALID_STATE',
        message: 'ゲーム状態が不正です',
        userMessage: '現在の操作はできません。画面をリロードしてください。',
        severity: Severity.error,
        shouldRetry: false,
        cause: cause,
      );
}

// ===== 保存関連エラー =====

class SaveException extends AppException {
  SaveException({
    required String code,
    required String message,
    required String userMessage,
    Severity severity = Severity.error,
    bool shouldRetry = true,
    Exception? cause,
  }) : super(
    code: code,
    message: message,
    userMessage: userMessage,
    severity: severity,
    shouldRetry: shouldRetry,
    cause: cause,
  );

  /// 棋譜保存失敗
  factory SaveException.kifuSaveFailed({Exception? cause}) =>
      SaveException(
        code: 'SAVE_KIFU_FAILED',
        message: '棋譜の保存に失敗しました',
        userMessage: '棋譜保存失敗。再度試してください。',
        severity: Severity.error,
        shouldRetry: true,
        cause: cause,
      );

  /// 統計更新失敗
  factory SaveException.statisticsUpdateFailed({Exception? cause}) =>
      SaveException(
        code: 'SAVE_STATS_FAILED',
        message: '統計情報の更新に失敗しました',
        userMessage: '統計更新失敗。再度試してください。',
        severity: Severity.warning,
        shouldRetry: true,
        cause: cause,
      );
}

// ===== ストレージ関連エラー =====

class StorageException extends AppException {
  StorageException({
    required String code,
    required String message,
    required String userMessage,
    Severity severity = Severity.error,
    bool shouldRetry = true,
    Exception? cause,
  }) : super(
    code: code,
    message: message,
    userMessage: userMessage,
    severity: severity,
    shouldRetry: shouldRetry,
    cause: cause,
  );

  /// SharedPreferences 読み込み失敗
  factory StorageException.readFailed({Exception? cause}) =>
      StorageException(
        code: 'STORAGE_READ_FAILED',
        message: 'ストレージからの読み込みに失敗しました',
        userMessage: 'データ読み込み失敗。再度試してください。',
        severity: Severity.warning,
        shouldRetry: true,
        cause: cause,
      );

  /// SharedPreferences 書き込み失敗
  factory StorageException.writeFailed({Exception? cause}) =>
      StorageException(
        code: 'STORAGE_WRITE_FAILED',
        message: 'ストレージへの書き込みに失敗しました',
        userMessage: 'データ保存失敗。ストレージの空き容量を確認してください。',
        severity: Severity.error,
        shouldRetry: true,
        cause: cause,
      );
}

// ===== データ関連エラー =====

class DataException extends AppException {
  DataException({
    required String code,
    required String message,
    required String userMessage,
    Severity severity = Severity.error,
    bool shouldRetry = false,
    Exception? cause,
  }) : super(
    code: code,
    message: message,
    userMessage: userMessage,
    severity: severity,
    shouldRetry: shouldRetry,
    cause: cause,
  );

  /// データが破損している
  factory DataException.corrupted({Exception? cause}) =>
      DataException(
        code: 'DATA_CORRUPTED',
        message: 'データが破損しています',
        userMessage: 'ゲーム状態が破損しています。サポートにお問い合わせください。',
        severity: Severity.critical,
        shouldRetry: false,
        cause: cause,
      );

  /// JSON デコード失敗
  factory DataException.decodeFailed({
    String? detail,
    Exception? cause,
  }) =>
      DataException(
        code: 'DATA_DECODE_FAILED',
        message: 'データのデコードに失敗しました: $detail',
        userMessage: 'データ形式が不正です。再度試してください。',
        severity: Severity.error,
        shouldRetry: true,
        cause: cause,
      );
}

// ===== 予期しないエラー =====

class UnexpectedException extends AppException {
  UnexpectedException({
    String message = 'Unknown error',
    Exception? cause,
  }) : super(
    code: 'UNKNOWN_ERROR',
    message: message,
    userMessage: '予期しないエラーが発生しました。再度試してください。',
    severity: Severity.error,
    shouldRetry: true,
    cause: cause,
  );
}
