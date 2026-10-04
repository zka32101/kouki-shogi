// lib/book_decoder.dart
// やねうら王形式の定跡書(.db)をデコード
// 形式: https://github.com/yaneurao/YaneuraOu/blob/master/docs/book_format.md

import 'dart:io';
import 'dart:typed_data';
import 'piece.dart';
import 'sfen_parser.dart';

/// やねうら王の定跡書ファイルからSFEN局面を抽出
class BookDecoder {
  /// .db定跡書ファイルを読み込み、SFEN局面リストを返す
  /// 戻値: 抽出したSFEN文字列のリスト
  static Future<List<String>> decodeSfenFromBook(String bookPath) async {
    try {
      final file = File(bookPath);
      if (!await file.exists()) {
        throw Exception('定跡書ファイルが見つかりません: $bookPath');
      }

      final bytes = await file.readAsBytes();
      return _parseSfenFromBytes(bytes);
    } catch (e) {
      print('Error: $e');
      return [];
    }
  }

  /// バイナリデータからSFEN局面を抽出（簡略実装）
  /// 注: 完全なパーサーではなく、テンプレート
  static List<String> _parseSfenFromBytes(Uint8List bytes) {
    final sfens = <String>[];

    // やねうら王形式の定跡書ヘッダーをチェック
    // ヘッダー: "YANEURAOU_BOOK1" (15 bytes)
    const headerMagic = 'YANEURAOU_BOOK1';

    if (bytes.length < 16) {
      print('ファイルが短すぎます（ヘッダー不完全）');
      return sfens;
    }

    final headerStr =
        String.fromCharCodes(bytes.sublist(0, 15)).replaceAll('\x00', '');

    if (!headerStr.startsWith('YANEURAOU')) {
      print('警告: 标準的なやねうら王ヘッダーではありません');
    }

    // 局面データの解析開始
    // Note: 完全な実装にはバイナリフォーマットの詳細理解が必要
    // ここではスタブとして、簡単な処理のみ
    print('定跡書サイズ: ${bytes.length} bytes');
    print('ヘッダー: $headerStr');

    // 実装例：テキスト形式の定跡書から抽出
    // 多くの公開定跡書はテキスト形式（SFEN1行）で配布されている
    sfens.addAll(_extractFromTextBook(bytes));

    return sfens;
  }

  /// テキスト形式の定跡書をパース（SFEN1行、重み付けなど）
  static List<String> _extractFromTextBook(Uint8List bytes) {
    final sfens = <String>[];

    try {
      // UTF-8デコード
      final text = String.fromCharCodes(bytes);
      final lines = text.split('\n');

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

        // SFEN形式: "sfen ...位置記号... moves ..."
        if (trimmed.startsWith('sfen ')) {
          // 重み付けなどの追加情報を除去
          final parts = trimmed.split(' ');
          if (parts.length >= 2) {
            // 最初の"sfen"を除いた部分から、"moves"までを抽出
            final movesIdx = parts.indexOf('moves');
            final sfenEnd = movesIdx > 0 ? movesIdx : parts.length;
            final sfen = parts.sublist(1, sfenEnd).join(' ');
            if (sfen.isNotEmpty) {
              sfens.add(sfen);
            }
          }
        }
      }
    } catch (e) {
      print('テキスト解析エラー: $e');
    }

    return sfens;
  }

  /// 定跡書から重要な局面を抽出（ヒューリスティック）
  /// - 盤の中盤以降の局面
  /// - 攻防が激しい局面（玉が危なそう）
  static List<String> filterImportantPositions(List<String> sfens) {
    final filtered = <String>[];

    for (final sfen in sfens) {
      try {
        final parsed = parseSfen(sfen);
        final ply = _estimateMoveNumber(sfen);

        // 条件1: 20手以上（中盤以降）
        if (ply < 20) continue;

        // 条件2: 盤が満杯すぎない（実現性の高い局面）
        final pieceCount = _countPieces(parsed.board);
        if (pieceCount < 8 || pieceCount > 32) continue;

        filtered.add(sfen);
      } catch (e) {
        // パース失敗の局面はスキップ
        continue;
      }
    }

    return filtered;
  }

  /// SFEN文字列から手数を推定
  static int _estimateMoveNumber(String sfen) {
    final parts = sfen.split(' ');
    if (parts.length >= 4) {
      try {
        return int.parse(parts[3]); // 4番目がムーブナンバー
      } catch (e) {
        return 0;
      }
    }
    return 0;
  }

  /// 盤面の駒数をカウント
  static int _countPieces(List<List<Piece?>> board) {
    int count = 0;
    for (final row in board) {
      for (final piece in row) {
        if (piece != null) count++;
      }
    }
    return count;
  }
}
