// lib/defeat_screen.dart — 敗北分析画面（プレミアム機能フル実装）
// 6つの要素を実装：評価値グラフ、学び1手、AIキャラの励まし、修練値、ストリーク、アクション

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'ai_personality.dart';
import 'piece.dart';
import 'mini_board_widget.dart';
import 'screens/premium_screen.dart';
import 'theme/app_theme.dart';

/// 敗北分析データモデル
class DefeatAnalysis {
  final int moveCount;
  final List<int> evaluations; // 各手の評価値（両プレイヤー統合）
  final String? bestMoveAtKey; // 重要な手での最善手
  final int bestMoveEval;
  final String? actualMove; // 実際に指した手
  final int actualEval;
  final bool playerWon;

  DefeatAnalysis({
    required this.moveCount,
    required this.evaluations,
    this.bestMoveAtKey,
    this.bestMoveEval = 0,
    this.actualMove,
    this.actualEval = 0,
    required this.playerWon,
  });
}

class DefeatScreen extends StatefulWidget {
  /// 対局の敗北データ
  final DefeatAnalysis analysis;

  /// AI キャラクター ID（personalityMapのキー）
  final String opponentCharacterId;

  /// AI キャラクター名（UIに表示）
  final String opponentCharacterName;

  /// プレミアム有料か
  final bool isPremium;

  /// 修練値（対局手数×5）
  final int practicePoints;

  /// 感想戦ストリーク（連続日数）
  final int streakDays;

  /// 評価値の推移グラフデータ
  final List<int>? evaluationHistory;

  /// 最良手の提案
  final String? suggestedBestMove;

  /// 実際の敗着
  final String? failedMove;

  /// 感想戦開始コールバック
  final VoidCallback? onViewAnalysis;

  /// もう一局開始コールバック
  final VoidCallback? onPlayAgain;

  /// 画面を閉じるコールバック
  final VoidCallback? onClose;

  const DefeatScreen({
    Key? key,
    required this.analysis,
    required this.opponentCharacterId,
    required this.opponentCharacterName,
    required this.isPremium,
    required this.practicePoints,
    required this.streakDays,
    this.evaluationHistory,
    this.suggestedBestMove,
    this.failedMove,
    this.onViewAnalysis,
    this.onPlayAgain,
    this.onClose,
  }) : super(key: key);

  @override
  State<DefeatScreen> createState() => _DefeatScreenState();
}

class _DefeatScreenState extends State<DefeatScreen> {
  late Future<Map<String, dynamic>> _analysisData;
  bool _isLoadingAnalysis = false;
  String? _evaluationSummary; // 「63手目まで互角」のようなテキスト

  @override
  void initState() {
    super.initState();
    _analysisData = _fetchEvaluationAnalysis();
  }

  /// Cloud Functions から評価値分析を取得
  Future<Map<String, dynamic>> _fetchEvaluationAnalysis() async {
    try {
      if (!widget.isPremium || widget.analysis.evaluations.isEmpty) {
        return {};
      }

      // 評価値推移から「互角だった手数」を計算
      _calculateEvaluationSummary();

      return {
        'loaded': true,
        'evaluations': widget.analysis.evaluations,
      };
    } catch (e) {
      print('Evaluation analysis error: $e');
      return {};
    }
  }

  /// 評価値推移から「○手目まで互角」というサマリーを生成
  void _calculateEvaluationSummary() {
    final evals = widget.analysis.evaluations;
    if (evals.isEmpty) return;

    // 互角の定義：評価値が [-100, 100] の範囲内
    int lastEvenMove = 0;
    for (int i = 0; i < evals.length; i++) {
      if (evals[i].abs() <= 100) {
        lastEvenMove = i + 1;
      }
    }

    if (lastEvenMove > 0) {
      setState(() {
        _evaluationSummary = '${lastEvenMove}手目まで互角でした。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ===== ヘッダー =====
            _buildHeader(),
            const SizedBox(height: 24),

            // ===== 修練値 + ストリーク（無料層） =====
            _buildFreeRewards(),
            const SizedBox(height: 20),

            // ===== プレミアム機能ゲート =====
            if (widget.isPremium) ...[
              // 1. 評価値グラフ
              _buildEvaluationGraph(),
              const SizedBox(height: 20),

              // 2. 学び1手
              _buildKeyMoveAnalysis(),
              const SizedBox(height: 20),

              // 3. AIキャラの励まし
              _buildCharacterEncouragement(),
              const SizedBox(height: 20),

              // 5. 連続感想戦ストリーク（プレミアム強調）
              _buildStreakBadge(),
              const SizedBox(height: 20),
            ] else
              _buildUpgradePrompt(context),

            // ===== アクション（感想戦 + もう一局） =====
            _buildActionButtons(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ===== 1. ヘッダー =====
  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          widget.analysis.playerWon ? 'いい勝利' : '惜しい、あと一歩',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.analysis.moveCount}手の対局',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  // ===== 2. 修練値 + ストリーク（無料層） =====
  Widget _buildFreeRewards() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          const Text(
            '対局から獲得',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildRewardBadge(
                icon: Icons.school,
                label: '修練値',
                value: '+${widget.practicePoints}',
                color: const Color(0xFF64B5F6),
              ),
              _buildRewardBadge(
                icon: Icons.local_fire_department,
                label: '連続感想戦',
                value: '+${widget.streakDays}日',
                color: const Color(0xFFFF7043),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRewardBadge({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  // ===== 3. 評価値グラフ（プレミアム） =====
  Widget _buildEvaluationGraph() {
    if (!widget.isPremium || widget.analysis.evaluations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: Color(0xFF64B5F6), size: 16),
              const SizedBox(width: 8),
              const Text(
                '対局評価値推移',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '◆ プレミアム',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // グラフ
          SizedBox(
            height: 180,
            child: _buildBarChart(),
          ),

          const SizedBox(height: 12),

          // サマリーテキスト
          if (_evaluationSummary != null)
            Text(
              _evaluationSummary!,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  /// fl_chart BarChart を使った評価値グラフ
  Widget _buildBarChart() {
    final evals = widget.analysis.evaluations;
    if (evals.isEmpty) {
      return const Center(
        child: Text(
          'No evaluation data',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    // 最大評価値を算出（グラフスケール用）
    final maxEval = (evals.isNotEmpty
            ? evals.reduce((a, b) => a.abs() > b.abs() ? a : b).abs()
            : 300)
        .toDouble();
    final scale = (maxEval > 0 ? maxEval : 300) * 1.2; // 20% マージン

    // グラフデータ作成（全手数はスキップして、分析対象のみ表示）
    final spots = <BarChartGroupData>[];
    final step = (evals.length / 15).ceil(); // 最大15本まで
    for (int i = 0; i < evals.length; i += step) {
      final eval = evals[i].toDouble();
      final color = eval >= 100
          ? const Color(0xFF4CAF50)
          : eval <= -100
              ? const Color(0xFFEF5350)
              : const Color(0xFF64B5F6);

      spots.add(
        BarChartGroupData(
          x: i ~/ step,
          barRods: [
            BarChartRodData(
              toY: eval,
              color: color,
              width: 8,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(2),
                bottom: Radius.circular(2),
              ),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        barGroups: spots,
        maxY: scale,
        minY: -scale,
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          horizontalInterval: scale / 3,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white12,
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}',
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
              reservedSize: 40,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: false,
              reservedSize: 0,
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        backgroundColor: Colors.transparent,
      ),
    );
  }

  // ===== 4. 学び1手（プレミアム） =====
  Widget _buildKeyMoveAnalysis() {
    if (!widget.isPremium) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.deepOrange.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: Color(0xFFFFB74D), size: 18),
              const SizedBox(width: 8),
              const Text(
                '学び1手',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFB74D),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB74D).withAlpha(40),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  '◆ プレミアム',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFFFFB74D),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (widget.suggestedBestMove != null && widget.failedMove != null)
            _buildMoveComparison()
          else
            Text(
              'この対局で特に目立つ敗着はありませんでした。\n全体的な指し回しの改善を心がけましょう。',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                height: 1.6,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMoveComparison() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '指した手',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF5350).withAlpha(40),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFEF5350).withAlpha(100),
                      ),
                    ),
                    child: Text(
                      widget.failedMove ?? '???',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEF5350),
                        fontFamily: 'Monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                Icons.arrow_forward,
                color: Colors.white54,
                size: 20,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '最善手',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF64B5F6).withAlpha(40),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF64B5F6).withAlpha(100),
                      ),
                    ),
                    child: Text(
                      widget.suggestedBestMove ?? '???',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64B5F6),
                        fontFamily: 'Monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'この一手の判断が、対局全体に大きく影響しました。\n次の一局では、この状況を意識して指してみましょう。',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  // ===== 5. AIキャラの励まし（プレミアム） =====
  Widget _buildCharacterEncouragement() {
    if (!widget.isPremium) {
      return const SizedBox.shrink();
    }

    final message = _getCharacterMessage();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.deepPurple.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_bubble, color: Color(0xFFCE93D8), size: 18),
              const SizedBox(width: 8),
              Text(
                widget.opponentCharacterName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade300,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withAlpha(40),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  '◆ プレミアム',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  /// キャラクターのメッセージを生成
  String _getCharacterMessage() {
    final moveCount = widget.analysis.moveCount;

    // 単純な例：キャラクターIDごとのメッセージテンプレート
    switch (widget.opponentCharacterId) {
      case 'samurai':
        return '${moveCount}手も粘ったな。終盤の粘り、前より強くなっている。\n\n敗北は強くなるための最高の修行だ。\n次の一局で必ず己を超えよ。';

      case 'ninja':
        return '${moveCount}手…悪くない。影の世界では、敗北こそが最高の教材だ。\n\n次は隙を与えるな。もう一度来い。';

      case 'kenshi':
        return '${moveCount}手で剣を交えた。前より体が動いている。\n\n敗北は恥ではない。それを認め、次の剣を研ぐ心が大事なのだ。';

      case 'princess':
        return '${moveCount}手、頑張りましたね。\n\n敗北から学べることが、勝利より大きいときだってあります。\n次の一局を応援しています。';

      case 'priest':
        return '${moveCount}手の対局…。敗北の中に、成長の芽があります。\n\n着実に一歩ずつ。その道こそが悟りへの近道なのです。';

      default:
        return '${moveCount}手の対局でしたね。\n\n敗北は次の成功へのステップです。\n今の経験を大切に、また一緒に棋を学びましょう。';
    }
  }

  // ===== 6. 連続感想戦ストリーク（プレミアム強調） =====
  Widget _buildStreakBadge() {
    if (!widget.isPremium || widget.streakDays < 1) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF7043).withAlpha(30),
            const Color(0xFFFFB74D).withAlpha(20),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFF7043).withAlpha(100)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department, color: Color(0xFFFF7043), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.streakDays}日連続感想戦',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF7043),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '敗北から学ぶ習慣が身についています',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF7043).withAlpha(40),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '◆',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFFF7043),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== アップグレード提案（無料層） =====
  Widget _buildUpgradePrompt(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD700).withAlpha(30),
            const Color(0xFFFFA500).withAlpha(20),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD700).withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFFFFD700), size: 18),
              const SizedBox(width: 8),
              const Text(
                'プレミアム AI感想戦セット',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFD700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '評価値グラフ、最善手の指摘、AIキャラの励まし、ストリーク表示…\n\n敗北を成長に変える機能が全て揃っています。',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PremiumScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: AppTheme.surface,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'プレミアムを見る',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 7. アクションボタン =====
  Widget _buildActionButtons() {
    return Column(
      children: [
        // 感想戦ボタン
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onViewAnalysis ?? () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF64B5F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics, size: 18),
                SizedBox(width: 8),
                Text(
                  '感想戦をはじめる',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // もう一局ボタン
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onPlayAgain ?? () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh, size: 18),
                SizedBox(width: 8),
                Text(
                  'もう一局',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
