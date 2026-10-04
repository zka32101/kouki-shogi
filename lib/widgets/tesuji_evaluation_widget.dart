// lib/widgets/tesuji_evaluation_widget.dart — 手筋AI評価表示ウィジェット

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TesujiEvaluationWidget extends StatelessWidget {
  final String? bestMove;
  final int? score;
  final int? winRate;
  final bool isLoading;
  final VoidCallback onEvaluate;

  const TesujiEvaluationWidget({
    super.key,
    this.bestMove,
    this.score,
    this.winRate,
    this.isLoading = false,
    required this.onEvaluate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent, width: 2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Row(
            children: [
              const Icon(Icons.psychology, color: AppTheme.accent),
              const SizedBox(width: 12),
              const Text(
                'AI 評価（YaneuraOu）',
                style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 評価結果
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            )
          else if (bestMove != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 推奨手
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '推奨手:',
                        style: TextStyle(color: AppTheme.accent, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        bestMove!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // スコアと勝率
                Row(
                  children: [
                    Expanded(
                      child: _ScoreCard(
                        label: '評価値',
                        value: score != null ? '${score! > 0 ? '+' : ''}$score' : '—',
                        color: _scoreColor(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _WinRateCard(
                        label: '勝率',
                        value: winRate != null ? '$winRate%' : '—',
                        winRate: winRate ?? 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 説明テキスト
                Text(
                  _evaluationDescription(),
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            )
          else
            Text(
              '「評価を実行」を押してAI評価を表示',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),

          const SizedBox(height: 16),

          // 評価ボタン
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onEvaluate,
              icon: const Icon(Icons.smart_toy),
              label: Text(isLoading ? '評価中...' : '評価を実行'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor() {
    if (score == null) return Colors.grey;
    if (score! > 500) return Colors.green;
    if (score! > 0) return Colors.lightGreen;
    if (score! > -500) return Colors.orange;
    return Colors.red;
  }

  String _evaluationDescription() {
    if (score == null) return '';
    if (score! > 500) return '先手が大きく優勢';
    if (score! > 200) return '先手がやや優勢';
    if (score! > 0) return '先手がわずかに優勢';
    if (score! > -200) return '後手がわずかに優勢';
    if (score! > -500) return '後手がやや優勢';
    return '後手が大きく優勢';
  }
}

class _ScoreCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ScoreCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F3460),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _WinRateCard extends StatelessWidget {
  final String label;
  final String value;
  final int winRate;

  const _WinRateCard({
    required this.label,
    required this.value,
    required this.winRate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F3460),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accent, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: winRate / 100,
              minHeight: 4,
              backgroundColor: Colors.grey.shade700,
              valueColor: AlwaysStoppedAnimation<Color>(
                winRate > 50 ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
