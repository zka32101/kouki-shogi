// lib/camera_ocr_screen.dart — カメラOCR盤読取機能
// Premium feature: Photograph a physical shogi board → app reads piece positions

import 'package:flutter/material.dart';
import 'dart:convert' as convert;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'piece.dart';
import 'mini_board_widget.dart';

// ────────────────────────────────────────────────────
// Model: DetectedPiece
// ────────────────────────────────────────────────────
class DetectedPiece {
  final int row;
  final int col;
  final PieceType type;
  final bool isPlayer1; // true: black (先手), false: white (後手)
  final double confidence; // 0.0 - 1.0
  final Rect boundingBox; // For visualization

  DetectedPiece({
    required this.row,
    required this.col,
    required this.type,
    required this.isPlayer1,
    required this.confidence,
    required this.boundingBox,
  });

  Map<String, dynamic> toJson() => {
        'row': row,
        'col': col,
        'type': type.toString().split('.').last,
        'isPlayer1': isPlayer1,
        'confidence': confidence,
      };

  factory DetectedPiece.fromJson(Map<String, dynamic> json) => DetectedPiece(
        row: json['row'] ?? 0,
        col: json['col'] ?? 0,
        type: _parsePieceType(json['type'] ?? 'pawn'),
        isPlayer1: json['isPlayer1'] ?? true,
        confidence: json['confidence'] ?? 0.8,
        boundingBox: Rect.zero,
      );
}

PieceType _parsePieceType(String typeStr) {
  switch (typeStr) {
    case 'king':
      return PieceType.king;
    case 'rook':
      return PieceType.rook;
    case 'bishop':
      return PieceType.bishop;
    case 'gold':
      return PieceType.gold;
    case 'silver':
      return PieceType.silver;
    case 'knight':
      return PieceType.knight;
    case 'lance':
      return PieceType.lance;
    case 'pawn':
      return PieceType.pawn;
    case 'promotedRook':
      return PieceType.promotedRook;
    case 'promotedBishop':
      return PieceType.promotedBishop;
    case 'promotedSilver':
      return PieceType.promotedSilver;
    case 'promotedKnight':
      return PieceType.promotedKnight;
    case 'promotedLance':
      return PieceType.promotedLance;
    case 'promotedPawn':
      return PieceType.promotedPawn;
    default:
      return PieceType.pawn;
  }
}

// ────────────────────────────────────────────────────
// Model: OCRBoardCapture
// ────────────────────────────────────────────────────
class OCRBoardCapture {
  final String id;
  final DateTime timestamp;
  final List<DetectedPiece> detectedPieces;
  final double overallConfidence;
  final String? imagePathOrBase64; // Mock: stored base64 or path
  final List<List<Piece?>> boardState; // Reconstructed board

  OCRBoardCapture({
    required this.id,
    required this.timestamp,
    required this.detectedPieces,
    required this.overallConfidence,
    this.imagePathOrBase64,
    required this.boardState,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'detectedPieces': detectedPieces.map((p) => p.toJson()).toList(),
        'overallConfidence': overallConfidence,
        'boardState': _serializeBoard(boardState),
      };

  factory OCRBoardCapture.fromJson(Map<String, dynamic> json) => OCRBoardCapture(
        id: json['id'] ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : DateTime.now(),
        detectedPieces: (json['detectedPieces'] as List?)
                ?.map((p) => DetectedPiece.fromJson(p))
                .toList() ??
            [],
        overallConfidence: json['overallConfidence'] ?? 0.0,
        boardState: _deserializeBoard(json['boardState']),
      );
}

// ────────────────────────────────────────────────────
// Model: Piece (simple representation)
// ────────────────────────────────────────────────────
class Piece {
  final PieceType type;
  final bool isPlayer1;

  Piece(this.type, this.isPlayer1);

  Map<String, dynamic> toJson() => {
        'type': type.toString().split('.').last,
        'isPlayer1': isPlayer1,
      };

  factory Piece.fromJson(Map<String, dynamic> json) => Piece(
        _parsePieceType(json['type'] ?? 'pawn'),
        json['isPlayer1'] ?? true,
      );
}

List<List<dynamic>> _serializeBoard(List<List<Piece?>> board) {
  return board.map((row) => row.map((p) => p?.toJson()).toList()).toList();
}

List<List<Piece?>> _deserializeBoard(dynamic boardJson) {
  if (boardJson == null) return List.generate(9, (_) => List.filled(9, null));
  return (boardJson as List)
      .map((row) => (row as List)
          .map((p) => p != null ? Piece.fromJson(p) : null)
          .toList()
          .cast<Piece?>())
      .toList()
      .cast<List<Piece?>>();
}

// ────────────────────────────────────────────────────
// Screen: CameraOCRScreen (StatefulWidget)
// ────────────────────────────────────────────────────
class CameraOCRScreen extends StatefulWidget {
  final bool isPremiumUser;

  const CameraOCRScreen({
    Key? key,
    this.isPremiumUser = false,
  }) : super(key: key);

  @override
  State<CameraOCRScreen> createState() => _CameraOCRScreenState();
}

class _CameraOCRScreenState extends State<CameraOCRScreen> {
  String? _selectedImagePath;
  List<DetectedPiece>? _detectedPieces;
  double _overallConfidence = 0.0;
  bool _isProcessing = false;
  bool _isEditingBoard = false;
  OCRBoardCapture? _currentCapture;
  List<List<Piece?>>? _editingBoard;

  @override
  void initState() {
    super.initState();
    _loadOCRHistory();
  }

  Future<void> _loadOCRHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('ocr_history_json') ?? [];
    // Optionally load history for display
  }

  Future<void> _saveOCRCapture(OCRBoardCapture capture) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('ocr_history_json') ?? [];
    historyJson.add(convert.jsonEncode(capture.toJson()));
    await prefs.setStringList('ocr_history_json', historyJson);
  }

  // Mock: Simulate camera/photo library pickup
  Future<void> _pickImageFromCamera() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 500));
    // Mock: In real app, use image_picker plugin
    _performOCRAnalysis();
  }

  Future<void> _pickImageFromLibrary() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 500));
    // Mock: In real app, use image_picker plugin
    _performOCRAnalysis();
  }

  // Mock OCR: Simulate piece detection
  void _performOCRAnalysis() {
    // Simulated detection: 13 random pieces detected
    final random = DateTime.now().millisecondsSinceEpoch % 2 == 0;
    final mockPieces = _generateMockDetection();

    setState(() {
      _detectedPieces = mockPieces;
      _overallConfidence = 0.94; // Mock confidence: 94%
      _isProcessing = false;

      // Reconstruct board from detected pieces
      final board = List.generate(9, (_) => List<Piece?>.filled(9, null));
      for (final piece in mockPieces) {
        board[piece.row][piece.col] =
            Piece(piece.type, piece.isPlayer1);
      }
      _editingBoard = board;
      _currentCapture = OCRBoardCapture(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        detectedPieces: mockPieces,
        overallConfidence: _overallConfidence,
        boardState: board,
      );
    });
  }

  List<DetectedPiece> _generateMockDetection() {
    // Mock: Detect 13 pieces with bounding boxes
    final allPieceTypes = [
      PieceType.king,
      PieceType.rook,
      PieceType.bishop,
      PieceType.gold,
      PieceType.silver,
      PieceType.knight,
      PieceType.lance,
      PieceType.pawn,
      PieceType.promotedRook,
      PieceType.promotedBishop,
      PieceType.promotedSilver,
      PieceType.promotedKnight,
      PieceType.promotedPawn,
    ];

    // Generate 13 pieces at random positions
    final detected = <DetectedPiece>[];
    final usedPositions = <String>{};

    for (int i = 0; i < 13 && i < allPieceTypes.length; i++) {
      int row, col;
      do {
        row = i ~/ 5; // 0-2
        col = i % 9; // 0-8
      } while (usedPositions.contains('$row,$col'));
      usedPositions.add('$row,$col');

      final isPlayer1 = i % 2 == 0;
      detected.add(DetectedPiece(
        row: row,
        col: col,
        type: allPieceTypes[i],
        isPlayer1: isPlayer1,
        confidence: 0.85 + (i * 0.01), // 0.85-0.98
        boundingBox: Rect.fromLTWH(col * 40.0, row * 40.0, 35, 35),
      ));
    }

    return detected;
  }

  void _toggleEditMode() {
    setState(() {
      _isEditingBoard = !_isEditingBoard;
    });
  }

  void _handleBoardSquareTap(int row, int col) {
    if (!_isEditingBoard || _editingBoard == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('駒を選択'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('行: $row, 列: $col'),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PieceButton(
                    label: '削除',
                    onTap: () {
                      _editingBoard![row][col] = null;
                      Navigator.pop(ctx);
                      setState(() {});
                    },
                  ),
                  ...PieceType.values.map((type) {
                    final label = _getPieceLabel(type);
                    return _PieceButton(
                      label: label,
                      isPlayer1: true,
                      onTap: () {
                        _editingBoard![row][col] = Piece(type, true);
                        Navigator.pop(ctx);
                        setState(() {});
                      },
                    );
                  }).toList(),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  String _getPieceLabel(PieceType type) {
    switch (type) {
      case PieceType.king:
        return '王';
      case PieceType.rook:
        return '飛';
      case PieceType.bishop:
        return '角';
      case PieceType.gold:
        return '金';
      case PieceType.silver:
        return '銀';
      case PieceType.knight:
        return '桂';
      case PieceType.lance:
        return '香';
      case PieceType.pawn:
        return '歩';
      case PieceType.promotedRook:
        return '竜';
      case PieceType.promotedBishop:
        return '馬';
      case PieceType.promotedSilver:
        return '全';
      case PieceType.promotedKnight:
        return '圭';
      case PieceType.promotedLance:
        return '成香';
      case PieceType.promotedPawn:
        return 'と';
    }
  }

  void _confirmBoardAndAnalyze() {
    if (_currentCapture == null) return;

    // Save to history
    _saveOCRCapture(_currentCapture!);

    // Show analysis options
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('局面分析を開始'),
        content: const Text('どの分析を行いますか？'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showAnalysisResult('詰み探索', '（OCRサービス実装予定）\n\n検出局面: ${_currentCapture!.detectedPieces.length}駒\n精度: ${(_overallConfidence * 100).toStringAsFixed(1)}%');
            },
            child: const Text('詰み探索'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showAnalysisResult('最善手診断', '（OCRサービス実装予定）\n\n推奨手: ー\n評価値: 不確定');
            },
            child: const Text('最善手診断'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showAnalysisResult('局面評価', '（OCRサービス実装予定）\n\n先手有利度: 判定中\n評価値: +0.0');
            },
            child: const Text('局面評価'),
          ),
        ],
      ),
    );
  }

  void _showAnalysisResult(String title, String result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(result),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPremiumUser) {
      return Scaffold(
        appBar: AppBar(title: const Text('カメラOCR盤読取')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'プレミアム機能',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('この機能はプレミアム会員のみ利用可能です'),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('戻る'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('カメラOCR盤読取'),
        elevation: 0,
        actions: [
          if (_currentCapture != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('キャプチャ情報'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('時刻: ${_currentCapture!.timestamp.toLocal().toString().split('.')[0]}'),
                        const SizedBox(height: 8),
                        Text('検出駒数: ${_currentCapture!.detectedPieces.length}'),
                        const SizedBox(height: 8),
                        Text('全体精度: ${(_overallConfidence * 100).toStringAsFixed(1)}%'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('閉じる'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    // No capture yet: Show input options
    if (_currentCapture == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              '物理盤を撮影して\n駒位置を自動読取',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 32),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _pickImageFromCamera,
                    icon: const Icon(Icons.camera),
                    label: const Text('カメラで撮影'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _pickImageFromLibrary,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('フォトライブラリから選択'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (_isProcessing)
              const Column(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(),
                  ),
                  SizedBox(height: 16),
                  Text('盤面を分析中...'),
                ],
              ),
          ],
        ),
      );
    }

    // Capture detected: Show board + options
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Confidence meter
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '検出精度',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${(_overallConfidence * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _overallConfidence > 0.9
                              ? Colors.green
                              : _overallConfidence > 0.75
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _overallConfidence,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _overallConfidence > 0.9
                            ? Colors.green
                            : _overallConfidence > 0.75
                                ? Colors.orange
                                : Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '検出駒数: ${_detectedPieces?.length ?? 0}駒',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Detected board
          _buildBoardDisplay(),
          const SizedBox(height: 16),

          // Edit button
          if (!_isEditingBoard)
            ElevatedButton.icon(
              onPressed: _toggleEditMode,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('編集する'),
            ),
          if (_isEditingBoard)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _toggleEditMode,
                    icon: const Icon(Icons.check),
                    label: const Text('編集完了'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _isEditingBoard = false);
                      // Reset to detected pieces
                      if (_currentCapture != null) {
                        _editingBoard = _currentCapture!.boardState;
                      }
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('キャンセル'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),

          // Analysis button
          ElevatedButton.icon(
            onPressed: _confirmBoardAndAnalyze,
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('分析を開始'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.blue.shade600,
            ),
          ),
          const SizedBox(height: 12),

          // Start over button
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _currentCapture = null;
                _detectedPieces = null;
                _editingBoard = null;
                _isEditingBoard = false;
                _overallConfidence = 0.0;
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('別の盤面を読取'),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardDisplay() {
    final board = _editingBoard;
    if (board == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditingBoard ? '編集モード' : '検出結果',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_detectedPieces != null && _detectedPieces!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_detectedPieces!.length}駒',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInteractiveBoardGrid(board),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveBoardGrid(List<List<Piece?>> board) {
    return Column(
      children: List.generate(9, (row) {
        return Row(
          children: List.generate(9, (col) {
            final piece = board[row][col];
            final isSelected = _detectedPieces?.any(
                  (p) => p.row == row && p.col == col,
                ) ??
                false;

            return Expanded(
              child: GestureDetector(
                onTap: _isEditingBoard
                    ? () => _handleBoardSquareTap(row, col)
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey.shade400,
                      width: 0.5,
                    ),
                    color: isSelected
                        ? Colors.yellow.shade100
                        : Colors.white,
                  ),
                  child: piece != null
                      ? Center(
                          child: _PieceDisplay(
                            piece: piece,
                            size: 24,
                          ),
                        )
                      : (_isEditingBoard
                          ? const Center(
                              child: Text(
                                '＋',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 18,
                                ),
                              ),
                            )
                          : null),
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}

// ────────────────────────────────────────────────────
// Widget: PieceDisplay
// ────────────────────────────────────────────────────
class _PieceDisplay extends StatelessWidget {
  final Piece piece;
  final double size;

  const _PieceDisplay({
    required this.piece,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final label = _getPieceLabelForDisplay(piece.type);
    final isPlayer1 = piece.isPlayer1;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isPlayer1 ? Colors.black : Colors.white,
        border: Border.all(
          color: Colors.grey.shade600,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isPlayer1 ? Colors.white : Colors.black,
            fontSize: size * 0.6,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _getPieceLabelForDisplay(PieceType type) {
    switch (type) {
      case PieceType.king:
        return '王';
      case PieceType.rook:
        return '飛';
      case PieceType.bishop:
        return '角';
      case PieceType.gold:
        return '金';
      case PieceType.silver:
        return '銀';
      case PieceType.knight:
        return '桂';
      case PieceType.lance:
        return '香';
      case PieceType.pawn:
        return '歩';
      case PieceType.promotedRook:
        return '竜';
      case PieceType.promotedBishop:
        return '馬';
      case PieceType.promotedSilver:
        return '全';
      case PieceType.promotedKnight:
        return '圭';
      case PieceType.promotedLance:
        return '成香';
      case PieceType.promotedPawn:
        return 'と';
    }
  }
}

// ────────────────────────────────────────────────────
// Widget: PieceButton (for edit dialog)
// ────────────────────────────────────────────────────
class _PieceButton extends StatelessWidget {
  final String label;
  final bool isPlayer1;
  final VoidCallback onTap;

  const _PieceButton({
    required this.label,
    this.isPlayer1 = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.blue.shade300,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(6),
          color: Colors.blue.shade50,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.blue.shade700,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
