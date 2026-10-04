// lib/kifu_replay_screen.dart — 棋譜再生画面

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'piece.dart';
import 'logic.dart';
import 'theme/app_theme.dart';

// ===== 初期盤面生成 =====
List<List<Piece?>> _buildInitBoard() {
  final b = List<List<Piece?>>.generate(
    9,
    (_) => List<Piece?>.filled(9, null, growable: false),
  );
  void s(int r, int c, PieceType t, bool p1) => b[r][c] = Piece(t, p1);

  // 後手（P2）上部
  s(0, 0, PieceType.lance, false);
  s(0, 1, PieceType.knight, false);
  s(0, 2, PieceType.silver, false);
  s(0, 3, PieceType.gold, false);
  s(0, 4, PieceType.king, false);
  s(0, 5, PieceType.gold, false);
  s(0, 6, PieceType.silver, false);
  s(0, 7, PieceType.knight, false);
  s(0, 8, PieceType.lance, false);
  s(1, 1, PieceType.rook, false);
  s(1, 7, PieceType.bishop, false);
  for (int c = 0; c < 9; c++) {
    s(2, c, PieceType.pawn, false);
  }

  // 先手（P1）下部
  s(8, 0, PieceType.lance, true);
  s(8, 1, PieceType.knight, true);
  s(8, 2, PieceType.silver, true);
  s(8, 3, PieceType.gold, true);
  s(8, 4, PieceType.king, true);
  s(8, 5, PieceType.gold, true);
  s(8, 6, PieceType.silver, true);
  s(8, 7, PieceType.knight, true);
  s(8, 8, PieceType.lance, true);
  s(7, 7, PieceType.rook, true);
  s(7, 1, PieceType.bishop, true);
  for (int c = 0; c < 9; c++) {
    s(6, c, PieceType.pawn, true);
  }

  return b;
}

// ===== KifuReplayScreen =====
class KifuReplayScreen extends StatefulWidget {
  final List<KifuMove> moves;
  final String title;
  final String handicap;

  /// フィルターモード: 特定手番のstepリスト（1-based）
  final List<int>? filterIndices;

  /// フィルターラベル（例: "悪手", "好手"）
  final String? filterLabel;

  /// 開始ステップ（フィルターの最初の手に自動ジャンプ）
  final int initialStep;

  const KifuReplayScreen({
    super.key,
    required this.moves,
    required this.title,
    this.handicap = '平手',
    this.filterIndices,
    this.filterLabel,
    this.initialStep = 0,
  });

  @override
  State<KifuReplayScreen> createState() => _KifuReplayScreenState();
}

class _KifuReplayScreenState extends State<KifuReplayScreen> {
  late List<List<Piece?>> board;
  Map<PieceType, int> p1Hand = {};
  Map<PieceType, int> p2Hand = {};

  /// 現在の手数（0 = 初期盤面、n = n手目まで適用済み）
  int _step = 0;

  /// 直前の移動先（ハイライト用）
  int? _lastTR, _lastTC;

  /// 再生制御用フィールド
  Timer? _playTimer;
  bool _isPlaying = false;

  /// フィルターモード: 現在のフィルター位置（0-based index into filterIndices）
  int _filterPos = 0;
  double _speed = 1.0; // 再生速度 (0.5x / 1x / 2x)

  // GIF書き出し用
  final GlobalKey _boardCaptureKey = GlobalKey();
  bool _isExportingGif = false;

  // 効き（利き）可視化。設定画面のトグルと同じキーを共有する
  static const _kShowAttackMapPref = 'review_show_attack_map';
  bool _showAttackMap = false;

  @override
  void initState() {
    super.initState();
    final start = widget.initialStep.clamp(0, widget.moves.length);
    _resetToStep(start);
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
    _playTimer?.cancel();
    super.dispose();
  }

  // ===== 対局をGIFアニメとして共有（X等への投稿用）=====
  Future<void> _shareAsGif() async {
    if (_isExportingGif) return;
    _stopReplay();
    final originalStep = _step;
    setState(() => _isExportingGif = true);

    try {
      final totalMoves = widget.moves.length;
      final frameCount = totalMoves + 1; // 初期局面込み

      // フレーム数が多すぎるとGIFが重くなるため間引く（最大60枚程度）
      const maxFrames = 60;
      final stride = (frameCount / maxFrames).ceil().clamp(1, frameCount);
      final steps = <int>[
        for (int i = 0; i < frameCount; i += stride) i,
      ];
      if (steps.last != totalMoves) steps.add(totalMoves);

      final encoder = img.GifEncoder(repeat: 0);
      for (final step in steps) {
        _resetToStep(step);
        // 盤面の再描画を待ってからキャプチャする
        await WidgetsBinding.instance.endOfFrame;
        await Future.delayed(const Duration(milliseconds: 30));
        if (!mounted) break;

        final boundary = _boardCaptureKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary == null) continue;
        final uiImage = await boundary.toImage(pixelRatio: 1.5);
        final byteData =
            await uiImage.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) continue;
        final frame = img.decodePng(byteData.buffer.asUint8List());
        if (frame == null) continue;
        // 終局局面は少し長めに表示
        final isLast = step == totalMoves;
        encoder.addFrame(frame, duration: isLast ? 150 : 45);
      }

      final gifBytes = encoder.finish();
      if (gifBytes == null || !mounted) return;

      final file = XFile.fromData(
        gifBytes,
        mimeType: 'image/gif',
        name: 'shogi_kifu.gif',
      );
      await Share.shareXFiles(
        [file],
        text: '${widget.title}\n将棋アプリ「効棋」',
      );
    } catch (_) {
      // 失敗時は静かに諦める（共有機能の付随機能のため）
    } finally {
      _resetToStep(originalStep);
      if (mounted) setState(() => _isExportingGif = false);
    }
  }

  // ===== 盤面を step 手目まで再構築 =====
  void _resetToStep(int step) {
    final b = _buildInitBoard();
    final Map<PieceType, int> h1 = {};
    final Map<PieceType, int> h2 = {};
    int? ltr, ltc;

    for (int i = 0; i < step && i < widget.moves.length; i++) {
      final m = widget.moves[i];
      _applyMove(m, board: b, p1Hand: h1, p2Hand: h2);
      if (m.tr >= 0) {
        ltr = m.tr;
        ltc = m.tc;
      }
    }

    setState(() {
      board = b;
      p1Hand = h1;
      p2Hand = h2;
      _step = step;
      _lastTR = ltr;
      _lastTC = ltc;
    });
  }

  // ===== 1手適用 =====
  void _applyMove(
    KifuMove m, {
    required List<List<Piece?>> board,
    required Map<PieceType, int> p1Hand,
    required Map<PieceType, int> p2Hand,
  }) {
    final isP1 = m.p1;
    if (m.drop != null) {
      // 打ち
      board[m.tr][m.tc] = Piece(m.drop!, isP1);
      final h = isP1 ? p1Hand : p2Hand;
      h[m.drop!] = (h[m.drop!] ?? 1) - 1;
      if ((h[m.drop!] ?? 0) <= 0) h.remove(m.drop!);
    } else {
      if (m.fr < 0 || m.fc < 0) return; // 不正データガード
      final piece = board[m.fr][m.fc];
      if (piece == null) return;
      final cap = board[m.tr][m.tc];
      if (cap != null) {
        // 取った駒は成りを解除して持ち駒へ
        final h = isP1 ? p1Hand : p2Hand;
        final bt = cap.baseType;
        h[bt] = (h[bt] ?? 0) + 1;
      }
      board[m.tr][m.tc] =
          m.promote ? Piece(piece.promotedType, piece.isPlayer1) : piece;
      board[m.fr][m.fc] = null;
    }
  }

  // ===== ナビゲーション =====
  void _goFirst() {
    _stopReplay();
    _resetToStep(0);
  }

  void _goPrev() {
    _stopReplay();
    if (_step > 0) _resetToStep(_step - 1);
  }

  void _goNext() {
    _stopReplay();
    if (_step < widget.moves.length) _resetToStep(_step + 1);
  }

  void _goLast() {
    _stopReplay();
    _resetToStep(widget.moves.length);
  }

  // ===== フィルターナビゲーション =====
  void _filterPrev() {
    final fi = widget.filterIndices;
    if (fi == null || fi.isEmpty) return;
    _stopReplay();
    final newPos = (_filterPos - 1).clamp(0, fi.length - 1);
    setState(() => _filterPos = newPos);
    _resetToStep(fi[newPos]);
  }

  void _filterNext() {
    final fi = widget.filterIndices;
    if (fi == null || fi.isEmpty) return;
    _stopReplay();
    final newPos = (_filterPos + 1).clamp(0, fi.length - 1);
    setState(() => _filterPos = newPos);
    _resetToStep(fi[newPos]);
  }

  // ===== 再生制御 =====
  void _startReplay() {
    if (_isPlaying) return;
    if (_step >= widget.moves.length) {
      _resetToStep(0); // 終了時は最初から再生
    }
    setState(() {
      _isPlaying = true;
    });
    _playNextMove();
  }

  void _playNextMove() {
    if (!_isPlaying || _step >= widget.moves.length) {
      _stopReplay();
      return;
    }

    // 終盤判定：最後の10手か
    int movesRemaining = widget.moves.length - _step;
    bool isEndgame = movesRemaining <= 10;
    int delayMs = ((isEndgame ? 2000 : 1500) / _speed).round();

    _playTimer = Timer(Duration(milliseconds: delayMs), () {
      if (_isPlaying && mounted) {
        // 自動再生中も手動操作(_resetToStep)と同じく実際に盤面へ手を適用する
        // （以前はハイライトだけ更新し board を更新していなかったため、
        //   自動再生中に駒が動いて見えないバグがあった）
        final m = widget.moves[_step];
        setState(() {
          _applyMove(m, board: board, p1Hand: p1Hand, p2Hand: p2Hand);
          _step++;
          if (m.tr >= 0) {
            _lastTR = m.tr;
            _lastTC = m.tc;
          }
        });
        if (_step < widget.moves.length) {
          _playNextMove();
        } else {
          _stopReplay();
        }
      }
    });
  }

  void _pauseReplay() {
    _playTimer?.cancel();
    setState(() {
      _isPlaying = false;
    });
  }

  void _stopReplay() {
    _playTimer?.cancel();
    setState(() {
      _isPlaying = false;
    });
  }

  // ===== BUILD =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.handicap,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.visibility,
              color: _showAttackMap ? Colors.orangeAccent : Colors.white54,
            ),
            tooltip: _showAttackMap ? '効き非表示' : '効きを表示',
            onPressed: _toggleAttackMap,
          ),
          IconButton(
            icon: _isExportingGif
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white70),
                  )
                : const Icon(Icons.movie_creation_outlined, color: Colors.white70),
            tooltip: '対局をGIFで共有',
            onPressed: _isExportingGif ? null : _shareAsGif,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 後手持ち駒
            _handArea(isP1: false),
            // 盤面
            Expanded(
              flex: 5,
              child: Center(
                child: RepaintBoundary(
                  key: _boardCaptureKey,
                  child: _boardWidget(),
                ),
              ),
            ),
            // 先手持ち駒
            _handArea(isP1: true),
            // コントロール
            _controls(),
            // 棋譜リスト
            Expanded(
              flex: 3,
              child: _kifuList(),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 持ち駒エリア =====
  Widget _handArea({required bool isP1}) {
    final hand = isP1 ? p1Hand : p2Hand;
    final label = isP1 ? '▲先手' : '△後手';
    return Container(
      height: 40,
      color: const Color(0xFF0F2A40),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Text(
            '$label 持駒: ',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          Expanded(
            child: hand.isEmpty
                ? const Text('なし', style: TextStyle(color: Colors.white24, fontSize: 11))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: hand.entries.map((e) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDEB887),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${pieceLabel(e.key)}${e.value > 1 ? " ×${e.value}" : ""}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isP1 ? Colors.black87 : Colors.red.shade800,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ===== 将棋盤 =====
  Widget _boardWidget() {
    final List<List<int>>? atkP1Map =
        _showAttackMap ? GL.attackMap(board, true) : null;
    final List<List<int>>? atkP2Map =
        _showAttackMap ? GL.attackMap(board, false) : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final cellSize = size / 9;

        return SizedBox(
          width: size,
          height: size,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFDEB887),
              border: Border.all(color: Colors.black54, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(9, (row) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(9, (col) {
                    final piece = board[row][col];
                    final isHighlight = _lastTR == row && _lastTC == col;

                    Color cellTint = Colors.transparent;
                    if (atkP1Map != null && atkP2Map != null) {
                      final p1V = atkP1Map[row][col];
                      final p2V = atkP2Map[row][col];
                      final baseIntensity = piece != null ? 60 : 110;
                      if (p1V > 0 && p2V == 0) {
                        cellTint = Colors.blue.withAlpha(baseIntensity);
                      } else if (p2V > 0 && p1V == 0) {
                        cellTint = Colors.red.withAlpha(baseIntensity);
                      } else if (p1V > 0 && p2V > 0) {
                        cellTint = Colors.purple.withAlpha((baseIntensity * 0.7).round());
                      }
                    }

                    return Container(
                      width: cellSize,
                      height: cellSize,
                      decoration: BoxDecoration(
                        color: isHighlight
                            ? Colors.yellow.withAlpha(80)
                            : cellTint,
                        border: const Border(
                          right: BorderSide(color: Colors.black54, width: 0.5),
                          bottom: BorderSide(color: Colors.black54, width: 0.5),
                        ),
                      ),
                      child: piece == null
                          ? null
                          : Center(
                              child: RotatedBox(
                                quarterTurns: piece.isPlayer1 ? 0 : 2,
                                child: Text(
                                  piece.label,
                                  style: TextStyle(
                                    fontSize: cellSize * 0.62,
                                    fontWeight: FontWeight.bold,
                                    color: piece.isPlayer1
                                        ? Colors.black87
                                        : Colors.red.shade800,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                    );
                  }),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  // ===== コントロール =====
  Widget _controls() {
    final total = widget.moves.length;
    final stepLabel = _step == 0
        ? '開始局面'
        : _step == total
            ? '終局（$total手）'
            : '$_step手目 / $total手';

    final fi = widget.filterIndices;
    final fl = widget.filterLabel ?? '';

    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // フィルターバナー
          if (fi != null && fi.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: fl == '悪手'
                    ? Colors.orange.shade900.withAlpha(180)
                    : Colors.lightBlue.shade900.withAlpha(180),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous, size: 20),
                    color: _filterPos > 0 ? Colors.white : Colors.white30,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: _filterPos > 0 ? _filterPrev : null,
                  ),
                  Text(
                    '$fl ${_filterPos + 1} / ${fi.length}手目',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, size: 20),
                    color: _filterPos < fi.length - 1 ? Colors.white : Colors.white30,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: _filterPos < fi.length - 1 ? _filterNext : null,
                  ),
                ],
              ),
            ),
          ],
          // ボタン行（再生制御）
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navBtn('|◀', !_isPlaying && _step > 0 ? _goFirst : null),
              _navBtn('◀', !_isPlaying && _step > 0 ? _goPrev : null),
              // 再生/一時停止ボタン
              SizedBox(
                width: 48,
                height: 40,
                child: TextButton(
                  onPressed: _isPlaying
                      ? _pauseReplay
                      : (_step < total ? _startReplay : null),
                  style: TextButton.styleFrom(
                    foregroundColor: _isPlaying || _step < total
                        ? Colors.white
                        : Colors.white24,
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    _isPlaying ? '⏸' : '▶',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              // 停止ボタン
              SizedBox(
                width: 48,
                height: 40,
                child: TextButton(
                  onPressed: _isPlaying ? _stopReplay : null,
                  style: TextButton.styleFrom(
                    foregroundColor: _isPlaying ? Colors.white : Colors.white24,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    '⏹',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    stepLabel,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              _navBtn('▶', !_isPlaying && _step < total ? _goNext : null),
              _navBtn('▶|', !_isPlaying && _step < total ? _goLast : null),
            ],
          ),
          // スライダー
          Slider(
            value: _step.toDouble(),
            min: 0,
            max: total.toDouble(),
            divisions: total > 0 ? total : 1,
            activeColor: Colors.lightBlueAccent,
            inactiveColor: Colors.white24,
            onChanged: !_isPlaying && total > 0
                ? (v) => _resetToStep(v.round())
                : null,
          ),
          // 再生速度選択
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('速度:', style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(width: 8),
              for (final spd in [0.5, 1.0, 2.0])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => setState(() => _speed = spd),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _speed == spd ? Colors.lightBlueAccent : Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        spd == 0.5 ? '0.5x' : spd == 1.0 ? '1x' : '2x',
                        style: TextStyle(
                          color: _speed == spd ? Colors.black : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navBtn(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: 48,
      height: 40,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: onPressed != null ? Colors.white : Colors.white24,
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ===== 棋譜リスト =====
  Widget _kifuList() {
    if (widget.moves.isEmpty) {
      return const Center(
        child: Text('棋譜がありません', style: TextStyle(color: Colors.white38)),
      );
    }

    return Container(
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              '棋譜',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: widget.moves.length,
              itemBuilder: (context, i) {
                final m = widget.moves[i];
                final step = i + 1;
                final isCurrent = step == _step;
                final isFiltered = widget.filterIndices?.contains(step) ?? false;
                final isBlunderMode = widget.filterLabel == '悪手';
                return GestureDetector(
                  onTap: () {
                    if (isFiltered && widget.filterIndices != null) {
                      final pos = widget.filterIndices!.indexOf(step);
                      if (pos >= 0) setState(() => _filterPos = pos);
                    }
                    _resetToStep(step);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? Colors.lightBlue.withAlpha(60)
                          : isFiltered
                              ? (isBlunderMode
                                  ? Colors.orange.withAlpha(40)
                                  : Colors.lightBlue.withAlpha(30))
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        if (isFiltered)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              isBlunderMode ? Icons.warning_amber : Icons.star,
                              size: 12,
                              color: isBlunderMode
                                  ? Colors.orange
                                  : Colors.lightBlueAccent,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            m.text,
                            style: TextStyle(
                              color: isCurrent
                                  ? Colors.lightBlueAccent
                                  : isFiltered
                                      ? (isBlunderMode
                                          ? Colors.orange.shade200
                                          : Colors.lightBlueAccent)
                                      : m.p1
                                          ? Colors.white70
                                          : Colors.lightBlue.shade200,
                              fontSize: 13,
                              fontWeight: isCurrent || isFiltered
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
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
}
