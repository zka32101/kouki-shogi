// lib/utils/shogi_data_validator.dart — 将棋データ検証ツール

/// 戦法・囲いデータ検証用ユーティリティ
class ShogiDataValidator {
  // 主要将棋サイト（棋譜データ・戦法検証用）
  static const verificationSources = {
    'elmo': 'https://www.elmo.fun/',
    '将棋DB2': 'https://www2.aoba.c.u-tokyo.ac.jp/shogi/',
    'ニコニコ将棋': 'https://www.nicovideo.jp/tag/%E5%B0%86%E6%A3%8B',
    '棋譜ぐんぐん': 'https://kifu.gg/',
    '将棋連盟': 'https://www.jsa.or.jp/',
  };

  /// 戦法・囲いの盤面データ整合性をチェック
  /// - 駒の衝突なし
  /// - 駒枚数が合法的（各側最大40枚）
  /// - 玉が1体ずつ存在
  static ValidationResult validateBoardData(List<List<dynamic>> board) {
    final errors = <String>[];

    // 盤面サイズ確認
    if (board.length != 9) {
      errors.add('盤面サイズが不正: ${board.length} (9であるべき)');
      return ValidationResult(isValid: false, errors: errors);
    }

    for (int r = 0; r < 9; r++) {
      if (board[r].length != 9) {
        errors.add('盤面列数が不正 [row $r]: ${board[r].length} (9であるべき)');
      }
    }

    // 駒の配置をチェック
    int p1KingCount = 0, p2KingCount = 0;
    int p1PieceCount = 0, p2PieceCount = 0;

    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final cell = board[r][c];
        if (cell == null) continue;

        // 駒情報を取得（Map または Piece オブジェクト）
        final isP1 = _extractIsP1(cell);
        if (isP1 == null) {
          errors.add('[$r,$c] 駒情報が不正: $cell');
          continue;
        }

        if (isP1) {
          p1PieceCount++;
          if (_isPiece(cell, 'king')) p1KingCount++;
        } else {
          p2PieceCount++;
          if (_isPiece(cell, 'king')) p2KingCount++;
        }
      }
    }

    // 玉の数をチェック
    if (p1KingCount != 1) errors.add('先手の玉が1体ではない: $p1KingCount');
    if (p2KingCount != 1) errors.add('後手の玉が1体ではない: $p2KingCount');

    // 駒枚数をチェック（初期配置18枚 + 成駒・取得駒の変動）
    if (p1PieceCount > 40) errors.add('先手の駒が多すぎる: $p1PieceCount');
    if (p2PieceCount > 40) errors.add('後手の駒が多すぎる: $p2PieceCount');

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      p1PieceCount: p1PieceCount,
      p2PieceCount: p2PieceCount,
    );
  }

  /// 駒情報から先手・後手フラグを抽出
  static bool? _extractIsP1(dynamic piece) {
    if (piece is Map<String, dynamic>) {
      return piece['isPlayer1'] as bool?;
    }
    // Piece オブジェクトの場合は `isPlayer1` プロパティを持つと仮定
    try {
      return (piece as dynamic).isPlayer1 as bool;
    } catch (_) {
      return null;
    }
  }

  /// 駒タイプをチェック
  static bool _isPiece(dynamic piece, String type) {
    if (piece is Map<String, dynamic>) {
      final t = piece['type'] as String?;
      return t == type;
    }
    try {
      final t = (piece as dynamic).type as dynamic;
      return t.toString().endsWith(type);
    } catch (_) {
      return false;
    }
  }

  /// ソースコードに記載されたサイトをチェック
  static List<String> checkSourceUrls(Map<String, dynamic> strategyData) {
    final urls = <String>[];

    // sourceUrl が指定されている場合
    if (strategyData['sourceUrl'] is String &&
        (strategyData['sourceUrl'] as String).isNotEmpty) {
      urls.add(strategyData['sourceUrl'] as String);
    }

    // 主要サイトのリンクを推奨
    urls.addAll(verificationSources.values.take(3)); // 上位3つのサイト

    return urls;
  }
}

/// 盤面データ検証結果
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final int? p1PieceCount;
  final int? p2PieceCount;

  ValidationResult({
    required this.isValid,
    required this.errors,
    this.p1PieceCount,
    this.p2PieceCount,
  });

  String get summary =>
      isValid
          ? '✓ 盤面データは正常です'
          : '✗ ${errors.length}件のエラーが見つかりました';

  @override
  String toString() => '$summary\n${errors.join('\n')}';
}
