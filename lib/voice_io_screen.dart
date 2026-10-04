// lib/voice_io_screen.dart — 音声入力・読み上げ画面
// Voice-driven shogi learning: speak moves, hear explanations

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'piece.dart';
import 'logic.dart';
import 'speech_service.dart';
import 'mini_board_widget.dart';
import 'theme/app_theme.dart';

// ===== VoiceIOScreen =====
class VoiceIOScreen extends StatefulWidget {
  /// 初期盤面（デモ用）
  final List<List<Piece?>>? initialBoard;
  final Map<PieceType, int>? initialP1Hand;
  final Map<PieceType, int>? initialP2Hand;

  const VoiceIOScreen({
    super.key,
    this.initialBoard,
    this.initialP1Hand,
    this.initialP2Hand,
  });

  @override
  State<VoiceIOScreen> createState() => _VoiceIOScreenState();
}

class _VoiceIOScreenState extends State<VoiceIOScreen>
    with TickerProviderStateMixin {
  // ── 盤面管理 ──
  late List<List<Piece?>> _board;
  late Map<PieceType, int> _p1Hand;
  late Map<PieceType, int> _p2Hand;
  bool _isPlayer1 = true;

  // ── 音声入力状態 ──
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _transcribedText = '';
  String _lastMoveText = '';
  String _errorMessage = '';
  int _recordingSeconds = 0;

  // ── TTS 再生状態 ──
  bool _isPlaying = false;
  String _playingText = '';

  // ── アニメーション ──
  late AnimationController _waveformController;
  late AnimationController _pulseController;

  // ── 認識履歴 ──
  final List<String> _recognitionHistory = [];

  @override
  void initState() {
    super.initState();
    _initializeBoard();
    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _errorMessage = 'マイクを認識できませんでした。もう一度お願いします';
        });
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
    if (!mounted) return;
    setState(() {
      _speechAvailable = available;
      if (!available) {
        _errorMessage = '音声認識が利用できません（マイクの権限を確認してください）';
      }
    });
  }

  @override
  void dispose() {
    _waveformController.dispose();
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _initializeBoard() {
    if (widget.initialBoard != null) {
      _board = List.generate(9, (r) => List<Piece?>.from(widget.initialBoard![r]));
      _p1Hand = Map.from(widget.initialP1Hand ?? {});
      _p2Hand = Map.from(widget.initialP2Hand ?? {});
    } else {
      // 初期棋面（平手）
      // 盤面座標の慣例: row 0-2 = 後手(isPlayer1=false)、row 6-8 = 先手(isPlayer1=true)
      // （natural_lang_qa_screen.dart 等、他画面と統一）
      _board = List.generate(9, (_) => List.filled(9, null));
      // 後手の駒を配置
      _board[0] = [
        Piece(PieceType.lance, false),
        Piece(PieceType.knight, false),
        Piece(PieceType.silver, false),
        Piece(PieceType.gold, false),
        Piece(PieceType.king, false),
        Piece(PieceType.gold, false),
        Piece(PieceType.silver, false),
        Piece(PieceType.knight, false),
        Piece(PieceType.lance, false),
      ];
      _board[1] = [
        null,
        Piece(PieceType.rook, false),
        null,
        null,
        null,
        null,
        null,
        Piece(PieceType.bishop, false),
        null,
      ];
      for (int c = 0; c < 9; c++) {
        _board[2][c] = Piece(PieceType.pawn, false);
      }

      // 先手の駒を配置
      _board[6] = List.filled(9, Piece(PieceType.pawn, true));
      _board[7] = [
        null,
        Piece(PieceType.bishop, true),
        null,
        null,
        null,
        null,
        null,
        Piece(PieceType.rook, true),
        null,
      ];
      _board[8] = [
        Piece(PieceType.lance, true),
        Piece(PieceType.knight, true),
        Piece(PieceType.silver, true),
        Piece(PieceType.gold, true),
        Piece(PieceType.king, true),
        Piece(PieceType.gold, true),
        Piece(PieceType.silver, true),
        Piece(PieceType.knight, true),
        Piece(PieceType.lance, true),
      ];

      _p1Hand = {};
      _p2Hand = {};
    }
  }

  // ───────────────────────────────────────────
  // 音声入力（speech_to_text による実音声認識）
  // ───────────────────────────────────────────
  Future<void> _startListening() async {
    if (!_speechAvailable) {
      setState(() => _errorMessage = '音声認識が利用できません（マイクの権限を確認してください）');
      // 権限が拒否された直後などは再初期化を試みる
      await _initSpeech();
      if (!_speechAvailable) return;
    }

    setState(() {
      _isListening = true;
      _transcribedText = '';
      _errorMessage = '';
      _recordingSeconds = 0;
    });

    await _speech.listen(
      // ignore: deprecated_member_use
      localeId: 'ja_JP',
      // ignore: deprecated_member_use
      listenFor: const Duration(seconds: 10),
      // ignore: deprecated_member_use
      pauseFor: const Duration(seconds: 3),
      onResult: (SpeechRecognitionResult result) {
        if (!mounted) return;
        setState(() {
          _recordingSeconds = (result.recognizedWords.length / 2).ceil();
          _transcribedText = result.recognizedWords;
        });
        if (result.finalResult) {
          final recognized = result.recognizedWords.trim();
          setState(() => _isListening = false);
          if (recognized.isEmpty) {
            setState(() => _errorMessage = 'もう一度お願いします');
          } else {
            _processVoiceMove(recognized);
          }
        }
      },
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
      _recordingSeconds = 0;
    });

    if (_transcribedText.isEmpty && _errorMessage.isEmpty) {
      setState(() => _errorMessage = 'もう一度お願いします');
    }
  }

  // 音声認識結果は「七六歩」のような漢数字や「76歩」のような算用数字、
  // どちらでも返ってくる可能性があるため、漢数字を算用数字へ正規化してから解析する。
  static const _kanjiDigits = {
    '一': '1', '二': '2', '三': '3', '四': '4', '五': '5',
    '六': '6', '七': '7', '八': '8', '九': '9',
  };

  String _normalizeDigits(String text) {
    var out = text;
    _kanjiDigits.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }

  void _processVoiceMove(String rawMoveText) {
    // 簡易パーサー: "7六歩" の形式を解析
    // 実装時は詳細な棋譜解析ライブラリを使用
    final moveText = _normalizeDigits(rawMoveText);

    final pattern = RegExp(r'(\d)\D*(\d)(.+)');
    final match = pattern.firstMatch(moveText);

    if (match == null) {
      setState(() {
        _errorMessage = 'もう一度お願いします';
        _transcribedText = '';
      });
      return;
    }

    final toCol = int.tryParse(match.group(1) ?? '') ?? -1;
    final toRow = int.tryParse(match.group(2) ?? '') ?? -1;
    final pieceName = match.group(3) ?? '';

    if (toCol < 1 || toCol > 9 || toRow < 1 || toRow > 9) {
      setState(() {
        _errorMessage = 'もう一度お願いします';
        _transcribedText = '';
      });
      return;
    }

    // 1-indexed から 0-indexed に変換
    final targetCol = 9 - toCol;
    final targetRow = toRow - 1;

    // 盤面に移動を試行（簡易版）
    try {
      _applyMove(targetRow, targetCol, pieceName);
      setState(() {
        _errorMessage = '';
        _lastMoveText = moveText;
        _recognitionHistory.add(moveText);
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'もう一度お願いします';
        _transcribedText = '';
      });
    }
  }

  void _applyMove(int targetRow, int targetCol, String pieceName) {
    // 簡易版：ターゲット位置に駒を移動（実際は合法性チェックが必要）
    // ここでは、移動可能な駒を自動で見つけて移動

    // 駒種を判定（簡易版）
    PieceType? pieceType;
    if (pieceName.contains('歩')) pieceType = PieceType.pawn;
    else if (pieceName.contains('香')) pieceType = PieceType.lance;
    else if (pieceName.contains('桂')) pieceType = PieceType.knight;
    else if (pieceName.contains('銀')) pieceType = PieceType.silver;
    else if (pieceName.contains('金')) pieceType = PieceType.gold;
    else if (pieceName.contains('角')) pieceType = PieceType.bishop;
    else if (pieceName.contains('飛')) pieceType = PieceType.rook;

    if (pieceType == null) throw Exception('Unknown piece: $pieceName');

    // 移動可能な駒を見つけて移動（簡易版）
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final piece = _board[r][c];
        if (piece == null || piece.type != pieceType) continue;
        if (piece.isPlayer1 != _isPlayer1) continue;

        // ターゲット位置に移動できるか確認
        final moves = GL.legal(_board, r, c);
        if (moves.any((m) => m.$1 == targetRow && m.$2 == targetCol)) {
          // 移動を実行
          _board[targetRow][targetCol] = piece;
          _board[r][c] = null;

          // ターンを切り替え
          setState(() {
            _isPlayer1 = !_isPlayer1;
          });
          return;
        }
      }
    }

    throw Exception('No valid move found');
  }

  // ───────────────────────────────────────────
  // TTS 再生
  // ───────────────────────────────────────────
  Future<void> _playExplanation() async {
    if (_lastMoveText.isEmpty) {
      setState(() => _errorMessage = '先に指し手を入力してください');
      return;
    }

    // 説明テキスト（簡易版）
    final explanation =
        '${_lastMoveText}ですね。良い手ですね。次は後手の番です。';

    setState(() {
      _isPlaying = true;
      _playingText = explanation;
    });

    // TTS を使用（SpeechService.speak）
    SpeechService.speak(explanation);

    // シミュレート: 2秒の再生時間
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isPlaying = false;
        _playingText = '';
      });
    }
  }

  // ───────────────────────────────────────────
  // UI ビルド
  // ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text(
          '音声入力・読み上げ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 盤面表示 ──
              _buildBoardSection(),
              const SizedBox(height: 20),

              // ── 音声入力セクション ──
              _buildVoiceInputSection(),
              const SizedBox(height: 20),

              // ── TTS 再生セクション ──
              _buildTTSSection(),
              const SizedBox(height: 20),

              // ── 認識履歴 ──
              _buildHistorySection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── 盤面表示ウィジェット ──
  Widget _buildBoardSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '盤面',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                _isPlayer1 ? '▲先手のターン' : '△後手のターン',
                style: TextStyle(
                  color: _isPlayer1 ? Colors.lightBlueAccent : Colors.orangeAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ボード表示
          Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: MiniBoardWidget(
                board: _board,
                highlightSquares: {},
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 音声入力セクション ──
  Widget _buildVoiceInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '音声入力',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // ── マイクボタン（赤丸） ──
          Center(
            child: GestureDetector(
              onTap: _isListening ? _stopListening : _startListening,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // パルスアニメーション（リスニング中のみ）
                  if (_isListening)
                    ScaleTransition(
                      scale: Tween(begin: 1.0, end: 1.3)
                          .animate(_pulseController),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withAlpha(80),
                        ),
                      ),
                    ),

                  // メインボタン
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening ? Colors.red : Colors.red.shade700,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withAlpha(150),
                          blurRadius: _isListening ? 20 : 10,
                          spreadRadius: _isListening ? 5 : 0,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        _isListening ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── 波形アニメーション ──
          if (_isListening) _buildWaveformAnimation(),
          const SizedBox(height: 16),

          // ── 録音時間 ──
          if (_isListening)
            Center(
              child: Text(
                '${_recordingSeconds}秒',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ),
          if (!_isListening && _transcribedText.isNotEmpty)
            const SizedBox(height: 12),

          // ── 認識結果テキスト ──
          if (_transcribedText.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F3460),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.greenAccent.withAlpha(100)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '認識結果',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _transcribedText,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // ── エラーメッセージ ──
          if (_errorMessage.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3E1616),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withAlpha(100)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'エラー',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _errorMessage,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── 波形アニメーション ──
  Widget _buildWaveformAnimation() {
    return Center(
      child: AnimatedBuilder(
        animation: _waveformController,
        builder: (context, child) {
          final waves = List.generate(5, (i) {
            final amplitude = 30 * (0.5 + 0.5 * sin(_waveformController.value * 2 * pi + i));
            return Container(
              width: 4,
              height: 40 + amplitude,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: Colors.lightBlueAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          });

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: waves,
          );
        },
      ),
    );
  }

  // ── TTS セクション ──
  Widget _buildTTSSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '説明の読み上げ',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // ── 再生ボタン ──
          Center(
            child: ElevatedButton.icon(
              icon: Icon(
                _isPlaying ? Icons.stop_circle : Icons.play_circle,
                size: 24,
              ),
              label: Text(_isPlaying ? '再生中...' : '再生'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isPlaying ? null : _playExplanation,
            ),
          ),
          const SizedBox(height: 12),

          // ── 再生テキスト ──
          if (_isPlaying)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F3460),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withAlpha(100)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.volume_up,
                        color: Colors.amber,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '再生中...',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _playingText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          // ── 最後の指し手 ──
          if (_lastMoveText.isNotEmpty && !_isPlaying)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F3460),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '最後の指し手',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _lastMoveText,
                    style: const TextStyle(
                      color: Colors.lightBlueAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── 認識履歴セクション ──
  Widget _buildHistorySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '認識履歴',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          if (_recognitionHistory.isEmpty)
            Text(
              '(まだ指し手がありません)',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 13,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recognitionHistory.asMap().entries.map((entry) {
                final idx = entry.key;
                final move = entry.value;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F3460),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    '${idx + 1}. $move',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
