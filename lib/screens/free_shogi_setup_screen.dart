// 自由将棋のセットアップ画面（駒配置エディタ）
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/free_shogi_config.dart';
import '../piece.dart';
import '../mini_board_widget.dart';
import '../services/free_shogi_service.dart';
import '../theme/app_theme.dart';

class FreeShogiFiSetupScreen extends StatefulWidget {
  final FreeShogiFiemplateEntry? initialTemplate;

  const FreeShogiFiSetupScreen({
    super.key,
    this.initialTemplate,
  });

  @override
  State<FreeShogiFiSetupScreen> createState() => _FreeShogiFiSetupScreenState();
}

class _FreeShogiFiSetupScreenState extends State<FreeShogiFiSetupScreen> {
  late List<List<Piece?>> p1Board;
  late List<List<Piece?>> p2Board;
  late int p1RemainingBudget;
  late int p2RemainingBudget;

  bool isP1Side = true; // 先手側を編集中か
  int? selectedPiece; // 選択中の駒タイプ（PieceType.index）
  String templateName = 'テンプレート';

  @override
  void initState() {
    super.initState();
    _initBoard();
  }

  void _initBoard() {
    final template = widget.initialTemplate;
    if (template != null) {
      p1Board = template.p1Board.map((row) => [...row]).toList();
      p2Board = template.p2Board.map((row) => [...row]).toList();
      p1RemainingBudget = template.p1Budget - FreeShogiFiece.calculateTotal(
        _countPieces(p1Board),
      );
      p2RemainingBudget = template.p2Budget - FreeShogiFiece.calculateTotal(
        _countPieces(p2Board),
      );
      templateName = template.name;
    } else {
      p1Board = List.generate(9, (_) => List<Piece?>.filled(9, null));
      p2Board = List.generate(9, (_) => List<Piece?>.filled(9, null));
      p1RemainingBudget = FreeShogiFiece.defaultBudget;
      p2RemainingBudget = FreeShogiFiece.defaultBudget;
    }
  }

  Map<PieceType, int> _countPieces(List<List<Piece?>> board) {
    final counts = <PieceType, int>{};
    for (final row in board) {
      for (final piece in row) {
        if (piece != null) {
          counts[piece.type] = (counts[piece.type] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  void _placePiece(int row, int col) {
    if (selectedPiece == null) return;
    final pieceType = PieceType.values[selectedPiece!];
    final cost = FreeShogiFiece.points[pieceType] ?? 0;
    final board = isP1Side ? p1Board : p2Board;
    final remaining = isP1Side ? p1RemainingBudget : p2RemainingBudget;

    // 既に駒がある場合は返金
    if (board[row][col] != null) {
      final refund = FreeShogiFiece.points[board[row][col]!.type] ?? 0;
      if (isP1Side) {
        p1RemainingBudget += refund;
      } else {
        p2RemainingBudget += refund;
      }
    }

    // 予算チェック
    if (cost <= remaining) {
      setState(() {
        board[row][col] = Piece(pieceType, isP1Side);
        if (isP1Side) {
          p1RemainingBudget -= cost;
        } else {
          p2RemainingBudget -= cost;
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ポイント不足です')),
      );
    }
  }

  void _clearPiece(int row, int col) {
    final board = isP1Side ? p1Board : p2Board;
    if (board[row][col] != null) {
      final refund = FreeShogiFiece.points[board[row][col]!.type] ?? 0;
      setState(() {
        board[row][col] = null;
        if (isP1Side) {
          p1RemainingBudget += refund;
        } else {
          p2RemainingBudget += refund;
        }
      });
    }
  }

  void _resetBoard() {
    setState(() {
      final board = isP1Side ? p1Board : p2Board;
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          board[r][c] = null;
        }
      }
      if (isP1Side) {
        p1RemainingBudget = FreeShogiFiece.defaultBudget;
      } else {
        p2RemainingBudget = FreeShogiFiece.defaultBudget;
      }
    });
  }

  Future<void> _saveTemplate() async {
    if (templateName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('テンプレート名を入力してください')),
      );
      return;
    }

    final entry = FreeShogiFiemplateEntry(
      id: widget.initialTemplate?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: templateName,
      description: widget.initialTemplate?.description ?? '',
      p1Board: p1Board,
      p2Board: p2Board,
      p1Budget: widget.initialTemplate?.p1Budget ?? FreeShogiFiece.defaultBudget,
      p2Budget: widget.initialTemplate?.p2Budget ?? FreeShogiFiece.defaultBudget,
    );

    try {
      await FreeShogiFiemplateService().saveLocalTemplate(entry);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('テンプレートを保存しました')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentBudget = isP1Side ? p1RemainingBudget : p2RemainingBudget;
    final currentBoard = isP1Side ? p1Board : p2Board;
    final sideLabel = isP1Side ? '先手' : '後手';

    return Scaffold(
      appBar: AppBar(
        title: const Text('自由将棋 - 駒配置'),
        backgroundColor: AppTheme.surface,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // テンプレート名入力
              TextField(
                onChanged: (val) => setState(() => templateName = val),
                decoration: InputDecoration(
                  labelText: 'テンプレート名',
                  hintText: templateName,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 先手/後手切り替え
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => setState(() => isP1Side = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isP1Side ? Colors.blue : Colors.grey,
                    ),
                    child: const Text('先手配置'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => setState(() => isP1Side = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !isP1Side ? Colors.red : Colors.grey,
                    ),
                    child: const Text('後手配置'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 予算表示
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$sideLabel側 - 残りポイント: $currentBudget'),
                    Text(
                      '使用: ${FreeShogiFiece.defaultBudget - currentBudget}/${FreeShogiFiece.defaultBudget}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 盤面（駒配置エディタ）
              Container(
                color: const Color(0xFFE8C87A),
                padding: const EdgeInsets.all(1),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 9,
                    childAspectRatio: 1,
                  ),
                  itemCount: 81,
                  itemBuilder: (context, idx) {
                    final row = idx ~/ 9;
                    final col = idx % 9;
                    final piece = currentBoard[row][col];
                    return GestureDetector(
                      onTap: () => _placePiece(row, col),
                      onLongPress: () => _clearPiece(row, col),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey, width: 0.5),
                        ),
                        child: Center(
                          child: piece != null
                              ? Text(
                                  _getPieceLabel(piece.type),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: piece.isPlayer1 ? Colors.black : Colors.red,
                                  ),
                                )
                              : const SizedBox(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // 駒選択パネル
              Text('$sideLabel側 の駒を選択してクリック', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _buildPieceButtons(),
              ),
              const SizedBox(height: 16),

              // ボタン群
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _resetBoard,
                    icon: const Icon(Icons.refresh),
                    label: const Text('リセット'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _saveTemplate,
                    icon: const Icon(Icons.save),
                    label: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPieceButtons() {
    final pieces = [
      PieceType.pawn,
      PieceType.lance,
      PieceType.knight,
      PieceType.silver,
      PieceType.gold,
      PieceType.bishop,
      PieceType.rook,
    ];

    return pieces.map((type) {
      final cost = FreeShogiFiece.points[type] ?? 0;
      final isSelected = selectedPiece == type.index;
      return GestureDetector(
        onTap: () => setState(() => selectedPiece = type.index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.grey.shade200,
            border: Border.all(
              color: isSelected ? Colors.blue.shade700 : Colors.grey,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_getPieceLabel(type), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('$cost', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      );
    }).toList();
  }

  String _getPieceLabel(PieceType type) {
    const labels = {
      'Pawn': '歩',
      'Lance': '香',
      'Knight': '桂',
      'Silver': '銀',
      'Gold': '金',
      'Bishop': '角',
      'Rook': '飛',
      'King': '玉',
      'PromPawn': 'と',
      'PromLance': '成香',
      'PromKnight': '成桂',
      'PromSilver': '成銀',
      'PromBishop': '馬',
      'PromRook': '龍',
    };
    return labels[type.toString().split('.').last] ?? '？';
  }
}
