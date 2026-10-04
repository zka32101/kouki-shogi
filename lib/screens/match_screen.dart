// lib/screens/match_screen.dart
// リアルタイムネットワーク対局画面（盤面同期付き）

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../logic.dart';
import '../piece.dart';
import '../game_screen.dart';
import '../services/matching_service.dart';
import '../services/network_service.dart';
import '../services/board_sync_service.dart';
import '../character_icons.dart';
import 'network_board_widget.dart';
import 'match_chat_widget.dart';
import 'report_user_screen.dart';
import 'match_analyzer_screen.dart';
import '../theme_config.dart';
import '../theme/app_theme.dart';
import 'dart:ui' show FontFeature;
import '../services/cheat_detection_service.dart';
import '../services/rating_service.dart';
import '../badge_service.dart';
import '../stats_screen.dart' show ratingToRank, ratingToColor;
import '../rank_badge_widget.dart' show showRankUpDialog;
import '../study_calendar_screen.dart';
import '../cloud_sync_service.dart';

class MatchScreen extends StatefulWidget {
  final String matchId;
  final bool isPlayer1;
  final String myPlayerId; // 自分のプレイヤーID（勝敗判定用）
  final int timeLimitSec;  // 持ち時間（秒）: 600=10分, 300=5分
  final int? opponentRating; // マッチング時点の相手レーティング（対局後のレーティング反映用。不明ならnull=反映しない）

  const MatchScreen({
    super.key,
    required this.matchId,
    required this.isPlayer1,
    this.myPlayerId = '',
    this.timeLimitSec = 600,
    this.opponentRating,
  });

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  final MatchingService _matchingService = MatchingService();
  final NetworkService _networkService = NetworkService();
  final BoardSyncService _boardSync = BoardSyncService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late Stream<NetworkBoardState?> _boardStream;
  bool _isResigning = false;
  bool _showChat = false;
  bool _showKifu = false;
  bool _isMakingMove = false;

  // タイム管理
  Timer? _clockTimer;
  int _myTimeRemaining = 600;
  int _opponentTimeRemaining = 600;
  DateTime? _lastTickAt;

  // 千日手検出: RepetitionChecker（連続王手検出対応）
  final _repChecker = RepetitionChecker();
  bool _sennichiteHandled = false;

  // 互換性のため残す（_checkSpecialEndings で使用）
  final List<String> _boardHistory = [];
  bool _sennichiteDialogShown = false;

  // 遅延行為トラッカー（対局中に相手の思考時間を記録）
  final _softPlayTracker = InGameSoftPlayTracker();
  DateTime? _opponentTurnStartedAt;
  int? _prevCurrentTurn;
  bool _trackingSaved = false;
  bool _badgeChecked = false;
  bool _ratingApplied = false;
  bool _studyRecorded = false;
  bool _cheatAnalysisTriggered = false;

  // キャラクターアイコン
  String? _myCharIconId;

  // 盤面テーマ
  PieceTheme _theme = PieceTheme.standard;

  // 最新の盤面状態キャッシュ（毎回Firestore読まずに使用）
  NetworkBoardState? _latestBoardState;

  // 時計: 5秒毎にRTDB同期
  Timer? _clockSyncTimer;
  int _clockSyncIntervalSec = 0;
  bool _clockInitialized = false;

  // プレゼンス（クラッシュ検出）
  StreamSubscription<bool>? _presenceSub;
  Timer? _disconnectCountdownTimer;
  bool _opponentConnected = false;
  bool _everSeenOpponentOnline = false;
  int _disconnectCountdown = 60;

  @override
  void initState() {
    super.initState();
    _myTimeRemaining = widget.timeLimitSec;
    _opponentTimeRemaining = widget.timeLimitSec;
    _boardStream = _boardSync.watchBoardState(widget.matchId).map((state) {
      _latestBoardState = state;

      // ── 相手思考時間トラッキング ──────────────────────────────
      if (state != null && state.status == 'active') {
        final myTurnNum = widget.isPlayer1 ? 1 : 2;
        final prev = _prevCurrentTurn;
        if (prev != null) {
          // 相手ターン → 自分ターン に切り替わった = 相手が指した
          if (prev != myTurnNum && state.currentTurn == myTurnNum) {
            if (_opponentTurnStartedAt != null) {
              final thinkMs = DateTime.now()
                  .difference(_opponentTurnStartedAt!)
                  .inMilliseconds;
              _softPlayTracker.recordMove(
                thinkTimeMs: thinkMs,
                timeLimitMs: widget.timeLimitSec * 1000,
              );
              _opponentTurnStartedAt = null;
            }
          }
          // 自分ターン → 相手ターン に切り替わった = 自分が指した
          if (prev == myTurnNum && state.currentTurn != myTurnNum) {
            _opponentTurnStartedAt = DateTime.now();
          }
        }
        _prevCurrentTurn = state.currentTurn;
      }

      // RTDBからのサーバー時刻基準で時計を常に補正（毎回再計算）
      if (state != null && state.lastTickMs > 0) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final elapsedMs = nowMs - state.lastTickMs;
        final p1Remaining = (state.p1Ms - (state.lastTurn == 1 ? elapsedMs : 0))
            .clamp(0, 600000);
        final p2Remaining = (state.p2Ms - (state.lastTurn == 2 ? elapsedMs : 0))
            .clamp(0, 600000);
        final myTarget  = ((widget.isPlayer1 ? p1Remaining : p2Remaining) / 1000).ceil();
        final opTarget  = ((widget.isPlayer1 ? p2Remaining : p1Remaining) / 1000).ceil();
        // 初回または3秒以上ずれている場合のみ上書き（UI飛び防止）
        if (!_clockInitialized || (_myTimeRemaining - myTarget).abs() > 3) {
          _myTimeRemaining = myTarget;
        }
        if (!_clockInitialized || (_opponentTimeRemaining - opTarget).abs() > 3) {
          _opponentTimeRemaining = opTarget;
        }
        _clockInitialized = true;
      }
      // 試合終了を検知してクロックを止める + 保存済みマッチをクリア
      if (state?.status == 'finished') {
        _clockTimer?.cancel();
        _clockSyncTimer?.cancel();
        Future.microtask(_clearActiveMatch);
        // 遅延行為トラッキングデータをFirestoreに保存（1回のみ）
        if (!_trackingSaved && _softPlayTracker.moveCount >= 3) {
          _trackingSaved = true;
          Future.microtask(() async {
            final opId = await _getOpponentId();
            if (opId != null) {
              await CheatDetectionService().saveInGameTracking(
                widget.matchId, opId, _softPlayTracker);
            }
          });
        }
        // レーティング反映→バッジ判定の順で実行（1回のみ）。
        // レーティング閾値バッジがこの対局の結果を反映する前の古い値で
        // 判定されないよう、必ずレーティング更新の完了を待ってから判定する。
        if (!_badgeChecked || !_ratingApplied) {
          final needRating = !_ratingApplied;
          final needBadge = !_badgeChecked;
          _badgeChecked = true;
          _ratingApplied = true;
          Future.microtask(() async {
            if (needRating) await _applyNetworkRatingUpdate(state!);
            if (needBadge) await _checkNetBadges(state!);
          });
        }
        // 学習カレンダー（連続記録・実績バッジ）に対局実施を記録（1回のみ）
        if (!_studyRecorded) {
          _studyRecorded = true;
          StudyCalendarScreen.recordActivity('taikyoku');
        }
        // 対局後のチート分析（1回のみ）。従来はmatching_service.dartの
        // 未使用メソッド内でしか呼ばれておらず、実際の対局終了経路からは
        // 一度も発火していなかった
        if (!_cheatAnalysisTriggered) {
          _cheatAnalysisTriggered = true;
          Future.microtask(() async {
            final myId = widget.myPlayerId.isNotEmpty
                ? widget.myPlayerId
                : (_networkService.currentUser?.uid ?? '');
            final opId = await _getOpponentId();
            if (myId.isNotEmpty) {
              await CheatDetectionService().analyzePlayer(myId);
            }
            if (opId != null) {
              await CheatDetectionService().analyzePlayer(opId);
            }
          });
        }
      }
      return state;
    });
    _startClock();
    _initBoardIfNeeded();
    _loadCharIcon();
    _loadTheme();
    _initPresence();
    _saveActiveMatch();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _clockSyncTimer?.cancel();
    _presenceSub?.cancel();
    _disconnectCountdownTimer?.cancel();
    _boardSync.goOffline(widget.matchId, widget.isPlayer1).catchError((_) {});
    super.dispose();
  }

  // ── 初期化 ─────────────────────────────────────────────────

  Future<void> _loadCharIcon() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('character_icon_id');
      if (mounted) setState(() => _myCharIconId = id);
    } catch (_) {}
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIdx = prefs.getInt('piece_theme_idx') ?? 0;
      final themes = PieceTheme.values;
      final theme = themeIdx < themes.length ? themes[themeIdx] : PieceTheme.standard;
      if (mounted) setState(() => _theme = theme);
    } catch (_) {}
  }

  Future<void> _initBoardIfNeeded() async {
    // ゲスト側はホストがマッチング時に初期化済み
    if (!widget.isPlayer1) return;
    try {
      final snap = await FirebaseDatabase.instance
          .ref('games/${widget.matchId}').get();
      if (!snap.exists) {
        await _boardSync.initMatchBoard(
          widget.matchId,
          board: GL.initialBoard(),
          timeLimitSec: widget.timeLimitSec,
        );
      }
    } catch (e) {
      print('Init board error: $e');
    }
  }

  // ── プレゼンス（クラッシュ検出）───────────────────────────────

  Future<void> _initPresence() async {
    try {
      await _boardSync.goOnline(widget.matchId, widget.isPlayer1);
      _presenceSub = _boardSync
          .watchOpponentPresence(widget.matchId, widget.isPlayer1)
          .listen(_onOpponentPresence);
    } catch (e) {
      print('[Presence] init error: $e');
    }
  }

  void _onOpponentPresence(bool isOnline) {
    if (_latestBoardState?.isFinished == true) return;
    if (isOnline) {
      _everSeenOpponentOnline = true;
      _disconnectCountdownTimer?.cancel();
      if (!_opponentConnected && mounted) {
        setState(() {
          _opponentConnected = true;
          _disconnectCountdown = 60;
        });
      }
    } else {
      // 一度もオンラインを確認していない場合はカウントダウンしない
      if (_everSeenOpponentOnline && _opponentConnected && mounted) {
        setState(() => _opponentConnected = false);
        _startDisconnectCountdown();
      }
    }
  }

  void _startDisconnectCountdown() {
    _disconnectCountdown = 60;
    _disconnectCountdownTimer?.cancel();
    _disconnectCountdownTimer =
        Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _latestBoardState?.isFinished == true) {
        t.cancel();
        return;
      }
      setState(() {
        _disconnectCountdown = (_disconnectCountdown - 1).clamp(0, 60);
      });
      if (_disconnectCountdown <= 0) {
        t.cancel();
        _claimVictoryByDisconnect();
      }
    });
  }

  Future<void> _claimVictoryByDisconnect() async {
    if (_latestBoardState?.isFinished == true) return;
    try {
      final myId = widget.myPlayerId.isNotEmpty
          ? widget.myPlayerId
          : (_networkService.currentUser?.uid ?? '');
      if (myId.isEmpty) return;
      await _networkService.finishMatchWithRating(
          widget.matchId, myId, 'disconnect');
    } catch (e) {
      print('[Presence] claim victory error: $e');
    }
  }

  // ── 対局セッション保存（クラッシュ後の復帰用）──────────────────

  static const _kMatchId = 'net_active_match_id';
  static const _kMatchIsP1 = 'net_active_match_is_p1';
  static const _kMatchPlayerId = 'net_active_match_player_id';
  static const _kMatchTimeLimit = 'net_active_match_time_limit';

  Future<void> _saveActiveMatch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kMatchId, widget.matchId);
      await prefs.setBool(_kMatchIsP1, widget.isPlayer1);
      await prefs.setString(_kMatchPlayerId, widget.myPlayerId);
      await prefs.setInt(_kMatchTimeLimit, widget.timeLimitSec);
    } catch (_) {}
  }

  static Future<void> _clearActiveMatch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kMatchId);
      await prefs.remove(_kMatchIsP1);
      await prefs.remove(_kMatchPlayerId);
      await prefs.remove(_kMatchTimeLimit);
    } catch (_) {}
  }

  // ── タイマー管理 ───────────────────────────────────────────

  void _startClock() {
    _lastTickAt = DateTime.now();
    _clockTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _tickClock());
  }

  void _tickClock() {
    // ゲーム終了済みなら何もしない
    if (_latestBoardState?.status == 'finished') return;

    final currentTurn = _latestBoardState?.currentTurn ?? 1;
    final isMyTurn = (currentTurn == 1) == widget.isPlayer1;

    if (!mounted) return;
    setState(() {
      if (isMyTurn) {
        _myTimeRemaining = (_myTimeRemaining - 1).clamp(0, 99999);
      } else {
        _opponentTimeRemaining = (_opponentTimeRemaining - 1).clamp(0, 99999);
      }
    });

    // タイムアウト検知（自分の時間切れのみ処理）
    if (isMyTurn && _myTimeRemaining <= 0) {
      _clockTimer?.cancel();
      _clockSyncTimer?.cancel();
      _handleTimeout();
      return;
    }

    // 5秒毎にRTDBへ同期（精度向上のため短縮）
    _clockSyncIntervalSec++;
    if (_clockSyncIntervalSec >= 5) {
      _clockSyncIntervalSec = 0;
      _syncClockToRtdb();
    }
  }

  void _syncClockToRtdb() {
    final p1Ms = (widget.isPlayer1
        ? _myTimeRemaining
        : _opponentTimeRemaining) * 1000;
    final p2Ms = (widget.isPlayer1
        ? _opponentTimeRemaining
        : _myTimeRemaining) * 1000;
    final currentTurn = _latestBoardState?.currentTurn ?? 1;
    _boardSync.syncClock(
      matchId: widget.matchId,
      p1Ms: p1Ms,
      p2Ms: p2Ms,
      currentTurn: currentTurn,
    ).catchError((_) {});
  }

  Future<void> _handleTimeout() async {
    try {
      final opponentId = await _getOpponentId();
      if (opponentId == null) return;

      await _networkService.finishMatchWithRating(
          widget.matchId, opponentId, 'timeout');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('時間切れで敗北しました', style: TextStyle(color: Colors.red))),
        );
      }
    } catch (e) {
      print('Timeout error: $e');
    }
  }

  // 相手プレイヤーIDをRTDBから取得（Firestoreなしで動作）
  Future<String?> _getOpponentId() async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref('games/${widget.matchId}').get();
      if (!snap.exists) return null;
      final data = Map<String, dynamic>.from(snap.value as Map);
      return widget.isPlayer1
          ? data['player2_id'] as String?
          : data['player1_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── 指し手 ─────────────────────────────────────────────────

  Future<void> _onMove(KifuMove move) async {
    if (_isMakingMove) return;
    setState(() => _isMakingMove = true);

    try {
      // キャッシュ済み盤面を使用（Firestoreを毎回読まない）
      final cached = _latestBoardState;
      if (cached == null) return;

      final board  = cached.board;
      final p1Hand = Map<PieceType, int>.from(cached.p1Hand);
      final p2Hand = Map<PieceType, int>.from(cached.p2Hand);

      // 指し手適用後の盤面を計算
      final newBoard  = GL.copy(board);
      final newP1Hand = Map<PieceType, int>.from(p1Hand);
      final newP2Hand = Map<PieceType, int>.from(p2Hand);
      GL.applyKifuMove(newBoard, newP1Hand, newP2Hand, move);

      final nextTurn = widget.isPlayer1 ? 2 : 1;
      final remainingMs = _myTimeRemaining * 1000;

      // RTDBにアトミックに書き込む
      await _boardSync.applyMove(
        matchId: widget.matchId,
        newBoard: newBoard,
        newP1Hand: newP1Hand,
        newP2Hand: newP2Hand,
        nextTurn: nextTurn,
        move: move,
        remainingMsForCurrentPlayer: remainingMs,
      );

      // 指した後の盤面で詰みチェック（上で計算済み）

      final opponentIsP1 = !widget.isPlayer1;
      final isCheckmate = _boardSync.isCheckmate(
        newBoard,
        newP1Hand,
        newP2Hand,
        opponentIsP1,
      );

      if (isCheckmate) {
        final myId = _networkService.currentUser!.uid;
        await _networkService.finishMatchWithRating(
            widget.matchId, myId, 'checkmate');
      } else {
        // 千日手・持将棋チェック
        _checkSpecialEndings(newBoard, newP1Hand, newP2Hand);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    } finally {
      if (mounted) setState(() => _isMakingMove = false);
    }
  }

  // ── 投了 ───────────────────────────────────────────────────

  Future<void> _resign() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('投了しますか？'),
        content: const Text('この対局を終了します。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('投了する')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isResigning = true);
    try {
      final opponentId = await _getOpponentId() ?? '';
      await _networkService.finishMatchWithRating(
          widget.matchId, opponentId, 'resignation');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
        setState(() => _isResigning = false);
      }
    }
  }

  // ── 千日手・持将棋検出 ────────────────────────────────────────

  String _boardHash(
    List<List<Piece?>> board,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
    bool isP1Turn,
  ) {
    final sb = StringBuffer();
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = board[r][c];
        sb.write(p == null ? '.' : '${p.type.index}${p.isPlayer1 ? 'B' : 'W'}');
      }
    }
    sb.write('|');
    for (final e in p1Hand.entries) sb.write('${e.key.index}:${e.value},');
    sb.write('|');
    for (final e in p2Hand.entries) sb.write('${e.key.index}:${e.value},');
    sb.write('|${isP1Turn ? '1' : '2'}');
    return sb.toString();
  }

  void _checkSpecialEndings(
    List<List<Piece?>> board,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
  ) {
    final isP1Turn = !widget.isPlayer1; // 相手番（今しがた指した後の次番）

    // ── 千日手チェック（RepetitionChecker 使用 · 連続王手検出対応）──
    if (!_sennichiteHandled &&
        _repChecker.record(board, p1Hand, p2Hand, isP1Turn)) {
      _sennichiteHandled = true;
      final isConsecutiveCheck =
          _repChecker.isConsecutiveCheck(board, p1Hand, p2Hand, isP1Turn);
      if (isConsecutiveCheck) {
        // 連続王手の千日手: isP1Turn 側に王手をかけ続けた相手（!isP1Turn）が負け
        // ネットワーク対局では自分が王手をかけていたかで判定
        final checkerIsMe = widget.isPlayer1 != isP1Turn;
        _showConsecutiveCheckLossDialog(myLose: checkerIsMe);
      } else {
        _showSennichiteDialog();
      }
      return;
    }

    // ── 持将棋: 両玉が相手陣に入りポイントを確認 ──
    if (_checkJishogi(board, p1Hand, p2Hand)) {
      _showJishogiDialog(board, p1Hand, p2Hand);
    }
  }

  bool _checkJishogi(
    List<List<Piece?>> board,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
  ) {
    // 先手玉が敵陣(row 0-2)に、後手玉が敵陣(row 6-8)にいるか
    bool p1KingIn = false, p2KingIn = false;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = board[r][c];
        if (p == null) continue;
        if (p.type == PieceType.king) {
          if (p.isPlayer1 && r <= 2) p1KingIn = true;
          if (!p.isPlayer1 && r >= 6) p2KingIn = true;
        }
      }
    }
    if (!p1KingIn || !p2KingIn) return false;

    // ポイントカウント: 飛・角=5点, 他=1点 (玉除く)
    int _count(List<List<Piece?>> b, Map<PieceType, int> hand, bool isP1) {
      int pts = 0;
      // 盤上の駒
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          final p = b[r][c];
          if (p == null || p.isPlayer1 != isP1 || p.type == PieceType.king) continue;
          final base = p.baseType == PieceType.rook || p.baseType == PieceType.bishop ? 5 : 1;
          pts += base;
        }
      }
      // 持ち駒
      for (final e in hand.entries) {
        final base = e.key == PieceType.rook || e.key == PieceType.bishop ? 5 : 1;
        pts += base * e.value;
      }
      return pts;
    }

    final p1Pts = _count(board, p1Hand, true);
    final p2Pts = _count(board, p2Hand, false);
    // 片方でも24点以上で持将棋判定を発動（正式ルール: 24点未満は負け）
    return p1Pts >= 24 || p2Pts >= 24;
  }

  void _showSennichiteDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('千日手', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        content: const Text(
          '同一局面が4回繰り返されました。\n千日手により引き分けを申し込みますか？',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('続ける'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _proposeDraw('sennichite');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
            child: const Text('引き分けを申し込む', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  /// 連続王手の千日手: 王手をかけ続けた側が負け（引き分け申し込みではなく確定）
  void _showConsecutiveCheckLossDialog({required bool myLose}) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          '連続王手の千日手',
          style: TextStyle(
            color: myLose ? Colors.redAccent : Colors.greenAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          myLose
              ? 'あなたが連続王手をかけ続けたため、\nルールにより負けとなります。'
              : '相手が連続王手をかけ続けたため、\nルールによりあなたの勝ちです！',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // 結果を確定させる
              try {
                final winnerId = myLose
                    ? await _getOpponentId() ?? ''
                    : (_networkService.currentUser?.uid ?? '');
                await _networkService.finishMatchWithRating(
                    widget.matchId, winnerId, 'consecutive_check');
              } catch (_) {}
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: myLose ? Colors.red.shade700 : Colors.green.shade700,
            ),
            child: const Text('確認', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showJishogiDialog(
    List<List<Piece?>> board,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
  ) {
    if (!mounted) return;

    // 点数計算（NyugyokuChecker と同じロジック）
    int _pts(bool isP1) {
      int pts = 0;
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          final p = board[r][c];
          if (p == null || p.isPlayer1 != isP1 || p.type == PieceType.king) continue;
          pts += (p.baseType == PieceType.rook || p.baseType == PieceType.bishop) ? 5 : 1;
        }
      }
      final hand = isP1 ? p1Hand : p2Hand;
      for (final e in hand.entries) {
        pts += (e.key == PieceType.rook || e.key == PieceType.bishop ? 5 : 1) * e.value;
      }
      return pts;
    }

    final p1Pts = _pts(true);
    final p2Pts = _pts(false);
    final myIsP1 = widget.isPlayer1;
    final myPts  = myIsP1 ? p1Pts : p2Pts;
    final oppPts = myIsP1 ? p2Pts : p1Pts;

    // 一方が24点未満 → 自動決着（不足側が負け）
    final p1Wins = p1Pts >= 24 && p2Pts < 24;
    final p2Wins = p2Pts >= 24 && p1Pts < 24;
    if (p1Wins || p2Wins) {
      final winnerId = p1Wins
          ? (widget.isPlayer1 ? (_networkService.currentUser?.uid ?? '') : '')
          : (!widget.isPlayer1 ? (_networkService.currentUser?.uid ?? '') : '');
      Future.microtask(() async {
        try {
          final wid = winnerId.isEmpty ? await _getOpponentId() ?? '' : winnerId;
          await _networkService.finishMatchWithRating(widget.matchId, wid, 'jishogi');
        } catch (_) {}
      });
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text(
            myPts >= 24 ? '持将棋 — あなたの勝ち' : '持将棋 — あなたの負け',
            style: TextStyle(
              color: myPts >= 24 ? Colors.greenAccent : Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '先手: $p1Pts点 / 後手: $p2Pts点\n'
            '24点未満のため${p1Wins ? "後手" : "先手"}の負けです。',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: myPts >= 24 ? Colors.green.shade700 : Colors.red.shade700,
              ),
              child: const Text('確認', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    // 両者24点以上 → 引き分け申し込みダイアログ
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('持将棋', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
        content: Text(
          '両玉が相手陣に入りました。\n'
          '先手: $p1Pts点 / 後手: $p2Pts点\n\n'
          '持将棋として引き分けを申し込みますか？',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('続ける'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _proposeDraw('jishogi');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            child: const Text('引き分けを申し込む', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _proposeDraw(String reason) async {
    try {
      await _firestore.collection('matches').doc(widget.matchId).update({
        'draw_proposed_by': _networkService.currentUser?.uid,
        'draw_reason': reason,
        'draw_proposed_at': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('引き分けを申し込みました。相手の応答を待っています...')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    }
  }

  // ── 通報 ───────────────────────────────────────────────────

  Future<void> _showReportDialog() async {
    try {
      final doc =
          await _firestore.collection('matches').doc(widget.matchId).get();
      final opponentId = widget.isPlayer1
          ? doc['player2_id'] as String?
          : doc['player1_id'] as String?;
      final opponentName = widget.isPlayer1
          ? doc['player2_name'] as String? ?? '相手'
          : doc['player1_name'] as String? ?? '相手';
      if (opponentId == null || !mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportUserScreen(
            reportedUserId: opponentId,
            reportedUsername: opponentName,
            matchId: widget.matchId,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    }
  }

  // ── UI ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isFinished = _latestBoardState?.isFinished == true;
    return PopScope(
      canPop: isFinished, // 試合終了後のみ戻れる
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return; // isFinished == true のとき（通常 pop）
        // 対局中に戻ろうとした → 投了確認ダイアログ
        final resign = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text(
              '対局を終了しますか？',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: const Text(
              '画面を離れると投了扱いになります。',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('続ける', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('投了して戻る'),
              ),
            ],
          ),
        );
        if (resign == true && mounted) {
          try {
            final opponentId = await _getOpponentId() ?? '';
            await _networkService.finishMatchWithRating(
                widget.matchId, opponentId, 'resignation');
            if (mounted) Navigator.pop(context);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('投了処理に失敗しました: $e')),
              );
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          title: const Text('対局中', style: TextStyle(color: Colors.white)),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: Icon(Icons.list_alt,
                  color: _showKifu ? Colors.amber : Colors.white70),
              onPressed: () => setState(() {
                _showKifu = !_showKifu;
                if (_showKifu) _showChat = false;
              }),
              tooltip: '棋譜',
            ),
            IconButton(
              icon: Icon(Icons.chat,
                  color: _showChat ? Colors.amber : Colors.white70),
              onPressed: () => setState(() {
                _showChat = !_showChat;
                if (_showChat) _showKifu = false;
              }),
              tooltip: 'チャット',
            ),
            IconButton(
              icon: const Icon(Icons.flag_outlined, color: Colors.white70),
              onPressed: _showReportDialog,
              tooltip: '通報',
            ),
          ],
        ),
        body: StreamBuilder<NetworkBoardState?>(
          stream: _boardStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final state = snapshot.data!;

            // ゲーム終了
            if (state.isFinished) {
              return _buildGameOverScreen(state);
            }

            final isMyTurn = (state.currentTurn == 1) == widget.isPlayer1;
            final adv = _computeAdvantage(state);

            return AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              color: _advantageBgColor(adv),
              child: SafeArea(
                child: Column(
                  children: [
                    // 切断バナー
                    if (!_opponentConnected)
                      Container(
                        color: Colors.orange.shade900,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.wifi_off,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '相手が切断されました。${_disconnectCountdown}秒後に勝利確定',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // 相手情報バー
                    _buildPlayerBar(isMe: false, isCurrentTurn: !isMyTurn),
                    // 形勢メーター
                    _buildAdvantageBar(adv),
                    // 盤面
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: NetworkBoardWidget(
                          state: state,
                          isPlayer1: widget.isPlayer1,
                          isMyTurn: isMyTurn && !_isMakingMove,
                          onMove: _onMove,
                          theme: _theme,
                        ),
                      ),
                    ),
                    // 形勢メーター（盤面下）
                    _buildAdvantageBar(adv),
                    // 自分情報バー
                    _buildPlayerBar(isMe: true, isCurrentTurn: isMyTurn),
                    // 操作ボタン
                    _buildActionBar(isMyTurn),
                    // チャットパネル
                    if (_showChat)
                      SizedBox(
                        height: 200,
                        child: MatchChatWidget(matchId: widget.matchId),
                      ),
                    // 棋譜パネル
                    if (_showKifu)
                      _buildKifuPanel(state),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── 形勢評価 ──────────────────────────────────────────────

  static const _pieceVal = <PieceType, int>{
    PieceType.rook: 10,
    PieceType.bishop: 9,
    PieceType.gold: 6,
    PieceType.silver: 5,
    PieceType.knight: 4,
    PieceType.lance: 4,
    PieceType.pawn: 1,
    PieceType.promotedRook: 13,
    PieceType.promotedBishop: 11,
    PieceType.promotedSilver: 6,
    PieceType.promotedKnight: 6,
    PieceType.promotedLance: 6,
    PieceType.promotedPawn: 6,
  };

  /// 駒得差から形勢を -1.0（後手有利）〜 +1.0（先手有利）で返す。
  double _computeAdvantage(NetworkBoardState state) {
    int p1 = 0, p2 = 0;
    for (final row in state.board) {
      for (final piece in row) {
        if (piece == null) continue;
        final v = _pieceVal[piece.type] ?? 0;
        if (piece.isPlayer1) p1 += v; else p2 += v;
      }
    }
    for (final e in state.p1Hand.entries) {
      p1 += (_pieceVal[e.key] ?? 0) * e.value;
    }
    for (final e in state.p2Hand.entries) {
      p2 += (_pieceVal[e.key] ?? 0) * e.value;
    }
    return ((p1 - p2) / 28.0).clamp(-1.0, 1.0);
  }

  /// 形勢に応じた背景色（先手優勢=青、後手優勢=赤）
  Color _advantageBgColor(double adv) {
    const neutral = AppTheme.bg;
    const p1Color = Color(0xFF0A1648);
    const p2Color = Color(0xFF380A0A);
    final abs = adv.abs();
    if (abs < 0.1) return neutral;
    final t = ((abs - 0.1) / 0.9).clamp(0.0, 1.0) * 0.75;
    return Color.lerp(neutral, adv > 0 ? p1Color : p2Color, t)!;
  }

  /// 形勢メーター（横棒）
  Widget _buildAdvantageBar(double adv) {
    final p1Share = ((adv + 1.0) / 2.0).clamp(0.0, 1.0);
    final p2Share = 1.0 - p1Share;
    final p1Flex = (p1Share * 1000).round().clamp(1, 999);
    final p2Flex = (p2Share * 1000).round().clamp(1, 999);
    return SizedBox(
      height: 5,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: p1Flex,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: Color.lerp(
                  const Color(0xFF304080),
                  const Color(0xFF2060FF),
                  (p1Share - 0.5).clamp(0.0, 0.5) * 2,
                ),
              ),
            ),
          ),
          Expanded(
            flex: p2Flex,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: Color.lerp(
                  const Color(0xFF803030),
                  const Color(0xFFFF2020),
                  (p2Share - 0.5).clamp(0.0, 0.5) * 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── プレイヤーバー ──────────────────────────────────────────

  Widget _buildPlayerBar({required bool isMe, bool isCurrentTurn = false}) {
    final time = isMe ? _myTimeRemaining : _opponentTimeRemaining;
    final timeStr = _formatTime(time);
    // 残り時間3段階：>60s 白 / 30-60s アンバー / <30s 赤
    final Color timeColor = time < 30
        ? AppTheme.danger
        : (time <= 60 ? AppTheme.accent : AppTheme.textHigh);
    final charIcon = (isMe && _myCharIconId != null)
        ? findCharacterById(_myCharIconId!)
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.s2, vertical: AppTheme.s1),
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.s3, vertical: AppTheme.s2),
      decoration: BoxDecoration(
        color: isCurrentTurn
            ? AppTheme.accent.withAlpha(38)
            : (isMe ? AppTheme.surfaceHigh : AppTheme.surface),
        borderRadius: BorderRadius.circular(AppTheme.rChip),
        border: Border(
          left: BorderSide(
            color: isCurrentTurn ? AppTheme.accent : Colors.transparent,
            width: 3,
          ),
        ),
        boxShadow: isCurrentTurn ? AppTheme.glow(AppTheme.accent) : null,
      ),
      child: Row(
        children: [
          if (charIcon != null)
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: charIcon.bgColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isMe
                      ? AppTheme.primary.withAlpha(180)
                      : Colors.white38,
                  width: 2.0,
                ),
                boxShadow: isMe
                    ? [BoxShadow(color: AppTheme.primary.withAlpha(60), blurRadius: 8)]
                    : null,
              ),
              child: ClipOval(
                child: Image.asset(
                  charIcon.imagePath,
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Text(charIcon.emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
              ),
            )
          else
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isMe
                    ? AppTheme.primary.withAlpha(30)
                    : Colors.white.withAlpha(15),
                border: Border.all(
                  color: isMe ? AppTheme.primary.withAlpha(150) : Colors.white38,
                  width: 1.5,
                ),
                boxShadow: isMe
                    ? [BoxShadow(color: AppTheme.primary.withAlpha(40), blurRadius: 6)]
                    : null,
              ),
              child: Icon(
                isMe ? Icons.person : Icons.person_outline,
                color: isMe ? AppTheme.primary : AppTheme.textMid,
                size: 26,
              ),
            ),
          const SizedBox(width: AppTheme.s2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isMe ? 'あなた' : '相手',
                style: TextStyle(
                  color: isMe ? AppTheme.primary : AppTheme.textMid,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isCurrentTurn)
                const Text(
                  '● 手番',
                  style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const Spacer(),
          // 残り時間（アイコン+大きめ数字、色で警告）
          Icon(Icons.timer_outlined, color: timeColor, size: 16),
          const SizedBox(width: AppTheme.s1),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              color: timeColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            child: Text(timeStr),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(bool isMyTurn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: AppTheme.surface,
      child: Row(
        children: [
          if (isMyTurn)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accent.withAlpha(40),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'あなたのターン',
                style: TextStyle(
                    color: AppTheme.accent, fontWeight: FontWeight.bold),
              ),
            )
          else
            Text('相手の番...',
                style: TextStyle(color: AppTheme.textMid)),
          const Spacer(),
          if (_isMakingMove)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            ElevatedButton.icon(
              onPressed: _isResigning ? null : _resign,
              icon: const Icon(Icons.flag, size: 16),
              label: const Text('投了'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
        ],
      ),
    );
  }

  // ── 棋譜パネル ─────────────────────────────────────────────

  Widget _buildKifuPanel(NetworkBoardState state) {
    final moves = state.moves;
    final scrollCtrl = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollCtrl.hasClients) {
        scrollCtrl.jumpTo(scrollCtrl.position.maxScrollExtent);
      }
    });

    return Container(
      height: 200,
      color: AppTheme.bg,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: AppTheme.surface,
            child: Row(
              children: [
                Icon(Icons.list_alt, color: AppTheme.textMid, size: 14),
                const SizedBox(width: 6),
                Text('棋譜 (${moves.length}手)',
                    style: TextStyle(color: AppTheme.textMid, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: moves.isEmpty
                ? Center(
                    child: Text('まだ指し手がありません',
                        style: TextStyle(color: AppTheme.textLow, fontSize: 12)))
                : ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: moves.length,
                    itemBuilder: (_, i) {
                      final m = moves[i];
                      final player = m.p1 ? '▲' : '△';
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 1),
                        child: Text(
                          '${m.num}. $player${m.note}',
                          style: TextStyle(
                            color: m.p1
                                ? AppTheme.textHigh
                                : AppTheme.textMid,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── ネット対局バッジ判定 ───────────────────────────────────
  Future<void> _checkNetBadges(NetworkBoardState state) async {
    try {
      final myId = widget.myPlayerId.isNotEmpty
          ? widget.myPlayerId
          : (_networkService.currentUser?.uid ?? '');
      final isWin = state.winner != null && state.winner == myId;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          'stats_total_net', (prefs.getInt('stats_total_net') ?? 0) + 1);
      if (isWin) {
        await prefs.setInt(
            'stats_net_wins', (prefs.getInt('stats_net_wins') ?? 0) + 1);
      }
      if (state.winner != null) {
        // 先手/後手どちらが勝ったか（自分視点ではなく席順視点で集計）
        final p1Won = isWin == widget.isPlayer1;
        await prefs.setInt(
          p1Won ? 'stats_p1_wins_net' : 'stats_p2_wins_net',
          (prefs.getInt(p1Won ? 'stats_p1_wins_net' : 'stats_p2_wins_net') ??
                  0) +
              1,
        );
      }

      final newBadges = await BadgeService.check(
        prefs,
        isWin: isWin,
        isVariant: false,
        isNetGame: true,
        moveCount: state.moveCount,
      );
      if (newBadges.isNotEmpty && mounted) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) await _showBadgeUnlockDialog(newBadges);
      }
    } catch (_) {}
  }

  // ── ネット対局レーティング反映 ─────────────────────────────
  // finishMatchWithRating は名前と裏腹に実際のレーティング計算を行わないため、
  // 対局終了を検知するこの一箇所でElo計算を実行しrating_currentに反映する
  // （AI対局と同じキーを使うことでレーティングスケールを統一する）。
  // レーティングはサーバー権威ではなく端末ローカル管理のため、両者が同じ入力
  // （自分の直近rating_current・マッチング時に交換した相手レーティング）で
  // 同じ計算式を実行することで対称的に整合させる。
  Future<void> _applyNetworkRatingUpdate(NetworkBoardState state) async {
    try {
      final oppRating = widget.opponentRating;
      if (oppRating == null) return; // 相手レーティング不明（招待対局等）は反映しない

      final myId = widget.myPlayerId.isNotEmpty
          ? widget.myPlayerId
          : (_networkService.currentUser?.uid ?? '');
      final winner = state.winner;
      if (winner == null || winner.isEmpty) return; // 引き分けはレーティング変動なし
      final myWon = winner == myId;

      final prefs = await SharedPreferences.getInstance();
      final myRating = prefs.getInt('rating_net_current') ?? 1000;
      final myGames = prefs.getInt('rating_network_games') ?? 0;

      final change = RatingService().calculateRatingChange(
        player1Rating: myRating,
        player2Rating: oppRating,
        player1Won: myWon,
        player1Games: myGames,
        player2Games: myGames, // 相手の対局数は不明なため自分と同じK値を仮定
      );
      final delta = change['player1'] ?? 0;
      final prevRankStr = ratingToRank(myRating);
      final newRating = (myRating + delta).clamp(0, 9999);

      await prefs.setInt('rating_net_current', newRating);
      await prefs.setInt('rating_network_games', myGames + 1);
      // rating_current はバッジ判定・棋力診断・マッチングなど多数の画面が
      // 参照する統一レーティング値。AI対局・ネット対局どちらのモードで
      // 上がったレーティングも失われないよう、両モードの高い方を採用する
      // （直近プレイしたモードで単純上書きすると、片方のモードで築いた
      // 実力が別モードの1敗で瞬時に下がって見えてしまうため）。
      final aiRating = prefs.getInt('rating_ai_current') ?? 0;
      await prefs.setInt('rating_current', newRating > aiRating ? newRating : aiRating);
      // ローカルの進捗をサーバーへも反映する（pushUserData()未使用だった問題の修正）
      CloudSyncService.pushUserData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(delta >= 0
              ? 'レーティング +$delta（$newRating）'
              : 'レーティング $delta（$newRating）'),
          backgroundColor:
              delta >= 0 ? Colors.green.shade700 : Colors.red.shade700,
          duration: const Duration(seconds: 3),
        ),
      );

      final newRankStr = ratingToRank(newRating);
      if (newRankStr != prevRankStr && delta > 0) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          await showRankUpDialog(context, newRankStr, ratingToColor(newRating));
        }
      }
    } catch (_) {}
  }

  Future<void> _showBadgeUnlockDialog(List<BadgeDef> badges) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.rCard),
          side: BorderSide(color: AppTheme.accent.withAlpha(100)),
        ),
        title: Text(
          badges.length > 1 ? '実績解除！' : '実績解除',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.accent,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: badges.map((b) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: b.color.withAlpha(40),
                    shape: BoxShape.circle,
                    border: Border.all(color: b.color.withAlpha(150)),
                  ),
                  child: Icon(b.icon, color: b.color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.title,
                        style: TextStyle(
                          color: AppTheme.textHigh,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        b.description,
                        style: TextStyle(color: AppTheme.textMid, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('閉じる', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }

  // ── ゲームオーバー画面 ─────────────────────────────────────

  Widget _buildGameOverScreen(NetworkBoardState state) {
    // myPlayerId（マッチング時に割り当て）またはFirebase UIDで勝敗判定
    final myId = widget.myPlayerId.isNotEmpty
        ? widget.myPlayerId
        : (_networkService.currentUser?.uid ?? '');
    final isWinner = state.winner != null && state.winner == myId;
    final isDraw = state.winner == null;

    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isDraw
                      ? Icons.handshake
                      : isWinner
                          ? Icons.emoji_events
                          : Icons.sentiment_dissatisfied,
                  size: 72,
                  color: isDraw
                      ? Colors.grey
                      : isWinner
                          ? Colors.amber
                          : Colors.grey.shade600,
                ),
                const SizedBox(height: 12),
                Text(
                  isDraw ? '引き分け' : isWinner ? '勝利！' : '敗北',
                  style: TextStyle(
                    color: isDraw
                        ? Colors.grey
                        : isWinner
                            ? Colors.amber
                            : Colors.grey.shade600,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text('${state.moveCount}手',
                    style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('一覧に戻る'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MatchAnalyzerScreen(
                              matchId: widget.matchId),
                        ),
                      ),
                      icon: const Icon(Icons.analytics, size: 16),
                      label: const Text('棋譜分析'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // 感想戦チャット
        Expanded(
          flex: 3,
          child: PostMatchChatWidget(matchId: widget.matchId),
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
