// lib/yaneuraou_service_web.dart — YaneuraOu WASM ブリッジ (Flutter Web専用)
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

import 'piece.dart';

/// YaneuraOu WASM エンジンを Web Worker 経由で動かすサービス。
class YaneuraouService {
  YaneuraouService._();

  static html.Worker? _worker;
  static Completer<void>? _readyCompleter;
  static Completer<String?>? _moveCompleter;
  static bool _isReady = false;
  static bool _isLoading = false;

  static Future<bool> initialize() async {
    if (_isReady) return true;
    if (_isLoading) {
      try {
        await _readyCompleter?.future;
        return _isReady;
      } catch (_) {
        return false;
      }
    }

    _isLoading = true;
    _readyCompleter = Completer<void>();

    try {
      _worker = html.Worker('yaneuraou-worker.js');
      _worker!.onMessage.listen(_onMessage);
      _worker!.onError.listen((e) {
        _isLoading = false;
        if (!(_readyCompleter?.isCompleted ?? true)) {
          _readyCompleter!.completeError('Worker error: $e');
        }
      });

      await _readyCompleter!.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException(
          'YaneuraOu init timeout',
          const Duration(seconds: 60),
        ),
      );
      return _isReady;
    } catch (_) {
      _isLoading = false;
      _isReady = false;
      _worker?.terminate();
      _worker = null;
      return false;
    }
  }

  static void _onMessage(html.MessageEvent e) {
    final data = e.data;
    if (data is! Map) return;
    final type = data['type'] as String?;

    switch (type) {
      case 'ready':
        _isReady = true;
        _isLoading = false;
        if (!(_readyCompleter?.isCompleted ?? true)) {
          _readyCompleter!.complete();
        }

      case 'bestmove':
        final move = data['move'] as String?;
        if (!(_moveCompleter?.isCompleted ?? true)) {
          _moveCompleter!.complete(move);
        }

      case 'error':
        _isLoading = false;
        if (!(_readyCompleter?.isCompleted ?? true)) {
          _readyCompleter!.completeError(data['message'] ?? 'error');
        }
        if (!(_moveCompleter?.isCompleted ?? true)) {
          _moveCompleter!.complete(null);
        }
    }
  }

  static Future<String?> getBestMove({
    required List<List<Piece?>> board,
    required Map<PieceType, int> p1Hand,
    required Map<PieceType, int> p2Hand,
    required bool p1Turn,
    int byoyomi = 3000,
  }) async {
    if (!_isReady) {
      final ok = await initialize();
      if (!ok) return null;
    }

    final sfen = boardToSfen(board, p1Hand, p2Hand, p1Turn);
    _moveCompleter = Completer<String?>();
    _worker!.postMessage({'type': 'go', 'sfen': sfen, 'byoyomi': byoyomi});

    try {
      return await _moveCompleter!.future.timeout(
        Duration(milliseconds: byoyomi + 5000),
        onTimeout: () {
          _worker?.postMessage({'type': 'stop'});
          return null;
        },
      );
    } catch (_) {
      return null;
    }
  }

  /// 局面の評価値を取得（単位: cp セント）
  /// 正=先手有利、負=後手有利
  /// 例: 300cp = 先手が約3目良い
  static Future<int?> evaluatePosition({
    required List<List<Piece?>> board,
    required Map<PieceType, int> p1Hand,
    required Map<PieceType, int> p2Hand,
    required bool p1Turn,
    int depth = 10,
  }) async {
    if (!_isReady) {
      final ok = await initialize();
      if (!ok) return null;
    }

    final sfen = boardToSfen(board, p1Hand, p2Hand, p1Turn);

    try {
      // YaneuraOu に 'eval' コマンドで評価値を取得
      final evalCompleter = Completer<int?>();
      final messageListener = (html.MessageEvent e) {
        final data = e.data;
        if (data is Map && data['type'] == 'eval') {
          final score = data['score'] as int?;
          if (!evalCompleter.isCompleted) {
            evalCompleter.complete(score);
          }
        }
      };

      _worker!.onMessage.listen(messageListener, onDone: () {
        if (!evalCompleter.isCompleted) {
          evalCompleter.complete(null);
        }
      });

      _worker!.postMessage({
        'type': 'eval',
        'sfen': sfen,
        'depth': depth,
      });

      return await evalCompleter.future.timeout(
        Duration(seconds: 10),
        onTimeout: () {
          _worker?.postMessage({'type': 'stop'});
          return null;
        },
      );
    } catch (e) {
      print('evaluatePosition error: $e');
      return null;
    }
  }

  static String boardToSfen(
    List<List<Piece?>> board,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
    bool p1Turn,
  ) {
    final sb = StringBuffer();
    for (int row = 0; row < 9; row++) {
      int empty = 0;
      for (int col = 0; col < 9; col++) {
        final p = board[row][col];
        if (p == null) {
          empty++;
        } else {
          if (empty > 0) { sb.write(empty); empty = 0; }
          sb.write(_pieceToSfen(p));
        }
      }
      if (empty > 0) sb.write(empty);
      if (row < 8) sb.write('/');
    }
    sb.write(p1Turn ? ' b ' : ' w ');

    const order = [
      PieceType.rook, PieceType.bishop, PieceType.gold,
      PieceType.silver, PieceType.knight, PieceType.lance, PieceType.pawn,
    ];
    const chars = ['R', 'B', 'G', 'S', 'N', 'L', 'P'];

    final hand = StringBuffer();
    for (int i = 0; i < order.length; i++) {
      final n = p1Hand[order[i]] ?? 0;
      if (n > 0) { if (n > 1) hand.write(n); hand.write(chars[i]); }
    }
    for (int i = 0; i < order.length; i++) {
      final n = p2Hand[order[i]] ?? 0;
      if (n > 0) { if (n > 1) hand.write(n); hand.write(chars[i].toLowerCase()); }
    }

    sb.write(hand.isEmpty ? '-' : hand);
    sb.write(' 1');
    return sb.toString();
  }

  static String _pieceToSfen(Piece p) {
    const map = {
      PieceType.king:           'K',
      PieceType.rook:           'R',
      PieceType.bishop:         'B',
      PieceType.gold:           'G',
      PieceType.silver:         'S',
      PieceType.knight:         'N',
      PieceType.lance:          'L',
      PieceType.pawn:           'P',
      PieceType.promotedRook:   '+R',
      PieceType.promotedBishop: '+B',
      PieceType.promotedSilver: '+S',
      PieceType.promotedKnight: '+N',
      PieceType.promotedLance:  '+L',
      PieceType.promotedPawn:   '+P',
    };
    final s = map[p.type]!;
    return p.isPlayer1 ? s : s.toLowerCase();
  }

  static AMove? usiToAMove(String usi) {
    if (usi.isEmpty || usi == 'resign' || usi == 'win') return null;
    if (usi.length >= 4 && usi[1] == '*') {
      final toFile = int.tryParse(usi[2]);
      if (toFile == null) return null;
      final toRow = usi[3].codeUnitAt(0) - 'a'.codeUnitAt(0);
      final toCol = 9 - toFile;
      final pt = _sfenCharToPt(usi[0].toUpperCase());
      if (pt == null) return null;
      return AMove(fr: -1, fc: -1, tr: toRow, tc: toCol, drop: pt);
    }
    if (usi.length < 4) return null;
    final fromFile = int.tryParse(usi[0]);
    final toFile   = int.tryParse(usi[2]);
    if (fromFile == null || toFile == null) return null;
    final fromRow = usi[1].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final toRow   = usi[3].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final promote = usi.length > 4 && usi[4] == '+';
    return AMove(fr: fromRow, fc: 9 - fromFile, tr: toRow, tc: 9 - toFile, promote: promote);
  }

  static PieceType? _sfenCharToPt(String c) {
    switch (c) {
      case 'K': return PieceType.king;
      case 'R': return PieceType.rook;
      case 'B': return PieceType.bishop;
      case 'G': return PieceType.gold;
      case 'S': return PieceType.silver;
      case 'N': return PieceType.knight;
      case 'L': return PieceType.lance;
      case 'P': return PieceType.pawn;
      default:  return null;
    }
  }

  static void dispose() {
    _worker?.terminate();
    _worker = null;
    _isReady = false;
    _isLoading = false;
    _readyCompleter = null;
    _moveCompleter = null;
  }
}
