// lib/kansousen_screen.dart
import 'dart:math' show sqrt, atan2, cos, sin;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'piece.dart';
import 'logic.dart';
import 'mini_board_widget.dart';
import 'game_screen.dart' show GameScreen, GameSettings, GameMode, AILevel, PieceTheme, Handicap;
import 'board_image_exporter.dart';
import 'theme/app_theme.dart';

// ---- 感想戦データ ----
enum MoveQuality {
  excellent, // 好手 (>= +150)
  good,      // 良手 (>= +30)
  normal,    // 普通 (>= -80)
  dubious,   // 疑問手 (>= -200)
  bad,       // 悪手 (< -200)
}

extension MoveQualityExt on MoveQuality {
  String get label {
    switch (this) {
      case MoveQuality.excellent: return '好手';
      case MoveQuality.good:      return '良手';
      case MoveQuality.normal:    return '普通';
      case MoveQuality.dubious:   return '疑問手';
      case MoveQuality.bad:       return '悪手';
    }
  }
  Color get color {
    switch (this) {
      case MoveQuality.excellent: return Colors.blue.shade400;
      case MoveQuality.good:      return Colors.lightBlue.shade300;
      case MoveQuality.normal:    return Colors.white38;
      case MoveQuality.dubious:   return Colors.orange.shade400;
      case MoveQuality.bad:       return Colors.red.shade400;
    }
  }
  IconData get icon {
    switch (this) {
      case MoveQuality.excellent: return Icons.star;
      case MoveQuality.good:      return Icons.check_circle_outline;
      case MoveQuality.normal:    return Icons.remove;
      case MoveQuality.dubious:   return Icons.warning_amber_outlined;
      case MoveQuality.bad:       return Icons.cancel_outlined;
    }
  }
}

MoveQuality classifyMove(int playerEvalChange) {
  if (playerEvalChange >= 150) return MoveQuality.excellent;
  if (playerEvalChange >= 30)  return MoveQuality.good;
  if (playerEvalChange >= -80) return MoveQuality.normal;
  if (playerEvalChange >= -200) return MoveQuality.dubious;
  return MoveQuality.bad;
}

/// eval change from the perspective of the player who just moved
int playerEvalChange(int evalBefore, int evalAfter, bool wasP1Turn) =>
    wasP1Turn ? evalAfter - evalBefore : evalBefore - evalAfter;

// ---- ポジションスナップショット ----
class _Snapshot {
  final List<List<Piece?>> board;
  final Map<PieceType, int> p1Hand;
  final Map<PieceType, int> p2Hand;
  final bool p1Turn; // whose turn BEFORE this position was reached
  final int eval;    // AI.eval at this position
  _Snapshot({
    required this.board,
    required this.p1Hand,
    required this.p2Hand,
    required this.p1Turn,
    required this.eval,
  });
}

class KansousenScreen extends StatefulWidget {
  final List<KifuMove> moves;
  final List<List<Piece?>> initialBoard;
  final String title;
  /// 先手が下に表示される（false = 先手が上＝後手視点）
  final bool flipped;
  /// 棋譜に保存されたテーマ名（将来の拡張用）
  final PieceTheme pieceTheme;

  const KansousenScreen({
    super.key,
    required this.moves,
    required this.initialBoard,
    required this.title,
    this.flipped = false,
    this.pieceTheme = PieceTheme.standard,
  });

  @override
  State<KansousenScreen> createState() => _KansousenScreenState();
}

class _KansousenScreenState extends State<KansousenScreen> {
  int _step = 0;
  late List<_Snapshot> _snapshots;
  final Map<int, AMove?> _bestMoveCache = {};
  final Map<int, List<AMove>> _topMovesCache = {};
  bool _loadingBest = false;
  final ScrollController _kifuScrollCtrl = ScrollController();
  final GlobalKey _boardAreaKey = GlobalKey();
  static const _itemW = 56.0 + 4.0; // card width + gap

  // ── 検討モード ──
  bool _studyMode = false;
  List<List<Piece?>>? _studyBoard;
  Map<PieceType, int> _studyP1Hand = {};
  Map<PieceType, int> _studyP2Hand = {};
  bool _studyP1Turn = true;
  int? _studySr, _studySc;
  PieceType? _studySelHand;
  Set<(int, int)> _studyHL = {};

  // 効き（利き）可視化。設定画面のトグルと同じキーを共有する
  static const _kShowAttackMapPref = 'review_show_attack_map';
  bool _showAttackMap = false;

  @override
  void initState() {
    super.initState();
    _buildSnapshots();
    _loadAttackMapPref();
  }

  Future<void> _loadAttackMapPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showAttackMap = prefs.getBool(_kShowAttackMapPref) ?? false;
    });
  }

  Future<void> _toggleAttackMap() async {
    final next = !_showAttackMap;
    setState(() => _showAttackMap = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowAttackMapPref, next);
  }

  @override
  void dispose() {
    _kifuScrollCtrl.dispose();
    super.dispose();
  }

  /// 盤面を 180度反転（後手視点 → 先手視点など）
  List<List<Piece?>> _flipBoard(List<List<Piece?>> b) {
    final flipped = List<List<Piece?>>.generate(
      9,
      (r) => List<Piece?>.generate(9, (c) => b[8 - r][8 - c]),
    );
    return flipped;
  }

  /// 効きマップ（int）を盤面と同じ向きに180度反転
  List<List<int>> _flipIntMap(List<List<int>> m) {
    return List.generate(9, (r) => List.generate(9, (c) => m[8 - r][8 - c]));
  }

  // ── 検討モード操作 ──
  void _toggleStudyMode() {
    setState(() {
      _studyMode = !_studyMode;
      if (_studyMode) {
        final snap = _snapshots[_step];
        _studyBoard = GL.copy(snap.board);
        _studyP1Hand = Map.from(snap.p1Hand);
        _studyP2Hand = Map.from(snap.p2Hand);
        _studyP1Turn = snap.p1Turn;
        _studySr = null; _studySc = null;
        _studySelHand = null;
        _studyHL = {};
      } else {
        _studyBoard = null;
        _studyHL = {};
      }
    });
  }

  void _studyClearSel() {
    _studySr = null; _studySc = null;
    _studySelHand = null;
    _studyHL = {};
  }

  void _studyTap(int r, int c) {
    final board = _studyBoard!;
    final piece = board[r][c];

    // ① 自駒タップ → 常に再選択（選択中でも）
    if (piece != null && piece.isPlayer1 == _studyP1Turn) {
      setState(() {
        _studyClearSel();
        _studySr = r; _studySc = c;
        for (int tr = 0; tr < 9; tr++) {
          for (int tc = 0; tc < 9; tc++) {
            final t = board[tr][tc];
            if (t == null || t.isPlayer1 != _studyP1Turn) {
              _studyHL.add((tr, tc));
            }
          }
        }
      });
      return;
    }

    // ② 移動確定（HL内マスをタップ）
    if ((_studySr != null || _studySelHand != null) && _studyHL.contains((r, c))) {
      setState(() {
        if (_studySelHand != null) {
          board[r][c] = Piece(_studySelHand!, _studyP1Turn);
          final h = _studyP1Turn ? _studyP1Hand : _studyP2Hand;
          h[_studySelHand!] = (h[_studySelHand!] ?? 1) - 1;
          if ((h[_studySelHand!] ?? 0) <= 0) h.remove(_studySelHand!);
        } else {
          final p = board[_studySr!][_studySc!]!;
          final cap = board[r][c];
          if (cap != null) {
            final h = _studyP1Turn ? _studyP1Hand : _studyP2Hand;
            final bt = cap.baseType;
            h[bt] = (h[bt] ?? 0) + 1;
          }
          board[r][c] = p;
          board[_studySr!][_studySc!] = null;
        }
        _studyP1Turn = !_studyP1Turn;
        _studyClearSel();
      });
      return;
    }

    // ③ その他 → 選択解除
    setState(() => _studyClearSel());
  }

  // ── AI対局起動 ──
  void _startAIGame() {
    final snap = _studyMode && _studyBoard != null
        ? null // 検討局面からは初期化して起動
        : _snapshots[_step];
    final board = _studyMode && _studyBoard != null
        ? GL.copy(_studyBoard!)
        : GL.copy(_snapshots[_step].board);
    final p1Hand = _studyMode && _studyBoard != null
        ? Map<PieceType, int>.from(_studyP1Hand)
        : Map<PieceType, int>.from(_snapshots[_step].p1Hand);
    final p2Hand = _studyMode && _studyBoard != null
        ? Map<PieceType, int>.from(_studyP2Hand)
        : Map<PieceType, int>.from(_snapshots[_step].p2Hand);
    final p1Turn = _studyMode && _studyBoard != null
        ? _studyP1Turn
        : _snapshots[_step].p1Turn;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => GameScreen(
        settings: const GameSettings(
          mode: GameMode.vsAI,
          aiLevel: AILevel.hard,
          aiIsP2: true,
        ),
        initialBoard: board,
        initialP1Hand: p1Hand,
        initialP2Hand: p2Hand,
        initialP1Turn: p1Turn,
      ),
    ));
  }

  void _buildSnapshots() {
    final snaps = <_Snapshot>[];
    var board = GL.copy(widget.initialBoard);
    Map<PieceType, int> p1Hand = {}, p2Hand = {};
    bool p1Turn = true;

    snaps.add(_Snapshot(
      board: GL.copy(board),
      p1Hand: Map.from(p1Hand),
      p2Hand: Map.from(p2Hand),
      p1Turn: p1Turn,
      eval: AI.eval(board, p1Hand, p2Hand, ignorePersonality: true),
    ));

    for (final move in widget.moves) {
      GL.applyKifuMove(board, p1Hand, p2Hand, move);
      p1Turn = !p1Turn;
      snaps.add(_Snapshot(
        board: GL.copy(board),
        p1Hand: Map.from(p1Hand),
        p2Hand: Map.from(p2Hand),
        p1Turn: p1Turn,
        eval: AI.eval(board, p1Hand, p2Hand, ignorePersonality: true),
      ));
    }
    _snapshots = snaps;
  }

  _Snapshot get _cur => _snapshots[_step];
  bool get _atInitial => _step == 0;
  bool get _atLast => _step >= _snapshots.length - 1;

  KifuMove? get _currentMove =>
      _step > 0 ? widget.moves[_step - 1] : null;

  MoveQuality? get _quality {
    if (_step == 0) return null;
    final move = widget.moves[_step - 1];
    final evalBefore = _snapshots[_step - 1].eval;
    final evalAfter = _snapshots[_step].eval;
    final change = playerEvalChange(evalBefore, evalAfter, move.p1);
    return classifyMove(change);
  }

  int? get _evalChange {
    if (_step == 0) return null;
    final move = widget.moves[_step - 1];
    final evalBefore = _snapshots[_step - 1].eval;
    final evalAfter = _snapshots[_step].eval;
    return playerEvalChange(evalBefore, evalAfter, move.p1);
  }

  void _goto(int step) {
    if (step < 0 || step >= _snapshots.length) return;
    setState(() => _step = step);
    _maybeFetchBest(step);
    // 棋譜リストを現在の手にスクロール
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_kifuScrollCtrl.hasClients) return;
      final target = ((step - 1) * _itemW).clamp(
          0.0, _kifuScrollCtrl.position.maxScrollExtent);
      _kifuScrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _maybeFetchBest(int step) async {
    if (step == 0) return;
    final q = _getQualityAt(step);
    if (q != MoveQuality.dubious && q != MoveQuality.bad) return;
    if (_bestMoveCache.containsKey(step)) return;

    setState(() => _loadingBest = true);
    final snapBefore = _snapshots[step - 1];
    final move = widget.moves[step - 1];
    // Run both best move and top-3 together
    final results = await Future.wait([
      Future(() => AI.bestMove(snapBefore.board, snapBefore.p1Hand, snapBefore.p2Hand, move.p1, 2)),
      Future(() => AI.topMoves(snapBefore.board, snapBefore.p1Hand, snapBefore.p2Hand, move.p1, 2, n: 3)),
    ]);
    if (mounted) {
      setState(() {
        _bestMoveCache[step] = results[0] as AMove?;
        _topMovesCache[step] = (results[1] as List<(AMove, int)>)
            .map((r) => r.$1)
            .toList();
        _loadingBest = false;
      });
    }
  }

  MoveQuality? _getQualityAt(int step) {
    if (step == 0) return null;
    final move = widget.moves[step - 1];
    final evalBefore = _snapshots[step - 1].eval;
    final evalAfter = _snapshots[step].eval;
    final change = playerEvalChange(evalBefore, evalAfter, move.p1);
    return classifyMove(change);
  }

  // ---- Build ----
  @override
  Widget build(BuildContext context) {
    final snap = _cur;
    final move = _currentMove;
    final quality = _quality;
    final evalChg = _evalChange;
    final bestMove = _step > 0 ? _bestMoveCache[_step] : null;
    final needsBest = quality == MoveQuality.dubious || quality == MoveQuality.bad;

    // last move highlights
    (int, int)? lastFrom;
    (int, int)? lastTo;
    (int, int) flipCoord((int, int) p) => (8 - p.$1, 8 - p.$2);
    if (move != null && move.fr >= 0) {
      lastFrom = widget.flipped ? flipCoord((move.fr, move.fc)) : (move.fr, move.fc);
      lastTo   = widget.flipped ? flipCoord((move.tr, move.tc)) : (move.tr, move.tc);
    } else if (move != null) {
      lastTo = widget.flipped ? flipCoord((move.tr, move.tc)) : (move.tr, move.tc);
    }

    // best move hints (only shown for 悪手/疑問手)
    (int, int)? hintFrom;
    (int, int)? hintTo;
    if (needsBest && bestMove != null) {
      if (bestMove.fr >= 0) {
        hintFrom = widget.flipped ? flipCoord((bestMove.fr, bestMove.fc)) : (bestMove.fr, bestMove.fc);
      }
      hintTo = widget.flipped ? flipCoord((bestMove.tr, bestMove.tc)) : (bestMove.tr, bestMove.tc);
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text(
          _studyMode ? '検討モード' : '感想戦 — ${widget.title}',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        centerTitle: true,
        actions: [
          // トップへ戻る
          IconButton(
            icon: const Icon(Icons.home_outlined, color: Colors.white54),
            tooltip: 'トップへ戻る',
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
          ),
          // 対局サマリー
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined, color: Colors.white54),
            tooltip: '対局サマリー',
            onPressed: _showSummaryDialog,
          ),
          // 盤面画像保存（持ち駒含む）
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined, color: Colors.white54),
            tooltip: '盤面を画像共有（持ち駒含む）',
            onPressed: () => _captureAndShare(),
          ),
          // 検討モード切替
          IconButton(
            icon: Icon(
              Icons.science_outlined,
              color: _studyMode ? Colors.greenAccent : Colors.white54,
            ),
            tooltip: _studyMode ? '感想戦に戻る' : '検討モード',
            onPressed: _toggleStudyMode,
          ),
          // 効き可視化
          IconButton(
            icon: Icon(
              Icons.visibility,
              color: _showAttackMap ? Colors.orangeAccent : Colors.white54,
            ),
            tooltip: _showAttackMap ? '効き非表示' : '効きを表示',
            onPressed: _toggleAttackMap,
          ),
          // AI対局
          IconButton(
            icon: const Icon(Icons.computer, color: Colors.amber),
            tooltip: 'この局面からAI対局',
            onPressed: _startAIGame,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── 評価グラフ ───
            _evalGraphWidget(),

            // ─── 手番情報 ───
            if (move != null)
              _moveInfoBar(move, quality, evalChg),

            // ─── 盤面 ───
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: AspectRatio(
                    aspectRatio: 10 / 11,
                    child: LayoutBuilder(builder: (_, cs) {
                      final totalSize = cs.maxWidth;
                      final labelSize = totalSize * 0.05;
                      final boardSize = totalSize - labelSize;
                      final cellSize = boardSize / 9;
                      final topMoves = _topMovesCache[_step] ?? [];
                      // 検討モード時は検討用盤面、通常時はスナップショット
                      final rawBoard = _studyMode && _studyBoard != null
                          ? _studyBoard!
                          : snap.board;
                      // flipped=true なら先手が下（通常の将棋盤向き）
                      final dispBoard = widget.flipped ? _flipBoard(rawBoard) : rawBoard;
                      final dispP1Hand = _studyMode ? _studyP1Hand : snap.p1Hand;
                      final dispP2Hand = _studyMode ? _studyP2Hand : snap.p2Hand;
                      List<List<int>>? atkP1Map, atkP2Map;
                      if (_showAttackMap) {
                        final rawP1 = GL.attackMap(rawBoard, true);
                        final rawP2 = GL.attackMap(rawBoard, false);
                        atkP1Map = widget.flipped ? _flipIntMap(rawP1) : rawP1;
                        atkP2Map = widget.flipped ? _flipIntMap(rawP2) : rawP2;
                      }

                      return RepaintBoundary(
                        key: _boardAreaKey,
                        child: Column(children: [
                        Expanded(
                          child: GestureDetector(
                            onTapUp: _studyMode ? (det) {
                              final bSize = boardSize;
                              final lSize = labelSize;
                              final x = det.localPosition.dx - lSize;
                              final y = det.localPosition.dy - lSize;
                              if (x < 0 || y < 0 || x > bSize || y > bSize) return;
                              final c = (x / cellSize).floor().clamp(0, 8);
                              final r = (y / cellSize).floor().clamp(0, 8);
                              _studyTap(r, c);
                            } : null,
                            child: Stack(children: [
                              MiniBoardWidget(
                                board: dispBoard,
                                lastMoveFrom: _studyMode ? (_studySr != null ? (_studySr!, _studySc!) : null) : lastFrom,
                                lastMoveTo: lastTo,
                                hintFrom: (!_studyMode && needsBest) ? hintFrom : null,
                                hintTo: (!_studyMode && needsBest) ? hintTo : null,
                                showLabels: true,
                                size: cs.maxWidth,
                                highlightSquares: _studyMode ? _studyHL : const {},
                                boardFlipped: widget.flipped,
                                p1AttackMap: atkP1Map,
                                p2AttackMap: atkP2Map,
                              ),
                              if (!_studyMode && needsBest && topMoves.isNotEmpty)
                                Positioned(
                                  left: labelSize,
                                  top: labelSize,
                                  width: boardSize,
                                  height: boardSize,
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: _ArrowOverlayPainter(
                                        moves: topMoves,
                                        cellSize: cellSize,
                                      ),
                                    ),
                                  ),
                                ),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 持ち駒
                        _handRow(dispP1Hand, true),
                        _handRow(dispP2Hand, false),
                        // 検討モード: 手番 + 持ち駒打ち込みUI
                        if (_studyMode) _studyHandBar(dispP1Hand, dispP2Hand),
                      ]));
                    }),
                  ),
                ),
              ),
            ),

            // ─── 悪手のヒント（感想戦のみ）───
            if (!_studyMode && needsBest) _hintPanel(bestMove),

            // ─── ナビゲーション（感想戦のみ）───
            if (!_studyMode) _navBar(),

            // ─── 棋譜リスト（感想戦のみ）───
            if (!_studyMode)
              SizedBox(
                height: 90,
                child: _kifuList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _evalGraphWidget() {
    if (_snapshots.length <= 1) return const SizedBox(height: 4);
    final evals = _snapshots.map((s) => s.eval).toList();
    final quals = List.generate(_snapshots.length, _getQualityAt);
    final ev = _snapshots[_step].eval;
    final evLabel = ev.abs() < 50
        ? '均衡'
        : (ev > 0 ? '先手 +$ev' : '後手 $ev');
    final evColor = ev > 50
        ? Colors.blue.shade300
        : ev < -50
            ? Colors.red.shade300
            : Colors.white54;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ラベル行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('▲先手', style: TextStyle(color: Colors.blue.shade300, fontSize: 10)),
              Text(evLabel, style: TextStyle(color: evColor, fontSize: 11, fontWeight: FontWeight.bold)),
              Text('△後手', style: TextStyle(color: Colors.red.shade300, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 3),
          // グラフ本体（タップで移動）
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 80,
              color: const Color(0xFF0A1628),
              child: LayoutBuilder(builder: (_, cs) {
                return GestureDetector(
                  onTapDown: (det) {
                    if (_snapshots.length <= 1) return;
                    final step = (det.localPosition.dx / cs.maxWidth *
                            (_snapshots.length - 1))
                        .round()
                        .clamp(0, _snapshots.length - 1);
                    _goto(step);
                  },
                  child: CustomPaint(
                    size: Size(cs.maxWidth, 80),
                    painter: _EvalGraphPainter(
                      evals: evals,
                      qualities: quals,
                      currentStep: _step,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moveInfoBar(KifuMove move, MoveQuality? quality, int? evalChg) {
    final sign = evalChg != null && evalChg >= 0 ? '+' : '';
    return Container(
      color: const Color(0xFF0F2A40),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        Text(
          '$_step手目  ${move.p1 ? "▲" : "△"}${move.note}',
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        if (evalChg != null)
          Text(
            '$sign$evalChg',
            style: TextStyle(
              color: evalChg >= 0 ? Colors.lightGreen : Colors.red.shade300,
              fontSize: 12,
            ),
          ),
        const SizedBox(width: 8),
        if (quality != null && quality != MoveQuality.normal && quality != MoveQuality.good)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: quality.color.withAlpha(40),
              border: Border.all(color: quality.color, width: 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(quality.icon, color: quality.color, size: 14),
              const SizedBox(width: 4),
              Text(quality.label, style: TextStyle(color: quality.color, fontSize: 12)),
            ]),
          ),
      ]),
    );
  }

  Widget _handRow(Map<PieceType, int> hand, bool isP1) {
    if (hand.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: Row(children: [
        Text(
          isP1 ? '▲持駒: ' : '△持駒: ',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        ...hand.entries.map((e) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Text(
            '${pieceLabel(e.key)}${e.value > 1 ? "×${e.value}" : ""}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        )),
      ]),
    );
  }

  Widget _studyHandBar(Map<PieceType, int> p1Hand, Map<PieceType, int> p2Hand) {
    final myHand = _studyP1Turn ? p1Hand : p2Hand;
    final side = _studyP1Turn ? '▲先手番' : '△後手番';
    final sideColor = _studyP1Turn ? Colors.blue.shade300 : Colors.red.shade300;
    return Container(
      color: const Color(0xFF0A2040),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: sideColor.withAlpha(40),
            border: Border.all(color: sideColor, width: 0.8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(side, style: TextStyle(color: sideColor, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        ...myHand.entries.map((e) => GestureDetector(
          onTap: () {
            setState(() {
              _studySr = null; _studySc = null;
              _studySelHand = e.key;
              _studyHL = {};
              for (int r = 0; r < 9; r++) {
                for (int c = 0; c < 9; c++) {
                  if (_studyBoard![r][c] == null) _studyHL.add((r, c));
                }
              }
            });
          },
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _studySelHand == e.key ? Colors.amber.withAlpha(60) : Colors.transparent,
              border: Border.all(
                color: _studySelHand == e.key ? Colors.amber : Colors.white24,
                width: 0.8,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${pieceLabel(e.key)}${e.value > 1 ? "×${e.value}" : ""}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        )),
        const Spacer(),
        TextButton.icon(
          icon: const Icon(Icons.replay, size: 14),
          label: const Text('リセット', style: TextStyle(fontSize: 11)),
          style: TextButton.styleFrom(foregroundColor: Colors.white38),
          onPressed: () => setState(() {
            final snap = _snapshots[_step];
            _studyBoard = GL.copy(snap.board);
            _studyP1Hand = Map.from(snap.p1Hand);
            _studyP2Hand = Map.from(snap.p2Hand);
            _studyP1Turn = snap.p1Turn;
            _studyClearSel();
          }),
        ),
      ]),
    );
  }

  Widget _hintPanel(AMove? best) {
    if (_loadingBest) {
      return Container(
        color: const Color(0xFF0A2040),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: const Row(children: [
          Icon(Icons.lightbulb_outline, color: AppTheme.accent, size: 16),
          SizedBox(width: 8),
          Text('好手を計算中...', style: TextStyle(color: AppTheme.accent, fontSize: 13)),
          SizedBox(width: 8),
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
          ),
        ]),
      );
    }
    if (best == null) return const SizedBox.shrink();

    final snapBefore = _snapshots[_step - 1];
    final move = widget.moves[_step - 1];
    // Use AI.apply to get the correctly mutated board+hands for eval
    final applied = AI.apply(
      snapBefore.board, snapBefore.p1Hand, snapBefore.p2Hand, best, move.p1,
    );
    final bestEval = AI.eval(applied.b, applied.p1h, applied.p2h, ignorePersonality: true);
    final sign = move.p1 ? (bestEval > 0 ? '+' : '') : (bestEval < 0 ? '' : '+');
    final bestScore = move.p1 ? bestEval : -bestEval;
    final from = best.drop != null
        ? '持ち駒(${pieceLabel(best.drop!)})'
        : _sq(best.fr, best.fc);
    final to = _sq(best.tr, best.tc);

    return Container(
      color: const Color(0xFF0A3060),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        const Icon(Icons.lightbulb, color: AppTheme.accent, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '好手: $from → $to  (評価: $sign$bestScore)',
            style: const TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ]),
    );
  }

  Widget _navBar() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.skip_previous, color: Colors.white),
          onPressed: _atInitial ? null : () => _goto(0),
        ),
        IconButton(
          icon: const Icon(Icons.navigate_before, color: Colors.white),
          onPressed: _atInitial ? null : () => _goto(_step - 1),
        ),
        Expanded(
          child: Slider(
            value: _step.toDouble(),
            min: 0,
            max: (_snapshots.length - 1).toDouble(),
            divisions: _snapshots.length > 1 ? _snapshots.length - 1 : 1,
            activeColor: Colors.amber,
            onChanged: (v) => _goto(v.round()),
          ),
        ),
        Text(
          '$_step/${_snapshots.length - 1}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        IconButton(
          icon: const Icon(Icons.navigate_next, color: Colors.white),
          onPressed: _atLast ? null : () => _goto(_step + 1),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next, color: Colors.white),
          onPressed: _atLast ? null : () => _goto(_snapshots.length - 1),
        ),
      ]),
    );
  }

  void _showSummaryDialog() {
    final p1Counts = <MoveQuality, int>{};
    final p2Counts = <MoveQuality, int>{};
    for (final q in MoveQuality.values) {
      p1Counts[q] = 0;
      p2Counts[q] = 0;
    }

    int maxDrop = 0;
    int maxDropStep = 0;

    for (int s = 1; s < _snapshots.length; s++) {
      final q = _getQualityAt(s);
      if (q == null) continue;
      final move = widget.moves[s - 1];
      if (move.p1) {
        p1Counts[q] = (p1Counts[q] ?? 0) + 1;
      } else {
        p2Counts[q] = (p2Counts[q] ?? 0) + 1;
      }
      if (s < _snapshots.length) {
        final evalBefore = _snapshots[s - 1].eval;
        final evalAfter = _snapshots[s].eval;
        final drop = -playerEvalChange(evalBefore, evalAfter, move.p1);
        if (drop > maxDrop) {
          maxDrop = drop;
          maxDropStep = s;
        }
      }
    }

    final totalMoves = widget.moves.length;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Row(children: [
          const Icon(Icons.bar_chart, color: Colors.amber, size: 22),
          const SizedBox(width: 8),
          Text('対局サマリー — ${widget.title}',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Text('総手数', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const Spacer(),
                  Text('$totalMoves手', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(height: 12),
              _summaryPlayerRow('▲先手', p1Counts),
              const SizedBox(height: 8),
              _summaryPlayerRow('△後手', p2Counts),
              if (maxDropStep > 0) ...[
                const SizedBox(height: 12),
                const Divider(color: Colors.white12),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.cancel_outlined, color: Colors.red.shade400, size: 16),
                  const SizedBox(width: 6),
                  Text('最大の悪手: ${maxDropStep}手目 (評価値 -$maxDrop)',
                      style: TextStyle(color: Colors.red.shade300, fontSize: 12)),
                ]),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _goto(maxDropStep > 0 ? maxDropStep : 0);
            },
            child: const Text('最大悪手へ', style: TextStyle(color: Colors.orange)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  Widget _summaryPlayerRow(String label, Map<MoveQuality, int> counts) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: MoveQuality.values.where((q) => (counts[q] ?? 0) > 0).map((q) =>
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: q.color.withAlpha(30),
                  border: Border.all(color: q.color.withAlpha(120)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(q.icon, color: q.color, size: 12),
                  const SizedBox(width: 4),
                  Text('${q.label} ${counts[q]}',
                      style: TextStyle(color: q.color, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
            ).toList(),
          ),
          if (MoveQuality.values.every((q) => (counts[q] ?? 0) == 0))
            const Text('データなし', style: TextStyle(color: Colors.white24, fontSize: 11)),
        ],
      ),
    );
  }

  // 盤面（持ち駒含む）を画像としてキャプチャしてシェア
  Future<void> _captureAndShare() async {
    try {
      final boundary = _boardAreaKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null && mounted) {
          final bytes = byteData.buffer.asUint8List();
          await Share.shareXFiles(
            [XFile.fromData(bytes, mimeType: 'image/png', name: 'shogi_board.png')],
            text: '将棋盤面 (${_step}手目)',
          );
          return;
        }
      }
    } catch (_) {}
    // Web向けフォールバック
    if (!mounted) return;
    final snap = _snapshots[_step];
    exportBoardImage(
      board: _studyMode && _studyBoard != null ? _studyBoard! : snap.board,
      p1Hand: _studyMode ? _studyP1Hand : snap.p1Hand,
      p2Hand: _studyMode ? _studyP2Hand : snap.p2Hand,
      filename: 'shogi_step${_step}.png',
    );
  }

  Widget _kifuList() {
    return Container(
      color: const Color(0xFF0A1628),
      child: widget.moves.isEmpty
          ? const Center(child: Text('手がありません', style: TextStyle(color: Colors.white38, fontSize: 12)))
          : ListView.builder(
              controller: _kifuScrollCtrl,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              itemCount: widget.moves.length,
              itemBuilder: (_, i) {
                final step = i + 1;
                final q = _getQualityAt(step);
                final isSelected = _step == step;
                return GestureDetector(
                  onTap: () => _goto(step),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 56,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.amber.withAlpha(50)
                          : AppTheme.surface,
                      border: Border.all(
                        color: isSelected
                            ? Colors.amber
                            : (q?.color ?? Colors.white12),
                        width: isSelected ? 2 : 0.8,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$step手',
                          style: TextStyle(
                            color: isSelected ? Colors.amber : Colors.white60,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (q != null && q != MoveQuality.normal && q != MoveQuality.good) ...[
                          const SizedBox(height: 2),
                          Icon(q.icon, color: q.color, size: 13),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ---- ユーティリティ ----
const _rowKanji = ['一','二','三','四','五','六','七','八','九'];
String _sq(int r, int c) => '${9 - c}${_rowKanji[r]}';

// ---- 評価グラフ描画 ----
class _EvalGraphPainter extends CustomPainter {
  final List<int> evals;
  final List<MoveQuality?> qualities;
  final int currentStep;
  static const _maxEval = 3000.0;

  const _EvalGraphPainter({
    required this.evals,
    required this.qualities,
    required this.currentStep,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (evals.length < 2) return;
    final n = evals.length - 1;
    final midY = size.height / 2;

    double xAt(int i) => i / n * size.width;
    double yAt(int v) =>
        midY - v.clamp(-_maxEval, _maxEval) / _maxEval * (midY - 6);

    // ── 目盛り線（±1000, ±2000）──
    for (final v in [-2000, -1000, 1000, 2000]) {
      final y = yAt(v);
      canvas.drawLine(Offset(0, y), Offset(size.width, y),
          Paint()..color = Colors.white.withAlpha(12)..strokeWidth = 0.5);
    }

    // ── ゼロライン ──
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY),
        Paint()..color = Colors.white30..strokeWidth = 0.8);

    // ── エリア塗り（セグメントごと）──
    for (int i = 0; i < n; i++) {
      final x1 = xAt(i);
      final x2 = xAt(i + 1);
      final y1 = yAt(evals[i]);
      final y2 = yAt(evals[i + 1]);
      final avg = (evals[i] + evals[i + 1]) / 2;
      final path = Path()
        ..moveTo(x1, y1)
        ..lineTo(x2, y2)
        ..lineTo(x2, midY)
        ..lineTo(x1, midY)
        ..close();
      canvas.drawPath(
          path,
          Paint()
            ..color = (avg > 0 ? const Color(0xFF1565C0) : const Color(0xFFC62828))
                .withAlpha(55));
    }

    // ── 折れ線 ──
    final linePaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final linePath = Path()..moveTo(xAt(0), yAt(evals[0]));
    for (int i = 1; i <= n; i++) {
      linePath.lineTo(xAt(i), yAt(evals[i]));
    }
    canvas.drawPath(linePath, linePaint);

    // ── 手の品質マーカー ──
    for (int i = 1; i <= n; i++) {
      final q = qualities[i];
      if (q == null || q == MoveQuality.normal) continue;
      final o = Offset(xAt(i), yAt(evals[i]));
      canvas.drawCircle(o, 4.0, Paint()..color = q.color);
      canvas.drawCircle(o, 4.0,
          Paint()..color = Colors.black38..style = PaintingStyle.stroke..strokeWidth = 0.8);
    }

    // ── 現在位置ライン ──
    canvas.drawLine(
        Offset(xAt(currentStep), 0),
        Offset(xAt(currentStep), size.height),
        Paint()
          ..color = Colors.amber.withAlpha(180)
          ..strokeWidth = 1.5);

    // ── 現在位置ドット ──
    final co = Offset(xAt(currentStep), yAt(evals[currentStep]));
    canvas.drawCircle(co, 5.5, Paint()..color = Colors.amber);
    canvas.drawCircle(co, 5.5,
        Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(_EvalGraphPainter old) =>
      old.currentStep != currentStep ||
      old.evals.length != evals.length ||
      (evals.isNotEmpty && old.evals.last != evals.last);
}

// ── 候補手矢印オーバーレイ ──────────────────
class _ArrowOverlayPainter extends CustomPainter {
  final List<AMove> moves;
  final double cellSize;
  // Colors for rank 1,2,3
  static const _colors = [Color(0xFFFFAA00), Color(0xFF4488FF), Color(0xFF44CC88)];

  const _ArrowOverlayPainter({required this.moves, required this.cellSize});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < moves.length && i < 3; i++) {
      _drawArrow(canvas, moves[i], _colors[i], 3.5 - i * 0.8);
    }
  }

  void _drawArrow(Canvas canvas, AMove mv, Color color, double width) {
    // drop: just mark destination
    final toX = (mv.tc + 0.5) * cellSize;
    final toY = (mv.tr + 0.5) * cellSize;

    if (mv.drop != null || mv.fr < 0) {
      final p = Paint()
        ..color = color.withAlpha(180)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width;
      canvas.drawCircle(Offset(toX, toY), cellSize * 0.35, p);
      return;
    }

    final fromX = (mv.fc + 0.5) * cellSize;
    final fromY = (mv.fr + 0.5) * cellSize;

    final dx = toX - fromX;
    final dy = toY - fromY;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 1) return;
    final ux = dx / len;
    final uy = dy / len;

    // shorten slightly from both ends
    final shrink = cellSize * 0.25;
    final sx = fromX + ux * shrink;
    final sy = fromY + uy * shrink;
    final ex = toX - ux * shrink;
    final ey = toY - uy * shrink;

    final p = Paint()
      ..color = color.withAlpha(200)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(sx, sy), Offset(ex, ey), p);

    // arrowhead
    const headLen = 10.0;
    const headAngle = 0.5; // radians
    final angle = atan2(dy, dx);
    final hp = Paint()
      ..color = color.withAlpha(220)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(ex, ey),
      Offset(ex - headLen * cos(angle - headAngle), ey - headLen * sin(angle - headAngle)),
      hp,
    );
    canvas.drawLine(
      Offset(ex, ey),
      Offset(ex - headLen * cos(angle + headAngle), ey - headLen * sin(angle + headAngle)),
      hp,
    );
  }

  @override
  bool shouldRepaint(_ArrowOverlayPainter old) =>
      old.moves != moves || old.cellSize != cellSize;
}
