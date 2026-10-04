// lib/screens/network_board_widget.dart
// ネットワーク対局用将棋盤 Widget（AI対局盤と同一レンダリング）

import 'package:flutter/material.dart';
import '../piece.dart';
import '../logic.dart';
import '../game_screen.dart';
import '../services/board_sync_service.dart';
import '../theme_config.dart';
import '../widgets/koma_painter.dart';
import '../widgets/board_painter.dart';

class NetworkBoardWidget extends StatefulWidget {
  final NetworkBoardState state;
  final bool isPlayer1; // 自分が先手か後手か
  final bool isMyTurn;
  final Function(KifuMove move) onMove; // 指し手コールバック
  final PieceTheme theme;

  const NetworkBoardWidget({
    super.key,
    required this.state,
    required this.isPlayer1,
    required this.isMyTurn,
    required this.onMove,
    this.theme = PieceTheme.standard,
  });

  @override
  State<NetworkBoardWidget> createState() => _NetworkBoardWidgetState();
}

class _NetworkBoardWidgetState extends State<NetworkBoardWidget>
    with SingleTickerProviderStateMixin {
  late BoardThemeConfig _themeConfig;
  (int, int)? _selectedCell;
  PieceType? _selectedHandPiece;
  List<(int, int)> _legalMoves = [];
  bool _showAttackMap = false;
  List<List<int>>? _p1AtkMap;
  List<List<int>>? _p2AtkMap;

  // 指し手アニメーション
  late final AnimationController _animController;
  late final Animation<double> _anim;
  int? _animFR, _animFC, _animTR, _animTC;

  @override
  void initState() {
    super.initState();
    _themeConfig = boardThemeConfig(widget.theme);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _anim = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.addListener(() => setState(() {}));
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _animFR = null;
          _animFC = null;
          _animTR = null;
          _animTC = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(NetworkBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.theme != widget.theme) {
      _themeConfig = boardThemeConfig(widget.theme);
    }
    if (_showAttackMap) _recomputeAtkMap();

    // 相手が指したら選択解除 + アニメーション起動
    if (widget.state.moveCount > oldWidget.state.moveCount) {
      if (!widget.isMyTurn) {
        _selectedCell = null;
        _selectedHandPiece = null;
        _legalMoves = [];
      }
      // 盤上移動のみアニメーション（打ちは瞬間表示）
      final last = widget.state.moves.isNotEmpty ? widget.state.moves.last : null;
      if (last != null && last.fr >= 0) {
        _animFR = last.fr;
        _animFC = last.fc;
        _animTR = last.tr;
        _animTC = last.tc;
        _animController.forward(from: 0);
      }
    }
  }

  void _recomputeAtkMap() {
    _p1AtkMap = GL.attackMap(widget.state.board, true);
    _p2AtkMap = GL.attackMap(widget.state.board, false);
  }

  // 盤面テクスチャ用の駒得比率（0.0=後手有利〜0.5=互角〜1.0=先手有利）
  // ローカル対局(game_screen.dart)の _advantageRatio() と同一の駒価値テーブル
  static const _advValues = {
    PieceType.king: 0,
    PieceType.rook: 5,
    PieceType.bishop: 3,
    PieceType.gold: 1,
    PieceType.silver: 1,
    PieceType.knight: 1,
    PieceType.lance: 1,
    PieceType.pawn: 1,
    PieceType.promotedRook: 6,
    PieceType.promotedBishop: 4,
  };

  double _boardAdvantageRatio() {
    int p1Score = 0, p2Score = 0;
    for (final row in widget.state.board) {
      for (final piece in row) {
        if (piece == null) continue;
        final val = _advValues[piece.type] ?? 0;
        if (piece.isPlayer1) p1Score += val; else p2Score += val;
      }
    }
    widget.state.p1Hand.forEach((type, cnt) => p1Score += (_advValues[type] ?? 0) * cnt);
    widget.state.p2Hand.forEach((type, cnt) => p2Score += (_advValues[type] ?? 0) * cnt);
    final total = p1Score + p2Score;
    return total == 0 ? 0.5 : p1Score / total;
  }

  Map<PieceType, int> get myHand =>
      widget.isPlayer1 ? widget.state.p1Hand : widget.state.p2Hand;
  Map<PieceType, int> get oppHand =>
      widget.isPlayer1 ? widget.state.p2Hand : widget.state.p1Hand;

  // 後手視点では盤を 180° 回転
  int _r(int r) => widget.isPlayer1 ? r : 8 - r;
  int _c(int c) => widget.isPlayer1 ? c : 8 - c;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHandRow(oppHand, isMyHand: false),
        const SizedBox(height: 2),
        Expanded(child: _buildBoardWithLabels()),
        const SizedBox(height: 2),
        _buildHandRow(myHand, isMyHand: true),
        _buildAttackMapToggle(),
      ],
    );
  }

  // ── 効きマップトグル ─────────────────────────────────────────

  Widget _buildAttackMapToggle() {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showAttackMap = !_showAttackMap;
                if (_showAttackMap) _recomputeAtkMap();
              });
            },
            icon: Icon(
              _showAttackMap ? Icons.visibility : Icons.visibility_off,
              size: 14,
              color: Colors.white60,
            ),
            label: const Text('効き', style: TextStyle(fontSize: 11, color: Colors.white60)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  // ── 盤面 + 筋・段ラベル ──────────────────────────────────────

  Widget _buildBoardWithLabels() {
    return LayoutBuilder(builder: (context, constraints) {
      final availH = constraints.maxHeight;
      final availW = constraints.maxWidth;
      final totalSz = availH < availW ? availH : availW;
      final labelSz = totalSz * 0.065;
      final boardSz = totalSz - labelSz;
      final cellSz = boardSz / 9;

      return Center(
        child: SizedBox(
          width: totalSz,
          height: totalSz,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 筋ラベル行（9-1 または 1-9）
              SizedBox(
                height: labelSz,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: labelSz), // コーナースペーサー
                    ...List.generate(9, (i) => SizedBox(
                      width: cellSz,
                      child: Text(
                        widget.isPlayer1 ? '${9 - i}' : '${i + 1}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: labelSz * 0.60,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    )),
                  ],
                ),
              ),
              // 盤面 + 段ラベル列
              SizedBox(
                height: boardSz,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 段ラベル（一〜九）
                    SizedBox(
                      width: labelSz,
                      height: boardSz,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(9, (i) => SizedBox(
                          width: labelSz,
                          height: cellSz,
                          child: Center(
                            child: Text(
                              _rowKanji(widget.isPlayer1 ? i + 1 : 9 - i),
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: labelSz * 0.60,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ),
                        )),
                      ),
                    ),
                    // 盤面本体
                    SizedBox(
                      width: boardSz,
                      height: boardSz,
                      child: _buildBoardCore(boardSz, cellSz),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildBoardCore(double sz, double cellSz) {
    final config = _themeConfig;
    final starColor = config.cell.computeLuminance() < 0.3
        ? Colors.white70
        : Colors.black87;
    final t = _anim.value;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        // 外枠線は GridOverlayPainter が盤面と同じ座標系で描く
        // （Container の border は decoration.padding により
        //   内側コンテンツを縮めてしまい、グリッド線・駒とズレる）
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(config.cell, Colors.white, 0.10)!,
            config.cell,
            Color.lerp(config.cell, Colors.black, 0.14)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(115),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // グリッド + 星
          CustomPaint(
            painter: BoardPainter(
              cellColor: config.cell,
              borderColor: config.cellBorder,
              starColor: starColor,
              textured: widget.theme == PieceTheme.textured,
              gradientTop: config.gradientTop,
              gradientBottom: config.gradientBottom,
              advantageRatio: _boardAdvantageRatio(),
            ),
            size: Size(sz, sz),
          ),
          // 駒 + ハイライト（アニメーション中は移動先の駒を非表示）
          Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(9, (dispRow) {
              final row = _r(dispRow);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(9, (dispCol) {
                  final col = _c(dispCol);
                  return _buildCell(row, col, cellSz, cellSz);
                }),
              );
            }),
          ),
          // 指し手スライドアニメーション
          if (_animFR != null && t < 0.999)
            _buildAnimOverlay(cellSz),
          // グリッド線・星は最前面に重ねる（マスの不透明背景に隠れないように）
          IgnorePointer(
            child: CustomPaint(
              painter: GridOverlayPainter(
                borderColor: config.cellBorder,
                outerBorderColor: const Color(0xFF4E342E),
                outerBorderWidth: 3.0,
                starColor: starColor,
              ),
              size: Size(sz, sz),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimOverlay(double cellSz) {
    final piece = widget.state.board[_animTR!][_animTC!];
    if (piece == null) return const SizedBox.shrink();

    final t = _anim.value;
    final srcDispR = _r(_animFR!).toDouble();
    final srcDispC = _c(_animFC!).toDouble();
    final dstDispR = _r(_animTR!).toDouble();
    final dstDispC = _c(_animTC!).toDouble();

    final x = (srcDispC + (dstDispC - srcDispC) * t) * cellSz;
    final y = (srcDispR + (dstDispR - srcDispR) * t) * cellSz;

    return Positioned(
      left: x,
      top: y,
      width: cellSz,
      height: cellSz,
      child: Center(child: _buildKomaTile(piece, cellSz, cellSz)),
    );
  }

  Widget _buildCell(int row, int col, double cellW, double cellH) {
    final piece = widget.state.board[row][col];
    final isSelected = _selectedCell == (row, col);
    final isLegal = _legalMoves.contains((row, col));
    final lastMove = widget.state.moves.isNotEmpty ? widget.state.moves.last : null;
    final isLastTo = lastMove?.tr == row && lastMove?.tc == col;
    final isLastFrom = lastMove != null && lastMove.fr >= 0 &&
        lastMove.fr == row && lastMove.fc == col;

    // アニメーション中は移動先セルの駒を非表示（オーバーレイが担当）
    final isAnimDst = _animFR != null &&
        _animTR == row &&
        _animTC == col &&
        _anim.value < 0.999;

    // 背景色
    Color bg = _themeConfig.cell;
    if (isSelected) {
      bg = Colors.amber.shade300;
    } else if (isLastTo || isLastFrom) {
      bg = Colors.amber.shade100;
    }

    // 効きマップ合成
    final p1V = _showAttackMap ? (_p1AtkMap?[row][col] ?? 0) : 0;
    final p2V = _showAttackMap ? (_p2AtkMap?[row][col] ?? 0) : 0;
    if (_showAttackMap) {
      if (p1V > 0 && p2V > 0) {
        bg = Color.lerp(bg, Colors.purple.shade300, 0.22)!;
      } else if (p1V > 0) {
        bg = Color.lerp(bg, Colors.blue.shade300, 0.18)!;
      } else if (p2V > 0) {
        bg = Color.lerp(bg, Colors.red.shade300, 0.18)!;
      }
    }

    // 境界線（ただ取り / 取れる駒）
    final net = p1V - p2V;
    final myP1 = widget.isPlayer1;
    final isTadaDori = isLegal && piece != null &&
        piece.isPlayer1 != myP1 && (myP1 ? net < 0 : net > 0);

    BoxBorder cellBorder;
    if (isTadaDori) {
      cellBorder = Border.all(color: Colors.red.shade400, width: 2.0);
    } else if (isLegal && piece != null) {
      cellBorder = Border.all(color: Colors.orange.shade300, width: 1.0);
    } else {
      cellBorder = Border.all(color: _themeConfig.cellBorder, width: 0.5);
    }

    return GestureDetector(
      onTap: () => _onTapCell(row, col),
      child: SizedBox(
        width: cellW,
        height: cellH,
        child: Container(
          decoration: BoxDecoration(color: bg, border: cellBorder),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 駒（アニメーション中の移動先は非表示）
              if (piece != null && !isAnimDst)
                Center(child: _buildKomaTile(piece, cellW, cellH)),
              // 合法手: 空マス → ドット
              if (isLegal && piece == null)
                Center(
                  child: Container(
                    width: cellW * 0.30,
                    height: cellW * 0.30,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D5B).withAlpha(190),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              // 合法手: 駒あり → リング
              if (isLegal && piece != null)
                Center(
                  child: Container(
                    width: cellW * 0.94,
                    height: cellH * 0.94,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF2E7D5B),
                        width: 3,
                      ),
                    ),
                  ),
                ),
              // 効き数ラベル
              if (_showAttackMap && net != 0)
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Text(
                    net > 0 ? '+$net' : '$net',
                    style: TextStyle(
                      fontSize: cellW * 0.26,
                      fontWeight: FontWeight.bold,
                      color: net > 0 ? Colors.blue.shade400 : Colors.red.shade400,
                      shadows: [
                        Shadow(color: Colors.black.withAlpha(160), blurRadius: 2),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKomaTile(Piece piece, double cellW, double cellH) {
    final pointsUp = piece.isPlayer1 == widget.isPlayer1;
    final quarterTurns = pointsUp ? 0 : 2;
    return SizedBox(
      width: cellW * 0.88,
      height: cellH * 0.88,
      child: CustomPaint(
        painter: KomaPainter(
          pointsUp: pointsUp,
          fill: const Color(0xFFF4DDA6),
          border: const Color(0xFFC49A4E),
        ),
        child: Center(
          child: RotatedBox(
            quarterTurns: quarterTurns,
            child: Text(
              piece.label,
              style: komaLabelStyle(
                isPromoted: piece.isPromoted,
                fontSize: cellW * 0.52,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 持ち駒行 ────────────────────────────────────────────────

  Widget _buildHandRow(Map<PieceType, int> hand, {required bool isMyHand}) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      color: Colors.brown.shade900.withAlpha(80),
      child: Row(
        children: [
          Text(
            isMyHand ? '持駒 ▼' : '持駒 ▲',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: hand.entries
                    .where((e) => e.value > 0)
                    .map((e) => GestureDetector(
                          onTap: isMyHand && widget.isMyTurn
                              ? () => _onTapHandPiece(e.key)
                              : null,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 2, vertical: 2),
                            decoration: BoxDecoration(
                              color: _selectedHandPiece == e.key
                                  ? Colors.amber.shade700
                                  : Colors.brown.shade700,
                              borderRadius: BorderRadius.circular(4),
                              border: _selectedHandPiece == e.key
                                  ? Border.all(color: Colors.amber, width: 1.5)
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 26,
                                  child: CustomPaint(
                                    painter: const KomaPainter(
                                      pointsUp: true,
                                      fill: Color(0xFFF4DDA6),
                                      border: Color(0xFFC49A4E),
                                    ),
                                    child: Center(
                                      child: Text(
                                        pieceLabel(e.key),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF3A2A18),
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (e.value > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 2),
                                    child: Text(
                                      '×${e.value}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── タップ処理 ──────────────────────────────────────────────

  void _onTapHandPiece(PieceType type) {
    if (!widget.isMyTurn) return;
    setState(() {
      if (_selectedHandPiece == type) {
        _selectedHandPiece = null;
        _selectedCell = null;
        _legalMoves = [];
      } else {
        _selectedHandPiece = type;
        _selectedCell = null;
        _legalMoves = GL.dropSquares(
          widget.state.board,
          type,
          widget.isPlayer1,
          myHand,
          oppHand,
        );
      }
    });
  }

  void _onTapCell(int row, int col) {
    if (!widget.isMyTurn) return;

    // 持ち駒から打つ
    if (_selectedHandPiece != null) {
      if (_legalMoves.contains((row, col))) {
        _commitDrop(_selectedHandPiece!, row, col);
      } else {
        setState(() {
          _selectedHandPiece = null;
          _legalMoves = [];
        });
      }
      return;
    }

    final piece = widget.state.board[row][col];

    // 移動先を選択中
    if (_selectedCell != null) {
      if (_legalMoves.contains((row, col))) {
        _commitMove(_selectedCell!, row, col);
        return;
      }
      // 自駒を再選択
      if (piece != null && piece.isPlayer1 == widget.isPlayer1) {
        _selectCell(row, col);
        return;
      }
      // 選択解除
      setState(() {
        _selectedCell = null;
        _legalMoves = [];
      });
      return;
    }

    // 自駒を選択
    if (piece != null && piece.isPlayer1 == widget.isPlayer1) {
      _selectCell(row, col);
    }
  }

  void _selectCell(int row, int col) {
    final moves = GL.legal(widget.state.board, row, col);
    setState(() {
      _selectedCell = (row, col);
      _selectedHandPiece = null;
      _legalMoves = moves;
    });
  }

  // ── 指し手決定 ──────────────────────────────────────────────

  Future<void> _commitMove((int, int) from, int toRow, int toCol) async {
    final piece = widget.state.board[from.$1][from.$2]!;
    bool promote = false;

    if (piece.canPromote && !piece.isPromoted) {
      final inZone = widget.isPlayer1
          ? (toRow <= 2 || from.$1 <= 2)
          : (toRow >= 6 || from.$1 >= 6);
      if (inZone && !piece.mustPromote(toRow)) {
        promote = await _showPromoteDialog(piece) ?? false;
      } else if (piece.mustPromote(toRow)) {
        promote = true;
      }
    }

    final moveCount = widget.state.moveCount + 1;
    final note = _buildMoveNote(piece, from, toRow, toCol, promote);

    final move = KifuMove(
      moveCount,
      widget.isPlayer1,
      note,
      fr: from.$1,
      fc: from.$2,
      tr: toRow,
      tc: toCol,
      promote: promote,
    );

    setState(() {
      _selectedCell = null;
      _legalMoves = [];
    });

    widget.onMove(move);
  }

  Future<void> _commitDrop(PieceType type, int row, int col) async {
    final moveCount = widget.state.moveCount + 1;
    // 常に先手視点の絶対座標（KIF標準）
    final toFile = 9 - col;
    final toRank = row + 1;
    final note = '$toFile${_rowKanji(toRank)}${pieceLabel(type)}打';
    final move = KifuMove(
      moveCount,
      widget.isPlayer1,
      note,
      fr: -1,
      fc: -1,
      tr: row,
      tc: col,
      drop: type,
    );

    setState(() {
      _selectedHandPiece = null;
      _legalMoves = [];
    });

    widget.onMove(move);
  }

  Future<bool?> _showPromoteDialog(Piece piece) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('成りますか？'),
        content: Text(
            '${piece.label} を ${pieceLabel(piece.promotedType)} に成りますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('成らない'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('成る'),
          ),
        ],
      ),
    );
  }

  String _buildMoveNote(
      Piece piece, (int, int) from, int toRow, int toCol, bool promote) {
    // 常に先手視点の絶対座標（KIF標準）
    final col = 9 - toCol;
    final row = toRow + 1;
    final suffix = promote ? '成' : '';
    return '$col${_rowKanji(row)}${piece.label}$suffix';
  }

  String _rowKanji(int r) {
    const kanji = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];
    return r >= 1 && r <= 9 ? kanji[r - 1] : r.toString();
  }
}
