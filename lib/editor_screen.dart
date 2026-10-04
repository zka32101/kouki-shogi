// lib/editor_screen.dart — 局面エディタ

import 'package:flutter/material.dart';
import 'piece.dart';
import 'logic.dart';
import 'game_screen.dart';
import 'theme/app_theme.dart';
import 'rule_validator.dart';

const _editPieces = [
  PieceType.pawn,
  PieceType.lance,
  PieceType.knight,
  PieceType.silver,
  PieceType.gold,
  PieceType.bishop,
  PieceType.rook,
  PieceType.king,
  PieceType.promotedPawn,
  PieceType.promotedLance,
  PieceType.promotedKnight,
  PieceType.promotedSilver,
  PieceType.promotedBishop,
  PieceType.promotedRook,
];
const _rowKanji2 = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];
const _handTypes = [
  PieceType.pawn,
  PieceType.lance,
  PieceType.knight,
  PieceType.silver,
  PieceType.gold,
  PieceType.bishop,
  PieceType.rook,
];

class EditorScreen extends StatefulWidget {
  final GameSettings gameSettings;
  const EditorScreen({super.key, required this.gameSettings});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late List<List<Piece?>> board;
  Map<PieceType, int> p1Hand = {}, p2Hand = {};
  bool startP1Turn = true; // 対局の開始手番
  bool placingP1 = true; // 今置こうとしている駒の手番
  PieceType? selectedType; // 選択中の駒種
  bool eraseMode = false; // 消去モード

  @override
  void initState() {
    super.initState();
    board = _emptyBoard();
  }

  static List<List<Piece?>> _emptyBoard() =>
      List.generate(9, (_) => List<Piece?>.filled(9, null, growable: false));

  static List<List<Piece?>> _stdBoard() {
    final b = _emptyBoard();
    void s(int r, int c, PieceType t, bool p1) => b[r][c] = Piece(t, p1);
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
    for (int c = 0; c < 9; c++) s(2, c, PieceType.pawn, false);
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
    for (int c = 0; c < 9; c++) s(6, c, PieceType.pawn, true);
    return b;
  }

  Color get _cellColor => widget.gameSettings.theme == PieceTheme.dark
      ? const Color(0xFF8B6914)
      : const Color(0xFFDEB887);
  Color get _cellBorder => widget.gameSettings.theme == PieceTheme.dark
      ? const Color(0xFF5C3D00)
      : Colors.brown.shade600;
  Color _pieceColor(Piece p) {
    if (widget.gameSettings.theme == PieceTheme.dark) {
      return p.isPromoted ? Colors.amber : Colors.white;
    }
    return p.isPromoted ? Colors.red.shade700 : Colors.black87;
  }

  // 行き所のない駒（歩・香の最終段、桂の最終2段）の配置を禁止
  bool _isInvalidPlacement(PieceType type, bool isP1, int row) {
    final lastRow = isP1 ? 0 : 8;
    final lastTwoRows = isP1 ? const [0, 1] : const [7, 8];
    if ((type == PieceType.pawn || type == PieceType.lance) && row == lastRow) {
      return true;
    }
    if (type == PieceType.knight && lastTwoRows.contains(row)) {
      return true;
    }
    return false;
  }

  void _onCell(int row, int col) {
    if (!eraseMode &&
        selectedType != null &&
        _isInvalidPlacement(selectedType!, placingP1, row)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('その駒はこの段に置けません（行き所のない駒）'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      if (eraseMode || selectedType == null) {
        board[row][col] = null;
        return;
      }
      final existing = board[row][col];
      if (existing != null &&
          existing.type == selectedType &&
          existing.isPlayer1 == placingP1) {
        board[row][col] = null; // 同じ駒をタップ → 消去
      } else {
        board[row][col] = Piece(selectedType!, placingP1);
      }
    });
  }

  // 将棋の駒数上限（1セットあたり）。飛角は各1枚、金銀桂香は各2枚、歩は9枚。
  static const _maxPieceCount = {
    PieceType.pawn: 9,
    PieceType.lance: 2,
    PieceType.knight: 2,
    PieceType.silver: 2,
    PieceType.gold: 2,
    PieceType.bishop: 1,
    PieceType.rook: 1,
  };

  void _adjustHand(PieceType type, bool isP1, int delta) {
    setState(() {
      final h = isP1 ? p1Hand : p2Hand;
      final max = _maxPieceCount[type] ?? 18;
      final newVal = ((h[type] ?? 0) + delta).clamp(0, max);
      newVal == 0 ? h.remove(type) : (h[type] = newVal);
    });
  }

  bool _validate() {
    int k1 = 0, k2 = 0;
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++) {
        final p = board[r][c];
        if (p != null && p.type == PieceType.king) {
          if (p.isPlayer1)
            k1++;
          else
            k2++;
        }
      }
    if (k1 != 1 || k2 != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('先手・後手それぞれ玉を1枚置いてください'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    final violations = validateBoard(board);
    if (violations.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('反則配置があります: ${violations.first.description}'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    return true;
  }

  void _startGame() {
    if (!_validate()) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          settings: widget.gameSettings,
          initialBoard: GL.copy(board),
          initialP1Hand: Map.from(p1Hand),
          initialP2Hand: Map.from(p2Hand),
          initialP1Turn: startP1Turn,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: '戻る',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('局面エディタ', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => setState(() {
              board = _stdBoard();
              p1Hand = {};
              p2Hand = {};
            }),
            child: const Text(
              '初期配置',
              style: TextStyle(color: Colors.lightBlueAccent),
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              board = _emptyBoard();
              p1Hand = {};
              p2Hand = {};
            }),
            child: const Text('全消し', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── 手番 & 対局開始 ──
            Container(
              color: const Color(0xFF0F3460),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Text(
                    '開始手番:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('▲先手', style: TextStyle(fontSize: 12)),
                    selected: startP1Turn,
                    onSelected: (_) => setState(() => startP1Turn = true),
                    selectedColor: Colors.blue.shade700,
                    labelStyle: TextStyle(
                      color: startP1Turn ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('△後手', style: TextStyle(fontSize: 12)),
                    selected: !startP1Turn,
                    onSelected: (_) => setState(() => startP1Turn = false),
                    selectedColor: Colors.red.shade700,
                    labelStyle: TextStyle(
                      color: !startP1Turn ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('対局開始', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: _startGame,
                  ),
                ],
              ),
            ),
            // ── 駒パレット ──
            Container(
              color: AppTheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '手番:',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        label: const Text('先手', style: TextStyle(fontSize: 11)),
                        selected: placingP1,
                        onSelected: (_) => setState(() => placingP1 = true),
                        selectedColor: Colors.blue.shade800,
                        labelStyle: TextStyle(
                          color: placingP1 ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        label: const Text('後手', style: TextStyle(fontSize: 11)),
                        selected: !placingP1,
                        onSelected: (_) => setState(() => placingP1 = false),
                        selectedColor: Colors.red.shade800,
                        labelStyle: TextStyle(
                          color: !placingP1 ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('消去', style: TextStyle(fontSize: 11)),
                        selected: eraseMode,
                        onSelected: (v) => setState(() {
                          eraseMode = v;
                          if (v) selectedType = null;
                        }),
                        selectedColor: Colors.orange.shade700,
                        labelStyle: TextStyle(
                          color: eraseMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _editPieces.map((type) {
                        final sel = selectedType == type && !eraseMode;
                        final dummy = Piece(type, true);
                        return GestureDetector(
                          onTap: () => setState(() {
                            eraseMode = false;
                            selectedType = sel ? null : type;
                          }),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: sel ? Colors.yellow.shade300 : _cellColor,
                              borderRadius: BorderRadius.circular(4),
                              border: sel
                                  ? Border.all(color: Colors.orange, width: 2)
                                  : null,
                            ),
                            child: Text(
                              pieceLabel(type),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: dummy.isPromoted
                                    ? (widget.gameSettings.theme ==
                                              PieceTheme.dark
                                          ? Colors.amber
                                          : Colors.red.shade700)
                                    : (widget.gameSettings.theme ==
                                              PieceTheme.dark
                                          ? Colors.white
                                          : Colors.black87),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            // ── 盤面 ──
            Expanded(child: Center(child: _buildBoard())),
            // ── 持ち駒エディタ ──
            _buildHandEditor(true),
            _buildHandEditor(false),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard() {
    return AspectRatio(
      aspectRatio: 10 / 11,
      child: LayoutBuilder(
        builder: (_, cs) {
          final boardSize = cs.maxWidth * 0.9;
          final labelSize = cs.maxWidth * 0.05;
          final cellSize = boardSize / 9;
          return Column(
            children: [
              Row(
                children: [
                  SizedBox(width: labelSize),
                  ...List.generate(
                    9,
                    (i) => SizedBox(
                      width: cellSize,
                      child: Text(
                        '${9 - i}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: labelSize * 0.7,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: List.generate(
                      9,
                      (i) => SizedBox(
                        width: labelSize,
                        height: cellSize,
                        child: Center(
                          child: Text(
                            _rowKanji2[i],
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: labelSize * 0.7,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: boardSize,
                    height: boardSize,
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.brown.shade800,
                        width: 2,
                      ),
                      color: _cellColor,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        9,
                        (row) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(9, (col) {
                            final piece = board[row][col];
                            return GestureDetector(
                              onTap: () => _onCell(row, col),
                              child: Container(
                                width: cellSize,
                                height: cellSize,
                                decoration: BoxDecoration(
                                  color: _cellColor,
                                  border: Border.all(
                                    color: _cellBorder,
                                    width: 0.5,
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
                                              fontSize: cellSize * .62,
                                              fontWeight: FontWeight.bold,
                                              color: _pieceColor(piece),
                                              height: 1.0,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHandEditor(bool isP1) {
    final hand = isP1 ? p1Hand : p2Hand;
    final label = isP1 ? '▲先手持駒' : '△後手持駒';
    return Container(
      color: isP1 ? const Color(0xFF1F4068) : const Color(0xFF0F2A40),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _handTypes.map((type) {
                  final count = hand[type] ?? 0;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          pieceLabel(type),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 2),
                        _adjBtn(
                          '-',
                          Colors.red.shade900,
                          () => _adjustHand(type, isP1, -1),
                        ),
                        SizedBox(
                          width: 22,
                          child: Text(
                            '$count',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        _adjBtn(
                          '+',
                          Colors.green.shade900,
                          () => _adjustHand(type, isP1, 1),
                        ),
                      ],
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

  Widget _adjBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
