import 'package:flutter/material.dart';
import 'ai_personality.dart';
import 'premium_defeat_analysis.dart';
import 'screens/premium_screen.dart';
import 'theme/app_theme.dart';

class DefeatExperienceWidget extends StatelessWidget {
  final String result;
  final int moveCount;
  final String? opponentCharacterId;
  final bool isPremium;
  final int practicePoints;
  final int streakDays;
  final VoidCallback onClose;
  final List<int>? evaluationHistory;
  final String? suggestedBestMove;
  final String? failedMove;
  final String opponentCharacterName;

  const DefeatExperienceWidget({
    required this.result,
    required this.moveCount,
    required this.opponentCharacterId,
    required this.isPremium,
    required this.practicePoints,
    required this.streakDays,
    required this.onClose,
    this.evaluationHistory,
    this.suggestedBestMove,
    this.failedMove,
    this.opponentCharacterName = '謎の棋士',
  });

  @override
  Widget build(BuildContext context) {
    // Null/empty チェック
    if (result.isEmpty) return const SizedBox.shrink();

    // このウィジェットは常にプレイヤーの敗北時にのみ呼び出される
    // （呼び出し元 game_screen.dart の _showGameEndDialog で判定済み）。
    // 旧ロジックは「先手」「後手」の両方に「勝」が付けば真になる式で、
    // 投了時の勝者/敗者両方の呼称を含む文言により常にtrueになっていた。
    const isLoss = true;

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
            // ヘッダー
            _buildHeader(isLoss),
            const SizedBox(height: 24),

            // 無料層：修練値 + ストリーク
            _buildFreeRewards(),
            const SizedBox(height: 20),

            // プレミアムゲート
            if (isPremium)
              PremiumDefeatAnalysisCard(
                moveCount: moveCount,
                evaluationHistory: evaluationHistory,
                suggestedBestMove: suggestedBestMove,
                failedMove: failedMove,
                opponentCharacterName: opponentCharacterName,
              )
            else
              _buildUpgradePrompt(context),

            const SizedBox(height: 20),
            _buildCloseButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isLoss) {
    final mainText = isLoss ? '惜しい、あと一歩' : 'いい勝負だった';
    final subText = '$moveCount手の対局';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - v)),
          child: child,
        ),
      ),
      child: Column(
        children: [
          Text(
            mainText,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subText,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

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
              _buildRewardCard(
                icon: Icons.school,
                label: '修練値',
                value: '+$practicePoints',
                color: const Color(0xFF64B5F6),
              ),
              _buildRewardCard(
                icon: Icons.local_fire_department,
                label: '感想戦ストリーク',
                value: '+$streakDays日',
                color: const Color(0xFFFF7043),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard({
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

  Widget _buildPremiumPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD700).withAlpha(25),
            const Color(0xFFFFA500).withAlpha(15),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD700).withAlpha(100)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.stars, color: Color(0xFFFFD700), size: 20),
              const SizedBox(width: 8),
              const Text(
                'プレミアム AI感想戦セット',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFD700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '評価値グラフ、最善手の指摘、AIキャラの励ましで敗北から学ぶ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradePrompt(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFFD700).withAlpha(100),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'プレミアム登録で AI感想戦セットを利用できます',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFFFFD700),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
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
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onClose,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: const Text(
          '閉じる',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
