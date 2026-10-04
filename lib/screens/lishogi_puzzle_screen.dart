// lib/screens/lishogi_puzzle_screen.dart
// lishogi.org デイリーパズル（詰将棋/問題）インタラクティブ画面

import 'package:flutter/material.dart';
import '../piece.dart';
import '../logic.dart';
import '../game_screen.dart';
import '../theme_config.dart';
import '../widgets/koma_painter.dart';
import '../widgets/board_painter.dart';
import '../services/lishogi_service.dart';
import '../theme/app_theme.dart';

class LishogiPuzzleScreen extends StatefulWidget {
  const LishogiPuzzleScreen({super.key});

  @override
  State<LishogiPuzzleScreen> createState() => _LishogiPuzzleScreenState();
}

enum _PuzzlePhase { loading, error, playing, opponentThink, solved, failed }

class _LishogiPuzzleScreenState extends State<LishogiPuzzleScreen>
    with SingleTickerProviderStateMixin {
  LishogiPuzzle? _puzzle;
  PuzzleBoardState? _boardState;
  _PuzzlePhase _phase = _PuzzlePhase.loading;
  String? _errorMsg;

  int _solutionIdx = 0;       // 次に指すべき解答インデックス
  bool _isPlayerTurn = true;  // プレイヤー番か
  bool _showingSolution = false;

  (int, int)? _selectedCell;
  PieceType? _selectedHandPiece;
  List<(int, int)> _legalMoves = [];

  String? _lastFeedback; // "正解" or "不正解"
  Color _feedbackColor = Colors.green;

  late final AnimationController _animController;
  late final Animation<double> _anim;
  int? _animFR, _animFC, _animTR, _animTC;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _anim = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.addListener(() => setState(() {}));
    _animController.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() { _animFR = null; });
      }
    });
    _loadPuzzle();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadPuzzle() async {
    setState(() {
      _phase = _PuzzlePhase.loading;
      _errorMsg = null;
      _solutionIdx = 0;
      _isPlayerTurn = true;
      _showingSolution = false;
      _lastFeedback = null;
      _selectedCell = null;
      _selectedHandPiece = null;
      _legalMoves = [];
    });

    final puzzle = await LishogiService.fetchDailyPuzzle();
    if (!mounted) return;

    if (puzzle == null) {
      setState(() {
        _phase = _PuzzlePhase.error;
        _errorMsg = 'パズルの読み込みに失敗しました。\nネットワーク接続を確認してください。';
      });
      return;
    }

    final board = LishogiService.parsePuzzleBoard(puzzle);
    if (!mounted) return;

    if (board == null) {
      setState(() {
        _phase = _PuzzlePhase.error;
        _errorMsg = 'パズルデータの解析に失敗しました。';
      });
      return;
    }

    setState(() {
      _puzzle = puzzle;
      _boardState = board;
      _isPlayerTurn = board.isPlayer1Turn;
      _phase = _PuzzlePhase.playing;
    });
  }

  bool get _isP1 => _puzzle?.isPlayer1Turn ?? true;

  int _r(int r) => _isP1 ? r : 8 - r;
  int _c(int c) => _isP1 ? c : 8 - c;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('lishogi パズル', style: TextStyle(color: AppTheme.textHigh)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_puzzle != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  '★ ${_puzzle!.rating}',
                  style: const TextStyle(color: Colors.amber, fontSize: 14),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: '次のパズル',
            onPressed: _loadPuzzle,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _PuzzlePhase.loading:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.amber),
              SizedBox(height: 16),
              Text('パズルを読み込み中...', style: TextStyle(color: AppTheme.textLow)),
            ],
          ),
        );
      case _PuzzlePhase.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMsg ?? 'エラーが発生しました',
                style: const TextStyle(color: AppTheme.textMid),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadPuzzle,
                child: const Text('再試行'),
              ),
            ],
          ),
        );
      default:
        return _buildPuzzleContent();
    }
  }

  Widget _buildPuzzleContent() {
    final puzzle = _puzzle!;
    return Column(
      children: [
        // テーマ表示
        if (puzzle.themes.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: const Color(0xFF0F3460),
            child: Wrap(
              spacing: 6,
              children: puzzle.themes.map((t) => Chip(
                label: Text(t, style: const TextStyle(fontSize: 11, color: AppTheme.textHigh)),
                backgroundColor: Colors.blueGrey.shade800,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )).toList(),
            ),
          ),
        // フィードバック
        if (_lastFeedback != null)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: _feedbackColor.withAlpha(40),
            child: Text(
              _lastFeedback!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _feedbackColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        // 番手表示
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(
                _isP1 ? Icons.circle : Icons.circle_outlined,
                size: 12,
                color: _isP1 ? Colors.amber : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                '${_isP1 ? "先手" : "後手"}番',
                style: const TextStyle(color: AppTheme.textMid, fontSize: 13),
              ),
              const Spacer(),
              Text(
                '${_solutionIdx}/${puzzle.solution.length}手',
                style: const TextStyle(color: AppTheme.textLow, fontSize: 12),
              ),
            ],
          ),
        ),
        // 持ち駒（相手）
        _buildHandRow(
          _isP1 ? _boardState!.p2Hand : _boardState!.p1Hand,
          isMyHand: false,
        ),
        // 盤面
        Expanded(child: _buildBoardWithLabels()),
        // 持ち駒（自分）
        _buildHandRow(
          _isP1 ? _boardState!.p1Hand : _boardState!.p2Hand,
          isMyHand: true,
        ),
        // ボタン行
        _buildButtons(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildButtons() {
    final isSolved = _phase == _PuzzlePhase.solved;
    final isFailed = _phase == _PuzzlePhase.failed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          if (!_showingSolution && !isSolved)
            OutlinedButton.icon(
              onPressed: _revealSolution,
              icon: const Icon(Icons.lightbulb_outline, size: 16),
              label: const Text('解答を見る'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.amber,
                side: const BorderSide(color: Colors.amber),
              ),
            ),
          const Spacer(),
          if (isSolved || isFailed)
            ElevatedButton.icon(
              onPressed: _loadPuzzle,
              icon: const Icon(Icons.skip_next, size: 16),
              label: const Text('次のパズル'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
            ),
        ],
      ),
    );
  }

  // ── 盤面 + ラベル ──────────────────────────────────────────

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
              SizedBox(
                height: labelSz,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: labelSz),
                    ...List.generate(9, (i) => SizedBox(
                      width: cellSz,
                      child: Text(
                        _isP1 ? '${9 - i}' : '${i + 1}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textLow,
                          fontSize: labelSz * 0.60,
                        ),
                      ),
                    )),
                  ],
                ),
              ),
              SizedBox(
                height: boardSz,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                              _rankKanji(_isP1 ? i + 1 : 9 - i),
                              style: TextStyle(
                                color: AppTheme.textLow,
                                fontSize: labelSz * 0.60,
                              ),
                            ),
                          ),
                        )),
                      ),
                    ),
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
    final config = boardThemeConfig(PieceTheme.standard);
    final starColor = config.cell.computeLuminance() < 0.3 ? Colors.white70 : Colors.black87;
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
          CustomPaint(
            painter: BoardPainter(
              cellColor: config.cell,
              borderColor: config.cellBorder,
              starColor: starColor,
            ),
            size: Size(sz, sz),
          ),
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
    final board = _boardState?.board;
    if (board == null || _animTR == null || _animTC == null) return const SizedBox.shrink();
    final piece = board[_animTR!][_animTC!];
    if (piece == null) return const SizedBox.shrink();

    final t = _anim.value;
    final srcDispR = _r(_animFR!).toDouble();
    final srcDispC = _c(_animFC!).toDouble();
    final dstDispR = _r(_animTR!).toDouble();
    final dstDispC = _c(_animTC!).toDouble();
    final x = (srcDispC + (dstDispC - srcDispC) * t) * cellSz;
    final y = (srcDispR + (dstDispR - srcDispR) * t) * cellSz;

    return Positioned(
      left: x, top: y, width: cellSz, height: cellSz,
      child: Center(child: _buildKomaTile(piece, cellSz, cellSz)),
    );
  }

  Widget _buildCell(int row, int col, double cellW, double cellH) {
    final board = _boardState!.board;
    final piece = board[row][col];
    final isSelected = _selectedCell == (row, col);
    final isLegal = _legalMoves.contains((row, col));
    final isAnimDst = _animFR != null && _animTR == row && _animTC == col && _anim.value < 0.999;

    Color bg = const Color(0xFFDDB06C);
    if (isSelected) bg = Colors.amber.shade300;

    BoxBorder cellBorder;
    if (isLegal && piece != null) {
      cellBorder = Border.all(color: Colors.orange.shade300, width: 1.0);
    } else {
      cellBorder = Border.all(color: const Color(0xFF8B6914), width: 0.5);
    }

    final canTap = _phase == _PuzzlePhase.playing && _isPlayerTurn;

    return GestureDetector(
      onTap: canTap ? () => _onTapCell(row, col) : null,
      child: SizedBox(
        width: cellW,
        height: cellH,
        child: Container(
          decoration: BoxDecoration(color: bg, border: cellBorder),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (piece != null && !isAnimDst)
                Center(child: _buildKomaTile(piece, cellW, cellH)),
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
              if (isLegal && piece != null)
                Center(
                  child: Container(
                    width: cellW * 0.94,
                    height: cellH * 0.94,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF2E7D5B), width: 3),
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
    final pointsUp = piece.isPlayer1 == _isP1;
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
            quarterTurns: pointsUp ? 0 : 2,
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

  Widget _buildHandRow(Map<PieceType, int> hand, {required bool isMyHand}) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      color: Colors.brown.shade900.withAlpha(80),
      child: Row(
        children: [
          Text(
            isMyHand ? '持駒' : '相手',
            style: const TextStyle(color: AppTheme.textLow, fontSize: 11),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: hand.entries
                    .where((e) => e.value > 0)
                    .map((e) => GestureDetector(
                          onTap: isMyHand && _phase == _PuzzlePhase.playing && _isPlayerTurn
                              ? () => _onTapHandPiece(e.key)
                              : null,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                            decoration: BoxDecoration(
                              color: _selectedHandPiece == e.key
                                  ? Colors.amber.shade700
                                  : Colors.brown.shade700,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 24,
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
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF3A2A18),
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (e.value > 1)
                                  Text('×${e.value}',
                                      style: const TextStyle(color: AppTheme.textHigh, fontSize: 10)),
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
    final hand = _isP1 ? _boardState!.p1Hand : _boardState!.p2Hand;
    final oppHand = _isP1 ? _boardState!.p2Hand : _boardState!.p1Hand;
    setState(() {
      if (_selectedHandPiece == type) {
        _selectedHandPiece = null;
        _legalMoves = [];
      } else {
        _selectedHandPiece = type;
        _selectedCell = null;
        _legalMoves = GL.dropSquares(
          _boardState!.board, type, _isP1, hand, oppHand,
        );
      }
    });
  }

  void _onTapCell(int row, int col) {
    if (_selectedHandPiece != null) {
      if (_legalMoves.contains((row, col))) {
        _submitMove(UsiMove(fr: -1, fc: -1, tr: row, tc: col, drop: _selectedHandPiece));
      }
      setState(() { _selectedHandPiece = null; _legalMoves = []; });
      return;
    }

    final piece = _boardState!.board[row][col];

    if (_selectedCell != null) {
      if (_legalMoves.contains((row, col))) {
        _submitMove(UsiMove(fr: _selectedCell!.$1, fc: _selectedCell!.$2, tr: row, tc: col));
        return;
      }
      if (piece != null && piece.isPlayer1 == _isP1) {
        _selectCell(row, col);
        return;
      }
      setState(() { _selectedCell = null; _legalMoves = []; });
      return;
    }

    if (piece != null && piece.isPlayer1 == _isP1) {
      _selectCell(row, col);
    }
  }

  void _selectCell(int row, int col) {
    setState(() {
      _selectedCell = (row, col);
      _selectedHandPiece = null;
      _legalMoves = GL.legal(_boardState!.board, row, col);
    });
  }

  Future<void> _submitMove(UsiMove usiMove) async {
    final puzzle = _puzzle!;
    final expectedUsi = puzzle.solution[_solutionIdx];

    // 解答USIのバリデーション（不正形式はスキップ）
    if (UsiParser.parse(expectedUsi) == null) {
      _loadNextPuzzle();
      return;
    }

    // 指し手をUSI文字列に変換して正解と比較
    // 成りなしでも成りUSIと一致する場合（成れる手を成らずで指した）も正解とする
    final submittedUsi = _usiMoveToString(usiMove);
    final isCorrect = submittedUsi == expectedUsi ||
        submittedUsi == expectedUsi.replaceAll('+', '');

    if (isCorrect) {
      // 正解: 盤面を更新（expectedUsiで適用して盤面を正確に保つ）
      final result = LishogiService.applyUsiMove(
        expectedUsi, _boardState!, _isP1, _solutionIdx + 1,
      );
      if (result == null) {
        // 解答適用失敗 → 次の問題へ
        _loadNextPuzzle();
        return;
      }
      final (_, newState) = result;

      setState(() {
        _boardState = newState;
        _lastFeedback = '正解！';
        _feedbackColor = Colors.green;
        _selectedCell = null;
        _selectedHandPiece = null;
        _legalMoves = [];
        _solutionIdx++;

        // アニメーション
        if (usiMove.fr >= 0) {
          _animFR = usiMove.fr; _animFC = usiMove.fc;
          _animTR = usiMove.tr; _animTC = usiMove.tc;
          _animController.forward(from: 0);
        }
      });

      if (_solutionIdx >= puzzle.solution.length) {
        // 全問正解
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) setState(() => _phase = _PuzzlePhase.solved);
        return;
      }

      // 相手の応手を自動で指す
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      _applyOpponentMove();
    } else {
      setState(() {
        _lastFeedback = '不正解... もう一度';
        _feedbackColor = Colors.red;
        _selectedCell = null;
        _selectedHandPiece = null;
        _legalMoves = [];
      });
    }
  }

  void _applyOpponentMove() {
    final puzzle = _puzzle!;
    if (_solutionIdx >= puzzle.solution.length) return;

    final oppUsi = puzzle.solution[_solutionIdx];
    final result = LishogiService.applyUsiMove(
      oppUsi, _boardState!, !_isP1, _solutionIdx + 1,
    );
    if (result == null) return;

    final (move, newState) = result;

    setState(() {
      _boardState = newState;
      _solutionIdx++;
      _lastFeedback = null;

      if (move.fr >= 0) {
        _animFR = move.fr; _animFC = move.fc;
        _animTR = move.tr; _animTC = move.tc;
        _animController.forward(from: 0);
      }

      if (_solutionIdx >= puzzle.solution.length) {
        _phase = _PuzzlePhase.solved;
        _lastFeedback = '完全正解！おめでとうございます！';
        _feedbackColor = Colors.greenAccent;
      } else {
        _phase = _PuzzlePhase.playing;
      }
    });
  }

  void _loadNextPuzzle() => _loadPuzzle();

  void _revealSolution() {
    setState(() {
      _showingSolution = true;
      _lastFeedback = '解答: ${_puzzle!.solution.join(' → ')}';
      _feedbackColor = Colors.amber;
    });
  }

  String _usiMoveToString(UsiMove m) {
    if (m.drop != null) {
      const usiPiece = {
        PieceType.rook: 'R', PieceType.bishop: 'B', PieceType.gold: 'G',
        PieceType.silver: 'S', PieceType.knight: 'N', PieceType.lance: 'L',
        PieceType.pawn: 'P',
      };
      final p = usiPiece[m.drop] ?? 'P';
      final file = 9 - m.tc;
      final rank = String.fromCharCode('a'.codeUnitAt(0) + m.tr);
      return '$p*$file$rank';
    }
    final ff = 9 - m.fc;
    final fr = String.fromCharCode('a'.codeUnitAt(0) + m.fr);
    final tf = 9 - m.tc;
    final tr = String.fromCharCode('a'.codeUnitAt(0) + m.tr);
    final promote = m.promote ? '+' : '';
    return '$ff$fr$tf$tr$promote';
  }

  String _rankKanji(int r) {
    const k = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];
    return r >= 1 && r <= 9 ? k[r - 1] : r.toString();
  }
}
