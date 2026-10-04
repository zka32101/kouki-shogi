// lib/rules_screen.dart — 将棋ルール解説（インタラクティブ駒動き確認）

import 'package:flutter/material.dart';
import 'piece.dart';
import 'logic.dart';
import 'mini_board_widget.dart';
import 'theme/app_theme.dart';

// Piece selector entry
class _PieceEntry {
  final PieceType type;
  final String label;
  final String name;
  final String description;
  final bool hasPromotion;
  final PieceType? promotedType;
  final String? promotedDescription;
  // Board row/col for the demo piece
  final int row;
  final int col;

  const _PieceEntry({
    required this.type,
    required this.label,
    required this.name,
    required this.description,
    this.hasPromotion = false,
    this.promotedType,
    this.promotedDescription,
    this.row = 4,
    this.col = 4,
  });
}

const _pieces = [
  _PieceEntry(
    type: PieceType.king,
    label: '王',
    name: '王将（おうしょう）',
    description: '周囲8マスに1マス動ける',
  ),
  _PieceEntry(
    type: PieceType.rook,
    label: '飛',
    name: '飛車（ひしゃ）',
    description: '上下左右に何マスでも動ける',
    hasPromotion: true,
    promotedType: PieceType.promotedRook,
    promotedDescription: '飛車の動き＋斜め隣1マス',
  ),
  _PieceEntry(
    type: PieceType.bishop,
    label: '角',
    name: '角行（かくぎょう）',
    description: '斜め方向に何マスでも動ける',
    hasPromotion: true,
    promotedType: PieceType.promotedBishop,
    promotedDescription: '角行の動き＋縦横隣1マス',
  ),
  _PieceEntry(
    type: PieceType.gold,
    label: '金',
    name: '金将（きんしょう）',
    description: '前後左右と斜め前に1マス動ける',
  ),
  _PieceEntry(
    type: PieceType.silver,
    label: '銀',
    name: '銀将（ぎんしょう）',
    description: '前と斜め4方向に1マス動ける',
    hasPromotion: true,
    promotedType: PieceType.promotedSilver,
    promotedDescription: '金将と同じ動き',
  ),
  _PieceEntry(
    type: PieceType.knight,
    label: '桂',
    name: '桂馬（けいま）',
    description: '前2マス横1マスのL字（飛び越え可）',
    hasPromotion: true,
    promotedType: PieceType.promotedKnight,
    promotedDescription: '金将と同じ動き',
    row: 6,
    col: 4,
  ),
  _PieceEntry(
    type: PieceType.lance,
    label: '香',
    name: '香車（きょうしゃ）',
    description: '前方に何マスでも動ける',
    hasPromotion: true,
    promotedType: PieceType.promotedLance,
    promotedDescription: '金将と同じ動き',
    row: 5,
    col: 4,
  ),
  _PieceEntry(
    type: PieceType.pawn,
    label: '歩',
    name: '歩兵（ふひょう）',
    description: '前に1マスだけ動ける',
    hasPromotion: true,
    promotedType: PieceType.promotedPawn,
    promotedDescription: '金将と同じ動き',
  ),
];

class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  int _selectedIndex = 0;
  bool _promoted = false;

  _PieceEntry get _entry => _pieces[_selectedIndex];

  (List<List<Piece?>>, Set<(int, int)>) _buildBoardAndDots() {
    final entry = _entry;
    final usePromoted = _promoted && entry.hasPromotion;
    final pieceType = usePromoted ? (entry.promotedType ?? entry.type) : entry.type;
    final piece = Piece(pieceType, true);

    // Empty board with the piece at its demo position
    final board = List.generate(9, (_) => List<Piece?>.filled(9, null, growable: true));
    board[entry.row][entry.col] = piece;

    // Compute moves using GL.pseudo
    final dots = GL.pseudo(board, entry.row, entry.col).toSet();

    return (board, dots);
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    final usePromoted = _promoted && entry.hasPromotion;
    final (board, dots) = _buildBoardAndDots();

    final pieceName = usePromoted
        ? '成${entry.label}（${_promotedReadingName(entry)}）'
        : entry.name;
    final description = usePromoted
        ? (entry.promotedDescription ?? entry.description)
        : entry.description;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('駒の動き'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: '戻る',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Piece selector grid
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(_pieces.length, (i) {
                final p = _pieces[i];
                final isSelected = i == _selectedIndex;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIndex = i;
                      _promoted = false;
                    });
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.amber.shade700
                          : AppTheme.bg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? Colors.amber.shade300
                            : Colors.white24,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        p.label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Board area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // Piece name & toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          pieceName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (entry.hasPromotion)
                        GestureDetector(
                          onTap: () => setState(() => _promoted = !_promoted),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _promoted
                                  ? Colors.red.shade700
                                  : AppTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _promoted
                                    ? Colors.red.shade300
                                    : Colors.white30,
                              ),
                            ),
                            child: Text(
                              _promoted ? '成り駒' : '成る',
                              style: TextStyle(
                                color: _promoted
                                    ? Colors.white
                                    : Colors.white60,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Board
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final boardSize = constraints.maxWidth.clamp(0.0, 300.0);
                      return Center(
                        child: MiniBoardWidget(
                          board: board,
                          moveDots: dots,
                          highlightSquares: {(entry.row, entry.col)},
                          size: boardSize,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  // Move description
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.green.shade500,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '移動できるマス',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '移動可能数: ${dots.length}マス',
                          style: TextStyle(
                            color: Colors.amber.shade300,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // All pieces reference list
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '全駒の動き一覧',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._pieces.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.brown.shade700,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: Text(
                                    p.label,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      p.description,
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _promotedReadingName(_PieceEntry entry) {
    switch (entry.type) {
      case PieceType.rook:
        return '龍王';
      case PieceType.bishop:
        return '龍馬';
      case PieceType.silver:
        return '成銀';
      case PieceType.knight:
        return '成桂';
      case PieceType.lance:
        return '成香';
      case PieceType.pawn:
        return 'と金';
      default:
        return '成り';
    }
  }
}
