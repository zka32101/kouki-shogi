// lib/ai_data_service.dart — 棋譜収集・オープニングブック（AI強化用）

import 'dart:convert';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'piece.dart';
import 'ranking_service.dart';

class AiDataService {
  AiDataService._();

  static bool _firebaseReady = false;
  static void setReady() => _firebaseReady = true;

  static DatabaseReference get _db => FirebaseDatabase.instance.ref();

  // ── ローカルキャッシュ（オープニングブック） ────────────────────────────
  // boardHash → { moveKey → (wins, total) }
  static final Map<String, Map<String, (int, int)>> _openingBook = {};
  static bool _bookLoaded = false;

  // ── ボード状態のハッシュ（81マス × 駒種+手番のコンパクト表現） ──────────
  static String boardHash(List<List<Piece?>> b) {
    final buf = StringBuffer();
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p == null) {
          buf.write('_');
        } else {
          buf.write('${p.type.index}${p.isPlayer1 ? 'S' : 'G'}');
        }
      }
    }
    return buf.toString();
  }

  // AMove → moveKey 文字列
  static String _moveKey(AMove mv) =>
      '${mv.fr}_${mv.fc}_${mv.tr}_${mv.tc}_${mv.promote ? 1 : 0}_${mv.drop?.index ?? 99}';

  // moveKey 文字列 → AMove
  static AMove? _parseMove(String key) {
    final parts = key.split('_');
    if (parts.length < 6) return null;
    try {
      final fr      = int.parse(parts[0]);
      final fc      = int.parse(parts[1]);
      final tr      = int.parse(parts[2]);
      final tc      = int.parse(parts[3]);
      final promote = parts[4] == '1';
      final dropIdx = int.parse(parts[5]);
      final drop    = dropIdx == 99 ? null : PieceType.values[dropIdx];
      return AMove(fr: fr, fc: fc, tr: tr, tc: tc, promote: promote, drop: drop);
    } catch (_) {
      return null;
    }
  }

  // ── 棋譜アップロード（AI学習用データ収集） ──────────────────────────────
  // kifu       : 棋譜リスト
  // boardHistory: 各手の局面スナップショット（手番前の盤面）
  // result     : 対局結果文字列
  // aiLevel    : AI深さ
  static Future<void> uploadGame({
    required List<KifuMove> kifu,
    required List<List<List<Piece?>>> boardHistory,
    required String result,
    required int aiLevel,
  }) async {
    if (!_firebaseReady) return;
    if (kifu.isEmpty || boardHistory.length < 2) return;
    if (aiLevel < 3) return; // depth<3 はノイズが多いため収集しない

    try {
      final userId = await RankingService.getUserId();
      final gameId = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

      // 軽量棋譜表現
      final moves = kifu.map((m) => {
        'fr': m.fr, 'fc': m.fc,
        'tr': m.tr, 'tc': m.tc,
        'p':  m.promote ? 1 : 0,
        if (m.drop != null) 'd': m.drop!.index,
      }).toList();

      await _db.child('kifus/$userId/$gameId').set({
        'moves':     moves,
        'result':    result,
        'aiLevel':   aiLevel,
        'moveCount': kifu.length,
        'date':      DateTime.now().toIso8601String(),
      });

      // オープニングブックを更新（序盤20手以内）
      final winnerIsP1 = result.contains('先手の勝ち');
      await _updateOpeningBook(kifu, boardHistory, winnerIsP1);
    } catch (_) {}
  }

  // ── オープニングブックへ記録（勝者の序盤手を累積） ──────────────────────
  static Future<void> _updateOpeningBook(
    List<KifuMove> kifu,
    List<List<List<Piece?>>> boardHistory,
    bool winnerIsP1,
  ) async {
    const maxPly = 20; // 序盤20手までを記録
    final limit  = min(kifu.length, min(maxPly, boardHistory.length - 1));
    final updates = <String, Object>{};

    for (int i = 0; i < limit; i++) {
      final isP1Turn      = i % 2 == 0;
      final isWinnersTurn = isP1Turn == winnerIsP1;

      final board   = boardHistory[i];
      final hash    = boardHash(board);
      final mv      = KifuMoveToAMove(kifu[i]);
      final key     = _moveKey(mv);
      final path    = 'opening_book/$hash/$key';

      // total は常に +1、wins は勝者の手のみ +1
      updates['$path/total'] = ServerValue.increment(1);
      if (isWinnersTurn) {
        updates['$path/wins'] = ServerValue.increment(1);
      }
    }

    if (updates.isNotEmpty) {
      await _db.update(updates);
    }
  }

  // KifuMove → AMove 変換
  static AMove KifuMoveToAMove(KifuMove m) =>
      AMove(fr: m.fr, fc: m.fc, tr: m.tr, tc: m.tc,
            promote: m.promote, drop: m.drop);

  // ── オープニングブックをダウンロード（起動時1回・24時間キャッシュ） ───────
  static Future<void> downloadOpeningBook() async {
    if (_bookLoaded) return;
    if (!_firebaseReady) { _bookLoaded = true; return; }
    try {
      const cacheKey     = 'opening_book_cache';
      const cacheTimeKey = 'opening_book_cache_time';
      final prefs = await SharedPreferences.getInstance();

      final cachedTime = prefs.getInt(cacheTimeKey) ?? 0;
      final now        = DateTime.now().millisecondsSinceEpoch;

      if (now - cachedTime < 24 * 3600 * 1000) {
        final cached = prefs.getString(cacheKey);
        if (cached != null && cached.isNotEmpty) {
          _loadBookFromJson(cached);
          _bookLoaded = true;
          return;
        }
      }

      // Firebase から上位 500 エントリ取得
      final snapshot = await _db.child('opening_book')
          .limitToLast(500)
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final raw = jsonEncode(snapshot.value);
        await prefs.setString(cacheKey, raw);
        await prefs.setInt(cacheTimeKey, now);
        _loadBookFromJson(raw);
      }
    } catch (_) {}
    _bookLoaded = true;
  }

  static void _loadBookFromJson(String jsonStr) {
    try {
      final raw = jsonDecode(jsonStr);
      if (raw is! Map) return;
      _openingBook.clear();
      for (final hashEntry in (raw as Map).entries) {
        if (hashEntry.value is! Map) continue;
        final moves = <String, (int, int)>{};
        for (final moveEntry in (hashEntry.value as Map).entries) {
          if (moveEntry.value is! Map) continue;
          final mv    = moveEntry.value as Map;
          final wins  = (mv['wins']  as num?)?.toInt() ?? 0;
          final total = (mv['total'] as num?)?.toInt() ?? 1;
          moves[moveEntry.key as String] = (wins, total);
        }
        if (moves.isNotEmpty) {
          _openingBook[hashEntry.key as String] = moves;
        }
      }
    } catch (_) {}
  }

  // ── AI: オープニングブックから最善手を取得 ───────────────────────────────
  // 返り値: null → ブックにない or 信頼度不足 → 通常探索へ
  // plyCount: 0-based (0=先手初手)
  static AMove? lookupOpeningBook(
    List<List<Piece?>> board,
    int plyCount,
  ) {
    if (!_bookLoaded || _openingBook.isEmpty) return null;
    if (plyCount >= 20) return null; // 序盤のみ

    final hash  = boardHash(board);
    final moves = _openingBook[hash];
    if (moves == null || moves.isEmpty) return null;

    // 信頼度の高い手を選ぶ（10局以上かつ勝率55%以上）
    String? bestKey;
    double  bestScore = 0.0;
    for (final entry in moves.entries) {
      final (wins, total) = entry.value;
      if (total < 10) continue;
      final winRate = wins / total;
      if (winRate >= 0.55 && winRate > bestScore) {
        bestScore = winRate;
        bestKey   = entry.key;
      }
    }
    if (bestKey == null) return null;
    return _parseMove(bestKey);
  }

  // ── 統計取得（デバッグ用） ─────────────────────────────────────────────────
  static int get bookSize => _openingBook.length;
}
