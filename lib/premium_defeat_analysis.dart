import 'package:flutter/material.dart';

class PremiumDefeatAnalysisCard extends StatelessWidget {
  final int moveCount;
  final List<int>? evaluationHistory;
  final String? suggestedBestMove;
  final String? failedMove;
  final String opponentCharacterName;

  const PremiumDefeatAnalysisCard({
    required this.moveCount,
    this.evaluationHistory,
    this.suggestedBestMove,
    this.failedMove,
    required this.opponentCharacterName,
  });

  @override
  Widget build(BuildContext context) {
    // Null/empty チェック
    if (moveCount <= 0 || opponentCharacterName.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // AI感想戦セットヘッダー
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFFD700).withAlpha(40),
                const Color(0xFFFFA500).withAlpha(30),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFFFD700).withAlpha(150),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFFFFD700), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'AI感想戦セット',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                '敗北から学ぶための AI分析',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 敗着カード
        _buildDefeatMoveCard(),
        const SizedBox(height: 12),

        // AIキャラからのひと言
        _buildAICharacterMessage(),
      ],
    );
  }

  Widget _buildDefeatMoveCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics, color: Color(0xFF64B5F6), size: 16),
              SizedBox(width: 8),
              Text(
                '敗着分析',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 実際の手と最善手の比較
          if (failedMove != null && suggestedBestMove != null) ...[
            _buildMoveComparison(),
          ] else
            Text(
              '${moveCount}手目での対局でした。\n次の一局で学びを活かしましょう。',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
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
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF5350).withAlpha(40),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFEF5350).withAlpha(100),
                      ),
                    ),
                    child: Text(
                      failedMove ?? '???',
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
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '→',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white54,
                  fontWeight: FontWeight.bold,
                ),
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
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF64B5F6).withAlpha(40),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF64B5F6).withAlpha(100),
                      ),
                    ),
                    child: Text(
                      suggestedBestMove ?? '???',
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
        const SizedBox(height: 10),
        const Text(
          'この一手の差が対局全体に影響しました。',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildAICharacterMessage() {
    final messages = _getCharacterMessage();

    return Container(
      padding: const EdgeInsets.all(12),
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
              Icon(
                Icons.chat_bubble_outline,
                color: Colors.deepPurple.shade300,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                opponentCharacterName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            messages,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _getCharacterMessage() {
    // キャラクター別のメッセージ生成
    // 実装では、opponentCharacterId や性格に基づいて異なるメッセージを返す
    return '''${moveCount}手も粘ったね。終盤の工夫が見られたよ。

次の一局で「最善手の一歩」を目指そう。敗北は強くなるための最高の教材だ。''';
  }
}
