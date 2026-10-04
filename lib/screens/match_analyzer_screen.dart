// lib/screens/match_analyzer_screen.dart
// ポストマッチ棋譜アナライザー（ネットワーク対局後の手の分析）

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:share_plus/share_plus.dart';
import '../services/board_sync_service.dart';
import '../services/network_service.dart';
import '../services/kifu_export_service.dart';
import '../piece.dart';
import '../logic.dart';
import '../theme/app_theme.dart';

// ── モデル ──────────────────────────────────────────────────────

enum MoveQuality {
  excellent, // 最善手
  good,      // 良い手
  inaccuracy,// 疑問手
  mistake,   // 悪手
  blunder,   // 大悪手
}

class AnalyzedMove {
  final int moveNum;
  final KifuMove move;
  final MoveQuality quality;
  final String comment;
  final int legalMoveCount; // その局面での合法手数（複雑度の指標）

  AnalyzedMove({
    required this.moveNum,
    required this.move,
    required this.quality,
    required this.comment,
    required this.legalMoveCount,
  });
}

// ── サービス ────────────────────────────────────────────────────

class MatchAnalysisResult {
  final String matchId;
  final List<AnalyzedMove> analyzedMoves;
  final String player1Name;
  final String player2Name;
  final int totalMoves;
  final Map<MoveQuality, int> qualityCounts;
  final double averageLegalMoves; // 平均合法手数（局面の複雑度）
  final int longestThinkMoveNum; // 最も考えた手
  final List<int> criticalMoveNumbers; // 形勢が変わった手番号

  MatchAnalysisResult({
    required this.matchId,
    required this.analyzedMoves,
    required this.player1Name,
    required this.player2Name,
    required this.totalMoves,
    required this.qualityCounts,
    required this.averageLegalMoves,
    required this.longestThinkMoveNum,
    required this.criticalMoveNumbers,
  });
}

// ── 簡易盤面分析エンジン ──────────────────────────────────────────

class SimpleAnalyzer {
  /// 棋譜を再生して各局面を分析
  static Future<MatchAnalysisResult> analyze({
    required String matchId,
    required List<KifuMove> moves,
    required String player1Name,
    required String player2Name,
    required Map<String, dynamic> matchData,
  }) async {
    // 初期盤面から棋譜を再生
    List<List<Piece?>> board = GL.initialBoard();
    Map<PieceType, int> p1Hand = {};
    Map<PieceType, int> p2Hand = {};

    final analyzedMoves = <AnalyzedMove>[];
    final qualityCounts = <MoveQuality, int>{
      for (final q in MoveQuality.values) q: 0
    };
    double totalLegalMoves = 0;
    final criticalMoves = <int>[];
    int prevLegalCount = -1;
    int longestThinkMove = 1;
    int longestThinkTime = 0;

    final moveTimes = _extractMoveTimes(matchData);

    for (int i = 0; i < moves.length; i++) {
      final move = moves[i];
      final isP1 = move.p1;

      // 現局面の合法手数を計算
      final legalMoves = _countLegalMoves(board, p1Hand, p2Hand, isP1);
      totalLegalMoves += legalMoves;

      // 手質評価
      final quality = _evaluateMoveQuality(
        board: board,
        p1Hand: p1Hand,
        p2Hand: p2Hand,
        move: move,
        legalMoveCount: legalMoves,
        moveNum: i + 1,
      );

      qualityCounts[quality] = (qualityCounts[quality] ?? 0) + 1;

      // 形勢急変チェック
      if (prevLegalCount > 0 &&
          (legalMoves < prevLegalCount * 0.3 || legalMoves == 0)) {
        criticalMoves.add(i + 1);
      }
      prevLegalCount = legalMoves;

      // 最長考慮時間
      if (i < moveTimes.length && moveTimes[i] > longestThinkTime) {
        longestThinkTime = moveTimes[i];
        longestThinkMove = i + 1;
      }

      final comment = _generateComment(quality, legalMoves, move, i + 1);

      analyzedMoves.add(AnalyzedMove(
        moveNum: i + 1,
        move: move,
        quality: quality,
        comment: comment,
        legalMoveCount: legalMoves,
      ));

      // 盤面を進める
      try {
        GL.applyKifuMove(board, p1Hand, p2Hand, move);
      } catch (_) {
        break;
      }
    }

    return MatchAnalysisResult(
      matchId: matchId,
      analyzedMoves: analyzedMoves,
      player1Name: player1Name,
      player2Name: player2Name,
      totalMoves: moves.length,
      qualityCounts: qualityCounts,
      averageLegalMoves:
          moves.isEmpty ? 0 : totalLegalMoves / moves.length,
      longestThinkMoveNum: longestThinkMove,
      criticalMoveNumbers: criticalMoves,
    );
  }

  static List<int> _extractMoveTimes(Map<String, dynamic> matchData) {
    try {
      final movesRaw = matchData['moves'] as List? ?? [];
      return movesRaw.map((m) {
        final map = m as Map;
        return (map['think_time_ms'] as int? ?? 0);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static int _countLegalMoves(
    List<List<Piece?>> board,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
    bool isP1,
  ) {
    try {
      int count = 0;
      // 盤上の駒の移動
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          final p = board[r][c];
          if (p == null || p.isPlayer1 != isP1) continue;
          final moves = GL.legal(board, r, c);
          count += moves.length;
        }
      }
      // 打ち駒
      final hand = isP1 ? p1Hand : p2Hand;
      for (final entry in hand.entries) {
        if (entry.value > 0) {
          count += GL.dropSquares(board, entry.key, isP1, hand, isP1 ? p2Hand : p1Hand).length;
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  static MoveQuality _evaluateMoveQuality({
    required List<List<Piece?>> board,
    required Map<PieceType, int> p1Hand,
    required Map<PieceType, int> p2Hand,
    required KifuMove move,
    required int legalMoveCount,
    required int moveNum,
  }) {
    // 簡易評価ロジック：
    // 合法手数が少ない局面での手は重要度が高い
    // 駒を取る手 → 良い手に偏重
    // 打ち駒 → 普通以上

    // 駒を取る手か？
    final captured = (move.tr >= 0 && move.tc >= 0)
        ? board[move.tr][move.tc]
        : null;
    final isCaptureMove = captured != null;
    final isDrop = move.fr == -1;
    final isPromotion = move.promote;

    // 王手判定（適用後に王手か）
    try {
      final testBoard = GL.copy(board);
      final testP1 = Map<PieceType, int>.from(p1Hand);
      final testP2 = Map<PieceType, int>.from(p2Hand);
      GL.applyKifuMove(testBoard, testP1, testP2, move);

      final isCheckAfter = GL.inCheck(testBoard, !move.p1);
      final hasLegalAfter =
          GL.hasLegalMove(testBoard, !move.p1, !move.p1 ? testP1 : testP2);

      if (!hasLegalAfter && isCheckAfter) {
        return MoveQuality.excellent; // 詰み
      }
      if (isCheckAfter) {
        return MoveQuality.excellent; // 王手
      }
    } catch (_) {}

    // 確率的評価（本来はエンジン必須だが簡易版）
    if (isCaptureMove && isPromotion) return MoveQuality.excellent;
    if (isCaptureMove) return MoveQuality.good;
    if (isDrop && isPromotion == false) return MoveQuality.good;

    // 合法手数に基づく
    if (legalMoveCount <= 3) return MoveQuality.excellent; // 唯一の良い手
    if (legalMoveCount <= 10) return MoveQuality.good;
    if (legalMoveCount <= 30) return MoveQuality.inaccuracy;
    return MoveQuality.good; // デフォルト
  }

  static String _generateComment(
    MoveQuality quality,
    int legalMoves,
    KifuMove move,
    int moveNum,
  ) {
    switch (quality) {
      case MoveQuality.excellent:
        if (move.fr == -1) return '打ち駒で局面をコントロール';
        if (move.promote) return '成りで駒の価値を上昇';
        return '最善手！局面を有利に導く';
      case MoveQuality.good:
        if (legalMoves <= 5) return '限られた選択肢の中で最善に近い手';
        return '安定した指し手';
      case MoveQuality.inaccuracy:
        return '他にも良い手があったかもしれません';
      case MoveQuality.mistake:
        return '少し損な手です';
      case MoveQuality.blunder:
        return '形勢を大きく損なう手でした';
    }
  }
}

// ── 画面 ────────────────────────────────────────────────────────

class MatchAnalyzerScreen extends StatefulWidget {
  final String matchId;
  const MatchAnalyzerScreen({super.key, required this.matchId});

  @override
  State<MatchAnalyzerScreen> createState() => _MatchAnalyzerScreenState();
}

class _MatchAnalyzerScreenState extends State<MatchAnalyzerScreen> {
  final BoardSyncService _boardSync = BoardSyncService();
  final NetworkService _networkService = NetworkService();

  MatchAnalysisResult? _result;
  bool _loading = true;
  String? _error;
  int _selectedMoveIndex = -1; // -1 = 概要

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    try {
      // Firestore（ルール制限あり）ではなくRTDBから読む
      final snap = await FirebaseDatabase.instance
          .ref('games/${widget.matchId}')
          .get();

      if (!snap.exists || snap.value == null) {
        setState(() {
          _loading = false;
          _error = '対局データが見つかりません';
        });
        return;
      }

      final data = Map<String, dynamic>.from(snap.value as Map);

      // RTDBのmovesはpushキーのMap形式
      final moves = <KifuMove>[];
      final movesRaw = data['moves'];
      if (movesRaw != null) {
        final movesMap = Map<String, dynamic>.from(movesRaw as Map);
        final entries = movesMap.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        for (final e in entries) {
          final m = BoardSyncService.moveFromJson(e.value);
          if (m != null) moves.add(m);
        }
      }

      if (moves.isEmpty) {
        setState(() {
          _loading = false;
          _error = '棋譜データがありません（手が指されていない可能性があります）';
        });
        return;
      }

      final result = await SimpleAnalyzer.analyze(
        matchId: widget.matchId,
        moves: moves,
        player1Name: '先手',
        player2Name: '後手',
        matchData: data,
      );

      if (mounted) {
        setState(() {
          _result = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '分析エラー: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('棋譜分析', style: TextStyle(color: AppTheme.textHigh)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_result != null)
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white70),
              tooltip: 'KIF形式で共有',
              onPressed: _exportKif,
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.amber)),
                  SizedBox(height: 16),
                  Text('棋譜を分析中...',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.red)))
              : _buildContent(),
    );
  }

  Future<void> _exportKif() async {
    final result = _result;
    if (result == null) return;

    final moves = result.analyzedMoves.map((am) => am.move).toList();
    final kifText = KifuExportService.toKifString(
      moves,
      p1Name: result.player1Name,
      p2Name: result.player2Name,
    );

    await Share.share(kifText, subject: '棋譜_${widget.matchId}');
  }

  Widget _buildContent() {
    final result = _result!;
    return Row(
      children: [
        // 左：概要 + 棋譜リスト
        SizedBox(
          width: 200,
          child: _buildSidebar(result),
        ),
        // 右：選択手の詳細
        Expanded(
          child: _selectedMoveIndex < 0
              ? _buildSummary(result)
              : _buildMoveDetail(result),
        ),
      ],
    );
  }

  Widget _buildSidebar(MatchAnalysisResult result) {
    return Column(
      children: [
        // 概要ボタン
        InkWell(
          onTap: () => setState(() => _selectedMoveIndex = -1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: _selectedMoveIndex < 0
                ? Colors.brown.shade900
                : AppTheme.surface,
            child: Row(
              children: [
                const Icon(Icons.summarize, size: 14, color: Colors.amber),
                const SizedBox(width: 6),
                const Text('概要',
                    style: TextStyle(color: AppTheme.textHigh, fontSize: 13)),
              ],
            ),
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
        // 棋譜リスト
        Expanded(
          child: ListView.builder(
            itemCount: result.analyzedMoves.length,
            itemBuilder: (_, i) {
              final am = result.analyzedMoves[i];
              final isSelected = _selectedMoveIndex == i;
              final isCritical =
                  result.criticalMoveNumbers.contains(am.moveNum);

              return InkWell(
                onTap: () =>
                    setState(() => _selectedMoveIndex = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  color: isSelected
                      ? Colors.brown.shade900
                      : Colors.transparent,
                  child: Row(
                    children: [
                      // 手番号
                      SizedBox(
                        width: 32,
                        child: Text(
                          '${am.moveNum}',
                          style: TextStyle(
                            color: isCritical
                                ? Colors.orange
                                : AppTheme.textLow,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      // 手の表記
                      Expanded(
                        child: Text(
                          am.move.note,
                          style: const TextStyle(
                              color: AppTheme.textMid, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 品質アイコン
                      _QualityDot(quality: am.quality),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(MatchAnalysisResult result) {
    final uid = _networkService.currentUser?.uid;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトル
          Text(
            '${result.player1Name} vs ${result.player2Name}',
            style: const TextStyle(
                color: AppTheme.textHigh,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          Text(
            '全${result.totalMoves}手',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // 手の品質分布
          const Text(
            '手の品質',
            style: TextStyle(
                color: AppTheme.textMid,
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._buildQualityBars(result),

          const SizedBox(height: 24),

          // 統計
          _buildStatGrid(result),

          const SizedBox(height: 24),

          // 重要局面
          if (result.criticalMoveNumbers.isNotEmpty) ...[
            const Text(
              '注目の局面',
              style: TextStyle(
                  color: AppTheme.textMid,
                  fontSize: 14,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.criticalMoveNumbers
                  .take(10)
                  .map((n) => GestureDetector(
                        onTap: () => setState(
                            () => _selectedMoveIndex = n - 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade900,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '$n 手目',
                            style: const TextStyle(
                                color: AppTheme.textHigh, fontSize: 12),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],

          const SizedBox(height: 24),

          // アドバイス
          _buildAdvice(result),
        ],
      ),
    );
  }

  List<Widget> _buildQualityBars(MatchAnalysisResult result) {
    final items = [
      (MoveQuality.excellent, '最善手 ✨', Colors.green),
      (MoveQuality.good, '良い手 👍', Colors.blue),
      (MoveQuality.inaccuracy, '疑問手 ❓', Colors.yellow),
      (MoveQuality.mistake, '悪手 ❗', Colors.orange),
      (MoveQuality.blunder, '大悪手 💀', Colors.red),
    ];

    return items.map((item) {
      final (quality, label, color) = item;
      final count = result.qualityCounts[quality] ?? 0;
      final ratio = result.totalMoves > 0
          ? count / result.totalMoves
          : 0.0;

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style:
                      const TextStyle(color: AppTheme.textMid, fontSize: 12)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  backgroundColor: AppTheme.surfaceHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style:
                  const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildStatGrid(MatchAnalysisResult result) {
    return Row(
      children: [
        _StatBox(
          label: '平均合法手数',
          value: result.averageLegalMoves.toStringAsFixed(1),
          icon: '📊',
        ),
        const SizedBox(width: 12),
        _StatBox(
          label: '最長考慮手',
          value: '${result.longestThinkMoveNum}手目',
          icon: '🕐',
        ),
      ],
    );
  }

  Widget _buildAdvice(MatchAnalysisResult result) {
    final blunders = result.qualityCounts[MoveQuality.blunder] ?? 0;
    final mistakes = result.qualityCounts[MoveQuality.mistake] ?? 0;
    final excellent = result.qualityCounts[MoveQuality.excellent] ?? 0;

    String advice;
    Color bgColor;

    if (blunders >= 3) {
      advice = '大悪手が多く見られます。形勢判断を意識して、各局面で時間をかけて考えるようにしましょう。';
      bgColor = Colors.red.shade900;
    } else if (mistakes >= 3) {
      advice = '悪手が散見されます。終盤の詰め筋と中盤の駒組みを重点的に練習しましょう。';
      bgColor = Colors.orange.shade900;
    } else if (excellent > result.totalMoves * 0.5) {
      advice = '素晴らしい対局！最善手を多く選んでいます。この調子で上位を目指しましょう。';
      bgColor = Colors.green.shade900;
    } else {
      advice = 'バランスの良い対局です。疑問手を減らすことでさらなる上達が見込めます。';
      bgColor = Colors.blue.shade900;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor.withAlpha(120),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              advice,
              style: const TextStyle(color: AppTheme.textHigh, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoveDetail(MatchAnalysisResult result) {
    final am = result.analyzedMoves[_selectedMoveIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 手番
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: am.move.p1
                      ? Colors.brown.shade800
                      : Colors.indigo.shade800,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '第${am.moveNum}手 ${am.move.p1 ? "▲先手" : "△後手"}',
                  style: const TextStyle(
                      color: AppTheme.textHigh, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              _QualityChip(quality: am.quality),
            ],
          ),
          const SizedBox(height: 16),

          // 手の表記
          Text(
            am.move.note,
            style: const TextStyle(
                color: AppTheme.textHigh,
                fontSize: 24,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // コメント
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              am.comment,
              style: const TextStyle(
                  color: AppTheme.textMid, height: 1.5),
            ),
          ),
          const SizedBox(height: 16),

          // 局面統計
          _StatBox(
            label: 'この局面の合法手数',
            value: '${am.legalMoveCount}手',
            icon: '♟️',
          ),

          const SizedBox(height: 24),

          // ナビゲーション
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: _selectedMoveIndex > 0
                    ? () => setState(
                        () => _selectedMoveIndex--)
                    : null,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('前の手'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceHigh,
                    foregroundColor: Colors.white),
              ),
              ElevatedButton.icon(
                onPressed:
                    _selectedMoveIndex < result.analyzedMoves.length - 1
                        ? () => setState(
                            () => _selectedMoveIndex++)
                        : null,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('次の手'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceHigh,
                    foregroundColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── ウィジェット ──────────────────────────────────────────────────

class _QualityDot extends StatelessWidget {
  final MoveQuality quality;
  const _QualityDot({required this.quality});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _color(),
        shape: BoxShape.circle,
      ),
    );
  }

  Color _color() {
    switch (quality) {
      case MoveQuality.excellent:
        return Colors.green;
      case MoveQuality.good:
        return Colors.blue;
      case MoveQuality.inaccuracy:
        return Colors.yellow;
      case MoveQuality.mistake:
        return Colors.orange;
      case MoveQuality.blunder:
        return Colors.red;
    }
  }
}

class _QualityChip extends StatelessWidget {
  final MoveQuality quality;
  const _QualityChip({required this.quality});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (quality) {
      MoveQuality.excellent => ('最善手 ✨', Colors.green),
      MoveQuality.good => ('良い手 👍', Colors.blue),
      MoveQuality.inaccuracy => ('疑問手 ❓', Colors.yellow),
      MoveQuality.mistake => ('悪手 ❗', Colors.orange),
      MoveQuality.blunder => ('大悪手 💀', Colors.red),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(60),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String icon;
  const _StatBox(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            Text(label,
                style:
                    const TextStyle(color: AppTheme.textLow, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
